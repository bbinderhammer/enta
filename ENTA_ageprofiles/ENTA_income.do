********************************************************************************
* Calculate income age profiles from EU-SILC
********************************************************************************
*
* PURPOSE:
*   Build per-capita income age profiles (one row per country, year, age) from
*   EU-SILC micro data. The profiles are later scaled to national-accounts
*   aggregates in the compilation step.
*
* OUTPUT FILES:
*   - inc_[CC].dta          Smoothed age profiles of YE YM YEM YPr YPp YO YPrX,
*                           equivalised household income (mean EHI, median EHIMED),
*                           and labour-market variables (EMPLSTATsilc, EMPLFTsilc,
*                           WHRUSUsilc), each for total, men (suffix m), women (f).
*   - ypp_rec_[CC].dta      Median number of YPp / YPr receivers per single age
*                           and year (used by Section 3 to decide borrowing).
*
* INPUT:
*   $silcwd/data/silc_[CC].dta   (produced by Micro_SILC.do)
*
* REQUIRES:
*   ENTA_setup.do (sets $silcwd and $country)
*   User-written command: supsmooth
*
* OUTLINE:
*   0. Load EU-SILC data and cap extreme incomes
*   1. Collapse micro data into age profiles
*      1b. Fix country-years where mortgage interest (HY100G) is missing
*      1c. Fix Irish private pensions in 2018
*   2. Smooth the profiles
*      2.1  Smooth individual income types
*      2.1b Enforce monotonicity at ages 15-17
*      2.2  Smooth equivalised household income
*      2.3  Save
*   3. Borrow property-income shapes for thin country-years
********************************************************************************


********************************************************************************
* 0.  LOAD EU-SILC DATA AND CAP EXTREME INCOMES
********************************************************************************

* List of countries to process (set earlier by ENTA_setup.do)
global country  AT BE BG CY CZ DE DK EE EL ES FI FR HU HR IE IT LT LU LV ///
    NL PL PT RO SE SI SK

foreach x in $country {

    * 0a. Load the country's micro file
    use $silcwd/data/silc_`x', clear


    * 0b. Use the room-based imputed-rent estimate for every country-year
    *
    * EU-SILC's official imputed rent (HY030G) is missing or zero for Germany
    * in all years, for all countries in income years 2020-2021, and for
    * scattered other country-years. Micro_SILC.do constructed YOest: each
    * person's share of dwelling rooms (full share if owner or rent-free, half
    * if reduced rent). We use YOest everywhere for consistency; only its age
    * shape matters because the compilation later rescales to the aggregate.
    replace YO = YOest


    * 0c. Cap outlier incomes
    *
    * For each income type, within each country-year:
    *   1. Set negatives and missings to zero.
    *   2. Compute the weighted mean over receivers (persons with income > 1 euro).
    *   3. Cap individual values at a multiple of that mean:
    *      - 6x for property income (YPr, YPp) - they have fat tails
    *      - 10x for all other types (YE, YM, YEM, YO)
    *
    * YE, YM and YEM are capped independently, so a capped person's YEM may
    * differ slightly from YE + YM (affects ~0.5 % of persons).

    local vars "YE YM YEM YPr YPp YO"

    foreach var of local vars {

        * Zero out missings and negatives
        replace `var' = 0 if `var' == . | `var' < 0

        * Weighted total income and weighted number of receivers (income > 1 euro)
        gen double `var'aggr = `var' * WEIGHTa
        gen double `var'pop  = (`var' > 1) * WEIGHTa

        bysort CNT2 YEAR: egen double t`var' = total(`var'aggr)
        bysort CNT2 YEAR: egen double n`var' = total(`var'pop)

        gen double mean`var' = t`var' / n`var'

        * Choose the cap multiple: 6 for property income, 10 otherwise
        local k = cond(inlist("`var'", "YPr", "YPp"), 6, 10)
        replace `var' = mean`var' * `k'  if `var' > mean`var' * `k'

        drop `var'aggr `var'pop t`var' n`var' mean`var'
    }

    * Keep the private-pension component of YPr (PY080G) for the Irish repair
    * in step 1c. Capped to lie within [0, YPr].
    gen double YPpens = cond(PY080G > 0 & PY080G < ., min(PY080G, YPr), 0)


    ******************************************************************************
    * 1.  COLLAPSE MICRO DATA INTO AGE PROFILES
    ******************************************************************************

    local vars "YE YM YEM YPp YPr YO EHI WHRUSU EMPLSTAT EMPLFT YPpens"


    * 1a. Count receivers of property income per single age
    *
    * For each country-year, count unweighted persons with YPp > 1 euro and
    * YPr > 1 euro at every age. Then take the median count across ages 30-59
    * (for YPp) and 30-79 (for YPr). These medians decide, in Section 3,
    * whether a country-year must borrow another country's profile shape and
    * how much weight its own shape gets.
    *
    * Country-years whose YPp was repaired in step 1b get their count set to
    * missing so that Section 3 leaves them untouched.

    preserve
    gen byte _recp = YPp > 1
    gen byte _recr = YPr > 1

    * Total receivers per country-year-age
    collapse (sum) _recp _recr, by(CNT2 YEAR AGE)

    * Restrict to the relevant age window before taking the median
    gen double _p = _recp if inrange(AGE, 30, 59)
    gen double _r = _recr if inrange(AGE, 30, 79)

    collapse (median) NYPPREC = _p  NYPRREC = _r, by(CNT2 YEAR)

    * Blank out the repaired years (their profile already comes from neighbours)
    replace NYPPREC = . if (CNT2 == "HU" & YEAR == 2018) ///
        | (CNT2 == "FR" & YEAR == 2020) ///
        | (CNT2 == "DE" & YEAR == 2008)

    save ENTA_ageprofiles/ageprofiles/ypp_rec_`x', replace
    restore


    * 1b-1. Collapse to weighted means (and median EHI) by country-year-age

    * Total population
    preserve
    collapse (median) EHIMED = EHI  (mean) `vars'  [pw = WEIGHTa], ///
        by(CNT2 YEAR AGE)
    tempfile tot
    sort CNT2 YEAR AGE
    save `tot', replace
    restore

    * Men only
    preserve
    keep if SEX == 1
    collapse (median) EHIMEDm = EHI  (mean) `vars'  [pw = WEIGHTa], ///
        by(CNT2 YEAR AGE)
    foreach v of local vars {
        rename `v' `v'm
    }
    tempfile men
    sort CNT2 YEAR AGE
    save `men', replace
    restore

    * Women only
    keep if SEX == 2
    collapse (median) EHIMEDf = EHI  (mean) `vars'  [pw = WEIGHTa], ///
        by(CNT2 YEAR AGE)
    foreach v of local vars {
        rename `v' `v'f
    }

    * Merge the three files (total, men, women) into one dataset
    sort CNT2 YEAR AGE
    merge 1:1 CNT2 YEAR AGE using `men', nogen
    sort CNT2 YEAR AGE
    merge 1:1 CNT2 YEAR AGE using `tot', nogen


    ****************************************************************************
    * 1b.  REPAIR COUNTRY-YEARS WITHOUT MORTGAGE-INTEREST DATA
    ****************************************************************************
    *
    * A few country-years have no usable HY100G (the sole source of YPp), so
    * the collapsed YPp profile is identically zero:
    *   HU 2018 - values recorded as 0 with flag "no income"
    *   FR 2020 - blank, flag "not collected"
    *   DE 2008 - blank, flag "missing"
    *
    * Fix: replace the broken year's YPp profile with the average of its two
    * neighbours. Exception: DE 2007 is broken too, so DE 2008 takes 2009 alone.

    local badyear ""
    if "`x'" == "HU"  local badyear 2018
    if "`x'" == "FR"  local badyear 2020
    if "`x'" == "DE"  local badyear 2008

    if "`badyear'" != "" {

        * Identify the neighbour years to average
        local before = `badyear' - 1
        local after  = `badyear' + 1
        if "`x'" == "DE"  local before = `after'   // 2007 unusable -> use 2009 twice

        * Compute the average YPp profile from the neighbours
        preserve
        keep if YEAR == `before' | YEAR == `after'
        keep CNT2 AGE YPp YPpm YPpf
        collapse (mean) YPp YPpm YPpf, by(CNT2 AGE)
        rename (YPp YPpm YPpf) (iYPp iYPpm iYPpf)
        tempfile ypfix
        sort CNT2 AGE
        save `ypfix', replace
        restore

        * Overwrite the broken year with the interpolated profile
        sort CNT2 AGE
        merge m:1 CNT2 AGE using `ypfix', nogen keep(master match)

        replace YPp  = iYPp  if YEAR == `badyear' & iYPp  < .
        replace YPpm = iYPpm if YEAR == `badyear' & iYPpm < .
        replace YPpf = iYPpf if YEAR == `badyear' & iYPpf < .
        drop iYPp iYPpm iYPpf

        sort CNT2 YEAR AGE
        display "`x' `badyear': YPp interpolated from `before' and `after'"
    }


    * Property income net of private pensions (YPrX)
    *
    * YPrX = YPr minus private pensions. It serves as the ownership key for
    * distributing corporate income over ages in the compilation. Private
    * pensions concentrate above 60 and reflect pension-fund withdrawals, not
    * ownership of operating businesses. Built here, before step 1c changes
    * the pension component of YPr for Ireland.

    foreach s in "" m f {
        gen double YPrX`s' = max(0, YPr`s' - YPpens`s')
    }


    ****************************************************************************
    * 1c.  REPLACE IRISH PRIVATE PENSIONS IN 2018
    ****************************************************************************
    *
    * IE EU-SILC 2018 reports private-pension income (PY080G) for 609 persons
    * versus ~150 in neighbouring years, inflating the weighted total from
    * ~0.5 bn to 3.1 bn. Cause unknown. Fix: swap the pension component of
    * the 2018 YPr profile with the average of 2017 and 2019; rent and
    * investment income stay as reported.

    if "`x'" == "IE" {

        preserve
        keep if YEAR == 2017 | YEAR == 2019
        keep CNT2 AGE YPpens YPpensm YPpensf
        collapse (mean) YPpens YPpensm YPpensf, by(CNT2 AGE)
        rename (YPpens YPpensm YPpensf) (iYPpens iYPpensm iYPpensf)
        tempfile pensfix
        sort CNT2 AGE
        save `pensfix', replace
        restore

        sort CNT2 AGE
        merge m:1 CNT2 AGE using `pensfix', nogen keep(master match)

        * Subtract the original pension part and add the interpolated one
        replace YPr  = YPr  - YPpens  + iYPpens  if YEAR == 2018 & iYPpens  < .
        replace YPrm = YPrm - YPpensm + iYPpensm if YEAR == 2018 & iYPpensm < .
        replace YPrf = YPrf - YPpensf + iYPpensf if YEAR == 2018 & iYPpensf < .

        drop iYPpens iYPpensm iYPpensf
        sort CNT2 YEAR AGE
        display "IE 2018: private pensions in YPr replaced by the 2017/2019 average"
    }

    drop YPpens YPpensm YPpensf


    ******************************************************************************
    * 2.  SMOOTH THE AGE PROFILES
    ******************************************************************************

    ****************************************************************************
    * 2.1  Smooth individual income types
    ****************************************************************************
    *
    * supsmooth is a nonparametric smoother (Friedman's super smoother). It is
    * applied year by year, for total / men / women separately, to ages 18+.
    *
    * Property income (YPp, YPr, YPrX) gets stronger smoothing (alpha = 8)
    * because these profiles are noisy. All other types (YE, YM, YEM, YO) use
    * the default bandwidth.
    *
    * Exceptions:
    *   - Germany: single-age data stops at 2021; later years stay unsmoothed.
    *   - France:  alpha(8) crashes supsmooth, so it uses the default too.

    * Determine the year range available in the data
    sum YEAR
    local min = max(2007, `r(min)')
    local max = `r(max)'

    * Pass 1: property income with stronger smoothing (alpha = 8)

    local vars "YPp YPr YPrX"

    * Country-specific overrides
    if "`x'" == "DE" {
        local max  = 2021
        local vars ""          // skip this pass; DE handled in pass 2
    }
    if "`x'" == "FR" {
        local vars ""          // skip this pass; FR handled in pass 2
    }

    foreach var of local vars {

        replace `var' = 0 if `var' == .

        * Create working copies that will hold the smoothed values
        gen double s`var'  = `var'
        gen double s`var'm = `var'm
        gen double s`var'f = `var'f

        forvalues yr = `min'/`max' {

            * Smooth total, men, women - ages 18+ only
            supsmooth `var'  AGE if YEAR == `yr' & AGE >= 18, gen(s`var'1)  bwcv alpha(8) nograph
            replace s`var'  = s`var'1  if s`var'1  != .

            supsmooth `var'm AGE if YEAR == `yr' & AGE >= 18, gen(s`var'm1) bwcv alpha(8) nograph
            replace s`var'm = s`var'm1 if s`var'm1 != .

            supsmooth `var'f AGE if YEAR == `yr' & AGE >= 18, gen(s`var'f1) bwcv alpha(8) nograph
            replace s`var'f = s`var'f1 if s`var'f1 != .

            drop s`var'1 s`var'm1 s`var'f1
        }
    }


    * Pass 2: remaining income types with default smoothing
    *
    * For DE and FR this pass also covers property income (skipped above).

    local vars "YE YM YEM YO"
    if "`x'" == "DE" {
        local max  = 2021
        local vars "YPr YPrX YPp YE YM YEM YO"
    }
    if "`x'" == "FR" {
        local vars "YPr YPrX YPp YE YM YEM YO"
    }

    foreach var of local vars {

        gen double s`var'  = `var'
        gen double s`var'm = `var'm
        gen double s`var'f = `var'f

        forvalues yr = `min'/`max' {

            supsmooth `var'  AGE if YEAR == `yr' & AGE >= 18, gen(s`var'1)  bwcv nograph
            replace s`var'  = s`var'1  if s`var'1  != .

            supsmooth `var'm AGE if YEAR == `yr' & AGE >= 18, gen(s`var'm1) bwcv nograph
            replace s`var'm = s`var'm1 if s`var'm1 != .

            supsmooth `var'f AGE if YEAR == `yr' & AGE >= 18, gen(s`var'f1) bwcv nograph
            replace s`var'f = s`var'f1 if s`var'f1 != .

            drop s`var'1 s`var'm1 s`var'f1
        }
    }


    * Restore the raw mean for the open-ended top age group
    *
    * The top age (80+, or 73+ for DE 2014-2018) pools many ages, so its raw
    * mean is more reliable than the smoother's edge extrapolation.

    sort CNT2 YEAR AGE
    by CNT2 YEAR: egen _topage = max(AGE)

    local vars "YPr YPrX YPp YE YM YEM YO"
    foreach var of local vars {

        * Keep the raw value at the top age
        replace s`var'  = `var'  if AGE == _topage & inrange(YEAR, `min', `max')
        replace s`var'm = `var'm if AGE == _topage & inrange(YEAR, `min', `max')
        replace s`var'f = `var'f if AGE == _topage & inrange(YEAR, `min', `max')

        * Overwrite originals with smoothed values
        replace `var'  = s`var'  if s`var'  != .
        replace `var'm = s`var'm if s`var'm != .
        replace `var'f = s`var'f if s`var'f != .
        drop s`var' s`var'm s`var'f

        * Floor at zero; children under 15 get zero
        replace `var'  = 0 if `var'  < 0 | AGE < 15
        replace `var'm = 0 if `var'm < 0 | AGE < 15
        replace `var'f = 0 if `var'f < 0 | AGE < 15
    }


    ****************************************************************************
    * 2.1b  Enforce non-decreasing income for ages 15-17
    ****************************************************************************
    *
    * Smoothing starts at 18, so the raw values at 15-17 can spike above the
    * smoothed value at 18. Walking downward from age 18, cap each age's value
    * at the next-higher age's value, ensuring a monotone rise into the
    * smoothed region.

    local vars "YPr YPrX YPp YE YM YEM YO"
    gsort CNT2 YEAR -AGE                       // descending age within group

    foreach var of local vars {
        by CNT2 YEAR: replace `var'  = `var'[_n-1]  ///
            if AGE >= 15 & AGE <= 17 & `var'[_n-1] != . & `var'  > `var'[_n-1]
        by CNT2 YEAR: replace `var'm = `var'm[_n-1] ///
            if AGE >= 15 & AGE <= 17 & `var'm[_n-1] != . & `var'm > `var'm[_n-1]
        by CNT2 YEAR: replace `var'f = `var'f[_n-1] ///
            if AGE >= 15 & AGE <= 17 & `var'f[_n-1] != . & `var'f > `var'f[_n-1]
    }

    sort CNT2 YEAR AGE


    ****************************************************************************
    * 2.2  Smooth equivalised household income (all ages)
    ****************************************************************************
    *
    * Unlike individual income, equivalised household income is defined at
    * every age (including children), so smoothing covers the full age range.

    local vars "EHI EHIMED"

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

        * Overwrite originals
        replace `var'  = s`var'
        replace `var'm = s`var'm
        replace `var'f = s`var'f
        drop s`var' s`var'm s`var'f
    }


    ****************************************************************************
    * 2.3  Save the smoothed income age profiles
    ****************************************************************************

    drop _topage
    sort CNT2 YEAR AGE

    * Rename labour-market variables to flag their EU-SILC origin
    local vars EMPLSTAT EMPLFT WHRUSU
    foreach var of local vars {
        rename `var'  `var'silc
        rename `var'm `var'silcm
        rename `var'f `var'silcf
    }

    save ENTA_ageprofiles/ageprofiles/inc_`x', replace

}   // end of country loop


********************************************************************************
* 3.  BORROW PROPERTY-INCOME SHAPES FOR THIN COUNTRY-YEARS
********************************************************************************
*
* MOTIVATION
************************************************************
* Some country-years have very few receivers of mortgage interest (YPp) or
* property income received (YPr), so the age profile is too noisy to use.
* The "20-receiver rule" identifies these cases and blends their own shape
* with the average shape of better-observed Central/Eastern European (CEE)
* countries in the same year.
*
* DECISION RULE (per country, applied to all its years for consistency)
************************************************************
* A country borrows if its median number of receivers per single age falls
* below 20 in at least half of the available years:
*   YPp (ages 30-59): RO, BG, HR, LT, LV
*   YPr (ages 30-79): RO, HU           (YPrX uses the same YPr counts)
*
* BLENDING FORMULA
************************************************************
*   blended shape = w x own shape + (1 - w) x donor shape
*   w = n / (n + 5),  where n = the country's typical number of receivers per
*   single age: the median over its years of the yearly median. One weight
*   per country, so that the mix does not change from year to year.
*
* "Shape" = profile / mean(profile at ages 20-79), so only the age pattern
* is borrowed; the level is later set by the national-accounts aggregate.
* If the own profile is zero everywhere, the donor shape is used in full.
* If the receiver count is missing (repaired years from step 1b), the own
* profile is kept unchanged.
*
* DONORS
* Any CEE country-year with >= 20 receivers per single age, of a country
* that does not borrow this variable itself. The donor shape is the unweighted
* mean across all donor country-years in that calendar year.

local cee  "BG CZ EE HR HU LT LV PL RO SI SK"
local k     5                              // blending parameter

* Three specifications: variable, receiver-count variable, borrowing countries
local spec1 "YPp  NYPPREC  RO BG HR LT LV"
local spec2 "YPr  NYPRREC  RO HU"
local spec3 "YPrX NYPRREC  RO HU"

tempfile ypsh ypnew


* 3a. Assemble all CEE profiles and receiver counts into one file

local first 1
foreach c of local cee {

    capture confirm file ENTA_ageprofiles/ageprofiles/inc_`c'.dta
    if _rc  continue                         // skip if file does not exist

    use CNT2 YEAR AGE YPp YPpm YPpf YPr YPrm YPrf YPrX YPrXm YPrXf ///
        using ENTA_ageprofiles/ageprofiles/inc_`c', clear

    merge m:1 CNT2 YEAR using ENTA_ageprofiles/ageprofiles/ypp_rec_`c', ///
        keep(master match) nogen

    if `first'  save `ypsh'
    else {
        append using `ypsh'
        save `ypsh', replace
    }
    local first 0
}

use `ypsh', clear


* 3b. Flag countries in the current run and perform blending

* _run = 1 for countries being processed now (so already-blended profiles
* from a previous run are not blended a second time)
gen byte _run = strpos(" $country ", " " + CNT2 + " ") > 0
gen byte _chg = 0                          // tracks which rows were modified

forvalues i = 1/3 {

    * Parse the specification: variable name, count variable, list of borrowers
    gettoken v   rest : spec`i'
    gettoken n   rec  : rest

    * Identify borrowers: listed countries in the current run, years with
    *     a non-missing receiver count ---
    * The weight uses the country's typical number of receivers (median over
    * its years), not the number of the single year
    bysort CNT2: egen double _ntyp = median(`n')
    gen double _w = _ntyp / (_ntyp + `k') ///
        if `n' < . & _run & strpos(" `rec' ", " " + CNT2 + " ") > 0

    * Identify donors: country-years with >= 20 receivers per single age,
    *     of countries that do not borrow this variable ---
    gen byte _don = (`n' >= 20 & `n' < . & strpos(" `rec' ", " " + CNT2 + " ") == 0)

    * Blend for total, men, women
    foreach s in "" m f {

        * Own shape: profile / mean(profile at ages 20-79)
        bysort CNT2 YEAR: egen double _m  = mean(cond(inrange(AGE, 20, 79), `v'`s', .))
        gen double _sh = cond(_m > 0 & _m < ., `v'`s' / _m, .)

        * Donor shape: average of donor countries' shapes in the same year and age
        bysort YEAR AGE: egen double _d = mean(cond(_don, _sh, .))

        * Blended profile (only for borrowing country-years)
        replace `v'`s' = cond(_sh < ., (_w * _sh + (1 - _w) * _d) * _m, _d) ///
            if _w < . & _d < .

        drop _m _sh _d
    }

    replace _chg = 1 if _w < .

    * Report which country-years borrow and how much weight their own shape gets
    di _n "`v': country-years that borrow " ///
        "(receivers per single age: of the year and typical; weight of own shape)"
    preserve
    keep if _w < . & AGE == 40
    sort CNT2 YEAR
    list CNT2 YEAR `n' _ntyp _w, noobs clean
    restore

    drop _w _don _ntyp
}


* 3c. Write the blended profiles back into the country files

keep if _chg
keep CNT2 YEAR AGE YPp YPpm YPpf YPr YPrm YPrf YPrX YPrXm YPrXf
save `ypnew'

levelsof CNT2, local(thin)

foreach c of local thin {
    use ENTA_ageprofiles/ageprofiles/inc_`c', clear

    * update replace: overwrite matching observations with the blended values
    merge 1:1 CNT2 YEAR AGE using `ypnew', update replace keep(1 3 4 5) nogen

    sort CNT2 YEAR AGE
    save ENTA_ageprofiles/ageprofiles/inc_`c', replace
}
