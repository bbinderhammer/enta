********************************************************************************
* ENTA output control 1: is the method applied correctly?
********************************************************************************
*
* Five checks on the files in ENTA_output_data:
*   1. Profiles add up to the aggregates
*   2. Components add up to their totals (aggregates and profiles)
*   3. Men + women = total
*   4. No negative values where none are possible
*   5. Every profile has ages 0-80 for men, women and total
*
* Each check holds or does not hold; nothing is judged.
*
* HOW TO RUN (about 1 minute; no setup file needed)
*   Open Stata, cd to the ENTA root folder, then:
*       do ENTA_output_control/1_method_check.do
*
* INPUT   ENTA_output_data/ENTA_esa.dta, ENTA_nta.dta, ENTA_aggregates.dta
*
* OUTPUT  ENTA_output_control/results/1_method_check_summary.csv
*             one row per test: cases tested, cases failed
*         ENTA_output_control/results/1_method_check_violations.csv
*             one row per failure: country, year, indicator, what is wrong
*         The summary is also printed on screen at the end.
*
* TOLERANCES (rounding in the published files)
local tol_mio 10       // aggregates and profile totals: 10 mio EUR ...
local tol_rel 0.0001   // ... and 0.01% of the value (both must be exceeded)
local tol_eur 1        // profiles: 1 EUR per person

* Indicators that are not money amounts (rates, hours) - no aggregate, skipped
* in checks 1 and 3
local notmoney `""EHI","EMPLSTAT","EMPLSTATsilc","EMPLFT","WHRUSUT","WHRACTT""'

********************************************************************************
* 0. Preparation
********************************************************************************

clear
set more off
capture mkdir ENTA_output_control/results

* Failure log: collects all violations across checks
tempfile viol
gen str40 CHECK = ""
gen str12 FILE  = ""
gen str10 CNT2  = ""
gen YEAR        = .
gen str40 IND   = ""
gen str120 WHAT = ""
gen double DIFF = .
save `viol', emptyok
global VIOL "`viol'"

* Summary log: one row per test (posted via postfile)
tempfile summary
capture postclose summ
postfile summ str40 CHECK str12 FILE str60 ITEM double(TESTED FAILED) using `summary'

* keep_violations: appends the current dataset (assumed to contain only
* failing rows) to the failure log. Needs CNT2 YEAR IND WHAT DIFF.
capture program drop keep_violations
program define keep_violations
    args check file
    gen str40 CHECK = "`check'"
    gen str12 FILE  = "`file'"
    keep CHECK FILE CNT2 YEAR IND WHAT DIFF
    append using "$VIOL"
    save "$VIOL", replace
end

* identity: tests "lhs = rhs" on wide-format data (one variable per indicator).
* A cell fails if the absolute difference exceeds tolabs AND tolrel x |lhs|.
* Missing components cause the cell to be skipped (missing propagation).
capture program drop identity
program define identity
    args check file lhs rhs tolabs tolrel
    * Check that every variable in the expression exists in the file
    local codes `lhs' `rhs'
    local codes : subinstr local codes "+" "", all
    local codes : subinstr local codes "-" "", all
    foreach c of local codes {
        capture confirm variable `c', exact
        if _rc {
            display as text "  not tested, `c' is not in the file: `lhs' = `rhs'"
            post summ ("`check'") ("`file'") ("`lhs' = `rhs' (not tested: no `c')") (.) (.)
            exit
        }
    }
    tempvar l d
    gen double `l' = `lhs'
    gen double `d' = `l' - (`rhs')
    quietly count if `d' < .
    local tested = r(N)
    gen byte BAD = abs(`d') > `tolabs' & abs(`d') > `tolrel'*abs(`l') & `d' < .
    quietly count if BAD
    local failed = r(N)
    post summ ("`check'") ("`file'") ("`lhs' = `rhs'") (`tested') (`failed')
    if `failed' > 0 {
        preserve
        keep if BAD
        gen double ABSD = abs(`d')
        collapse (max) DIFF=ABSD (count) NCELL=ABSD, by(CNT2 YEAR)
        gen str40 IND = "`lhs'"
        gen str120 WHAT = "`lhs' = `rhs': " + string(NCELL) + " cell(s), largest difference " + string(DIFF, "%12.2f")
        keep_violations "`check'" "`file'"
        restore
    }
    drop BAD
end

* Load the aggregates (one row per country, year, sector and indicator)
use CNT2 YEAR IND SECTOR VALAGGR using ENTA_output_data/ENTA_aggregates, clear
isid CNT2 YEAR IND SECTOR
tempfile agg
save `agg'

********************************************************************************
* 1. Profiles add up to the aggregates
********************************************************************************
* Sum over ages of (value per person x population), in mio EUR, compared with
* the national total in ENTA_aggregates.
*
* Which total belongs to a profile: the one with the same indicator code, in
*   ENTA_esa  ->  sector Households; public consumption (CG, CGE, CGH, CGX) in
*                 sector Government; indicators ending in C in Corporations
*   ENTA_nta  ->  sector "NTA Aggregates"
*
* Profiles without a national total are not tested and are listed on screen:
* transfers within households (BPW, TPW, TFW, TFWI, TFWO), which the national
* accounts do not record, and the variants of disposable income (YD1-YD3).

foreach f in esa nta {
    use CNT2 YEAR AGE VALUE IND SEX using ENTA_output_data/ENTA_`f' if SEX=="Total", clear

    * Get the population (one of the "indicators" in the same file)
    preserve
    keep if IND=="POP"
    rename VALUE POP
    keep CNT2 YEAR AGE POP
    tempfile pop
    save `pop'
    restore
    drop if IND=="POP" | inlist(IND, `notmoney')
    merge m:1 CNT2 YEAR AGE using `pop', assert(match) nogen

    * Profile total in mio EUR. An all-missing profile stays missing
    * (collapse (sum) would turn it into 0).
    gen double MIO = VALUE*POP/1e6
    collapse (sum) PROFILE=MIO (count) NVAL=VALUE, by(CNT2 YEAR IND)
    replace PROFILE = . if NVAL==0

    * Sector of the national total
    gen str14 SECTOR = "NTA Aggregates"
    if "`f'"=="esa" {
        replace SECTOR = "Households"
        replace SECTOR = "Government"   if inlist(IND,"CG","CGE","CGH","CGX")
        replace SECTOR = "Corporations" if inlist(IND,"YC","TC","BPBC","BPPC","SC")
    }
    merge 1:1 CNT2 YEAR IND SECTOR using `agg', keep(master match)

    * Profiles without a national total in any country or year: list and skip
    bysort IND: egen HASAGG = max(_merge==3)
    quietly levelsof IND if HASAGG==0, local(noagg) clean
    display as text _n "Check 1, ENTA_`f': no national total, not tested:" _n "  `noagg'"
    drop if HASAGG==0

    * Compare profile total with aggregate
    gen double DIFF = PROFILE - VALAGGR
    gen byte BAD = 0
    replace BAD = 1 if PROFILE<. & VALAGGR<. & abs(DIFF)>`tol_mio' & abs(DIFF)>`tol_rel'*abs(VALAGGR)
    replace BAD = 1 if PROFILE<. & VALAGGR==. & abs(PROFILE)>`tol_mio' // profile exists, aggregate missing
    replace BAD = 1 if PROFILE==. & VALAGGR<. & abs(VALAGGR)>`tol_mio' // aggregate exists, profile missing

    quietly count
    local tested = r(N)
    quietly count if BAD
    post summ ("1 Profiles = aggregates") ("`f'") ("all profiles with an aggregate") (`tested') (r(N))

    keep if BAD
    gen str120 WHAT = "profile " + string(PROFILE, "%14.1f") + " against aggregate " + string(VALAGGR, "%14.1f") + " mio EUR (" + SECTOR + ")"
    keep_violations "1 Profiles = aggregates" "`f'"
}

********************************************************************************
* 2. Components add up to their totals
********************************************************************************

* 2a. Aggregates, sector Households (mio EUR)
use `agg' if SECTOR=="Households", clear
drop SECTOR
reshape wide VALAGGR, i(CNT2 YEAR) j(IND) string
rename VALAGGR* *

local c "2 Components = total"
identity "`c'" "aggregates" "Y"     "YEM + YA"                       `tol_mio' `tol_rel'
identity "`c'" "aggregates" "YEM"   "YE + YM"                        `tol_mio' `tol_rel'
identity "`c'" "aggregates" "YA"    "YP + YO"                        `tol_mio' `tol_rel'
identity "`c'" "aggregates" "T"     "TYEM + TYA + TB + TCON + TX"    `tol_mio' `tol_rel'
identity "`c'" "aggregates" "TB"    "TBSPEN + TBSN + TBPPEN"         `tol_mio' `tol_rel'
identity "`c'" "aggregates" "TX"    "TXH + TXNPISH"                  `tol_mio' `tol_rel'
identity "`c'" "aggregates" "BS"    "BSPEN + BSFAM + BSU + BSX"      `tol_mio' `tol_rel'
identity "`c'" "aggregates" "BPPEN" "BPSOCfc - TPSOCfc"              `tol_mio' `tol_rel'
identity "`c'" "aggregates" "CH"    "CHE + CHH + CHR + CHX"          `tol_mio' `tol_rel'

* 2b. Profiles in ENTA_esa (EUR per person, every age and sex)
use CNT2 YEAR AGE SEX VALUE IND using ENTA_output_data/ENTA_esa, clear
drop if IND=="POP" | inlist(IND, `notmoney')
reshape wide VALUE, i(CNT2 YEAR SEX AGE) j(IND) string
rename VALUE* *

identity "`c'" "esa" "Y"     "YEM + YA"                       `tol_eur' 0
identity "`c'" "esa" "YEM"   "YE + YM"                        `tol_eur' 0
identity "`c'" "esa" "YA"    "YP + YO"                        `tol_eur' 0
identity "`c'" "esa" "T"     "TYEM + TYA + TB + TCON + TX"    `tol_eur' 0
identity "`c'" "esa" "TB"    "TBSPEN + TBSN + TBPPEN"         `tol_eur' 0
identity "`c'" "esa" "BS"    "BSPEN + BSFAM + BSU + BSX"      `tol_eur' 0
identity "`c'" "esa" "BPPEN" "BPSOCfc - TPSOCfc"              `tol_eur' 0
identity "`c'" "esa" "BP"    "BPB + BPW - TPW"                `tol_eur' 0
identity "`c'" "esa" "CH"    "CHE + CHH + CHR + CHX"          `tol_eur' 0
identity "`c'" "esa" "CG"    "CGE + CGH + CGX"                `tol_eur' 0

* 2c. Profiles in ENTA_nta (EUR per person, every age and sex)
use CNT2 YEAR AGE SEX VALUE IND using ENTA_output_data/ENTA_nta, clear
drop if IND=="POP"
reshape wide VALUE, i(CNT2 YEAR SEX AGE) j(IND) string
rename VALUE* *

identity "`c'" "nta" "Y"     "YL + YA"                        `tol_eur' 0
identity "`c'" "nta" "YA"    "YAF + YAG"                      `tol_eur' 0
identity "`c'" "nta" "YAF"   "YAH + YAC"                      `tol_eur' 0
identity "`c'" "nta" "C"     "CF + CG"                        `tol_eur' 0
identity "`c'" "nta" "CF"    "CFE + CFH + CFR + CFX"          `tol_eur' 0
identity "`c'" "nta" "CG"    "CGE + CGH + CGX"                `tol_eur' 0
identity "`c'" "nta" "S"     "SF + SG"                        `tol_eur' 0
identity "`c'" "nta" "YDF"   "CF + SF"                        `tol_eur' 0
identity "`c'" "nta" "YDH"   "CF + SH"                        `tol_eur' 0
identity "`c'" "nta" "YDC"   "SC"                             `tol_eur' 0
* Life-cycle identity: C + S = Y + net transfers
identity "`c'" "nta" "C + S" "YL + YAF + YAG + TFB + TFW - TGO + TGI"  `tol_eur' 0

********************************************************************************
* 3. Men + women = total
********************************************************************************
* Population: checked at every age (tolerance 1 person).
* Profiles: value x population summed over ages, in mio EUR; tolerance 0.01%
* of the sum of absolute amounts.

foreach f in esa nta {
    use CNT2 YEAR AGE SEX VALUE IND using ENTA_output_data/ENTA_`f', clear

    * Population by sex: men + women must equal total at every age
    preserve
    keep if IND=="POP"
    rename VALUE POP
    drop IND
    tempfile popsex
    save `popsex'
    reshape wide POP, i(CNT2 YEAR AGE) j(SEX) string
    gen double DIFF = POPMen + POPWomen - POPTotal
    quietly count
    local tested = r(N)
    keep if abs(DIFF) > 1
    quietly count
    post summ ("3 Men + women = total") ("`f'") ("population, every age") (`tested') (r(N))
    gen str40 IND = "POP"
    gen str120 WHAT = "age " + string(AGE) + ": men + women - total = " + string(DIFF, "%12.1f") + " persons"
    keep_violations "3 Men + women = total" "`f'"
    restore

    * Profiles: value x population summed over ages, in mio EUR
    drop if IND=="POP" | inlist(IND, `notmoney')
    merge m:1 CNT2 YEAR AGE SEX using `popsex', assert(match) nogen
    gen double M = VALUE*POP/1e6
    gen double A = abs(M)
    collapse (sum) M A, by(CNT2 YEAR IND SEX)
    reshape wide M A, i(CNT2 YEAR IND) j(SEX) string
    gen double DIFF = MMen + MWomen - MTotal
    quietly count
    local tested = r(N)
    keep if abs(DIFF) > `tol_rel'*max(ATotal, 1)
    quietly count
    post summ ("3 Men + women = total") ("`f'") ("profiles, summed over ages") (`tested') (r(N))
    gen str120 WHAT = "men + women - total = " + string(DIFF, "%12.2f") + " mio EUR"
    keep_violations "3 Men + women = total" "`f'"
}

********************************************************************************
* 4. No negative values where none are possible
********************************************************************************
* Consumption, benefits received and income components cannot be negative.
* Threshold: -0.5 EUR per person (the files are rounded to integers).
* Exception: Estonian funded-pension benefits (BPSOCfc), where Eurostat itself
* reports negative values.

foreach f in esa nta {
    use CNT2 YEAR AGE SEX VALUE IND using ENTA_output_data/ENTA_`f', clear
    gen byte NONNEG = 0
    if "`f'"=="esa" {
        replace NONNEG = 1 if inlist(IND,"CH","CHE","CHH","CHR","CHX","CG","CGE","CGH","CGX")
        replace NONNEG = 1 if inlist(IND,"BS","BSFAM","BSU","BSX","BSPEN","TBPPEN")
        replace NONNEG = 1 if inlist(IND,"YE","YM","YEM","YO","POP")
        replace NONNEG = 1 if IND=="BPSOCfc" & CNT2!="EE"
    }
    else {
        replace NONNEG = 1 if inlist(IND,"C","CF","CFE","CFH","CFR","CFX","CG","CGE","CGH")
        replace NONNEG = 1 if inlist(IND,"CGX","TGIC","TGICF","TGICU","TGICX","TGICPEN","YL","POP")
    }
    keep if NONNEG
    quietly count
    local tested = r(N)
    keep if VALUE < -0.5
    quietly count
    local failed = r(N)
    post summ ("4 No negative values") ("`f'") ("cells (country, year, indicator, sex, age)") (`tested') (`failed')
    if `failed' > 0 {
        collapse (min) DIFF=VALUE (count) NCELL=VALUE, by(CNT2 YEAR IND)
        gen str120 WHAT = string(NCELL) + " negative cell(s), lowest value " + string(DIFF, "%12.1f") + " EUR per person"
        keep_violations "4 No negative values" "`f'"
    }
}

********************************************************************************
* 5. Every profile has ages 0-80 for men, women and total
********************************************************************************
* Each country, year, indicator and sex must have exactly 81 rows (ages 0-80).
* Missing values (source does not report them) are counted for information but
* are not failures.

foreach f in esa nta {
    use CNT2 YEAR AGE SEX VALUE IND using ENTA_output_data/ENTA_`f', clear
    quietly count if VALUE==.
    local nmiss = r(N)
    display as text _n "Check 5, ENTA_`f': missing values by indicator (information, not a failure)"
    capture noisily tabulate IND if VALUE==.

    collapse (count) NROW=AGE (min) AGEMIN=AGE (max) AGEMAX=AGE, by(CNT2 YEAR IND SEX)
    quietly count
    local tested = r(N)
    post summ ("5 Ages 0-80 complete") ("`f'") ("information: cells with a missing value") (`nmiss') (.)

    * Check row count and age range
    preserve
    keep if NROW!=81 | AGEMIN!=0 | AGEMAX!=80
    quietly count
    post summ ("5 Ages 0-80 complete") ("`f'") ("profiles (country, year, indicator, sex)") (`tested') (r(N))
    gen double DIFF = NROW - 81
    gen str120 WHAT = SEX + ": " + string(NROW) + " rows, ages " + string(AGEMIN) + " to " + string(AGEMAX)
    keep_violations "5 Ages 0-80 complete" "`f'"
    restore

    * Check that all three sexes are present for every indicator
    collapse (count) NSEX=NROW, by(CNT2 YEAR IND)
    quietly count
    local tested = r(N)
    keep if NSEX!=3
    quietly count
    post summ ("5 Ages 0-80 complete") ("`f'") ("men, women and total present") (`tested') (r(N))
    gen double DIFF = NSEX - 3
    gen str120 WHAT = string(NSEX) + " of 3 sexes present"
    keep_violations "5 Ages 0-80 complete" "`f'"
}

********************************************************************************
* Results
********************************************************************************

postclose summ

use "$VIOL", clear
sort CHECK FILE IND CNT2 YEAR
export delimited using ENTA_output_control/results/1_method_check_violations.csv, replace
local nviol = _N

use `summary', clear
export delimited using ENTA_output_control/results/1_method_check_summary.csv, replace

set linesize 120
display as text _n "ENTA output control 1, method check - summary" _n
display as text %-24s "CHECK" %-12s "FILE" %-52s "WHAT IS TESTED" %12s "TESTED" %10s "FAILED"
forvalues i = 1/`=_N' {
    display as text %-24s CHECK[`i'] %-12s FILE[`i'] %-52s ITEM[`i'] as result %12.0fc TESTED[`i'] %10.0fc FAILED[`i']
}

quietly summarize FAILED
if r(sum)==0 {
    display as result _n "All checks hold."
}
else {
    display as error _n "`nviol' failure(s). See ENTA_output_control/results/1_method_check_violations.csv"
}
