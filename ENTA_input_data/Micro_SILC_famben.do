********************************************************************************
* Individualise family benefits (HY050G) to persons
********************************************************************************
*
* PURPOSE
* EU-SILC records family benefits (HY050G) at the household level. This
* script distributes them to individual household members, creating the
* person-level variable HY050Gp ("individualised family benefits, gross").
*
* DISTRIBUTION RULE
************************************************************
*   1. Identify children in education (under 35, ACTIVITY == 1).
*   2. Link each child to their father (RB220) and/or mother (RB230),
*      verifying that the parent actually lives in the same household.
*   3. Allocate benefits to parents of children in education, INVERSELY
*      proportional to each partner's income share within the couple
*      (the lower earner, who does more childcare, gets more).
*   4. If no child in education can be attributed to anyone in the
*      household, distribute benefits to ALL adults, also inversely
*      proportional to their income share.
*
* CALLING CONVENTION
************************************************************
* This is NOT a standalone file. It is called via `do Micro_SILC_famben.do`
* from within Micro_SILC.do (Section 3.1), and operates on the dataset
* already in memory. It expects the following variables to exist:
*
*   ACTIVITY, AGE, RB220, RB230     (education status, parent IDs)
*   HHID, YEAR, PID                 (household/person identifiers)
*   COUPLEID, ADULT, NADULT         (couple and adult indicators)
*   HY050G                          (household-level family benefits)
*   PY010G-PY140G                   (personal income components -> PYG)
*
* OUTPUT
*   Adds: HY050Gp (individualised family benefits, gross)
*   Drops all helper variables at the end.
********************************************************************************


********************************************************************************
* STEP 1:  Compute total personal income (PYG) for income-share calculations
********************************************************************************
*
* PYG is the sum of all gross personal income components. It is used below
* to determine each partner's share of couple income and each adult's share
* of household income.

gen double PYG = PY010G + PY020G + PY050G + PY080G + PY090G + PY100G ///
    + PY110G + PY120G + PY130G + PY140G

tempfile data
save `data', replace


********************************************************************************
* STEP 2:  Build a lookup of co-resident household members
********************************************************************************
*
* EU-SILC's father/mother ID fields (RB220/RB230) can remain filled even
* when the parent (or child) has left the household. A simple missing-value
* check is not enough - we need to verify that the ID actually belongs to
* someone living in the same household and year. This lookup file is used
* for that verification below.

preserve
keep YEAR HHID PID
tempfile hhmembers
save `hhmembers'
restore


********************************************************************************
* STEP 3:  Identify children of fathers (via RB220)
********************************************************************************
*
* For each child whose father (RB220) is co-resident, count:
*   - EDUCHILD: how many of the father's children are in education
*   - NCHILD:   how many of the father's children live in the household
*
* The result is one row per father (identified by PID), saved in `fatherdata'.

* Flag children currently in education (under 35)
gen byte EDUC = (ACTIVITY == 1 & AGE < 35)
label var EDUC "in education and younger than 35"

* Verify that the father actually lives in this household
drop PID
rename RB220 PID
merge m:1 YEAR HHID PID using `hhmembers', keep(master match)
rename PID RB220
replace RB220 = . if _merge != 3    // parent not co-resident or ID missing
drop _merge

* Keep only children with an identified co-resident father
keep EDUC RB220 HHID YEAR
drop if RB220 == .
rename RB220 PID                     // father's ID becomes merge key

* Group siblings (children sharing the same father in the same HH)
egen SIBLING = group(YEAR HHID PID)
sort SIBLING

* Count children in education and total children per father
by SIBLING: egen EDUCHILD = total(EDUC == 1)
label var EDUCHILD "number of children in education"

bysort YEAR HHID SIBLING: egen NCHILD = count(PID)
label var NCHILD "number of children"

* Keep one row per father
egen SIBLINGTAG = tag(SIBLING)
keep if SIBLINGTAG == 1

sort YEAR PID
tempfile fatherdata
save `fatherdata'


********************************************************************************
* STEP 4:  Identify children of mothers (via RB230)
********************************************************************************
*
* Same logic as Step 3, but using the mother's ID (RB230).

use `data', clear

gen byte EDUC = (ACTIVITY == 1 & AGE < 35)
label var EDUC "in education and younger than 35"

* Verify that the mother actually lives in this household
drop PID
rename RB230 PID
merge m:1 YEAR HHID PID using `hhmembers', keep(master match)
rename PID RB230
replace RB230 = . if _merge != 3
drop _merge

* Keep only children with an identified co-resident mother
keep EDUC RB230 HHID YEAR
drop if RB230 == .
rename RB230 PID

* Group siblings and count
egen SIBLING = group(YEAR HHID PID)
sort SIBLING

by SIBLING: egen EDUCHILD = total(EDUC == 1)
label var EDUCHILD "number of children in education"

bysort YEAR HHID SIBLING: egen NCHILD = count(PID)
label var NCHILD "number of children"

egen SIBLINGTAG = tag(SIBLING)
keep if SIBLINGTAG == 1

sort YEAR PID
tempfile motherdata
save `motherdata'


********************************************************************************
* STEP 5:  Merge father and mother information back onto all persons
********************************************************************************
*
* Each person now gets EDUCHILD and NCHILD if they are identified as a
* parent. A person listed as both father and mother (rare: ~40 cases in the
* 2025 release) keeps the father values (the `update` option preserves
* non-missing values from the first merge).

use `data', clear

sort YEAR PID
merge 1:1 YEAR PID using `fatherdata', update
drop _merge

sort YEAR PID
merge 1:1 YEAR PID using `motherdata', update
drop _merge


********************************************************************************
* STEP 6:  Distribute family benefits to individual household members
********************************************************************************


************************************************************
* 6a.  Compute each partner's income share within the couple
************************************************************
*
* The income share is bounded to [0, 1] to prevent negative benefits when
* one partner has negative income. If couple income is not positive, no
* share is computed and benefits are split equally (below).

bysort YEAR HHID COUPLEID: egen double inc_couple = sum(PYG) if COUPLEID != .

gen double incshare_couple = min(max(PYG / inc_couple, 0), 1) ///
    if inc_couple > 0 & inc_couple < .


************************************************************
* 6b.  Determine number of children in education per parent
************************************************************
*
* Within couples, take the maximum EDUCHILD: couples are assumed to care
* jointly for children, even if only one partner is the biological parent.
* Parents who live together but are NOT identified as a couple (no common
* COUPLEID) each keep their own count and share equally.

bysort YEAR HHID COUPLEID: egen NEDUCHILD = max(EDUCHILD) if COUPLEID != .
replace NEDUCHILD = EDUCHILD if COUPLEID == .


************************************************************
* 6c.  Weight by inverse income share (lower earner gets more)
************************************************************
*
* Multiply children-in-education count by (1 - income share), so the
* partner with less income gets a larger weight.

replace NEDUCHILD = NEDUCHILD * (1 - incshare_couple) if incshare_couple != .


************************************************************
* 6d.  Normalise weights to sum to 1 within each household
************************************************************

bysort YEAR HHID: egen double NEDUCHILDHH = sum(NEDUCHILD)
replace NEDUCHILD = NEDUCHILD / NEDUCHILDHH


************************************************************
* 6e.  Fallback: if no children in education, distribute to all adults
************************************************************
*
* When no child in education can be attributed to anyone in the household
* (NEDUCHILDHH == 0), benefits go to all adults, inversely proportional to
* their share of the adults' total income. Equal shares if that income is
* not positive or there is only one adult.

drop NEDUCHILDHH
bysort YEAR HHID: egen double NEDUCHILDHH = sum(NEDUCHILD)

* Adults' total primary income within the household
bysort YEAR HHID: egen double famb_inc = sum(PYG * (ADULT == 1))

* Each adult's inverse income weight, bounded to [0, 1]
gen double famb_w = 1 - min(max(PYG / famb_inc, 0), 1) ///
    if ADULT == 1 & famb_inc > 0 & famb_inc < .

bysort YEAR HHID: egen double famb_sw = sum(famb_w)

* Apply fallback weights where no child-in-education was found
replace NEDUCHILD = famb_w / famb_sw ///
    if ADULT == 1 & NEDUCHILDHH == 0 & famb_sw > 0

* Equal split among adults when income-based weights are unavailable
replace NEDUCHILD = 1 / NADULT ///
    if ADULT == 1 & NEDUCHILDHH == 0 & !(famb_sw > 0)

drop famb_inc famb_w famb_sw


************************************************************
* 6f.  Compute individualised family benefits
************************************************************

gen double HY050Gp = HY050G * NEDUCHILD
replace HY050Gp = 0 if HY050Gp == .
label var HY050Gp "Individualized family benefits, gross"


********************************************************************************
* STEP 7:  Clean up helper variables
********************************************************************************
*
* None of these variables is used after this point, either in Micro_SILC.do
* or in any downstream file. EDUC in particular is the education status of
* one of the person's CHILDREN, not the person's own status.

drop PYG EDUC SIBLING SIBLINGTAG EDUCHILD NCHILD ///
    NEDUCHILD NEDUCHILDHH inc_couple incshare_couple
