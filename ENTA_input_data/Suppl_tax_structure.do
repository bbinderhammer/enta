********************************************************************************
* Tax structure by economic function (DG TAXUD, Taxation Trends in Europe)
*
* Input:  ENTA_input_data/Original_input_data/taxud_tax_ec_func_en.csv, DG
*         TAXUD's tax_ec_func, stored in the repository (download block below,
*         commented out). Million EUR.
* Output: ENTA_input_data/ENTA_input_datasets/taxstructure_wide.dta, one row
*         per CNT2 YEAR:
*           TYEB  LAB    taxes on labour, total
*           TYEE  LEES   taxes on labour paid by employees
*           TYER  LEYRS  taxes on labour paid by employers
*           TB    LNON   taxes on labour paid by the non-employed (on
*                        benefits and pensions)
*           TYP   KIH    taxes on capital income of households
*           TYM   KISE   taxes on income of the self-employed
* Read by ENTA_input_data/Aggr_ESA2010.do (Section C.2), which uses TYER
* for employer payroll taxes and carries all six into esa_aggregates.dta; from
* there ENTA_aggregates_compilation.do splits household income taxes with
* TYEE, TYM, TYP and TB. ENTA_aggregates_compilation.do also merges this file
* directly (Section 3, government). TYEB is kept only as a cross-check.
* Zeros are source values, not gaps: BG reports LNON = 0 in every year;
* LV reports KIH = 0 in 2000 and 2004-2009 and LNON = 0 in 1995.
********************************************************************************

*************************************
* 1. Taxes by function
*************************************

* Download and read data

* Tax revenue by economic function (DG TAXUD's REDISSTAT platform - a
* separate SDMX 2.1 API from Eurostat's own, so the eurostatuse package
* used by sibling Suppl_*.do files doesn't apply here; fetched directly
* instead). Commented out, and not covered by the download switch in
* ENTA_setup.do: the csv is provided with the code, and a new download would
* overwrite the version used. Re-run manually to refresh; keeps a local copy
* of the raw file in case the API changes shape or goes away.
/*
  cd ENTA_input_data/Original_input_data
  copy "https://webgate.ec.europa.eu/taxation_customs/redisstat/api/dissemination/sdmx/2.1/data/tax_ec_func?format=SDMX-CSV" taxud_tax_ec_func_en.csv, replace
  cd "$wkdir"
*/

clear
import delimited using ENTA_input_data/Original_input_data/taxud_tax_ec_func_en.csv, delim(",")

gen CNT2 = substr(geo,1,2)
gen YEAR = time_period
split ef, parse(:)
drop ef
rename ef1 ef
* Match on the code only (same approach as ef above), not the combined
* "code:label" string - robust to Eurostat tweaking the label text.
split unit, parse(:)
drop unit
rename unit1 unit
keep if unit=="MIO_EUR"
gen VALAGGR = obs_value

* ENTA terminology of taxes by economic function (tax source)

gen FUNCTION = "TYEB" if ef=="LAB" // taxes on labour, total
replace FUNCTION = "TYEE" if ef=="LEES" // taxes on labour, paid by employees
replace FUNCTION = "TYER" if ef=="LEYRS" // taxes on labour, paid by employers
replace FUNCTION = "TB" if ef=="LNON"  // taxes on labour, paid by the non-employed (benefits, pensions)
* replace FUNCTION = "TA" if ef=="CAP" // taxes on capital total
replace FUNCTION = "TYP" if ef=="KIH" // taxes on capital, income of households
* replace FUNCTION = "TYAC" if ef=="KIC" // taxes on capital, income of corporations
replace FUNCTION = "TYM" if ef=="KISE" // taxes on capital, income of the self-employed
* replace FUNCTION = "TSA" if ef=="KS" // taxes on capital, stock of capital

* replace FUNCTION = "TCON" if ef=="C:Taxes on consumption" // taxes on consumption
* replace FUNCTION = "TPR" if ef=="PROP" // taxes on property

keep if FUNCTION!=""

* Reshape and save the data

keep CNT2 YEAR FUNCTION VALAGGR

reshape wide VALAGGR, i(CNT2 YEAR) j(FUNCTION) string

local variables "TYEB TB TYEE TYER TYP TYM" // TCON
foreach var of local variables {
    rename VALAGGR`var' `var'
}

sort CNT2 YEAR

* Every ENTA country needs all six values in every year from 1995 to the last
* year in the file; a gap would otherwise reach the aggregates without a
* message (Aggr_ESA2010.do keeps unmatched ESA rows).
local countries "AT BE BG CY CZ DE DK EE EL ES FI FR HR HU IE IT LT LU LV NL PL PT RO SE SI SK"
gen byte enta = 0
foreach c of local countries {
    quietly replace enta = 1 if CNT2=="`c'"
}
summarize YEAR if enta, meanonly
local lastyear = r(max)
local nyears = `lastyear' - 1994
foreach c of local countries {
    quietly count if CNT2=="`c'" & inrange(YEAR, 1995, `lastyear') & ///
        !missing(TYEB, TB, TYEE, TYER, TYP, TYM)
    if r(N)!=`nyears' {
        display as error "Suppl_tax_structure.do: `c' has all six values in " r(N) " of the `nyears' years 1995-`lastyear' - not saved."
        exit 459
    }
}
drop enta

save ENTA_input_data/ENTA_input_datasets/taxstructure_wide, replace
