
********************************************************************************
* Calculate age profiles for public benefits from EU-SILC
********************************************************************************
*
* PURPOSE
* Produce smoothed per-capita age profiles of public benefits (pensions,
* family/education, unemployment, other) from EU-SILC micro data. The
* compilation step later scales these profiles to national-accounts totals.
*
* OUTPUT FILES
************************************************************
*   ben_[CC].dta       One row per country / year / age. Contains:
*                      BSPPEN (pensions), BSFAM (family & education),
*                      BSU (unemployment), BSX (other benefits), BSP (total),
*                      ADULT (share counted as economically independent).
*                      Each variable also for men (suffix m) and women (f).
*
* INPUT
*   $silcwd/data/silc_[CC].dta   (built by Micro_SILC.do)
*
* REQUIRES
*   ENTA_setup.do  (sets globals $silcwd, $country)
*   supsmooth      (user-written nonparametric smoother)
*
* NOTES
* - Unlike the income and tax scripts, benefits are NOT floored to zero
*   below age 15 and NOT capped at ages 15-17 (intentional).
* - Smoothing starts at age 18 for all benefit types.
* - Unemployment benefits (BSU) receive special treatment around the
*   "cliff age" where they end (Section 2a).
* - Pensions get a non-decreasing (isotonic) fit from age 50 to their peak,
*   because the standard smoother blurs the sharp step at retirement (2b).
********************************************************************************


********************************************************************************
* 0.  LOAD AND PREPARE EU-SILC DATA
********************************************************************************

* Countries to process
global country  AT BE BG CY CZ DE DK EE EL ES FI FR HU HR IE IT LT LU LV ///
    NL PL PT RO SE SI SK

* The five benefit types that will be collapsed into age profiles
local vars "BSP BSFAM BSU BSPPEN BSX"


************************************************************
* 0a.  Define the isotonic-regression helper (Mata) and the pension-fit program
************************************************************
*
* _enta_isomono:  Pool-adjacent-violators algorithm (isotonic regression).
*     Given a variable sorted by age, it produces a non-decreasing fit,
*     optionally bounded below (lo) and above (cap), then applies a 3-point
*     moving average to reduce staircase effects while keeping the endpoints.
*
* _enta_penfit:   Wrapper that applies _enta_isomono to pensions from age 50
*     up to their peak (the age of maximum smoothed pensions at 58-72).
*     The fit is anchored to the smoothed values at both ends so that it
*     joins the smoothed profile without a jump.

capture mata mata drop _enta_isomono()
mata:
void _enta_isomono(
    string scalar yv,       // input variable (raw means)
    string scalar outv,     // output variable (fitted values)
    string scalar touse,    // indicator: which observations to use
    real scalar cap,        // upper bound (missing = no bound)
    real scalar lo          // lower bound (missing = no bound)
)
{
    real colvector idx, y, val, wt, cnt, f, g
    real scalar    n, m, i, j, k

    idx = selectindex(st_data(., touse))
    n   = rows(idx)
    if (n < 3) return
    y = st_data(idx, yv)

    /* --- Pool-adjacent-violators (equal weights) --- */
    val = J(n,1,.);  wt = J(n,1,.);  cnt = J(n,1,.);  m = 0
    for (i = 1; i <= n; i++) {
        m++
        val[m] = y[i];  wt[m] = 1;  cnt[m] = 1
        while (m > 1) {
            if (val[m-1] <= val[m]) break
            val[m-1] = (val[m-1]*wt[m-1] + val[m]*wt[m]) / (wt[m-1] + wt[m])
            wt[m-1]  = wt[m-1] + wt[m]
            cnt[m-1] = cnt[m-1] + cnt[m]
            m--
        }
    }

    /* --- Expand blocks back to single ages --- */
    f = J(n,1,.);  k = 0
    for (i = 1; i <= m; i++) {
        for (j = 1; j <= cnt[i]; j++) {
            k++;  f[k] = val[i]
        }
    }

    /* --- Apply bounds and anchor endpoints --- */
    if (cap < .) f = rowmin((f, J(n,1,cap)))
    if (lo  < .) f = rowmax((f, J(n,1,lo)))
    if (lo  < .) f[1] = lo
    if (cap < .) f[n] = cap

    /* --- 3-point moving average (keeps endpoints) --- */
    g = f
    for (i = 2; i < n; i++) g[i] = (f[i-1] + f[i] + f[i+1]) / 3

    st_store(idx, outv, g)
}
end


* Stata program: apply the isotonic fit to pensions between age 50 and their
* peak. The peak is the age of the maximum smoothed pension at ages 58-72.
* The fit is bounded by the smoothed values at age 50 (lower) and at the peak
* (upper) so that it connects seamlessly.

capture program drop _enta_penfit
program define _enta_penfit
    args raw sm yr
    tempvar c sel iso
    quietly {
        * Find the peak: maximum of the smoothed profile at ages 58-72
        gen double `c' = `sm' if YEAR == `yr' & inrange(AGE, 58, 72)
        summarize `c', meanonly
        if r(N) == 0 exit
        local cap = r(max)

        * Peak age (earliest age that attains the maximum)
        summarize AGE if `c' == `cap', meanonly
        local p = r(min)

        * Lower anchor: smoothed value at age 50
        summarize `sm' if YEAR == `yr' & AGE == 50, meanonly
        if r(N) == 0 exit
        local lo = r(mean)

        * Skip if the profile is already non-decreasing or the window is tiny
        if `lo' >= `cap' | `p' <= 51 exit

        * Run the isotonic fit from age 50 to the peak
        gen byte   `sel' = YEAR == `yr' & inrange(AGE, 50, `p') & `raw' < .
        gen double `iso' = .
        mata: _enta_isomono("`raw'", "`iso'", "`sel'", `cap', `lo')

        * Overwrite the smoothed profile between 50 and the peak (exclusive
        * of endpoints, which already equal the anchors)
        replace `sm' = `iso' if `iso' < . & AGE > 50 & AGE < `p'
    }
end


********************************************************************************
* MAIN LOOP: process each country
********************************************************************************

foreach x in $country {

    use $silcwd/data/silc_`x', clear


    ************************************************************
    * 0b.  Cap outlier benefits
    ************************************************************
    *
    * Same logic as in the income script: within each country-year, compute
    * the weighted mean over receivers (benefit > 1 euro) and cap individual
    * values at 10 x that mean. Negatives and missings are set to zero first.

    foreach var of local vars {

        replace `var' = 0 if `var' == . | `var' < 0

        * Weighted total and weighted count of receivers
        gen double `var'aggr = `var' * WEIGHTa
        gen double `var'pop  = (`var' > 1) * WEIGHTa

        bysort CNT2 YEAR: egen double t`var' = total(`var'aggr)
        bysort CNT2 YEAR: egen double n`var' = total(`var'pop)

        gen double mean`var' = t`var' / n`var'

        * Cap at 10 x the receiver mean
        replace `var' = mean`var' * 10  if `var' > mean`var' * 10

        drop `var'aggr `var'pop t`var' n`var' mean`var'
    }


    ****************************************************************************
    * 1.  COLLAPSE MICRO DATA INTO AGE PROFILES, BY SEX
    ****************************************************************************

    * Total population
    preserve
    collapse (mean) `vars' ADULT [pw = WEIGHTa], by(CNT2 YEAR AGE)
    tempfile tot
    sort CNT2 YEAR AGE
    save `tot', replace
    restore

    * Men
    preserve
    keep if SEX == 1
    collapse (mean) `vars' ADULT [pw = WEIGHTa], by(CNT2 YEAR AGE)
    foreach v of local vars {
        rename `v' `v'm
    }
    rename ADULT ADULTm
    tempfile men
    sort CNT2 YEAR AGE
    save `men', replace
    restore

    * Women
    keep if SEX == 2
    collapse (mean) `vars' ADULT [pw = WEIGHTa], by(CNT2 YEAR AGE)
    foreach v of local vars {
        rename `v' `v'f
    }
    rename ADULT ADULTf

    * Merge total + men + women
    sort CNT2 YEAR AGE
    merge 1:1 CNT2 YEAR AGE using `men', nogen
    merge 1:1 CNT2 YEAR AGE using `tot', nogen


    ****************************************************************************
    * 2.  SMOOTH THE AGE PROFILES
    ****************************************************************************

    * Determine the year range to smooth
    sum YEAR
    local min = max(2007, `r(min)')
    local max = `r(max)'
    if "`x'" == "DE"  local max = 2021   // DE single-age data ends at 2021

    * Identify the open-ended top age group (80+, or 73+ for DE 2014-2018).
    * Its raw mean is kept after smoothing because it pools many ages and the
    * smoother's edge estimate is unreliable there.
    sort CNT2 YEAR AGE
    by CNT2 YEAR: egen _topage = max(AGE)

    * Store the raw sum of BSU + pensions before smoothing. This is used in
    * Section 2b to repair pension profiles around the unemployment cliff.
    gen double RSUM  = BSU  + BSPPEN
    gen double RSUMm = BSUm + BSPPENm
    gen double RSUMf = BSUf + BSPPENf


    **************************************************************************
    * 2a.  FIND THE BSU CLIFF AGE
    **************************************************************************
    *
    * Unemployment benefits typically drop to (near) zero at the age when
    * recipients move into early-retirement or pension schemes. This "cliff"
    * differs by country, sex and year.
    *
    * Detection rule (applied per year, separately for total/men/women):
    *   1. Compute the mean BSU at ages 50-56 as a reference level.
    *   2. Starting from age 57, find the first age where BSU stays at or
    *      below 15 % of that reference for three consecutive ages.
    *   3. Take the median of the detected cliff over three years (previous,
    *      current, next) to stabilise against noise. Default: 62.
    *
    * Smoothing (below) treats ages before and after the cliff separately,
    * with a moving-average bridge in between.

    foreach s in "" m f {

        local k = cond("`s'" == "", "0", "`s'")

        * Reference level: mean BSU at ages 50-56
        tempvar ref low l1 l2 cand cut
        by CNT2 YEAR: egen double `ref' = mean(cond(inrange(AGE, 50, 56), BSU`s', .))

        * Flag ages where BSU is at most 15 % of the reference
        gen byte `low' = BSU`s' <= 0.15 * `ref'

        * Check whether the next two ages are also low
        by CNT2 YEAR: gen byte `l1' = `low'[_n+1] if AGE[_n+1] == AGE + 1
        by CNT2 YEAR: gen byte `l2' = `low'[_n+2] if AGE[_n+2] == AGE + 2

        * Earliest age (57-72) with three consecutive low values
        gen `cand' = AGE if `low' & `l1' == 1 & `l2' == 1 ///
            & inrange(AGE, 57, 72) & `ref' > 0
        by CNT2 YEAR: egen `cut' = min(`cand')
        replace `cut' = 62 if `cut' == .             // default when no cliff found
        replace `cut' = .  if YEAR < `min' | YEAR > `max'

        * Stabilise: take the median cliff over three consecutive years
        preserve
        keep CNT2 YEAR `cut'
        duplicates drop
        sort CNT2 YEAR
        by CNT2: gen _cm1 = `cut'[_n-1] if YEAR[_n-1] == YEAR - 1
        by CNT2: gen _cp1 = `cut'[_n+1] if YEAR[_n+1] == YEAR + 1
        egen _BSUCUT`k' = rowmedian(_cm1 `cut' _cp1)
        keep CNT2 YEAR _BSUCUT`k'
        tempfile cut`k'
        save `cut`k'', replace
        restore

        merge m:1 CNT2 YEAR using `cut`k'', nogen
        sort CNT2 YEAR AGE
        drop `ref' `low' `l1' `l2' `cand' `cut'
    }


    **************************************************************************
    * 2b.  SMOOTH EACH BENEFIT TYPE
    **************************************************************************

    foreach var of local vars {

        * Create working copies for the smoothed values
        gen double s`var'  = `var'
        gen double s`var'm = `var'm
        gen double s`var'f = `var'f

        forvalues yr = `min'/`max' {

            * Non-BSU benefits: straightforward smoothing from age 18
            if "`var'" != "BSU" {

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

            * BSU: smooth only from 18 up to four years before the cliff
            *
            * The cliff age itself keeps its raw mean. The three ages just
            * before it get a moving average (below). Ages after the cliff
            * are smoothed separately (further below).

            if "`var'" == "BSU" {
                foreach s in "" m f {
                    local k = cond("`s'" == "", "0", "`s'")
                    quietly sum _BSUCUT`k' if YEAR == `yr'
                    if r(N) > 0 {
                        local c = r(mean) - 3
                        supsmooth `var'`s' AGE if YEAR == `yr' ///
                            & AGE >= 18 & AGE < `c', ///
                            gen(s`var'`s'1) bwcv nograph
                        replace s`var'`s' = s`var'`s'1 if s`var'`s'1 != .
                        drop s`var'`s'1
                    }
                }
            }
        }

        sort CNT2 YEAR AGE


        * BSU: 1-2-1 moving average in the three ages before the cliff
        *
        * These ages are too close to the cliff for the smoother but too far
        * for the raw means to be trusted. A weighted moving average (weights
        * 1-2-1, i.e. centred kernel) bridges between the smoothed region and
        * the cliff. Only ages inside the three-year window contribute.

        if "`var'" == "BSU" {
            foreach s in "" m f {
                local k = cond("`s'" == "", "0", "`s'")
                tempvar prv nxt ma

                by CNT2 YEAR: gen double `prv' = `var'`s'[_n-1] ///
                    if AGE[_n-1] == AGE - 1 & AGE - 1 >= _BSUCUT`k' - 3
                by CNT2 YEAR: gen double `nxt' = `var'`s'[_n+1] ///
                    if AGE[_n+1] == AGE + 1 & AGE + 1 <  _BSUCUT`k'

                * Full 1-2-1 average when both neighbours exist;
                * asymmetric at the edges of the window
                gen double `ma' = (`prv' + 2*`var'`s' + `nxt') / 4 ///
                    if `prv' < . & `nxt' < .
                replace `ma' = (2*`var'`s' + `nxt') / 3 ///
                    if `prv' == . & `nxt' < .
                replace `ma' = (`prv' + 2*`var'`s') / 3 ///
                    if `prv' < . & `nxt' == .
                replace `ma' = `var'`s' if `ma' == .

                replace s`var'`s' = `ma' ///
                    if AGE >= _BSUCUT`k' - 3 & AGE < _BSUCUT`k' ///
                    & inrange(YEAR, `min', `max')

                drop `prv' `nxt' `ma'
            }
        }


        * BSU after the cliff: smooth the tail on its own
        *
        * Very few people receive BSU past retirement age, so the raw means
        * jump erratically. Smoothing this tail separately avoids pulling the
        * pre-cliff profile toward zero.

        if "`var'" == "BSU" {
            forvalues yr = `min'/`max' {
                foreach s in "" m f {
                    local k = cond("`s'" == "", "0", "`s'")
                    capture supsmooth `var'`s' AGE ///
                        if YEAR == `yr' & AGE > _BSUCUT`k', ///
                        gen(_tail) bwcv nograph
                    if _rc {
                        di as text "BSU`s' `x' `yr': tail not smoothed " ///
                            "(rc " _rc "), raw means kept"
                    }
                    else {
                        replace s`var'`s' = _tail if _tail < .
                        drop _tail
                    }
                }
            }
        }


        * Open-ended top age group: keep raw mean (or cap for BSU)

        if "`var'" != "BSU" {
            * Non-BSU: restore the raw mean at the top age
            replace s`var'  = `var'  if AGE == _topage & inrange(YEAR, `min', `max')
            replace s`var'm = `var'm if AGE == _topage & inrange(YEAR, `min', `max')
            replace s`var'f = `var'f if AGE == _topage & inrange(YEAR, `min', `max')
        }
        else {
            * BSU: the top age may not exceed the preceding age (avoid an
            * upward spike from a handful of receivers)
            sort CNT2 YEAR AGE
            foreach s in "" m f {
                by CNT2 YEAR: replace s`var'`s' = min(s`var'`s', s`var'`s'[_n-1]) ///
                    if AGE == _topage & AGE[_n-1] == AGE - 1 ///
                    & inrange(YEAR, `min', `max')
            }
        }


        * Pensions: non-decreasing fit from 50 to their peak
        *
        * The standard smoother spreads the retirement step over many ages.
        * The isotonic fit (_enta_penfit) preserves the step while removing
        * noise. Above the peak the smoothed profile is kept (pensions per
        * person can fall at very old ages).

        if "`var'" == "BSPPEN" {
            sort CNT2 YEAR AGE
            foreach s in "" m f {
                forvalues yr = `min'/`max' {
                    _enta_penfit `var'`s' s`var'`s' `yr'
                }
            }
        }


        * BSU at ages 16-17: cap at the value of the next older age
        *
        * These unsmoothed raw means rest on very few receivers and can spike.

        if "`var'" == "BSU" {
            sort CNT2 YEAR AGE
            foreach a in 17 16 {
                foreach s in "" m f {
                    by CNT2 YEAR: replace s`var'`s' = min(s`var'`s', s`var'`s'[_n+1]) ///
                        if AGE == `a' & AGE[_n+1] == `a' + 1 ///
                        & inrange(YEAR, `min', `max')
                }
            }
        }


        * Replace originals with smoothed values; floor at zero

        replace `var'  = s`var'
        replace `var'f = s`var'f
        replace `var'm = s`var'm
        drop s`var' s`var'm s`var'f

        replace `var'  = 0 if `var'  < 0
        replace `var'f = 0 if `var'f < 0
        replace `var'm = 0 if `var'm < 0

    }   // end loop over benefit types


    **************************************************************************
    * 2c.  REPAIR PENSIONS AROUND THE BSU CLIFF
    **************************************************************************
    *
    * Problem: BSU rightly keeps its sharp cliff, but the smoother blurs the
    * corresponding pension step at the same age. Since early-retirement pay
    * (in BSU) hands over to pensions, their raw SUM is smooth. Fix: smooth
    * the sum, apply the same non-decreasing pension fit to it, and back out
    * pensions = smoothed sum - published BSU, for the six ages around the
    * cliff (cliff-3 to cliff+2).

    foreach s in "" m f {
        local k = cond("`s'" == "", "0", "`s'")

        * Smooth the raw sum (BSU + pensions)
        gen double sRSUM`s' = .
        forvalues yr = `min'/`max' {
            supsmooth RSUM`s' AGE if YEAR == `yr' & AGE >= 18, ///
                gen(tmp) bwcv nograph
            replace sRSUM`s' = tmp if tmp < .
            drop tmp
        }

        * Apply the non-decreasing pension fit to the smoothed sum
        sort CNT2 YEAR AGE
        forvalues yr = `min'/`max' {
            _enta_penfit RSUM`s' sRSUM`s' `yr'
        }

        * Back out pensions = smoothed sum minus BSU, in the cliff window
        replace BSPPEN`s' = max(0, sRSUM`s' - BSU`s') ///
            if inrange(AGE, _BSUCUT`k' - 3, _BSUCUT`k' + 2) ///
            & inrange(YEAR, `min', `max')

        drop RSUM`s' sRSUM`s'
    }


    **************************************************************************
    * 2d.  SAVE
    **************************************************************************

    drop _topage _BSUCUT0 _BSUCUTm _BSUCUTf
    sort CNT2 YEAR AGE
    save ENTA_ageprofiles/ageprofiles/ben_`x', replace

}   // end of country loop
