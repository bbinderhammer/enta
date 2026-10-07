********************************************************************************
* Suppl_tax_list.do - composition of the taxes on benefits (TB) from DG TAXUD's
* national tax lists
*
* Decomposes DG TAXUD's "taxes on labour paid by the non-employed" (economic
* function LNON), which ENTA uses as the taxes on benefits TB
* (Suppl_tax_structure.do), into shares by the kind of income they are levied
* on, using the national tax lists published with Taxation Trends in the EU.
*
* TB has two parts in DG TAXUD's methodology:
*   (A) tax-list items assigned to LNON directly - mostly social contributions
*       of or for the non-employed (health insurance of pensioners,
*       contributions paid for the unemployed, health insurance the state pays
*       for state-insured persons), plus country-specific tax items (PL
*       income tax on social transfers, DK tax on pension lump sums, EL levy
*       on pensions);
*   (B) the personal income tax (items marked SPLIT1) times the country's own
*       "transfers" share from the sheet "2026 PIT split".
*
* Each (A) item is classified by the income it is levied on:
*   PIT    income tax on social transfers (PL; with part (B))
*   PAYG   on pay-as-you-go pensions only
*   FUND   on funded pensions only
*   PEN    on pensions of both kinds
*   BEN    on non-pension benefits (unemployment ...)
*   MIX    contributions by the non-employed on pensions and benefits, which
*          the list does not separate
*   STATE  contributions the state pays on behalf of beneficiaries; in SI
*          also what the list does not explain (Section 4)
*   OTHER  paid by non-employed people without a benefit (students, the
*          uninsured)
*
* Output: ENTA_input_data/ENTA_input_datasets/tb_taxlist.dta, one row per
*         CNT2 YEAR (EU-26, 1995-2024): shares of the published LNON
*         sh_PIT sh_PAYG sh_FUND sh_PEN sh_BEN sh_MIX sh_STATE sh_OTHER, which
*         add up to 1 (missing where LNON is 0: BG), and rec_gap, the
*         reconstruction (A) + (B) against the published LNON in %.
* Read by: ENTA_aggregates_compilation.do (Section 1.3, TB components).
* Input:  ENTA_input_data/Original_input_data/National_tax_list_2026.xlsx
*         (DG TAXUD, million national currency, published with the code);
*         taxud_tax_ec_func_en.csv (published LNON, mio EUR);
*         ENTA_input_datasets/ppp_exchange_rates.dta (Suppl_ppp_exchange_rates.do,
*         run first).
* Requires ENTA_setup_TU.do / ENTA_setup.do ($wkdir).
*
* Content
* 1. Transfers share of personal income tax
* 2. National tax lists
* 3. Assign the LNON items
* 4. Shares of TB and check against the published LNON
********************************************************************************

global country AT BE BG CY CZ DE DK EE EL ES FI FR HR HU IE IT LT LU LV ///
    NL PL PT RO SE SI SK

local ntl "ENTA_input_data/Original_input_data/National_tax_list_2026.xlsx"


********************************************************************************
* 1. Transfers share of personal income tax
********************************************************************************
* The sheet "2026 PIT split" gives, per country and year, the shares of the
* personal income tax attributed to labour, self-employed, capital and
* transfers (pensions, unemployment benefits ...), as provided by the
* countries to DG TAXUD and adjusted by DG TAXUD to add up to 1. The transfers
* share times the SPLIT1 items of the tax list is part (B) of LNON (Section 3).

import excel using "`ntl'", sheet("2026 PIT split") cellrange(A4) ///
    clear allstring

* Country code, split type and the year columns (D = 1995 ... AG = 2024)
keep A B D-AG
rename (A B) (CNT2 SPLIT)

* Year columns from letters to v1995, v1996, ...
local y 1995
foreach v of varlist D-AG {
    rename `v' v`y'
    local ++y
}

* Only the transfers row of each country
keep if SPLIT == "transfers"

* From wide (one column per year) to long
reshape long v, i(CNT2) j(YEAR)
destring v, replace force
rename v PITtra
keep CNT2 YEAR PITtra
sort CNT2 YEAR

tempfile pitsplit
save `pitsplit'


********************************************************************************
* 2. National tax lists
********************************************************************************
* One sheet per country lists every tax and social contribution with its ESA
* code (column A), detail code (B), English name (F), economic function (J:
* LNON, SPLIT1, ...) and the amounts 1995-2024 (L-AO) in million national
* currency. Row 8 is the header, the items start in row 9.
*
* Rows without an ESA code are DG TAXUD's own additions to the lists ("changes
* in yellow", sheet "Explanatory notes") and belong to the item above them:
* the split of an item over several economic functions (NL's contributions of
* the non-employed, 21,368 mio EUR in 2019; LT's state-paid health insurance
* before its own item starts in 2016) and the D995 corrections for taxes
* assessed but unlikely to be collected (FR, LU, LT, DK, BE). They inherit the
* ESA and detail code of the item above. Without them, 63% of NL's LNON and
* up to 93% of LT's before 2016 would be unexplained.
*
* From the first control total down (rows EF_LNON, EF_SPLIT1 ... = "Sum of
* taxes with economic function = ...") nothing is an item: the control totals
* would double every total, and below them some sheets (DK, ES, FR) hold a
* block of shares, not amounts.

tempfile lists
local first 1

foreach x in $country {

    * One country sheet from the first item row on
    import excel using "`ntl'", sheet("`x'") cellrange(A9) clear allstring

    * Columns used: A = ESA code, B = detail code, F = English name,
    * J = economic function, L-AO = amounts 1995-2024
    keep A B F J L-AO
    rename (A B F J) (ESA DETAIL NAME_EN EF)
    replace EF = strtrim(EF)

    * Amount columns from letters to v1995, v1996, ...
    local y 1995
    foreach v of varlist L-AO {
        rename `v' v`y'
        local ++y
    }

    * Cut the sheet at the first control total
    gen int row = _n
    quietly summarize row if substr(ESA, 1, 3) == "EF_"
    if r(N) == 0 {
        display as error "Suppl_tax_list.do: no control totals (EF_) in sheet `x'."
        exit 459
    }
    drop if row >= r(min)

    * DG TAXUD's additions inherit the item above (the fill cascades down
    * through consecutive additions)
    gen byte TAXUDadd = ESA == ""
    replace ESA    = ESA[_n-1]    if ESA == ""
    replace DETAIL = DETAIL[_n-1] if TAXUDadd

    * Only items assigned to LNON, SPLIT1 or SPLIT2
    keep if inlist(EF, "LNON", "SPLIT1", "SPLIT2")

    * Country, item number, and from wide to long
    gen CNT2 = "`x'"
    gen int item = _n
    drop row
    reshape long v, i(CNT2 item) j(YEAR)
    destring v, replace force
    rename v NAC

    * Collect all countries in one file
    if !`first' append using `lists'
    save `lists', replace
    local first 0
}


********************************************************************************
* 3. Assign the LNON items
********************************************************************************
* Each item tagged LNON is assigned to a category by the income or the persons
* it applies to, from the item names of the 2026 edition of the lists.
* The rules use the ESA and detail codes; for the rules that address single
* items by detail code, the English name is checked, so that a renumbering in
* a later edition stops the run instead of assigning the wrong item. An item
* without a category also stops the run.

gen CAT = ""

* Income tax split by DG TAXUD's PIT method

replace CAT = "SPLIT1" if EF == "SPLIT1"
replace CAT = "SPLIT2" if EF == "SPLIT2"

* (A) Items assigned to LNON directly

* PL: income tax on social transfers and benefits (identified in the Polish
* tax statistics; the only country where the income tax on benefits is a
* direct LNON item)
replace CAT = "PIT"   if EF == "LNON" & CNT2 == "PL" ///
    & ESA == "D51M" & DETAIL == "C03"

* DK: correction of the income tax assessed but unlikely to be collected,
* LNON part (DG TAXUD addition)
replace CAT = "PIT"   if EF == "LNON" & CNT2 == "DK" & ESA == "D995C"

* EL: levy on pensions (AGAGE), from 2010
replace CAT = "PAYG"  if EF == "LNON" & CNT2 == "EL" ///
    & ESA == "D51A" & DETAIL == "C03"

* AT: special pension contributions of retired civil servants
replace CAT = "PAYG"  if EF == "LNON" & CNT2 == "AT" ///
    & ESA == "D613CN" & DETAIL == "C03"

* DK: tax on pension schemes with lump-sum disbursement (funded pensions;
* volatile - 71,638 mio DKK in 2014, the capital-pension conversion)
replace CAT = "FUND"  if EF == "LNON" & CNT2 == "DK" ///
    & ESA == "D51A" & DETAIL == "C04"

* AT: health insurance contributions of retired local government staff
* (both kinds of pension)
replace CAT = "PEN"   if EF == "LNON" & CNT2 == "AT" ///
    & ESA == "D613CN" & DETAIL == "C04"

* ES: social contributions the employment agency (SEPE) pays for the
* unemployed
replace CAT = "BEN"   if EF == "LNON" & CNT2 == "ES" & ESA == "D613CN"

* HU: pension and non-pension contributions on unemployment benefits
replace CAT = "BEN"   if EF == "LNON" & CNT2 == "HU" ///
    & ESA == "D613CN" & inlist(DETAIL, "C03", "C04")

* BE, DE, FR, IT, LU: contributions by the non-employed (pensioners, benefit
* recipients), not separated in the list; NL's contributions of the
* non-employed (DG TAXUD addition); the D995 corrections of such
* contributions (FR, LU)
replace CAT = "MIX"   if EF == "LNON" ///
    & inlist(CNT2, "BE", "DE", "FR", "IT", "LU") & inlist(ESA, "D613CN", "D995FN")
replace CAT = "MIX"   if EF == "LNON" & CNT2 == "NL" & TAXUDadd

* AT: health and pension insurance contributions of the non-employed
replace CAT = "MIX"   if EF == "LNON" & CNT2 == "AT" ///
    & ESA == "D613CN" & inlist(DETAIL, "C01", "C02")

* CZ, SK, LT, EE: health insurance the state pays for state-insured persons
* (pensioners, children, students, the unemployed, carers); LT including
* the D995 correction
replace CAT = "STATE" if EF == "LNON" ///
    & inlist(CNT2, "CZ", "SK", "LT", "EE") & inlist(ESA, "D613CN", "D995FN")

* AT: contributions to students' associations
replace CAT = "OTHER" if EF == "LNON" & CNT2 == "AT" & ESA == "D59F"

* HU: health contributions of the uninsured non-employed
replace CAT = "OTHER" if EF == "LNON" & CNT2 == "HU" ///
    & ESA == "D613CN" & inlist(DETAIL, "C01", "C02")

* Check: the single items addressed by detail code

gen _name = lower(NAME_EN)
gen byte _bad = 0
replace _bad = 1 if CNT2 == "PL" & CAT == "PIT"  & ESA == "D51M" & !strpos(_name, "social transfers")
replace _bad = 1 if CNT2 == "EL" & CAT == "PAYG" & !strpos(_name, "pension")
replace _bad = 1 if CNT2 == "AT" & CAT == "PAYG" & !strpos(_name, "retired")
replace _bad = 1 if CNT2 == "DK" & CAT == "FUND" & !strpos(_name, "lump sum")
replace _bad = 1 if CNT2 == "AT" & CAT == "PEN"  & !strpos(_name, "local government")
replace _bad = 1 if CNT2 == "HU" & CAT == "BEN"  & !strpos(_name, "unemployment")
replace _bad = 1 if CNT2 == "HU" & CAT == "OTHER" & !strpos(_name, "non-employed")
replace _bad = 1 if CNT2 == "AT" & CAT == "MIX"  & !strpos(_name, "insurance")
replace _bad = 1 if CNT2 == "AT" & CAT == "OTHER" & !strpos(_name, "student")
quietly count if _bad & !TAXUDadd
if r(N) > 0 {
    list CNT2 ESA DETAIL CAT NAME_EN if _bad & !TAXUDadd & YEAR == 2019, noobs
    display as error "Suppl_tax_list.do: an item addressed by detail code has another name (Section 3)."
    exit 459
}
drop _name _bad

* Check: every LNON item with a value has a category

quietly count if CAT == "" & NAC != 0 & !missing(NAC)
if r(N) > 0 {
    list CNT2 YEAR ESA DETAIL NAME_EN NAC if CAT == "" & NAC != 0 & !missing(NAC), noobs
    display as error "Suppl_tax_list.do: LNON items without a category (Section 3)."
    exit 459
}

* Items without a category are zero or missing in every year
drop if CAT == ""

* Country x year x category

collapse (sum) NAC, by(CNT2 YEAR CAT)
reshape wide NAC, i(CNT2 YEAR) j(CAT) string

* Every category column exists (a country may have no item of a kind)
foreach c in SPLIT1 SPLIT2 PIT PAYG FUND PEN BEN MIX STATE OTHER {
    capture confirm variable NAC`c'
    if _rc gen double NAC`c' = 0
    replace NAC`c' = 0 if missing(NAC`c')
}

* Transfers share of personal income tax (Section 1). A country-year with
* SPLIT1 items but no share stops the run rather than being set to 0 (which
* would move its income tax on transfers into the residual).
sort CNT2 YEAR
merge 1:1 CNT2 YEAR using `pitsplit', keep(master match) nogen
quietly count if NACSPLIT1 != 0 & missing(PITtra)
if r(N) > 0 {
    list CNT2 YEAR NACSPLIT1 if NACSPLIT1 != 0 & missing(PITtra), noobs
    display as error "Suppl_tax_list.do: SPLIT1 items without a transfers share (sheet 2026 PIT split)."
    exit 459
}
replace PITtra = 0 if missing(PITtra)

* Part (B): the LNON part of the SPLIT1 income-tax items, added to PL's
* direct income-tax item (and DK's correction) already in NACPIT
replace NACPIT = NACPIT + NACSPLIT1 * PITtra


********************************************************************************
* 4. Shares of TB and check against the published LNON
********************************************************************************

* Published LNON (DG TAXUD tax_ec_func, mio EUR)

preserve
import delimited using ///
    "ENTA_input_data/Original_input_data/taxud_tax_ec_func_en.csv", ///
    clear varnames(1)
* import delimited lowercases the column names; stop if the download
* changed its layout
confirm variable ef unit geo time_period obs_value
keep if ef == "LNON" & unit == "MIO_EUR"
rename (geo time_period obs_value) (CNT2 YEAR LNON)
keep CNT2 YEAR LNON
sort CNT2 YEAR
tempfile lnon
save `lnon'
restore

* Published LNON in national currency: EXR_NAC_EUR is the exchange rate in
* national currency per euro (1 for the euro area; for the years before a
* country joined, the list is in euro as well - the reconstruction matches
* in those years)
merge 1:1 CNT2 YEAR using `lnon', keep(master match) nogen
merge 1:1 CNT2 YEAR using ///
    ENTA_input_data/ENTA_input_datasets/ppp_exchange_rates, ///
    keepusing(EXR_NAC_EUR) keep(master match) nogen
gen double LNONnac = LNON * EXR_NAC_EUR

* What (A) + (B) do not explain
* With DG TAXUD's additions (Section 2) the lists reproduce the published
* LNON within 1% in almost every country-year. The remainder is
* SI's: part of its SPLIT2 contributions of the self-employed goes to LNON
* without a published share (implied 0.43-0.50), most likely the pensioners'
* health contributions the pension fund pays (EUROMOD's credited
* contributions, 407 of 553 mio EUR for pensioners in 2019). The residual
* goes to STATE in SI. Everywhere else the measured parts are rescaled to
* the published LNON, i.e. the small residual (below 2% since 2005) is
* spread over the parts in proportion. (Put into one part, a negative
* residual could make that part negative.)

gen double NACA = NACPAYG + NACFUND + NACPEN + NACBEN ///
    + NACMIX + NACSTATE + NACOTHER
gen double RES  = LNONnac - NACA - NACPIT

* Reconstruction gap in % of the published LNON (before the residual)
gen double rec_gap = 100 * (NACA + NACPIT - LNONnac) / LNONnac ///
    if LNONnac != 0

replace NACSTATE = NACSTATE + RES if CNT2 == "SI"

* Shares of the published LNON
* SI: parts incl. the residual over the published LNON; elsewhere the parts
* over their own sum (the rescaling above)

gen double DEN = cond(CNT2 == "SI", LNONnac, NACA + NACPIT)
foreach c in PIT PAYG FUND PEN BEN MIX STATE OTHER {
    gen double sh_`c' = NAC`c' / DEN ///
        if LNONnac != 0 & !missing(LNONnac) & DEN != 0
}

* The shares add up to 1 (the residual closes them)
egen double shsum = rowtotal(sh_*)
assert abs(shsum - 1) < 1e-6 if !missing(sh_PIT)
drop shsum

* Diagnostic listing

display _n as text "Reconstruction (A) + (B) against the published LNON, % (|gap| > 2%, 2005+):"
list CNT2 YEAR rec_gap if abs(rec_gap) > 2 & !missing(rec_gap) & YEAR >= 2005, ///
    noobs clean

* Save

keep CNT2 YEAR sh_* rec_gap
order CNT2 YEAR sh_PIT sh_PAYG sh_FUND sh_PEN sh_BEN ///
    sh_MIX sh_STATE sh_OTHER rec_gap
sort CNT2 YEAR
save ENTA_input_data/ENTA_input_datasets/tb_taxlist, replace
