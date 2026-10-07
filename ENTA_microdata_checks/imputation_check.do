********************************************************************************
* imputation_check.do
*
* PURPOSE
*   How well does the imputation of consumption into EU-SILC reproduce the age
*   profile of consumption in the Household Budget Survey (HBS)?
*   For the manual's chapter "Data quality assessment".
*
* BACKGROUND
*   Micro_impute_cons_into_SILC.do fits one GLM (gamma, log link) of
*   standardised consumption per household member on the household's income
*   percentile, size and age composition, using the HBS 2010 and 2015
*   households, and predicts it for every EU-SILC household.
*
* WHAT IS COMPARED
*   Three age profiles of consumption per person (CHX: consumption other than
*   education, health and imputed rent), by five-year age group, for the HBS
*   years 2010 and 2015:
*     orig  HBS, reported consumption
*     pred  HBS, consumption predicted by the regression for the same
*           households. Differs from orig by the model error.
*     silc  EU-SILC, imputed consumption of the same year, as ENTA uses it.
*           Differs from orig by the model error AND by the difference between
*           the two samples.
*
*   Household consumption is allocated to the members with the NTA equivalence
*   scale on five-year age groups (0.4 below 5, rising to 1 at 20; the HBS has
*   no single ages), the same for all three, so the comparison shows the
*   imputation, not the allocation.
*
*   The open age group is 80+ (75+ in PT). Persons without an age group (at
*   most a few hundred per country) are left out of the profiles but counted
*   in their household's scale.
*
* INPUT
*   $hbswd/SILC_HBS_<CC>.dta and $hbswd/CHX1015_<CC>.dta
*   (both from Micro_impute_cons_into_SILC.do)
*
* OUTPUT  (ENTA_microdata_checks/results/imputation/, not kept under version control)
*   imp_profiles.csv   country, year, age group: the three profiles in euro per
*                      person, and the persons in the HBS and in EU-SILC.
*                      No log is written.
*                      Manual_quality_tables.R turns it into the manual's table
*                      and figure.
*
* RUN
*   After ENTA_setup.do / ENTA_setup_TU.do (they set $hbswd), from the ENTA root.
********************************************************************************

version 19
set more off


********************************************************************************
* 0. Settings
********************************************************************************

* Output folder
cap mkdir ENTA_microdata_checks/results
cap mkdir ENTA_microdata_checks/results/imputation
local out "ENTA_microdata_checks/results/imputation"

* Countries
local countries "AT BE BG CY CZ DE DK EE EL ES FI FR HR HU IE IT LT LU LV NL PL PT RO SE SI SK"

* The two HBS waves
local hbs_years "2010, 2015"

* In the data: CON==1 are the HBS households, CON==0 the EU-SILC households


********************************************************************************
* 1. One country at a time: profiles of the three consumption measures
********************************************************************************

tempfile profiles
local first 1

foreach c of local countries {

    ****************************************************************************
    * 1a. Load the country's persons, keep the years with an HBS wave
    ****************************************************************************
    use CNT2 CON YEAR HHID HHSIZE WEIGHTa AGEGR5 CHX CHXavg ///
        using "$hbswd/SILC_HBS_`c'", clear
    keep if inlist(YEAR, `hbs_years')

    * Drop EU-SILC years without an HBS wave (NL has no 2010)
    bysort YEAR: egen byte has_hbs = max(CON==1)
    keep if has_hbs
    drop has_hbs

    ****************************************************************************
    * 1b. Attach the regression's prediction (CHXPRED), found by household
    ****************************************************************************
    merge m:1 CNT2 CON YEAR HHID using "$hbswd/CHX1015_`c'", ///
        keepusing(CHXPRED) keep(master match)
    quietly count if _merge==1
    if r(N)>0 di as error "`c': " r(N) " persons without a prediction"
    drop _merge

    ****************************************************************************
    * 1c. NTA equivalence scale on five-year age groups
    *     AGEGR5 is the lower bound of the group. Weight 0.4 below 5, then a
    *     straight line from 0.4 (age 4) to 1 (age 20), taken at the group
    *     midpoints 7, 12 and 17; 1 from 20 on. A missing age group gets 1, so
    *     the person still counts in the household's scale.
    ****************************************************************************
    gen double weight_person = 1
    replace weight_person = 0.4                 if AGEGR5<5
    replace weight_person = 0.4 + 0.6*(7-4)/16  if AGEGR5==5
    replace weight_person = 0.4 + 0.6*(12-4)/16 if AGEGR5==10
    replace weight_person = 0.4 + 0.6*(17-4)/16 if AGEGR5==15

    * Household total of the weights, and each person's share of it
    bysort CON YEAR HHID: egen double weight_household = total(weight_person)
    gen double CSCALE5 = weight_person / weight_household

    ****************************************************************************
    * 1d. Consumption per person in euro
    *     orig: reported (HBS households only)
    *     pred: predicted (HBS and EU-SILC households). CHXPRED is
    *           standardised consumption per household member, so it is
    *           multiplied back by household size and by the average level
    *           CHXavg before it is allocated with the scale.
    ****************************************************************************
    gen double orig = CHX * CSCALE5 if CON==1
    gen double pred = CHXPRED * HHSIZE * CHXavg * CSCALE5

    ****************************************************************************
    * 1e. Open age group: the oldest group seen in the HBS (80+, 75+ in PT),
    *     applied to both surveys. Persons without an age group are dropped.
    ****************************************************************************
    quietly sum AGEGR5 if CON==1
    local top = r(max)
    replace AGEGR5 = `top' if AGEGR5>`top' & AGEGR5<.
    drop if AGEGR5==.

    ****************************************************************************
    * 1f. Person-weighted mean consumption per age group, survey and year
    ****************************************************************************
    collapse (mean) orig pred [pw=WEIGHTa], by(CNT2 CON YEAR AGEGR5)
    tempfile means
    save `means'

    ****************************************************************************
    * 1g. Unweighted number of persons per age group, survey and year
    *     (counted again from the raw file, with the same open age group)
    ****************************************************************************
    use CNT2 CON YEAR AGEGR5 using "$hbswd/SILC_HBS_`c'", clear
    keep if inlist(YEAR, `hbs_years') & AGEGR5<.
    replace AGEGR5 = `top' if AGEGR5>`top'
    gen byte one = 1
    collapse (sum) n_persons=one, by(CNT2 CON YEAR AGEGR5)
    merge 1:1 CNT2 CON YEAR AGEGR5 using `means', keep(match) nogen

    ****************************************************************************
    * 1h. One row per country, year and age group:
    *     orig and pred from the HBS rows, silc (= pred) from the EU-SILC rows
    ****************************************************************************
    preserve
    keep if CON==1
    keep CNT2 YEAR AGEGR5 orig pred n_persons
    rename n_persons n_hbs
    tempfile hbs
    save `hbs'
    restore

    keep if CON==0
    keep CNT2 YEAR AGEGR5 pred n_persons
    rename (pred n_persons) (silc n_silc)
    merge 1:1 CNT2 YEAR AGEGR5 using `hbs', keep(match) nogen
    order CNT2 YEAR AGEGR5 orig pred silc n_hbs n_silc
    sort CNT2 YEAR AGEGR5
    list, noobs clean

    ****************************************************************************
    * 1i. Stack the countries
    ****************************************************************************
    if `first' {
        save `profiles'
    }
    else {
        append using `profiles'
        save `profiles', replace
    }
    local first 0
}


********************************************************************************
* 2. Save all countries
********************************************************************************

use `profiles', clear
sort CNT2 YEAR AGEGR5
export delimited using "`out'/imp_profiles.csv", replace

