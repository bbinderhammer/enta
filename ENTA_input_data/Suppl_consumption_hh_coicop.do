********************************************************************************
* Private consumption by COICOP
********************************************************************************

* Household final consumption expenditure by purpose (COICOP), million EUR at
* current prices, for four items: CP00 (total), CP042 (imputed rentals for
* housing), CP06 (health) and CP10 (education). Years 1995 to lyear (below);
* missing 2023 and 2024 values are imputed with the growth of C (see the
* note above the imputation).
*
* Input:  ENTA_input_data/Original_input_data/nama_10_co3_p3.dta (Eurostat,
*         downloaded again when global download is 1)
*         ENTA_input_data/ENTA_input_datasets/esa_aggregates.dta (C and Cmp,
*         sector S14_S15), built by Aggr_ESA2010.do - run that file first
*         ENTA_input_data/ENTA_input_datasets/ppp_exchange_rates.dta
*         (EXR_2020), built by Suppl_ppp_exchange_rates.do
* Output: ENTA_input_data/ENTA_input_datasets/consumption_hh_coicop.dta, one
*         row per CNT2 YEAR with CP00 CP06 CP10 CP042
* Read by ENTA_aggregates/ENTA_aggregates_compilation.do, Section 1.7:
*         CHE = CP10/CP00 * C and CHH = CP06/CP00 * C (shares of C),
*         CHR = CP042 (a level, not a share)

if "$download"=="1" {
    * In Stata's temp folder, outside Dropbox: eurostatuse erases its working
    * file at the end, which fails while Dropbox holds it
    cd "`c(tmpdir)'"
    eurostatuse  nama_10_co3_p3, noflags clear
    cd "$wkdir"
    save ENTA_input_data/Original_input_data/nama_10_co3_p3, replace
}

local lyear = 2024 // latest year
clear

use ENTA_input_data/Original_input_data/nama_10_co3_p3, clear
keep if unit=="CP_MEUR"
keep if coicop=="CP042" | coicop=="CP06" | coicop=="CP10" | coicop=="TOTAL"

**************************
* Make years to a variable (original each year as variable)
**************************

tempfile data
save `data'
forvalues y=1995/`lyear' {
    use `data', clear
    keep unit unit_label coicop coicop_label geo geo_label nama_10_co3_p3`y'
    rename nama_10_co3_p3`y' NA
    gen year = `y'
    tempfile na`y'
    save `na`y''
}
clear
forvalues y=1995/`lyear' {
    append using `na`y''
}


* Make COICOP categories to variable
local coicop "CP042 CP06 CP10"
foreach cat of local coicop {
    preserve
    keep if coicop=="`cat'"
    rename NA `cat'
    sort geo year
    tempfile `cat'
    save ``cat''
    restore
}

keep if coicop=="TOTAL"
rename NA CP00
sort geo year
merge 1:1 geo year using `CP06'
drop _merge
sort geo year
merge 1:1 geo year using `CP10'
drop _merge
sort geo year
merge 1:1 geo year using `CP042'
drop _merge

rename geo CNT2
rename year YEAR
keep CNT2 YEAR CP00 CP06 CP10 CP042
sort CNT2 YEAR

* Replace strings in the data. eurostatuse's current output already
* stores these as clean numeric values (flags stripped at import) - guard
* against that rather than assume string, so this still works if a future
* eurostatuse version leaves flagged values as text instead.
local variables "CP00 CP06 CP10 CP042"
foreach var of local variables {
    capture confirm string variable `var'
    if !_rc {
        replace `var'="" if `var'==": "
        destring `var', ignore("p" ": " "e" ": @C") replace
    }
}

* Check the unit of the table. The values are read as million euro, so the
* total (CP00) has to be close to household consumption in the sector
* accounts (Cmp, sector S14_S15, from esa_aggregates): in the 26 ENTA
* countries it is 0.90 to 1.27 times Cmp.
* Bulgaria is the exception: Eurostat's euro column holds the values in
* leva, about twice Cmp in every year. They are converted with the exchange
* rate of 2020 from ppp_exchange_rates (EXR_2020, 1.9558 leva per euro, the
* same rate ENTA_units uses). The rate of 2020 is used for all years because
* the values of all years are in today's lev.
* The file stops if a country is outside 0.8 to 1.5 times Cmp after the
* conversion. This also happens when Eurostat corrects the Bulgarian values:
* then the conversion has to be removed.
* REQUIRES ppp_exchange_rates.dta: run Suppl_ppp_exchange_rates.do first.

preserve
use CNT2 YEAR sector Cmp using ENTA_input_data/ENTA_input_datasets/esa_aggregates, clear
keep if sector=="S14_S15"
drop sector
tempfile cmp
save `cmp'
restore
merge 1:1 CNT2 YEAR using `cmp', keep(master match) nogen
merge 1:1 CNT2 YEAR using ENTA_input_data/ENTA_input_datasets/ppp_exchange_rates, keepusing(EXR_2020) keep(master match) nogen

foreach var in CP00 CP06 CP10 CP042 {
    replace `var' = `var' / EXR_2020 if CNT2=="BG"
}

gen double unit_check = CP00 / Cmp
count if (unit_check<0.8 | unit_check>1.5) & unit_check<.
if r(N) > 0 {
    display as error "Suppl_consumption_hh_coicop.do: CP00 is not 0.8 to 1.5 times household consumption (Cmp) in these rows - check the unit of nama_10_co3_p3:"
    list CNT2 YEAR CP00 Cmp unit_check if (unit_check<0.8 | unit_check>1.5) & unit_check<., noobs
    error 459
}
drop Cmp EXR_2020 unit_check

* Impute 2023 and 2024 where Eurostat has not published them yet: the
* previous year's value grows with household consumption at basic prices
* (C, sector S14_S15) from esa_aggregates. Carrying the last value forward
* unchanged would freeze imputed rent (CHR = CP042) at its 2022 level while
* all other consumption grew.
* Applied per variable, so a published value is never
* touched and a partly published year only fills its gaps; 2024 builds on
* the (possibly imputed) 2023 value. Shares of CP00 are therefore kept at
* the last published year.
* REQUIRES esa_aggregates.dta: run Aggr_ESA2010.do before this file.

fillin CNT2 YEAR
drop _fillin

preserve
use CNT2 YEAR sector C using ENTA_input_data/ENTA_input_datasets/esa_aggregates, clear
keep if sector=="S14_S15"
drop sector
tempfile cb
save `cb'
restore
merge 1:1 CNT2 YEAR using `cb', keep(master match) nogen

sort CNT2 YEAR
foreach y in 2023 2024 {
    foreach var in CP00 CP06 CP10 CP042 {
        by CNT2: replace `var' = `var'[_n-1] * C / C[_n-1] ///
            if YEAR==`y' & YEAR[_n-1]==`y'-1 & missing(`var')
    }
}
drop C

save ENTA_input_data/ENTA_input_datasets/consumption_hh_coicop, replace

