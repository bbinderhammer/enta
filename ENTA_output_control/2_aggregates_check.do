********************************************************************************
* ENTA output control 2: breaks in levels and in components of the aggregates
********************************************************************************
*
* Lists the largest year-to-year changes in the published aggregates, so that
* a person can look at them. It does not decide whether a change is an error:
* a break can come from the economy, from a change in the source, or from a
* mistake.
*
* All amounts are measured in percent of national income (Y, total economy)
* of the same country and year.
*
*   1. National income (Y) itself
*        - Y = GDP - CFC + YEROW + YPROW - TPSp (the definition, must hold)
*        - GDP against Eurostat B1GQ, Y against Eurostat B5N (net national
*          income), both taken directly from the ESA sector accounts
*        - Y in percent of GDP, and the growth of Y
*   2. Level breaks: an aggregate changes much more than it usually does
*   3. Component shifts: a component of a total changes while the total
*      hardly does (the pattern of a reclassification in the source)
*   4. Imputed rent in percent of private consumption: values outside the
*      range found in the EU countries point to a wrong unit in the source
*   Parts 2 and 3 leave out the country-years in which Y itself is unusual.
*
* HOW TO RUN (about 1 minute; no setup file needed)
*   Open Stata, cd to the ENTA root folder, then:
*       do ENTA_output_control/2_aggregates_check.do
*
* INPUT   ENTA_output_data/ENTA_aggregates.dta
*         ENTA_input_data/Original_input_data/nasa_10_nf_tr.dta (Eurostat
*         sector accounts; part 1 skips the comparison if the file is absent)
*
* OUTPUT  in ENTA_output_control/results, one row per case, largest first:
*           2_aggregates_Y.csv                      national income
*           2_aggregates_level_breaks.csv           level breaks
*           2_aggregates_component_shifts.csv       component shifts
*           2_aggregates_rent_share.csv             imputed rent
*         The number of cases and the largest ones are shown on the screen.
*         The column LEDGER gives the ID of the row in ledger.csv that
*         explains the case, or "new".
*
* YEARS: the published years of the age profiles. The usual yearly change of
* a series is measured over these years too.
local first_year 2008
local last_year  2023

* THRESHOLDS
local y_growth   15    // Y: growth differs from the country's usual growth by 15 percentage points
local y_gdp      4     // Y in % of GDP: change of 4 percentage points in a year
local y_b5n      2     // Y in % of Eurostat B5N: change of 2 percentage points in a year
local min_pp     1.5   // level break: change of at least 1.5 % of Y in a year ...
local times      8     // ... and at least 8 times the usual yearly change of the series
local min_years  8     // series with fewer yearly changes are not tested
local min_comp   2     // component shift: the component changes by at least 2 % of Y ...
local total_part 0.5   // ... and the total by less than half the change of the component
local rent_min   5     // imputed rent: below 5 % of private consumption ...
local rent_max   25    // ... or above 25 %
local nshow      20    // cases shown on the screen

********************************************************************************
* 0. Preparation
********************************************************************************

clear
set more off
set linesize 160
capture mkdir ENTA_output_control/results
do ENTA_output_control/0_ledger_match.do     // defines the program ledger_match

* National income of the total economy: the reference for all percentages
use CNT2 YEAR SECTOR IND VALAGGR using ENTA_output_data/ENTA_aggregates, clear
keep if SECTOR=="Total economy" & IND=="Y"
* the year before the first year is kept, for the change in the first year
keep if inrange(YEAR, `first_year'-1, `last_year')
rename VALAGGR YREF
keep CNT2 YEAR YREF
isid CNT2 YEAR
tempfile yref
save `yref'

********************************************************************************
* 1. National income (Y) itself
********************************************************************************

use CNT2 YEAR SECTOR IND VALAGGR using ENTA_output_data/ENTA_aggregates, clear
keep if SECTOR=="Total economy" & inlist(IND,"Y","GDP","CFC","YEROW","YPROW","TPSp")
keep if inrange(YEAR, `first_year'-1, `last_year')
drop SECTOR
reshape wide VALAGGR, i(CNT2 YEAR) j(IND) string
rename VALAGGR* *

* 1.1 The definition of Y
gen double Y_DEFINITION = GDP - CFC + YEROW + YPROW - TPSp
gen double DIFF_DEFINITION = Y - Y_DEFINITION

* 1.2 GDP and net national income directly from the ESA sector accounts
capture confirm file ENTA_input_data/Original_input_data/nasa_10_nf_tr.dta
local have_esa = (_rc==0)
if `have_esa' {
    preserve
    use if unit=="CP_MEUR" & sector=="S1" ///
        & ((na_item=="B1GQ" & direct=="PAID") | (na_item=="B5N" & direct=="RECV")) ///
        using ENTA_input_data/Original_input_data/nasa_10_nf_tr, clear
    keep geo na_item nasa_10_nf_tr*
    reshape long nasa_10_nf_tr, i(geo na_item) j(YEAR)
    * values can be text with Eurostat flags
    capture confirm string variable nasa_10_nf_tr
    if !_rc {
        replace nasa_10_nf_tr = "" if inlist(nasa_10_nf_tr, ":", ": ", ": @N", "0 n")
        destring nasa_10_nf_tr, ignore("p" "b" "e") replace force
    }
    reshape wide nasa_10_nf_tr, i(geo YEAR) j(na_item) string
    rename nasa_10_nf_trB1GQ ESA_B1GQ
    rename nasa_10_nf_trB5N  ESA_B5N
    rename geo CNT2
    tempfile esa
    save `esa'
    restore
    merge 1:1 CNT2 YEAR using `esa', keep(master match) nogen
}
else {
    display as error "nasa_10_nf_tr.dta not found: GDP and Y are not compared with Eurostat"
    gen double ESA_B1GQ = .
    gen double ESA_B5N  = .
}
gen double DIFF_GDP_ESA = GDP - ESA_B1GQ
gen double Y_PCT_B5N    = 100*Y/ESA_B5N

* 1.3 Y in percent of GDP, growth of Y, and their change from the year before
gen double Y_PCT_GDP = 100*Y/GDP
sort CNT2 YEAR
by CNT2: gen byte PREV = YEAR==YEAR[_n-1]+1
by CNT2: gen double Y_GROWTH      = 100*(Y/Y[_n-1]-1)              if PREV
by CNT2: gen double CH_Y_PCT_GDP  = Y_PCT_GDP - Y_PCT_GDP[_n-1]    if PREV
by CNT2: gen double CH_Y_PCT_B5N  = Y_PCT_B5N - Y_PCT_B5N[_n-1]    if PREV
by CNT2: egen double USUAL_GROWTH = median(Y_GROWTH)

* What is unusual (a missing value never counts)
* Only the published years are listed
gen str80 CASE = ""
replace CASE = CASE + "definition of Y; "        if abs(DIFF_DEFINITION)>10 & DIFF_DEFINITION<.
replace CASE = CASE + "GDP differs from B1GQ; "  if abs(DIFF_GDP_ESA)>10 & DIFF_GDP_ESA<.
replace CASE = CASE + "growth of Y; "            if abs(Y_GROWTH-USUAL_GROWTH)>=`y_growth' & Y_GROWTH<.
replace CASE = CASE + "Y in % of GDP; "          if abs(CH_Y_PCT_GDP)>=`y_gdp' & CH_Y_PCT_GDP<.
replace CASE = CASE + "Y in % of B5N; "          if abs(CH_Y_PCT_B5N)>=`y_b5n' & CH_Y_PCT_B5N<.

* Years in which Y itself is unusual. Every percentage of Y moves in such a
* year, so parts 2 and 3 leave these country-years out.
preserve
keep if strpos(CASE, "growth of Y") | strpos(CASE, "Y in % of")
keep CNT2 YEAR
tempfile ybreak
save `ybreak'
restore

display as text _n "1. NATIONAL INCOME (Y)"
quietly count if abs(DIFF_DEFINITION)>10 & DIFF_DEFINITION<.
display as text "   Y = GDP - CFC + YEROW + YPROW - TPSp does not hold (more than 10 mio EUR): " as result r(N) as text " country-years"
quietly count if abs(DIFF_GDP_ESA)>10 & DIFF_GDP_ESA<.
display as text "   GDP differs from Eurostat B1GQ (more than 10 mio EUR): " as result r(N) as text " country-years"
replace CASE = "" if YEAR<`first_year'
quietly count if CASE!=""
display as text "   Country-years with at least one unusual value: " as result r(N)
display as text _n "   Y in percent of GDP and of Eurostat net national income (B5N), by country"
table CNT2, statistic(min Y_PCT_GDP) statistic(max Y_PCT_GDP) statistic(min Y_PCT_B5N) statistic(max Y_PCT_B5N) nformat(%6.1f)

preserve
keep if CASE!=""
gen double SIZE = max(abs(Y_GROWTH-USUAL_GROWTH)/`y_growth', abs(CH_Y_PCT_GDP)/`y_gdp', abs(CH_Y_PCT_B5N)/`y_b5n')
gen str3 IND = "Y"
ledger_match national_income
drop IND
quietly count if LEDGER=="new"
display as text "   Of these new (not in the ledger): " as result r(N)
gsort -SIZE
keep CNT2 YEAR LEDGER CASE Y GDP Y_GROWTH USUAL_GROWTH Y_PCT_GDP CH_Y_PCT_GDP Y_PCT_B5N CH_Y_PCT_B5N DIFF_DEFINITION DIFF_GDP_ESA
order CNT2 YEAR LEDGER CASE
format Y_GROWTH USUAL_GROWTH Y_PCT_GDP CH_Y_PCT_GDP Y_PCT_B5N CH_Y_PCT_B5N %6.1f
export delimited using ENTA_output_control/results/2_aggregates_Y.csv, replace
display as text _n "   Largest cases (all in ENTA_output_control/results/2_aggregates_Y.csv)"
if _N>0 {
    list CNT2 YEAR LEDGER CASE Y_GROWTH USUAL_GROWTH Y_PCT_GDP CH_Y_PCT_GDP CH_Y_PCT_B5N in 1/`=min(_N,`nshow')', noobs separator(0) abbreviate(14)
}
restore

********************************************************************************
* 2. Level breaks
********************************************************************************
* Every published series (country, sector, indicator) in percent of national
* income. A level break is a change from one year to the next of at least
* min_pp percentage points that is also at least `times' times the usual
* yearly change of that series (the median of its absolute yearly changes).
* COUNTRIES tells in how many countries the same indicator has a level break in
* the same year: a high number points to a common cause (2009, 2020).
* Country-years in which Y itself is unusual (part 1) are left out.

use CNT2 YEAR SECTOR IND INDICATOR VALAGGR using ENTA_output_data/ENTA_aggregates, clear
drop if SECTOR=="Total economy" & IND=="Y"
merge m:1 CNT2 YEAR using `yref', keep(match) nogen
gen double PCT_Y = 100*VALAGGR/YREF

sort CNT2 SECTOR IND YEAR
by CNT2 SECTOR IND: gen double CHANGE = PCT_Y - PCT_Y[_n-1] if YEAR==YEAR[_n-1]+1
by CNT2 SECTOR IND: gen double PCT_Y_BEFORE = PCT_Y[_n-1]   if YEAR==YEAR[_n-1]+1
gen double ABSCH = abs(CHANGE)
by CNT2 SECTOR IND: egen double USUAL = median(ABSCH)
by CNT2 SECTOR IND: egen NCHANGES = count(ABSCH)
gen double TIMES_USUAL = ABSCH/USUAL

* kept for part 3
tempfile series
save `series'

quietly count if ABSCH<. & NCHANGES>=`min_years'
local tested = r(N)
keep if ABSCH>=`min_pp' & ABSCH<. & TIMES_USUAL>=`times' & NCHANGES>=`min_years'
merge m:1 CNT2 YEAR using `ybreak', keep(master) nogen     // not in years where Y itself is unusual
bysort SECTOR IND YEAR: gen COUNTRIES = _N
ledger_match level
gen byte ISNEW = LEDGER=="new"

* The same amount is often published under several codes (for example social
* benefits as BS in Households and Government and as TGIC in the NTA
* aggregates). Such cases are shown once, with all their codes.
gen str40 CODE = SECTOR + ": " + IND
gen double KEY = round(ABSCH, 0.001)
sort CNT2 YEAR KEY ISNEW CODE
by CNT2 YEAR KEY: gen strL ALSO = CODE if _n==1
by CNT2 YEAR KEY: replace ALSO = ALSO[_n-1] + "; " + CODE if _n>1
by CNT2 YEAR KEY: gen NCODES = _N
by CNT2 YEAR KEY: replace ALSO = ALSO[_N]
by CNT2 YEAR KEY: keep if _n==1
rename ALSO ALL_CODES

gsort -ABSCH
display as text _n "2. LEVEL BREAKS"
display as text "   Yearly changes tested: " as result `tested' as text ";  level breaks (same amount counted once): " as result _N
quietly count if LEDGER=="new"
display as text "   Of these new (not in the ledger): " as result r(N)
keep CNT2 YEAR LEDGER SECTOR IND INDICATOR PCT_Y_BEFORE PCT_Y CHANGE USUAL TIMES_USUAL COUNTRIES NCODES ALL_CODES
order CNT2 YEAR LEDGER SECTOR IND INDICATOR PCT_Y_BEFORE PCT_Y CHANGE USUAL TIMES_USUAL COUNTRIES NCODES ALL_CODES
format PCT_Y_BEFORE PCT_Y CHANGE USUAL %7.2f
format TIMES_USUAL %6.1f
export delimited using ENTA_output_control/results/2_aggregates_level_breaks.csv, replace
display as text "   Largest cases, in percent of national income (all in ENTA_output_control/results/2_aggregates_level_breaks.csv)"
if _N>0 {
    list CNT2 YEAR LEDGER SECTOR IND PCT_Y_BEFORE PCT_Y CHANGE TIMES_USUAL COUNTRIES in 1/`=min(_N,`nshow')', noobs separator(0) abbreviate(14)
}
display as text _n "   Level breaks by year (same amount counted once)"
tabulate YEAR

********************************************************************************
* 3. Component shifts
********************************************************************************
* For every total with components: a component changes by at least min_comp
* percentage points of national income, while the total changes by less than
* total_part of that. Then money has moved between the components, as when
* the source reclassifies a benefit from one function to another.

* total_and_parts SECTOR TOTAL "PART1 PART2 ...": collects the yearly changes
capture program drop total_and_parts
program define total_and_parts
    args sector total parts
    preserve
    use CNT2 YEAR SECTOR IND CHANGE PCT_Y if SECTOR=="`sector'" & IND=="`total'" using "$SERIES", clear
    drop SECTOR IND
    rename CHANGE CH_TOTAL
    rename PCT_Y TOTAL_PCT_Y
    tempfile tot
    save `tot'
    use CNT2 YEAR SECTOR IND CHANGE PCT_Y PCT_Y_BEFORE if SECTOR=="`sector'" using "$SERIES", clear
    gen byte ISPART = 0
    foreach p of local parts {
        replace ISPART = 1 if IND=="`p'"
    }
    keep if ISPART
    drop ISPART
    merge m:1 CNT2 YEAR using `tot', keep(match) nogen
    gen str12 TOTAL = "`total'"
    append using "$SHIFTS"
    save "$SHIFTS", replace
    restore
end

global SERIES "`series'"
tempfile shifts
clear
gen str12 TOTAL = ""
save `shifts', emptyok
global SHIFTS "`shifts'"

total_and_parts "Households" Y   "YEM YA"
total_and_parts "Households" YEM "YE YM"
total_and_parts "Households" YA  "YP YO"
total_and_parts "Households" T   "TYEM TYA TB TCON TX"
total_and_parts "Households" TB  "TBSPEN TBSN TBPPEN"
total_and_parts "Households" TX  "TXH TXNPISH"
total_and_parts "Households" BS  "BSPEN BSFAM BSU BSX"
total_and_parts "Households" CH  "CHE CHH CHR CHX"
total_and_parts "Government" CG  "CGE CGH CGX"

use "$SHIFTS", clear
quietly count if CHANGE<. & CH_TOTAL<.
local tested = r(N)
keep if abs(CHANGE)>=`min_comp' & CHANGE<. & CH_TOTAL<. & abs(CH_TOTAL) < `total_part'*abs(CHANGE)
merge m:1 CNT2 YEAR using `ybreak', keep(master) nogen     // not in years where Y itself is unusual
gen double ABSCH = abs(CHANGE)
ledger_match components
gsort -ABSCH
rename IND COMPONENT
rename CHANGE CH_COMPONENT
rename PCT_Y COMPONENT_PCT_Y
rename PCT_Y_BEFORE COMPONENT_BEFORE

display as text _n "3. COMPONENT SHIFTS"
display as text "   Yearly changes of components tested: " as result `tested' as text ";  component shifts: " as result _N
quietly count if LEDGER=="new"
display as text "   Of these new (not in the ledger): " as result r(N)
keep CNT2 YEAR LEDGER SECTOR TOTAL COMPONENT COMPONENT_BEFORE COMPONENT_PCT_Y CH_COMPONENT TOTAL_PCT_Y CH_TOTAL
order CNT2 YEAR LEDGER SECTOR TOTAL COMPONENT COMPONENT_BEFORE COMPONENT_PCT_Y CH_COMPONENT TOTAL_PCT_Y CH_TOTAL
format COMPONENT_BEFORE COMPONENT_PCT_Y CH_COMPONENT TOTAL_PCT_Y CH_TOTAL %7.2f
export delimited using ENTA_output_control/results/2_aggregates_component_shifts.csv, replace
display as text "   Largest cases, in percent of national income (all in ENTA_output_control/results/2_aggregates_component_shifts.csv)"
if _N>0 {
    list CNT2 YEAR LEDGER TOTAL COMPONENT COMPONENT_BEFORE COMPONENT_PCT_Y CH_COMPONENT CH_TOTAL in 1/`=min(_N,`nshow')', noobs separator(0) abbreviate(16)
}

********************************************************************************
* 4. Imputed rent in percent of private consumption
********************************************************************************
* Imputed rent (CHR) is taken from Eurostat's consumption by purpose as an
* amount in million euro, not as a share. If the source holds another unit
* for a country, CHR is wrong by a factor and the rest of consumption (CHX)
* takes the difference. In the EU countries imputed rent is between rent_min
* and rent_max percent of private consumption (CH); the country-years outside
* this range are listed. These cases are not linked to the ledger: a value
* outside the range has to be corrected in the code.

use CNT2 YEAR SECTOR IND VALAGGR if SECTOR=="Households" & inlist(IND,"CH","CHR") using ENTA_output_data/ENTA_aggregates, clear
keep if inrange(YEAR, `first_year', `last_year')
drop SECTOR
reshape wide VALAGGR, i(CNT2 YEAR) j(IND) string
rename VALAGGR* *
gen double RENT_PCT_CH = 100*CHR/CH

display as text _n "4. IMPUTED RENT IN PERCENT OF PRIVATE CONSUMPTION"
table CNT2, statistic(min RENT_PCT_CH) statistic(max RENT_PCT_CH) nformat(%6.1f)
keep if (RENT_PCT_CH<`rent_min' | RENT_PCT_CH>`rent_max') & RENT_PCT_CH<.
display as text "   Country-years outside `rent_min' to `rent_max' percent: " as result _N
gsort -RENT_PCT_CH
keep CNT2 YEAR CHR CH RENT_PCT_CH
format RENT_PCT_CH %6.1f
export delimited using ENTA_output_control/results/2_aggregates_rent_share.csv, replace
if _N>0 {
    list CNT2 YEAR CHR CH RENT_PCT_CH in 1/`=min(_N,`nshow')', noobs separator(0)
}
