********************************************************************************
* Impute consumption into EU-SILC from Household Budget Survey data
********************************************************************************
*
* PURPOSE
* EU-SILC has detailed income but no consumption data. The Household Budget
* Survey (HBS) has consumption but a smaller sample and fewer years. This
* script bridges the two: it estimates a consumption model on HBS households
* and predicts each EU-SILC household's consumption from its observable
* characteristics (income percentile, size, age composition).
*
* METHOD
* A single GLM regression (gamma family, log link) of standardised per-member
* consumption (CHXSTD / HHSIZE) on household characteristics, fitted on HBS
* 2010 and 2015 households (with CHXSTD < 10, i.e. excluding extreme
* outliers). The fitted model is then used to predict consumption for every
* EU-SILC household in every year - the relationship is assumed stable over
* time. The gamma-log specification guarantees positive predictions without
* needing a retransformation correction.
*
* OUTPUT FILES
************************************************************
*   $hbswd/SILC_HBS_[CC].dta   Combined EU-SILC + HBS person-level file
*                               (intermediate, read only by Section 1).
*
*   $hbswd/CHX1015_[CC].dta    One row per household: CNT2 CON YEAR HHID
*                               CHXPRED (predicted standardised consumption
*                               per household member, excluding education,
*                               health and imputed rent).
*
* INPUT
*   $silcwd/data/silc_[CC].dta          EU-SILC micro data (Micro_SILC.do)
*   $hbswd/HBS_[CC].dta                HBS micro data (Micro_HBS.do)
*   ENTA_aggregates/ENTA_units.dta      Per-capita consumption for
*                                       standardisation
*
* REQUIRES
*   Micro_SILC.do and Micro_HBS.do must have been run first.
*   ENTA_setup.do (sets $silcwd, $hbswd).
********************************************************************************


global country "DE AT BE BG CY CZ DK EE EL ES FI FR HR HU IE IT LT LU LV NL PL PT RO SE SI SK"


********************************************************************************
* 0.  COMBINE EU-SILC AND HBS DATA
********************************************************************************
*
* Stack EU-SILC and HBS persons into one file per country so that Section 1
* can fit a model on HBS households and predict for SILC households in one
* pass. CON = 0 marks SILC persons, CON = 1 marks HBS persons.

foreach x in $country {


    ************************************************************
    * 0a.  Load EU-SILC and keep the variables needed for the regression
    ************************************************************

    use "$silcwd/data/silc_`x'", clear

    gen CON = 0    // flag: this is SILC data
    keep CNT2 YEAR HHID HHSIZE HHTAG WEIGHTa WEIGHT AGE* SEX ///
        YDCASH CON NCHILD* PID* PERC YEM BSPPEN BSN YPr YPp YO


    ************************************************************
    * 0b.  Append HBS data
    ************************************************************

    append using "$hbswd/HBS_`x'.dta"

    * Floor negative disposable income at zero
    replace YDCASH = 0 if YDCASH < 0


    ************************************************************
    * 0c.  Build household-composition variables available in both sources
    ************************************************************
    *
    * These variables describe each household's age structure and are used
    * as regressors in the consumption model (Section 1).

    * Number of children under 20, capped at 3
    bysort YEAR HHID: egen NCHILD20 = total(AGEGR5 < 20)
    replace NCHILD20 = 3 if NCHILD20 > 3

    * Number of members in selected age groups
    bysort YEAR HHID: egen NAGE25 = total(AGEGR5 == 20 | AGEGR5 == 25 | AGEGR5 == 30)
    bysort YEAR HHID: egen NAGE65 = total(AGEGR5 == 65)
    bysort YEAR HHID: egen NAGE70 = total(AGEGR5 == 70)
    bysort YEAR HHID: egen NAGE75 = total(AGEGR5 == 75)
    bysort YEAR HHID: egen NAGE80 = total(AGEGR5 == 80)


    ************************************************************
    * 0d.  Compute per-capita consumption for standardisation
    ************************************************************
    *
    * CHXavg = national aggregate consumption / total population (from
    * ENTA_units.dta). Dividing household consumption by CHXavg removes
    * cross-year differences in price and income levels, so the 2010/2015
    * regression coefficients can be applied to other years.

    capture drop CHXavg
    sort CNT2 YEAR
    merge m:1 CNT2 YEAR using ENTA_aggregates/ENTA_units, ///
        keepusing(CHXesa POPtot)
    keep if _merge == 3
    drop _merge

    gen double CHXavg = CHXesa * 1000000 / POPtot
    drop CHXesa POPtot


    ************************************************************
    * 0e.  Save the combined file
    ************************************************************

    save $hbswd/SILC_HBS_`x', replace
}


********************************************************************************
* 1.  IMPUTE CONSUMPTION INTO EU-SILC USING A REGRESSION MODEL
********************************************************************************
*
* Fit a GLM on HBS 2010 and 2015 households, then predict standardised
* per-member consumption (CHXPRED) for every household in both SILC and HBS.

global country "AT BE BG CY CZ DE DK EE EL ES FI FR HR HU IE IT LT LU LV NL PL PT RO SE SI SK"

foreach x in $country {

    use $hbswd/SILC_HBS_`x', clear


    ************************************************************
    * 1a.  Prepare the dependent variable
    ************************************************************
    *
    * CHXSTD is total household consumption (other than education, health
    * and imputed rent), already standardised by CHXavg in Micro_HBS.do.
    * Divide by HHSIZE to get per-member consumption.

    replace CHXSTD = CHXSTD / HHSIZE


    ************************************************************
    * 1b.  Fit the consumption model on HBS 2010/2015 households
    ************************************************************
    *
    * The model is estimated on one observation per household (HHTAG == 1)
    * from HBS (CON == 1) years 2010 and 2015, excluding extreme outliers
    * (CHXSTD < 10 after standardisation).
    *
    * GLM with gamma family and log link:
    *   - Ensures predictions are always positive (unlike OLS, which could
    *     predict negative consumption).
    *   - The `predict` command after `glm` returns the fitted mean
    *     directly, with no need for retransformation or smearing correction
    *     (unlike log-OLS followed by exp()).
    *
    * Regressors:
    *   PERC      Income percentile of the household (within country-year)
    *   HHSIZE    Number of household members
    *   NCHILD20  Number of children under 20 (capped at 3)
    *   NAGE25    Members aged 20-34
    *   NAGE65    Members aged 65-69
    *   NAGE70    Members aged 70-74
    *   NAGE75    Members aged 75-79
    *   NAGE80    Members aged 80+

    glm CHXSTD PERC HHSIZE NCHILD20 NAGE25 NAGE65 NAGE70 NAGE75 NAGE80 ///
        if HHTAG == 1 & CHXSTD < 10, ///
        family(gamma) link(log)


    ************************************************************
    * 1c.  Predict consumption for every household (SILC and HBS)
    ************************************************************

    predict CHXPRED


    ************************************************************
    * 1d.  Save one row per household with the predicted consumption
    ************************************************************

    keep if HHTAG == 1
    keep CNT2 CON YEAR HHID CHXPRED

    sort CNT2 CON YEAR HHID
    save $hbswd/CHX1015_`x', replace
}
