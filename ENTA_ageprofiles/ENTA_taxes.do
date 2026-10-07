********************************************************************************
* Calculate age profiles for taxes from EU-SILC and EUROMOD tax rates
********************************************************************************
*
* PURPOSE
* Build smoothed per-capita tax age profiles by multiplying EU-SILC income/
* benefit amounts by EUROMOD effective tax rates. Only the age shapes matter:
* the compilation step rescales them to national-accounts aggregates.
*
* OUTPUT FILES
************************************************************
*   tax_[CC].dta    One row per country / year / age. Contains:
*                   TYEM    (tax on employment income)
*                   TBSPEN  (tax on pay-as-you-go pensions)
*                   TBPPEN  (tax on funded pensions)
*                   TBSN    (tax on other benefits)
*                   Each also for men (suffix m) and women (f).
*
* INPUT
*   $silcwd/data/silc_[CC].dta                        EU-SILC micro data
*   ENTA_input_data/ENTA_input_datasets/taxr.dta       EUROMOD tax rates by
*                                                      10-year age group
*
* REQUIRES
*   ENTA_setup.do   (sets $silcwd, $country)
*   supsmooth       (user-written nonparametric smoother)
********************************************************************************


* Countries to process
global country  AT BE BG CY CZ DE DK EE EL ES FI FR HU HR IE IT LT LU LV ///
    NL PL PT RO SE SI SK


********************************************************************************
* 0.  LOAD AND PREPARE EU-SILC DATA
********************************************************************************

foreach x in $country {

    use $silcwd/data/silc_`x', clear


    ************************************************************
    * 0a.  Merge EUROMOD effective tax rates onto the micro data
    ************************************************************
    *
    * The tax-rate file contains one rate per country, year and 10-year age
    * group (0-19, 20-29, ..., 70-79, 80+). Every EU-SILC person matches.

    sort CNT2 YEAR AGEGR10
    merge m:1 CNT2 YEAR AGEGR10 ///
        using ENTA_input_data/ENTA_input_datasets/taxr
    keep if _merge == 3
    drop _merge


    ************************************************************
    * 0b.  Compute tax = income x rate, with a fallback for near-zero rates
    ************************************************************
    *
    * Each tax variable is the product of an income/benefit base and its
    * EUROMOD rate. Two taxes (TBSPEN, TBPPEN) share the same base (BSPPEN)
    * but have different rates, reflecting pay-as-you-go vs. funded pensions.
    *
    * FALLBACK: When the tax rate is essentially zero (< 1 %) in the age
    * groups where the base income concentrates, the rate is unreliable (too
    * few taxpayers in EUROMOD). In that case the tax profile is set equal to
    * the income profile itself - only its shape matters, since the
    * compilation rescales to the aggregate anyway.
    *
    * Where the fallback triggers (checked by age group):
    *   TBSPEN / TBPPEN:  rate zeroed at ages 60+ (where pensions concentrate)
    *   TBSN:             rate zeroed at ages 20-60 (where other benefits are)
    *   TYEM:             rate zeroed in ALL age groups (rate zero at age 0 is
    *                     normal and does not trigger the fallback)

    * Zero out missing / negative income bases
    foreach inc in YEM BSPPEN BSN {
        replace `inc' = 0 if `inc' == . | `inc' < 0
    }

    * Build each tax variable
    foreach tax in TYEM TBSPEN TBPPEN TBSN {

        * Identify the income base for this tax
        local var = cond("`tax'" == "TYEM",  "YEM", ///
            cond("`tax'" == "TBSN",  "BSN", "BSPPEN"))

        * Zero out negligibly small rates (< 1 %)
        replace `tax'r = 0 if `tax'r < 0.01

        * Decide whether to fall back to the income shape
        *
        * Check if the rate was zeroed in the age groups that matter for this
        * tax base. If any such group has a zeroed rate, flag the entire
        * country-year for fallback.

        if "`var'" == "BSPPEN" {
            * Pensions concentrate at 60+: trigger if rate zeroed there
            gen byte `tax'_z = (`tax'r == 0) & inlist(AGEGR10, 60, 70, 80)
        }
        else if "`var'" == "BSN" {
            * Other benefits concentrate at working age: trigger if zeroed at 20-60
            gen byte `tax'_z = (`tax'r == 0) & inlist(AGEGR10, 20, 30, 40, 50, 60)
        }
        else {
            * Employment income: trigger only if rate is zero in ALL groups
            bysort CNT2 YEAR: egen double `tax'_mx = max(`tax'r)
            gen byte `tax'_z = (`tax'_mx == 0)
            drop `tax'_mx
        }

        * Country-year flag: 1 if any relevant group was zeroed
        bysort CNT2 YEAR: egen byte `tax'_fb = max(`tax'_z)

        * Compute the tax: income x rate, or just income if fallback fires
        gen double `tax' = cond(`tax'_fb == 1, `var', `var' * `tax'r)

        drop `tax'_z `tax'_fb
    }


    ************************************************************
    * 0c.  Cap outlier taxes
    ************************************************************
    *
    * Same approach as for income: cap each tax at 10 x its weighted mean
    * per payer (persons paying > 1 euro), within each country-year.

    local vars "TYEM TBSPEN TBPPEN TBSN"

    foreach var of local vars {

        * Weighted total and weighted count of payers
        gen double `var'aggr = `var' * WEIGHTa
        gen double `var'pop  = (`var' > 1) * WEIGHTa

        bysort CNT2 YEAR: egen double t`var' = total(`var'aggr)
        bysort CNT2 YEAR: egen double n`var' = total(`var'pop)

        gen double mean`var' = t`var' / n`var'

        * Cap at 10 x the payer mean
        replace `var' = mean`var' * 10  if `var' > mean`var' * 10

        drop `var'aggr `var'pop t`var' n`var' mean`var'
    }


    ****************************************************************************
    * 1.  COLLAPSE MICRO DATA INTO AGE PROFILES, BY SEX
    ****************************************************************************

    local vars "TYEM TBSPEN TBPPEN TBSN"

    * Total population
    preserve
    collapse (mean) `vars' [pw = WEIGHTa], by(CNT2 YEAR AGE)
    tempfile tot
    sort CNT2 YEAR AGE
    save `tot', replace
    restore

    * Men
    preserve
    keep if SEX == 1
    collapse (mean) `vars' [pw = WEIGHTa], by(CNT2 YEAR AGE)
    foreach v of local vars {
        rename `v' `v'm
    }
    tempfile men
    sort CNT2 YEAR AGE
    save `men', replace
    restore

    * Women
    keep if SEX == 2
    collapse (mean) `vars' [pw = WEIGHTa], by(CNT2 YEAR AGE)
    foreach v of local vars {
        rename `v' `v'f
    }

    * Merge total + men + women
    sort CNT2 YEAR AGE
    merge 1:1 CNT2 YEAR AGE using `men', nogen
    sort CNT2 YEAR AGE
    merge 1:1 CNT2 YEAR AGE using `tot', nogen


    ****************************************************************************
    * 2.  SMOOTH THE AGE PROFILES
    ****************************************************************************

    * Determine the year range to smooth
    sum YEAR
    local min = max(2007, `r(min)')
    local max = `r(max)'

    * Country-specific year-range adjustments
    if "`x'" == "DE"  local max = 2021   // single-age data ends at 2021
    if "`x'" == "HR"  local min = 2009   // Croatian EU-SILC starts at 2009;
    * 2009-2010 tax rates imputed from 2011

    * Identify the open-ended top age group (80+, or 73+ for DE 2014-2018).
    * Its raw mean is restored after smoothing because the smoother's edge
    * estimate is unreliable there.
    sort CNT2 YEAR AGE
    by CNT2 YEAR: egen _topage = max(AGE)


    ************************************************************
    * 2a.  Apply supsmooth to each tax variable (ages 18+)
    ************************************************************

    foreach var of local vars {

        * Working copies for the smoothed values
        gen double s`var'  = `var'
        gen double s`var'm = `var'm
        gen double s`var'f = `var'f

        * Smooth year by year, for total / men / women
        forvalues yr = `min'/`max' {

            supsmooth `var'  AGE if YEAR == `yr' & AGE >= 18, ///
                gen(s`var'1)  bwcv nograph
            replace s`var'  = s`var'1  if s`var'1  != .

            supsmooth `var'm AGE if YEAR == `yr' & AGE >= 18, ///
                gen(s`var'm1) bwcv nograph
            replace s`var'm = s`var'm1 if s`var'm1 != .

            supsmooth `var'f AGE if YEAR == `yr' & AGE >= 18, ///
                gen(s`var'f1) bwcv nograph
            replace s`var'f = s`var'f1 if s`var'f1 != .

            drop s`var'1 s`var'm1 s`var'f1
        }

        * Restore the raw mean at the top age group
        replace s`var'  = `var'  if AGE == _topage & inrange(YEAR, `min', `max')
        replace s`var'm = `var'm if AGE == _topage & inrange(YEAR, `min', `max')
        replace s`var'f = `var'f if AGE == _topage & inrange(YEAR, `min', `max')

        * Overwrite originals with smoothed values
        replace `var'  = s`var'
        replace `var'f = s`var'f
        replace `var'm = s`var'm
        drop s`var' s`var'm s`var'f

        * Floor at zero; children under 15 get zero
        replace `var'  = 0 if `var'  < 0 | AGE < 15
        replace `var'f = 0 if `var'f < 0 | AGE < 15
        replace `var'm = 0 if `var'm < 0 | AGE < 15
    }


    ************************************************************
    * 2b.  Enforce non-decreasing taxes at ages 15-17
    ************************************************************
    *
    * Smoothing starts at 18, so the raw values at 15-17 can spike above the
    * smoothed value at 18. Walking downward from 18, cap each age's value
    * at the next-higher age's value to ensure a monotone rise into the
    * smoothed region. Age 18 itself is never changed.

    gsort CNT2 YEAR -AGE    // descending age within each group

    foreach var of local vars {
        by CNT2 YEAR: replace `var'  = `var'[_n-1]  ///
            if AGE >= 15 & AGE <= 17 & `var'[_n-1]  != . & `var'  > `var'[_n-1]
        by CNT2 YEAR: replace `var'm = `var'm[_n-1] ///
            if AGE >= 15 & AGE <= 17 & `var'm[_n-1] != . & `var'm > `var'm[_n-1]
        by CNT2 YEAR: replace `var'f = `var'f[_n-1] ///
            if AGE >= 15 & AGE <= 17 & `var'f[_n-1] != . & `var'f > `var'f[_n-1]
    }

    sort CNT2 YEAR AGE


    ************************************************************
    * 2c.  Save the smoothed tax age profiles
    ************************************************************

    drop _topage
    save ENTA_ageprofiles/ageprofiles/tax_`x', replace

}   // end of country loop
