********************************************************************************
* coverage_silc.do
*
* PURPOSE
*   Measure how much of each ESA aggregate the EU-SILC survey "sees", for the
*   income components that carry an age profile:
*
*       coverage = sum(x * WEIGHTa) over persons / ESA aggregate
*
*   by country and income year.
*
*   The age profiles take only their SHAPE from EU-SILC; the LEVEL comes from
*   the aggregate (ENTA_compilation1_esa.do, "adjust": same code, Households).
*   Coverage therefore says how much of the aggregate the survey captures. A
*   coverage that jumps between years points to a survey break that the
*   age shape may share.
*
*   Two versions of the SILC total are computed:
*     raw   the variable as Micro_SILC.do builds it (negatives kept, no cap)
*     used  as the profile files use it: negatives set to 0, and capped at
*           10 x the mean per receiver (6 x for YPr, YPp) per country-year
*           (ENTA_income.do, ENTA_benefits.do)
*
* PAIRS (SILC -> aggregate); the definitions differ in known ways
*   YE      PY010G + PY021G + company car + PY030G -> D1 received
*           (compensation of employees)
*   YM      PY050G -> mixed income (Aggr_ESA2010.do: household share of B2/B3,
*           weighted by B3G/(B2G+B3G))
*   YEM     YE + YM -> YE + YM
*   YPr     (HY090G + HY040G)/adults + PY080G -> D4 received
*           (SILC has no imputed interest and no property income attributed to
*           insurance policyholders; PY080G private pensions are not property
*           income in ESA)
*   YPp     HY100G mortgage interest -> D4 paid
*   BSFAM   family (HY050G, personalised) + education (PY140G)
*           -> COFOG family/children + education benefits
*   BSU     PY090G -> COFOG unemployment (cash)
*   BSPPEN  PY100G + PY110G + PY130G -> pensions incl. funded (BSPPEN);
*           also compared with BSPEN (excl. funded), reported as IND
*           "BSPPEN_PEN" in the output
*
* YEARS
*   Income years 2008-2023 (the published years).
*   Euro adopters in that window: CY 2008, SK 2009, EE 2011, LV 2014,
*   LT 2015, HR 2023. The aggregates are in euro in every year; SILC amounts
*   of years before adoption are converted with the irrevocable rate where
*   they are in national currency (see step 2).
*
* INPUT
*   $silcwd/data/silc_*.dta, ENTA_aggregates/ENTA_aggregates.dta
*
* OUTPUT  (ENTA_microdata_checks/results/coverage/, not kept under version control)
*   coverage_silc.csv     all country-years
*   coverage_summary.csv  per country and indicator: median, min, max,
*                         largest change between two consecutive years
*   coverage_eu.csv       median over countries, by year
*   No log is written.
*
* RUN
*   After ENTA_setup.do / ENTA_setup_TU.do (they set $silcwd), from the ENTA root.
********************************************************************************

version 19
set more off


********************************************************************************
* 0. Settings
********************************************************************************

* Output folder
cap mkdir ENTA_microdata_checks/results
cap mkdir ENTA_microdata_checks/results/coverage
local out "ENTA_microdata_checks/results/coverage"

* Countries
global country "AT BE BG CY CZ DE DK EE EL ES FI FR HR HU IE IT LT LU LV NL PL PT RO SE SI SK"

* Indicators: income components and benefit components
local inc  "YE YM YEM YPr YPp"
local ben  "BSFAM BSU BSPPEN"

* Years assessed: the published years of the age profiles, SILC income
* years
local y0 2008
local y1 2023

* Cap on a single person's amount, as a multiple of the mean per receiver
local cap_default  10
local cap_property  6      // for YPr and YPp


********************************************************************************
* 1. SILC totals per country-year, raw and as used by the profile files
********************************************************************************

tempfile silc
local first 1

foreach c in $country {

    * 1a. Load one country, keep the years assessed
    use CNT2 YEAR WEIGHTa `inc' `ben' using $silcwd/data/silc_`c', clear
    keep if inrange(YEAR, `y0', `y1')

    * 1b. For each indicator build the "raw" and the "used" person-level amount
    foreach v in `inc' `ben' {

        * raw = untouched (negatives and no cap)
        gen double `v'_raw = `v'

        * used = negatives and missings to 0, then capped (below)
        replace `v' = 0 if `v'==. | `v'<0

        * Weighted amount and weighted number of receivers (amount > 1) ...
        gen double wtd_amount  = `v' * WEIGHTa
        gen double wtd_recvr   = (`v'>1) * WEIGHTa
        * ... totalled per country-year
        bysort CNT2 YEAR: egen double tot_amount = total(wtd_amount)
        bysort CNT2 YEAR: egen double tot_recvr  = total(wtd_recvr)

        * Cap at k x mean per receiver
        local k = cond(inlist("`v'","YPr","YPp"), `cap_property', `cap_default')
        replace `v' = (tot_amount/tot_recvr) * `k' ///
            if `v' > (tot_amount/tot_recvr) * `k' & tot_recvr>0
        drop wtd_amount wtd_recvr tot_amount tot_recvr

        gen double `v'_used = `v'
        * Receiver flag (amount > 1), evaluated after negatives and cap, as before
        gen byte   `v'_rec  = (`v'>1)
    }

    * 1c. Weight the raw and used amounts, then sum to country-year level
    *     (receiver flags are summed unweighted: sample counts)
    foreach v in `inc' `ben' {
        replace `v'_raw  = `v'_raw  * WEIGHTa
        replace `v'_used = `v'_used * WEIGHTa
    }
    collapse (sum) *_raw *_used *_rec, by(CNT2 YEAR)

    * 1d. Stack the countries
    if `first' {
        save `silc'
    }
    else {
        append using `silc'
        save `silc', replace
    }
    local first 0
}

* 1e. One row per country-year-indicator
use `silc', clear
reshape long @_raw @_used @_rec, i(CNT2 YEAR) j(IND) string
rename (_raw _used _rec) (SILCraw SILCused RECEIVERS)


********************************************************************************
* 2. Euro conversion rate and first euro year, by country
********************************************************************************

* Default: no conversion needed (EURRATE 1, no euro-adoption year).
* The rate is national currency per euro. Which pre-euro years are actually
* in national currency is detected in step 3.
gen double EURRATE = 1
gen int    EURYEAR = .

*      country  rate      first euro year
foreach spec in "CY 0.585274 2008" ///
    "SK 30.126   2009" ///
    "EE 15.6466  2011" ///
    "LV 0.702804 2014" ///
    "LT 3.4528   2015" ///
    "HR 7.5345   2023" {
    tokenize `spec'
    replace EURRATE = `2' if CNT2=="`1'"
    replace EURYEAR = `3' if CNT2=="`1'"
}


********************************************************************************
* 3. Merge the ESA aggregates and compute coverage
********************************************************************************

* 3a. Aggregates for the household sector, one row per country-year-IND.
*     BSPEN (pensions excl. funded) is renamed so that it becomes a separate
*     indicator, BSPPEN_PEN, after the reshape back to long.
preserve
use ENTA_aggregates/ENTA_aggregates, clear
keep if SECTOR=="Households" & ///
    inlist(IND,"YE","YM","YEM","YPr","YPp","BSFAM","BSU","BSPPEN","BSPEN")
keep CNT2 YEAR IND VALAGGR
reshape wide VALAGGR, i(CNT2 YEAR) j(IND) string
gen VALAGGRBSPPEN_PEN = VALAGGRBSPEN
drop VALAGGRBSPEN
reshape long VALAGGR, i(CNT2 YEAR) j(IND) string
tempfile agg
save `agg'
restore

* 3b. Duplicate the BSPPEN rows so the SILC pension total is compared once
*     with BSPPEN and once with BSPEN (as BSPPEN_PEN)
expand 2 if IND=="BSPPEN", gen(dup)
replace IND = "BSPPEN_PEN" if dup==1
drop dup

* 3c. Attach the aggregates; the aggregates are in million euro
merge 1:1 CNT2 YEAR IND using `agg', keep(master match) nogen
replace VALAGGR = VALAGGR * 1000000

* 3d. Detect pre-euro years in which SILC reports national currency.
*     Rule: a pre-euro year counts as national currency when its YE coverage,
*     divided by the rate, is closer (in logs) to the country's median YE
*     coverage in euro years than the unconverted coverage is.
gen double cov_YE = SILCraw/VALAGGR if IND=="YE"
bysort CNT2: egen double med_YE_euro = ///
    median(cond(YEAR>=EURYEAR & EURYEAR<., cov_YE, .))
gen byte nc_YE = YEAR<EURYEAR & EURYEAR<. & ///
    abs(ln(cov_YE/EURRATE) - ln(med_YE_euro)) < abs(ln(cov_YE) - ln(med_YE_euro)) ///
    if IND=="YE"
* Spread the YE decision to all indicators of the same country-year
bysort CNT2 YEAR: egen byte NATCUR = max(nc_YE)
replace NATCUR = 0 if NATCUR==.
drop cov_YE med_YE_euro nc_YE

di "Country-years taken as national currency in SILC:"
tab CNT2 YEAR if NATCUR==1 & IND=="YE"

* 3e. Convert those years to euro
replace SILCraw  = SILCraw  / EURRATE if NATCUR==1
replace SILCused = SILCused / EURRATE if NATCUR==1

* 3f. Coverage = SILC total / aggregate, and save the full table
gen double COVraw  = SILCraw  / VALAGGR
gen double COVused = SILCused / VALAGGR
sort IND CNT2 YEAR
order CNT2 YEAR IND COVused COVraw SILCused SILCraw VALAGGR RECEIVERS NATCUR
export delimited using "`out'/coverage_silc.csv", replace


********************************************************************************
* 4. Summaries
********************************************************************************

* 4a. Largest year-on-year change of coverage per indicator and country
*     (log points), the year it happened, and the coverage ratio then
bysort IND CNT2 (YEAR): gen double dlog_cov = ///
    ln(COVused) - ln(COVused[_n-1]) if YEAR==YEAR[_n-1]+1
gen double absdlog_cov = abs(dlog_cov)
bysort IND CNT2: egen double max_absdlog = max(absdlog_cov)

gen int yjump_row = YEAR if absdlog_cov==max_absdlog & absdlog_cov<.
bysort IND CNT2: egen int YJUMP = max(yjump_row)

gen double fjump_row = exp(dlog_cov) if YEAR==YJUMP
bysort IND CNT2: egen double FJUMP = max(fjump_row)

* 4b. Per country and indicator: median, min, max, receivers, jump
preserve
collapse (median) MED=COVused (min) MIN=COVused (max) MAX=COVused ///
    (median) MEDREC=RECEIVERS (min) MINREC=RECEIVERS ///
    (first) YJUMP FJUMP (min) y0=YEAR (max) y1=YEAR, by(IND CNT2)
format MED MIN MAX FJUMP %6.3f
label var FJUMP "coverage ratio, year YJUMP over the year before (largest change)"
export delimited using "`out'/coverage_summary.csv", replace

* Print one block per indicator to the screen
levelsof IND, local(inds)
foreach i of local inds {
    di _n "==== `i' ===="
    list CNT2 MED MIN MAX YJUMP FJUMP MEDREC MINREC if IND=="`i'", noobs clean
}
restore

* 4c. EU-wide: median over countries, by indicator and year
preserve
collapse (median) COVused, by(IND YEAR)
reshape wide COVused, i(YEAR) j(IND) string
format COVused* %6.3f
list, noobs clean
export delimited using "`out'/coverage_eu.csv", replace
restore


