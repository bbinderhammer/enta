********************************************************************************
* survey_breaks.do
*
* Purpose:  Investigate unexplained breaks in published age profiles from
*           EU-SILC data. Each "case" is a (country, variable, year-range)
*           combination flagged in the ledger with no explanation.
*
*           For every case and income year the script reports:
*             - person count and receiver count (value > euro1)
*             - weighted total (eurom), male share, distribution over 5 age groups
*             - share of the total from the 5 largest weighted amounts
*               (high share -> sampling effect; low share -> survey/benefit change)
*
* Input:    $silcwd/data/silc_[CC].dta  (produced by Micro_SILC.do)
*
* Output:   ENTA_microdata_checks/results/survey_breaks/
*             survey_breaks.csv          - one row per case x year x sex x age
*             survey_breaks_summary.csv  - one row per case x year
*           (working files only; not published)
*
* Usage:    Run after ENTA_setup.do / ENTA_setup_TU.do (which sets $silcwd),
*           from the ENTA root directory. Takes about one minute.
********************************************************************************


********************************************************************************
*  0.  Setup
********************************************************************************

version 19
set more off
set linesize 200

* Create output directory (silently ignore if it already exists)
cap mkdir ENTA_microdata_checks/results
cap mkdir ENTA_microdata_checks/results/survey_breaks
local out "ENTA_microdata_checks/results/survey_breaks"

* [INACTIVE] no log is written
* cap log close sb
* log using "`out'/survey_breaks_log.txt", text replace name(sb)


********************************************************************************
*  0b. Define the cases to investigate
********************************************************************************

* Each token string: Country  Variable  FirstYear  LastYear  LedgerRow
*
* Variable mnemonics (as stored in silc_[CC].dta):
*   BSU   - unemployment benefits
*   BSX   - social-exclusion & housing benefits
*   BSFAM - family & education benefits
*   YPr   - property income received
*   YPp   - mortgage interest paid
*   YO    - imputed rent
*   YE    - compensation of employees
*   YM    - income from self-employment

* The list has to stay on one line: Stata does not accept line breaks inside it
local cases `" "RO BSX 2012 2016 L066" "RO YPr 2012 2016 L067" "RO YPr 2008 2013 L091" "RO YO 2008 2011 L090" "RO YM 2008 2011 L090" "CY BSFAM 2015 2019 L068" "DK YPr 2008 2011 L075" "DK YPp 2008 2011 L075" "SK BSU 2008 2011 L080" "HR BSU 2012 2016 L081" "PT BSU 2019 2023 L082" "IE BSU 2021 2023 L083" "EL BSU 2021 2023 L084" "LV YPr 2008 2011 L085" "LV YPp 2008 2011 L085" "EE BSU 2008 2011 L086" "EE BSFAM 2008 2011 L086" "EE BSX 2009 2013 L087" "HR BSFAM 2021 2023 L088" "LT YPr 2010 2014 L089" "LT YE 2008 2011 L092" "LT YM 2008 2011 L092" "'


********************************************************************************
*  1.  Loop over cases - build a person-level dataset, then collapse
********************************************************************************

tempfile all
local first 1                        // flag: first iteration saves, rest append

foreach case of local cases {

    * Parse the five tokens
    tokenize `case'
    local cc  `1'                      // country code  (e.g. "RO")
    local var `2'                      // variable name (e.g. "BSX")
    local y0  `3'                      // first income year
    local y1  `4'                      // last  income year
    local row `5'                      // ledger row ID (e.g. "L066")

    di as txt _n ">>> Processing: `cc' `var' `y0'-`y1' (`row')"

    * Load only the columns and years we need
    use CNT2 YEAR AGE SEX WEIGHTa `var' ///
        using "$silcwd/data/silc_`cc'", clear
    keep if inrange(YEAR, `y0', `y1')

    * Identifiers for this case
    gen str8 VAR    = "`var'"
    gen str8 LEDGER = "`row'"

    * Weighted amount per person; flag receivers (> euro1)
    gen double AMOUNT   = `var' * WEIGHTa
    replace    AMOUNT   = 0 if missing(AMOUNT)
    gen byte   RECEIVER = (`var' > 1 & !missing(`var'))

    * Top-5 concentration: share of the year's total from the
    *      five persons with the largest weighted amounts ----
    *      (A high share means the profile hinges on very few observations.)
    gen double NEGAMOUNT = -AMOUNT                       // for descending sort
    bysort YEAR (NEGAMOUNT): gen double TOP5 = sum(AMOUNT) if _n <= 5
    by YEAR: egen double TOP5SUM = max(TOP5)             // running sum at rank 5
    by YEAR: egen double TOTAL   = total(AMOUNT)
    gen double TOP5_PCT = 100 * TOP5SUM / TOTAL
    drop TOP5 TOP5SUM TOTAL NEGAMOUNT

    * Classify into five age groups
    gen byte AGEGROUP = 1 + (AGE >= 20) + (AGE >= 40) + (AGE >= 55) + (AGE >= 65)
    label define AGEGROUP 1 "0-19" 2 "20-39" 3 "40-54" 4 "55-64" 5 "65+", replace
    label values AGEGROUP AGEGROUP

    * Collapse to cell level (year x sex x age group)
    gen byte PERSONS = 1
    collapse (sum)  PERSONS RECEIVERS=RECEIVER AMOUNT ///
        (mean) TOP5_PCT,                         ///
        by(CNT2 VAR LEDGER YEAR SEX AGEGROUP)

    * Convert to million euro (pre-scaling amounts)
    replace AMOUNT = AMOUNT / 1e6

    * Stack onto the cumulative file
    if `first' {
        save `all'
    }
    else {
        append using `all'
        save `all', replace
    }
    local first 0
}

* Write the detailed (cell-level) CSV
use `all', clear
sort CNT2 VAR LEDGER YEAR SEX AGEGROUP
export delimited using "`out'/survey_breaks.csv", replace


********************************************************************************
*  2.  Summary file - one row per case x year
********************************************************************************

* Create helper variables for the collapse

* Amount attributable to men only
gen double AMOUNT_MEN = AMOUNT if SEX == 1

* Amount in each age group (will be summed across sexes)
forvalues g = 1/5 {
    gen double A`g' = AMOUNT if AGEGROUP == `g'
}

* Collapse across sex and age group
collapse (sum)  PERSONS RECEIVERS AMOUNT AMOUNT_MEN A1 A2 A3 A4 A5 ///
    (mean) TOP5_PCT,                                           ///
    by(CNT2 VAR LEDGER YEAR)

* Derive percentage shares

* Male share of total weighted amount
gen double MEN_PCT = 100 * AMOUNT_MEN / AMOUNT

* Age-group shares of total weighted amount
local g = 0
foreach name in PCT_0_19 PCT_20_39 PCT_40_54 PCT_55_64 PCT_65 {
    local ++g
    gen double `name' = 100 * A`g' / AMOUNT
}

* Drop intermediate variables
drop AMOUNT_MEN A1 A2 A3 A4 A5

* Format and order for readability
format AMOUNT   %9.1f
format MEN_PCT PCT_* TOP5_PCT %6.1f
order  CNT2 VAR LEDGER YEAR PERSONS RECEIVERS AMOUNT ///
    MEN_PCT PCT_* TOP5_PCT
sort   CNT2 VAR LEDGER YEAR

* Export and display
export delimited using "`out'/survey_breaks_summary.csv", replace

* Print a readable table to the screen
*   AMOUNT   : weighted total in million euro (before scaling to aggregates)
*   MEN_PCT  : male share of the total (%)
*   PCT_*    : share of each age group in the total (%)
*   TOP5_PCT : share of the 5 largest weighted amounts in the total (%)
list CNT2 VAR LEDGER YEAR PERSONS RECEIVERS AMOUNT                 ///
    MEN_PCT PCT_0_19 PCT_20_39 PCT_40_54 PCT_55_64 PCT_65 TOP5_PCT, ///
    noobs sepby(CNT2 VAR LEDGER) abbreviate(10)

* [INACTIVE] no log is written
* log close sb
