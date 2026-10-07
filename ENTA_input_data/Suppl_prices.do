********************************************************************************
* Consumer price index (HICP), 2020 = 100
*
* Eurostat's annual HICP (prc_hicp_aind) starts in 1996 - in 1997 for BG and
* 1998 for HR. It is completed back to 1995 with the growth of the World Bank
* consumer price index (https://data.worldbank.org/indicator/FP.CPI.TOTL).
*
* Output: ENTA_input_data/ENTA_input_datasets/hicp.dta (CNT2 YEAR HICP),
*         read by ENTA_aggregates/ENTA_units.do
********************************************************************************

* Download - only if switched on in ENTA_setup.do (global download 1)
if "$download"=="1" {
    * In Stata's temp folder, outside Dropbox: eurostatuse erases its working
    * file at the end, which fails while Dropbox holds it
    cd "`c(tmpdir)'"
    eurostatuse prc_hicp_aind, noflags clear
    cd "$wkdir"
    save ENTA_input_data/Original_input_data/prc_hicp_aind, replace
}

*****************************
* 1. Eurostat
*****************************

use ENTA_input_data/Original_input_data/prc_hicp_aind, clear
keep if coicop=="CP00" // All items HICP
keep if unit=="INX_A_AVG"

* One column per year -> one row per country and year
keep geo prc_hicp_aind*
reshape long prc_hicp_aind, i(geo) j(YEAR)
rename (geo prc_hicp_aind) (CNT2 HICP)
drop if missing(HICP)
summarize YEAR, meanonly
local lastyear = r(max)  // last Eurostat year, for the check in 3.

tempfile estat
save `estat'

*****************************
* 2. World Bank
*****************************

import excel ENTA_input_data/Original_input_data/CPI_world_bank.xls, sheet("Data") cellrange(A4:BQ270) firstrow clear
rename CountryName country

* Columns E-BQ are the years 1960-2024; their year is in the variable label
foreach v of varlist E - BQ {
    local x : variable label `v'
    rename `v' HICP_wb`x'
}
keep country HICP_wb*
reshape long HICP_wb, i(country) j(YEAR)
drop if missing(HICP_wb)

do ENTA_input_data/Prog_gen_CNT2_from_country_name.do
drop if CNT2==""
keep CNT2 YEAR HICP_wb

*****************************
* 3. Complete the Eurostat index back to 1995; 2020 = 100
*****************************

merge 1:1 CNT2 YEAR using `estat', nogen

* Chained back one year at a time from each country's first Eurostat year,
* so BG and HR are completed as well as the countries starting in 1996.
sort CNT2 YEAR
forvalues y = 1997(-1)1995 {
    by CNT2: replace HICP = HICP[_n+1] * HICP_wb/HICP_wb[_n+1] ///
        if YEAR==`y' & HICP==. & YEAR[_n+1]==`y'+1
}

* Rebase to 2020 = 100 in double precision, like HICP itself (a float
* intermediate lost digits 8+ of every value, e.g. AT 2020 = 99.999999)
gen double hicpn = HICP if YEAR==2020
bysort CNT2: egen double hicpnt = mean(hicpn)
replace HICP = HICP/hicpnt*100

drop if HICP==.
keep CNT2 YEAR HICP

* Every ENTA country needs an index for every year from 1995 to the last
* Eurostat year. A year could otherwise go missing without a message: at
* the drop above if the World Bank series lacks a year needed for the
* back-casting, or for a whole country without a 2020 value to rebase on.
local nyears = `lastyear' - 1994
foreach c in AT BE BG CY CZ DE DK EE EL ES FI FR HR HU IE IT LT LU LV NL PL PT RO SE SI SK {
    quietly count if CNT2=="`c'" & inrange(YEAR, 1995, `lastyear')
    if r(N)!=`nyears' {
        display as error "Suppl_prices.do: HICP of `c' covers " r(N) " of the `nyears' years 1995-`lastyear' - not saved."
        exit 459
    }
}
sort CNT2 YEAR
save ENTA_input_data/ENTA_input_datasets/hicp, replace
