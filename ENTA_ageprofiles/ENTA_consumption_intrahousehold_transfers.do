********************************************************************************
* Estimate private consumption and intrahousehold transfers
********************************************************************************
*
* PURPOSE
* Build smoothed per-capita age profiles of private consumption (split into
* education, health, imputed rent, and everything else), consumption taxes,
* and intrahousehold transfers (cash flows between household members that
* redistribute income from earners to dependants). The compilation step
* later rescales every profile to national-accounts aggregates.
*
* OUTPUT FILES
************************************************************
*   ctpriv_[CC].dta           One row per country / year / age. Contains:
*                             CHX (other consumption), CHE (education),
*                             CHH (health), CHR (imputed rent),
*                             CHNR (= CHX+CHE+CHH), TCON (consumption tax),
*                             YDCASH (disposable cash income),
*                             TFWI / TFWO (intrahousehold transfers in/out),
*                             TFBHI / TFBHO (inter-household transfers in/out).
*                             Each also for men (suffix m) and women (f).
*
*   cfe_cfh_1015_[CC].dta     Intermediate: HBS-based agexsex pattern of
*                             health consumption (read in Section 2).
*
* INPUT
*   ENTA_input_data/.../consumption_educ_profile.dta
*                                       Age and sex profile of education
*                                       consumption, from the national
*                                       accounts by level of education and
*                                       enrollment
*                                       (Suppl_consumption_educ_profile.do)
*   $hbswd/HBS_[CC].dta                 Household Budget Survey micro data
*   $silcwd/data/silc_[CC].dta          EU-SILC micro data
*   $hbswd/CHX1015_[CC].dta             Imputed consumption matched to SILC
*   ENTA_aggregates/ENTA_units.dta       Per-capita consumption aggregates
*   ENTA_aggregates/ENTA_aggregates.dta  (via adjustaggr program)
*   ENTA_input_data/.../taxr.dta         EUROMOD effective tax rates
*   ENTA_input_data/.../population80w.dta Population by single age
*
* REQUIRES
*   ENTA_setup.do   (sets $hbswd, $silcwd; provides adjustaggr, adjustgender)
*   supsmooth       (user-written nonparametric smoother)
********************************************************************************


********************************************************************************
* 1.  HEALTH CONSUMPTION FROM THE HOUSEHOLD BUDGET SURVEY
********************************************************************************

************************************************************
* 1.1  Iterative within-household allocation of health spending
************************************************************
*
* HBS records health spending (CHH) at the household level. To obtain age
* profiles we need to split each household's total among its members.
* Education spending (CHE) is not allocated this way: nothing in the
* iteration says who is in education, and the spending went to the parents'
* ages. Its profile comes from enrollment (Section 2b). The approach:
*
*   1. Start with equal per-capita shares (spending / household size).
*   2. Collapse to agexsex means -> an initial age profile.
*   3. Use that profile to predict each member's share of the household
*      total, then re-collapse to updated age profiles.
*   4. Repeat steps 2-3 fifteen times until convergence.
*
* Spending is standardised by CHXavg (national per-capita consumption from
* ENTA_units.dta) to control for price/income differences across years.

global country  AT BE BG CY CZ DE DK EE EL ES FI FR HU HR IE IT LT LU LV ///
    NL PL PT RO SE SI SK

foreach x in $country {

    use "$hbswd/HBS_`x'", clear

    * Keep only consumption observations (CON==1 in Micro_HBS.do)
    keep if CON == 1


    * Compute per-capita consumption for standardisation
    capture drop CHXavg
    sort CNT2 YEAR
    merge m:1 CNT2 YEAR using ENTA_aggregates/ENTA_units, keepusing(CHXesa POPtot)
    keep if _merge == 3
    drop _merge
    gen double CHXavg = CHXesa * 1000000 / POPtot
    drop CHXesa POPtot


    * Initialise each person's weight as their per-capita share
    gen double CHHw = CHH / HHSIZE / CHXavg


    * Iterate 15 times to refine the within-household allocation
    forvalues i = 1/15 {

        * Collapse to age-group x sex means: the current age profile
        preserve
        collapse (mean) CHHi = CHHw  [aw = WEIGHTa], ///
            by(AGEGR5 SEX)
        sort AGEGR5 SEX
        tempfile w
        save `w'
        restore

        * Merge the profile back and compute each member's predicted share
        sort AGEGR5 SEX
        merge m:1 AGEGR5 SEX using `w', nogenerate

        * Household totals of the predicted amounts
        bysort YEAR HHID: egen double CHHh = total(CHHi)

        * Update the person's weight = their share of the household total
        replace CHHw = CHHi / CHHh

        drop CHHi CHHh
    }

    * Apply the converged weights to the standardised household totals
    replace CHH = CHHSTD * CHHw

    * [INACTIVE] The same iteration for education spending. Not used: the
    * profile of education consumption comes from enrollment (Section 2b).
    * To run it again, add these lines at the places of the CHH lines above
    * and CHE to the collapse below.
    * gen double CHEw = CHE / HHSIZE / CHXavg
    * collapse (mean) CHEi = CHEw  CHHi = CHHw  [aw = WEIGHTa], by(AGEGR5 SEX)
    * bysort YEAR HHID: egen double CHEh = total(CHEi)
    * replace CHEw = CHEi / CHEh
    * replace CHE = CHESTD * CHEw

    * Save the HBS-based agexsex pattern
    collapse (mean) CHH [pw = WEIGHTa], by(CNT2 AGEGR5 SEX)
    sort CNT2 AGEGR5 SEX
    save "ENTA_ageprofiles/ageprofiles/cfe_cfh_1015_`x'", replace
}


********************************************************************************
* 2.  INTEGRATE CONSUMPTION INTO EU-SILC
********************************************************************************

global country  AT BE BG CY CZ DE DK EE EL ES FI FR HU HR IE IT LT LU LV ///
    NL PL PT RO SE SI SK

foreach x in $country {

    use $silcwd/data/silc_`x', clear


    ************************************************************
    * 2a.  Build the NTA consumption scale
    ************************************************************
    *
    * The NTA scale determines how much of total household consumption each
    * member is assumed to consume. Children under 5 get 40 % of an adult;
    * it rises linearly from 40 % at age 5 to 100 % at age 20.

    gen double alpha = 1
    replace alpha = 0.4 if AGEGR5 < 5
    replace alpha = 0.4 + (1 - 0.4) * ((AGE - 4) / (20 - 4)) ///
        if AGE >= 5 & AGE <= 20

    * Germany 2022+: age 16 is recoded (5-year groups start there)
    replace alpha = 0.9 if AGE == 16 & CNT2 == "DE" & YEAR >= 2022

    * Each person's share of effective household size
    bysort CNT2 YEAR HHID: egen double hhmem = sum(alpha)
    gen double CSCALE = alpha / hhmem


    ************************************************************
    * 2b.  Merge the health profile (HBS) and the education profile
    ************************************************************

    * In Portugal HBS ends at age group 75; map 80 -> 75 for the merge
    gen AGEGR5all = AGEGR5
    replace AGEGR5 = 75 if AGEGR5 == 80 & CNT2 == "PT"

    sort CNT2 AGEGR5 SEX
    merge m:1 CNT2 AGEGR5 SEX ///
        using "ENTA_ageprofiles/ageprofiles/cfe_cfh_1015_`x'"
    keep if _merge == 3
    drop _merge

    replace AGEGR5 = AGEGR5all
    drop AGEGR5all

    * Education consumption: every person gets the value of his or her age
    * and sex in the profile built from the national accounts by level of
    * education and enrollment (Suppl_consumption_educ_profile.do). It holds
    * the shape only; adjustaggr sets the level (Section 2e). A person
    * without an age has no place in the profile and gets 0 (such persons
    * are in no age profile: they are dropped at the population merge in
    * Section 4d). The file stops if a person with an age finds no value.
    capture drop CHE
    sort CNT2 YEAR AGE SEX
    merge m:1 CNT2 YEAR AGE SEX using ///
        ENTA_input_data/ENTA_input_datasets/consumption_educ_profile, ///
        keep(master match) keepusing(CHE) nogenerate
    count if CHE == . & AGE == .
    display "`x': persons without age, education consumption set to 0: " r(N)
    replace CHE = 0 if CHE == . & AGE == .
    count if CHE == .
    if r(N) > 0 {
        display as error "No education profile for these years, ages and sexes (`x'):"
        table YEAR AGE SEX if CHE == ., missing
        error 459
    }


    ************************************************************
    * 2c.  Build the CHX (other consumption) profile
    ************************************************************
    *
    * CHX1015_[CC].dta contains CHXPRED: a household-level prediction of
    * "other" consumption, imputed into SILC from HBS. Multiply by
    * household size to get the household total, then by CHXavg (national
    * per-capita consumption) and the NTA scale to get each member's share.

    gen CON = 0
    sort CNT2 CON YEAR HHID
    merge m:1 CNT2 CON YEAR HHID using $hbswd/CHX1015_`x'
    keep if _merge == 3
    drop _merge CON

    * National per-capita consumption for level adjustment
    sort CNT2 YEAR
    merge m:1 CNT2 YEAR using ENTA_aggregates/ENTA_units, keepusing(CHXesa POPtot)
    keep if _merge == 3
    drop _merge
    gen double CHXavg = CHXesa * 1000000 / POPtot
    drop CHXesa POPtot

    * Individual consumption = household prediction x household size x scale
    gen double CHXPREDHH = CHXPRED * HHSIZE
    gen double CHX = CHXPREDHH * CHXavg * CSCALE


    ************************************************************
    * 2d.  Imputed rent consumption
    ************************************************************
    *
    * Each person's imputed-rent consumption equals their room-based
    * imputed-rent estimate (YOest, from Micro_SILC.do).

    gen double CHR = YOest


    ************************************************************
    * 2e.  Rescale consumption components to national-accounts aggregates
    ************************************************************
    *
    * adjustaggr multiplies each variable by the ratio of the ESA aggregate
    * to the weighted SILC total, so the micro profiles match the macro level.

    adjustaggr YDCASH CHR CHX CHE CHH


    ************************************************************
    * 2f.  Derived consumption variables
    ************************************************************

    * Non-rent consumption
    gen double CHNR = CHX + CHH + CHE

    * Consumption taxes (proportional to non-rent consumption, rescaled to
    * the aggregate)
    gen double TCON = CHNR
    adjustaggr TCON

    * Imputed-rent consumption: each person's share of the household's total
    * imputed rent (= sum of members' YR), allocated by the NTA scale.
    rename CHR YR
    bysort CNT2 YEAR HHID: egen double YRhh = sum(YR)
    gen double CHR = YRhh * CSCALE


    ************************************************************
    * 2g.  Individual disposable cash income before intrahousehold transfers
    ************************************************************
    *
    * YDCASHIND = employment income + property income received - property
    * income paid + social benefits + inter-household transfers (net,
    * domestic) - taxes.
    *
    * The EUROMOD tax rates are merged and applied the same way as in
    * ENTA_taxes.do, except that there is no fallback for near-zero rates
    * (tax is simply zero in those cases).

    * Merge EUROMOD tax rates
    sort CNT2 YEAR AGEGR10
    merge m:1 CNT2 YEAR AGEGR10 ///
        using ENTA_input_data/ENTA_input_datasets/taxr
    drop if _merge != 3
    drop _merge

    * Compute taxes = income x rate (zero out negligibly small rates first)
    local vars "YEM BSPPEN BSN"
    foreach var of local vars {
        replace T`var'r = 0 if T`var'r < 0.01
        gen double T`var' = `var' * T`var'r
    }


    * Inter-household transfers (domestic part)
    *
    * HY080G (received) and HY130G (paid) are per household; divide equally
    * among adults. Both sides are scaled to the smaller total, which is
    * the domestic part (the excess is cross-border, already in the ESA
    * aggregate BROW). The balanced net (IHR - IHP) enters YDCASHIND;
    * the domestic volume (IHVOL) is published as TFBHI / TFBHO below.

    bysort CNT2 YEAR HHID: egen double IHNAD = total(ADULT)
    gen double IHR = cond(ADULT == 1, HY080G / IHNAD, 0)   // received
    gen double IHP = cond(ADULT == 1, HY130G / IHNAD, 0)   // paid

    * Weighted totals of received and paid
    gen double IHw = IHR * WEIGHTa
    bysort CNT2 YEAR: egen double IHTR = total(IHw)
    replace IHw = IHP * WEIGHTa
    bysort CNT2 YEAR: egen double IHTP = total(IHw)

    * Scale both sides to the smaller total (= domestic volume)
    gen double IHVOL = min(IHTR, IHTP)
    replace IHR = IHR * IHVOL / IHTR  if IHTR > 0
    replace IHP = IHP * IHVOL / IHTP  if IHTP > 0
    drop IHw IHTR IHTP IHNAD

    * Individual disposable cash income
    gen double YDCASHIND = YEM + YPr - YPp + BSP + IHR - IHP ///
        - TYEM - TBSPPEN - TBSN


    * Rescale YDCASHIND to match the YDCASH aggregate
    *
    * adjustaggr applies a multiplicative factor (IHK). The same factor is
    * applied to the domestic inter-household volume so that the published
    * TFBHI / TFBHO are consistent with the income that enters YDCASHIND.

    gen double IHw2 = YDCASHIND * WEIGHTa
    bysort CNT2 YEAR: egen double IHT0 = total(IHw2)

    rename YDCASH YDCASHtemp
    rename YDCASHIND YDCASH
    adjustaggr YDCASH
    rename YDCASH YDCASHIND
    rename YDCASHtemp YDCASH

    replace IHw2 = YDCASHIND * WEIGHTa
    bysort CNT2 YEAR: egen double IHT1 = total(IHw2)
    gen double IHK = IHT1 / IHT0
    drop IHw2 IHT0 IHT1


    ****************************************************************************
    * 3.  INTRAHOUSEHOLD TRANSFERS
    ****************************************************************************
    *
    * Intrahousehold transfers redistribute disposable cash income among
    * household members. They have three components:
    *   1. Income sharing between partners (couples pool their income).
    *   2. Transfers from adults to dependants (parents cover children's and
    *      other dependants' consumption deficits).
    *   3. Redistribution of imputed rent (owners share housing services
    *      with non-owning members).


    ************************************************************
    * 3.1  Component 1: income sharing between partners
    ************************************************************
    *
    * Within each couple (identified by COUPLEID), income is equalised:
    * each partner moves to the couple's mean income. The transfer is the
    * difference between the couple mean and the individual's own income.

    bysort CNT2 YEAR HHID COUPLEID: egen double INCCOUPLE = mean(YDCASHIND) ///
        if COUPLEID != .

    gen double TFW0 = 0
    replace TFW0 = INCCOUPLE - YDCASHIND  if COUPLEID != .

    * Split into inflows (received) and outflows (given)
    gen double TFW0I = 0
    replace TFW0I =  TFW0  if TFW0 > 0 & TFW0 != .

    gen double TFW0O = 0
    replace TFW0O = -TFW0  if TFW0 < 0 & TFW0 != .

    * Income after partner sharing
    gen double YDCASHIND0 = YDCASHIND + TFW0


    ************************************************************
    * 3.2  Component 2: transfers between generations (adults -> dependants)
    ************************************************************
    *
    * After partner sharing, each person has a surplus (income > consumption)
    * or a deficit (income < consumption). Within the household, surpluses
    * are taxed to cover deficits. Any deficit not covered is charged to
    * adults in proportion to their positive income.

    * Individual surplus / deficit
    gen double LCS = YDCASHIND0 - (CHNR + TCON)

    gen double SURIN = 0
    replace SURIN =  LCS  if LCS >= 0       // surplus

    gen double DEFIN = 0
    replace DEFIN = -LCS  if LCS <= 0       // deficit (positive number)

    * Household-level surplus and deficit
    sort CNT2 YEAR HHID
    by CNT2 YEAR HHID: egen double SURHH = total(SURIN)
    by CNT2 YEAR HHID: egen double DEFHH = total(DEFIN)

    * Household "tax rate": fraction of each surplus used to cover deficits
    gen double HHTAX = DEFHH / SURHH
    replace HHTAX = 1 if SURHH == 0         // no surplus -> tax rate is 1
    replace HHTAX = 1 if DEFHH > SURHH      // deficit exceeds surplus

    * Total surplus collected ("taxed") within the household
    by CNT2 YEAR HHID: egen double SURTAXHH = total(SURIN * HHTAX)

    * Residual deficit: the part not covered by the household's surplus
    gen double DEFRESIDSHARE = (DEFHH - SURTAXHH) / DEFHH
    replace DEFRESIDSHARE = 0 if DEFHH == 0

    gen double DEFRESID = DEFIN * DEFRESIDSHARE
    by CNT2 YEAR HHID: egen double DEFRESIDHH = total(DEFRESID)

    * Allocate the residual deficit to adults
    *
    * Each adult covers a share proportional to their positive income.
    * If no adult has positive income, the deficit is split equally among
    * adults (they are assumed to dissave on behalf of the dependants).

    gen double YHHEAD = ADULT * YDCASHIND0
    bysort CNT2 YEAR HHID: egen double NYHHEAD = sum(YHHEAD)

    bysort CNT2 YEAR HHID: egen double NADULTHH = total(ADULT)
    gen double YHHEADpos    = max(0, YHHEAD)
    bysort CNT2 YEAR HHID: egen double NYHHEADpos = total(YHHEADpos)

    gen double HEADKEY = YHHEADpos / NYHHEADpos ///
        if NYHHEADpos > 0 & NYHHEADpos < .
    replace HEADKEY = ADULT / NADULTHH ///
        if !(NYHHEADpos > 0 & NYHHEADpos < .)

    drop YHHEADpos NYHHEADpos

    * Each adult's net transfer = residual deficit they cover minus their own
    * residual deficit
    gen double INTRAHHTRANS = DEFRESIDHH * HEADKEY - DEFRESID
    drop NADULTHH HEADKEY

    * Split into inflows and outflows

    gen double TFW1O = 0
    gen double TFW1I = 0

    * Uncovered deficit: adults pay, dependants receive
    replace TFW1O =  INTRAHHTRANS  if INTRAHHTRANS > 0
    replace TFW1I = -INTRAHHTRANS  if INTRAHHTRANS < 0

    * Covered deficit: surplus holders pay, deficit holders receive
    replace TFW1O = TFW1O + SURIN * HHTAX
    replace TFW1I = TFW1I + DEFIN * (1 - DEFRESIDSHARE)


    ************************************************************
    * 3.3  Component 3: redistribution of imputed rent
    ************************************************************
    *
    * Some household members consume more housing (CHR) than they "own" (YR).
    * The excess is a transfer from owners to non-owners within the household.

    gen double TFWRI = 0
    replace TFWRI = CHR - YR  if CHR > YR

    * Household total of inflows from housing redistribution
    bysort YEAR HHID: egen double TFWRIhh = sum(TFWRI)

    * "Tax rate" on owners' imputed rent to fund non-owners' consumption
    gen double CHRtax = 0
    replace CHRtax = TFWRIhh / YRhh  if YRhh != 0

    gen double TFWRO = YR * CHRtax


    ************************************************************
    * 3.4  Combine all three components
    ************************************************************

    gen double TFWO = TFW0O + TFW1O + TFWRO    // total outflows (given)
    gen double TFWI = TFW0I + TFW1I + TFWRI    // total inflows (received)


    ************************************************************
    * 3.5  Inter-household transfers: pooled age shape
    ************************************************************
    *
    * Yearly single-age profiles of HY080/HY130 are too noisy (small samples).
    * Instead, pool the age shape over all available years:
    *   - Express each person's balanced transfer relative to the year's
    *     per-capita domestic volume.
    *   - Average by age (and sex), weighted.
    *   - Smooth once with supsmooth.
    *
    * Section 4 then scales this shape to each year's domestic volume.
    * DE 2022+ (5-year age groups) is excluded from the shape.

    preserve

    keep CNT2 YEAR AGE SEX WEIGHTa IHR IHP IHVOL IHK

    * Per-capita domestic volume for standardisation
    bysort CNT2 YEAR: egen double IHPOP = total(WEIGHTa)
    gen double IHpc  = IHVOL / IHPOP
    gen double IHRr  = IHR / IHpc  if IHpc > 0    // relative received
    gen double IHPr  = IHP / IHpc  if IHpc > 0    // relative paid

    tempfile ihp
    save `ihp'

    * Domestic volume per year, scaled consistently with YDCASHIND
    collapse (mean) IHVOL IHK, by(CNT2 YEAR)
    replace IHVOL = IHVOL * IHK
    drop IHK
    tempfile ihvol
    save `ihvol'

    * Pooled shape by sex
    use `ihp', clear
    drop if CNT2 == "DE" & YEAR >= 2022
    collapse (mean) IHRr IHPr [pw = WEIGHTa], by(AGE SEX)
    keep if SEX == 1 | SEX == 2
    reshape wide IHRr IHPr, i(AGE) j(SEX)
    rename (IHRr1 IHPr1 IHRr2 IHPr2) (IHRrm IHPrm IHRrf IHPrf)
    tempfile ihsex
    save `ihsex'

    * Pooled shape, total (both sexes combined)
    use `ihp', clear
    drop if CNT2 == "DE" & YEAR >= 2022
    collapse (mean) IHRr IHPr [pw = WEIGHTa], by(AGE)
    merge 1:1 AGE using `ihsex', nogen
    sort AGE

    * Smooth each shape variable (ages 18+), floor at zero
    foreach v in IHRr IHPr IHRrm IHPrm IHRrf IHPrf {
        replace `v' = 0 if `v' == .
        supsmooth `v' AGE if AGE >= 18, gen(`v's) bwcv nograph
        replace `v' = `v's  if `v's < .
        replace `v' = 0     if `v' < 0
        drop `v's
    }

    tempfile ihshape
    save `ihshape'

    restore

    drop IHR IHP IHVOL IHK


    ****************************************************************************
    * 4.  CREATE AGE PROFILES AND SMOOTH
    ****************************************************************************

    ************************************************************
    * 4a.  Collapse to per-capita means by country / year / age / sex
    ************************************************************

    local variables "TFWO TFWI CHR CHNR CHX CHE CHH YDCASH TCON"

    * Total population
    preserve
    collapse (mean) `variables' [pw = WEIGHTa], by(CNT2 YEAR AGE)
    sort CNT2 YEAR AGE
    tempfile total
    save `total'
    restore

    * Men
    preserve
    keep if SEX == 1
    collapse (mean) `variables' [pw = WEIGHTa], by(CNT2 YEAR AGE)
    foreach var of local variables {
        rename `var' `var'm
    }
    sort CNT2 YEAR AGE
    tempfile men
    save `men'
    restore

    * Women
    keep if SEX == 2
    collapse (mean) `variables' [pw = WEIGHTa], by(CNT2 YEAR AGE)
    foreach var of local variables {
        rename `var' `var'f
    }
    sort CNT2 YEAR AGE

    * Merge total + men + women
    merge 1:1 CNT2 YEAR AGE using `total', nogenerate
    sort CNT2 YEAR AGE
    merge 1:1 CNT2 YEAR AGE using `men', nogenerate
    sort CNT2 YEAR AGE


    ************************************************************
    * 4b.  Smooth consumption and consumption taxes (all ages)
    ************************************************************
    *
    * supsmooth is applied over the full age range (consumption is defined
    * for children too). Smoothed values are floored at zero: the smoother
    * can overshoot below zero at the edge of the age range.
    * Education consumption (CHE) is not smoothed: it follows enrollment,
    * which starts and ends at fixed ages, and holds no sampling noise.

    sum YEAR
    local min = `r(min)'
    local max = `r(max)'
    if "`x'" == "DE"  local max = 2021

    local vars "CHR TCON CHNR CHX CHH"

    foreach var of local vars {

        gen double s`var'  = `var'
        gen double s`var'm = `var'm
        gen double s`var'f = `var'f

        forvalues yr = `min'/`max' {

            supsmooth `var'  AGE if YEAR == `yr', gen(s`var'1)  bwcv nograph
            replace s`var'  = s`var'1  if s`var'1  != .

            supsmooth `var'm AGE if YEAR == `yr', gen(s`var'm1) bwcv nograph
            replace s`var'm = s`var'm1 if s`var'm1 != .

            supsmooth `var'f AGE if YEAR == `yr', gen(s`var'f1) bwcv nograph
            replace s`var'f = s`var'f1 if s`var'f1 != .

            drop s`var'1 s`var'm1 s`var'f1
        }

        * Overwrite originals with smoothed values
        replace `var'  = s`var'
        replace `var'f = s`var'f
        replace `var'm = s`var'm
        drop s`var' s`var'm s`var'f

        * Floor at zero (consumption and consumption taxes cannot be negative)
        replace `var'  = 0 if `var'  < 0
        replace `var'm = 0 if `var'm < 0
        replace `var'f = 0 if `var'f < 0
    }


    ************************************************************
    * 4c.  Smooth intrahousehold transfers (all ages, no zero floor)
    ************************************************************
    *
    * Transfers can legitimately be zero or near-zero at some ages, and are
    * not floored - unlike consumption.

    local vars "TFWO TFWI"

    foreach var of local vars {

        gen double s`var'  = `var'
        gen double s`var'm = `var'm
        gen double s`var'f = `var'f

        forvalues yr = `min'/`max' {

            supsmooth `var'  AGE if YEAR == `yr', gen(s`var'1)  bwcv nograph
            replace s`var'  = s`var'1  if s`var'1  != .

            supsmooth `var'm AGE if YEAR == `yr', gen(s`var'm1) bwcv nograph
            replace s`var'm = s`var'm1 if s`var'm1 != .

            supsmooth `var'f AGE if YEAR == `yr', gen(s`var'f1) bwcv nograph
            replace s`var'f = s`var'f1 if s`var'f1 != .

            drop s`var'1 s`var'm1 s`var'f1
        }

        replace `var'  = s`var'
        replace `var'f = s`var'f
        replace `var'm = s`var'm
        drop s`var' s`var'm s`var'f
    }


    ************************************************************
    * 4d.  Adjust TFWI and TFWO so that total inflows = total outflows
    ************************************************************
    *
    * Intrahousehold transfers must net to zero across the whole population.
    * Rescale TFWO (outflows) so that its population-weighted total equals
    * that of TFWI (inflows).

    * Merge population counts (with age adjustments matching Germany's
    * grouped-age structure in later years)
    preserve
    use ENTA_input_data/ENTA_input_datasets/population80w, clear

    recode AGE (0/4=0) (5/9=5) (10/14=10) (15/19=15) (20/24=20) ///
        (25/29=25) (30/34=30) (35/39=35) (40/44=40) (45/49=45)   ///
        (50/54=50) (55/59=55) (60/64=60) (65/69=65) (70/74=70)   ///
        (75/79=75) (80/max=80), gen(AGEGR5)

    replace AGE = AGEGR5 if AGE >= 20 & YEAR >= 2022 & CNT2 == "DE"
    replace AGE = 16     if AGE >= 16 & AGE < 20 & YEAR >= 2022 & CNT2 == "DE"
    replace AGE = 73     if AGE >= 73 & YEAR >= 2014 & YEAR <= 2018 & CNT2 == "DE"

    collapse (sum) POP POPm POPf, by(CNT2 YEAR AGE)
    sort CNT2 YEAR AGE
    tempfile pop
    save `pop'
    restore

    sort CNT2 YEAR AGE
    merge 1:1 CNT2 YEAR AGE using `pop'
    keep if _merge == 3
    drop _merge

    * Rescale outflows to match inflows
    gen double TFWI_pop = TFWI * POP
    gen double TFWO_pop = TFWO * POP
    bysort CNT2 YEAR: egen double TFWI_pop_sum = total(TFWI_pop)
    bysort CNT2 YEAR: egen double TFWO_pop_sum = total(TFWO_pop)
    replace TFWO = TFWO * TFWI_pop_sum / TFWO_pop_sum
    drop TFWI_pop* TFWO_pop*

    * Ensure men's + women's profiles are consistent with the total
    adjustgender TFWI TFWO


    ************************************************************
    * 4e.  Inter-household transfers: scale the pooled shape to each year
    ************************************************************
    *
    * The pooled age shape from Section 3.5 is multiplied by the year's
    * domestic volume (IHVOL) and divided by the population-weighted total
    * of the shape, so that the profile sums to IHVOL.

    merge m:1 AGE       using `ihshape', nogen keep(master match)
    merge m:1 CNT2 YEAR using `ihvol',   nogen keep(master match)

    foreach v in R P {
        local o = cond("`v'" == "R", "TFBHI", "TFBHO")

        * Population-weighted total of the relative shape
        gen double _t = IH`v'r * POP
        bysort CNT2 YEAR: egen double _T = total(_t)

        * Scale shape to the year's volume
        gen double `o'  = cond(_T > 0, IH`v'r  * IHVOL / _T, 0)
        gen double `o'm = cond(_T > 0, IH`v'rm * IHVOL / _T, 0)
        gen double `o'f = cond(_T > 0, IH`v'rf * IHVOL / _T, 0)

        replace `o'  = 0 if `o'  == .
        replace `o'm = 0 if `o'm == .
        replace `o'f = 0 if `o'f == .

        drop _t _T
    }

    drop IHRr IHPr IHRrm IHPrm IHRrf IHPrf IHVOL

    * Ensure men + women are consistent with the total
    adjustgender TFBHI TFBHO


    ************************************************************
    * 4f.  Save the final consumption and transfer age profiles
    ************************************************************

    sort CNT2 YEAR AGE
    save "ENTA_ageprofiles/ageprofiles/ctpriv_`x'", replace

}   // end of country loop
