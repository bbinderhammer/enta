********************************************************************************
* Purchasing power parities and exchange rates
*
* Source: Eurostat prc_ppp_ind, household final consumption expenditure
* (ppp_cat E011), three items:
*   EXP_EUR        nominal expenditure in euro
*   EXP_NAC        nominal expenditure in national currency
*   PPP_EU27_2020  purchasing power parity (national currency per PPS,
*                  EU27_2020 = 1)
* Derived: EXR_NAC_EUR = EXP_NAC/EXP_EUR, the exchange rate (national
* currency per euro); PPP_EUR = EXR_NAC_EUR/PPP_EU27_2020, PPS per euro;
* EXR_2020 and PPP_EUR_2020, their 2020 values.
*
* Output: ENTA_input_data/ENTA_input_datasets/ppp_exchange_rates.dta
*         (CNT2 YEAR PPP_EUR PPP_EU27_2020 PPP_EUR_2020 EXR_NAC_EUR EXR_2020),
*         read by ENTA_aggregates/ENTA_units.do, which carries all five into
*         the published ENTA_units
********************************************************************************

* Download - only if switched on in ENTA_setup.do (global download 1)
if "$download"=="1" {
    * In Stata's temp folder, outside Dropbox: eurostatuse erases its working
    * file at the end, which fails while Dropbox holds it
    cd "`c(tmpdir)'"
    eurostatuse prc_ppp_ind, noflags clear
    cd "$wkdir"
    save ENTA_input_data/Original_input_data/prc_ppp_ind, replace
}

*****************************
* 1. Eurostat
*****************************

use ENTA_input_data/Original_input_data/prc_ppp_ind, clear
keep if na_item=="EXP_EUR" | na_item=="EXP_NAC" | na_item=="PPP_EU27_2020"
keep if ppp_cat=="E011" // Household final consumption expenditure

* One column per year -> one row per country, item and year. The years are
* taken from the columns present, so a new download needs no edit here.
keep na_item geo prc_ppp_ind*
reshape long prc_ppp_ind, i(na_item geo) j(YEAR)
drop if YEAR<1995
rename (geo prc_ppp_ind) (CNT2 NA)

* Keep only years with at least some information
bysort YEAR CNT2: egen yearmiss = count(NA) // number of non-missing values in variable NA
drop if yearmiss==0
drop yearmiss

* One column per item
reshape wide NA, i(CNT2 YEAR) j(na_item) string
rename (NAEXP_EUR NAEXP_NAC NAPPP_EU27_2020) (EXP_EUR EXP_NAC PPP_EU27_2020)

*****************************
* 2. Exchange rates and PPPs
*****************************
* In double precision, like the Eurostat values they are built from

gen double EXR_NAC_EUR = EXP_NAC/EXP_EUR
label var EXR_NAC_EUR "Exchange rate: LCU per Euro"

* Exchange rate with base year 2020
gen double EXR_2020t = EXR_NAC_EUR if YEAR==2020
bysort CNT2: egen double EXR_2020 = mean(EXR_2020t)
drop EXR_2020t
label var EXR_2020 "Exchange rate in 2020: LCU per Euro"

gen double PPP_EUR = EXR_NAC_EUR/PPP_EU27_2020
label var PPP_EUR "Purchasing power of one Euro in PPP"

* PPP with base year 2020
gen double PPP_EUR_2020t = PPP_EUR if YEAR==2020
bysort CNT2: egen double PPP_EUR_2020 = mean(PPP_EUR_2020t)
drop PPP_EUR_2020t
label var PPP_EUR_2020 "PPP of one Euro in 2020"

keep CNT2 YEAR PPP_EUR PPP_EU27_2020 PPP_EUR_2020 EXR_NAC_EUR EXR_2020 // PPP_NAC
sort CNT2 YEAR

*****************************
* 3. Check and save
*****************************
* Every ENTA country needs all five values in every year from 1995 to the
* last year Eurostat has for them, including the 2020 base. Missing ones
* would otherwise reach ENTA_units without a message.
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
        !missing(PPP_EUR, PPP_EU27_2020, PPP_EUR_2020, EXR_NAC_EUR, EXR_2020)
    if r(N)!=`nyears' {
        display as error "Suppl_ppp_exchange_rates.do: `c' has complete values in " r(N) " of the `nyears' years 1995-`lastyear' - not saved."
        exit 459
    }
}
drop enta

save ENTA_input_data/ENTA_input_datasets/ppp_exchange_rates, replace
