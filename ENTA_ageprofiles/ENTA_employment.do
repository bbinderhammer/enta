********************************************************************************
* Age-profiles of LFS-based quantities, such as employment
********************************************************************************

* Output: ENTA_ageprofiles/ageprofiles/lfs_[CNT2].dta, one row per country,
*         year and age (80 = 80 and over): weighted means of EMPL (employed,
*         at least 1 usual hour a week), EMPLFT and EMPLFTACT (full-time
*         equivalents from usual and actual hours), EMPLSTAT (employed by
*         status), WHRUSU and WHRACT (weekly hours in the main job, usual and
*         actual) and WHRUSUT and WHRACTT (all jobs), UNEMPL (ILO
*         unemployed) and UNEMPLBEN (receives unemployment benefits; smoothed
*         for RO and EL, see Section 1); each also for men (suffix m) and women
*         (suffix f).
* Read by: ENTA_compilation1_esa.do (:217, :222).
* Input:  $lfswd/lfs_[CNT2].dta (Micro_LFS.do).
* Requires ENTA_setup_TU.do / ENTA_setup.do ($lfswd).
* Not smoothed, deliberately: the LFS sample is large enough. The exception is
* UNEMPLBEN for RO and EL (Section 1).
* Ages: NL, CZ, SK and IE deliver 5-year groups only (AGE is the lower
* bound; compilation1 merges them on AGEGR5); AT, HR, IT and SK end in an
* open group 75+ (AGE 75). Children 0-14 delivered with an age group only
* form one row with AGE missing, which compilation1 drops - it sets every LFS
* measure to 0 below age 15.
*
* Content
* 0. Load LFS data
* 1. Generate age-profiles

********************************************************************************
* 0. Load LFS data
********************************************************************************

global country "AT BE BG CY CZ DE DK EE EL ES FI FR HR HU IE IT LT LU LV NL PL PT RO SE SI SK" //
* global country "AT DE IT FR PL CZ ES SE DK"
* global country "CZ SI"

foreach x in $country {

    * Read data
    use $lfswd/lfs_`x'.dta, clear

    * Open top age group 80+: ages above 80 are set to 80, so that age 80 holds
    * everyone aged 80 and over - the open group of population80w and of the
    * other profiles, and the only top row ENTA_compilation1_esa.do merges.
    replace AGE = 80 if AGE>80 & AGE<.

    * [INACTIVE] shares of full-time and part-time employed, not used
    /*
    * Generate additonal variables
      gen EMPLFTSH = 0
        replace EMPLFTSH = 1 if EMPLFT==1
      gen EMPLPTSH = 0
        replace EMPLPTSH = 1 if EMPLFT<1 & WHRUSU>1
    */

    ********************************************************************************
    * 1. Generate age-profiles
    ********************************************************************************

    local vars "EMPL EMPLFT EMPLFTACT EMPLSTAT WHRUSU WHRUSUT WHRACT WHRACTT UNEMPL UNEMPLBEN"
    * [INACTIVE] earlier list, with variables no longer built
    * local vars "WHRUSU WHRACT EMPL EMPL2 EMPLFTSH EMPLPTSH EMPLFT"

    * Men (suffix m) and women (suffix f)
    foreach s in 1 2 {
        local sfx = cond(`s'==1, "m", "f")
        preserve
        keep if SEX==`s'
        collapse (mean) `vars' [pw=WEIGHTa], by(CNT2 YEAR AGE)
        foreach var of local vars {
            rename `var' `var'`sfx'
        }
        tempfile sex`s'
        save `sex`s''
        restore
    }

    * Total, and the two sexes merged on
    collapse (mean) `vars' [pw=WEIGHTa], by(CNT2 YEAR AGE)
    merge 1:1 CNT2 YEAR AGE using `sex1', nogen
    merge 1:1 CNT2 YEAR AGE using `sex2', nogen

    * UNEMPLBEN, the share receiving unemployment benefits, is the one LFS
    * measure that is smoothed: ENTA_compilation1_esa.do uses it as the
    * age shape of the unemployment benefits of RO, EL and SK, where EU-SILC
    * has fewer than 20 receivers per single age in most years and the LFS
    * clearly more (the 20-receiver rule). Receivers (REGISTER 1) a year in the LFS: RO 436-1,782,
    * EL 2,000-4,900 (about 400 from 2021). supsmooth as for the benefits in
    * ENTA_benefits.do, ages 18-64, by year and sex; below 18 and from 65 the
    * raw means (0 from 65 in RO: the benefits end with retirement), floored at
    * 0. Only for the countries in `unbcnt', the ones that use it. SK (270-763
    * receivers a year) uses it too, but is not smoothed: its LFS has
    * five-year age groups only, which compilation1 spreads over the single
    * ages of each group (a step function).
    local unbcnt "RO EL"
    if strpos(" `unbcnt' ", " `x' ") {
        sort CNT2 YEAR AGE
        levelsof YEAR if !missing(UNEMPLBEN), local(yrs)
        foreach s in "" m f {
            foreach yr of local yrs {
                capture drop _s
                capture supsmooth UNEMPLBEN`s' AGE if YEAR==`yr' & inrange(AGE,18,64), gen(_s) bwcv nograph
                if !_rc {
                    replace UNEMPLBEN`s' = max(_s, 0) if _s<.
                }
                else {
                    display as error "UNEMPLBEN`s' `x' `yr': not smoothed (supsmooth r(" _rc "))"
                }
                capture drop _s
            }
        }
    }

    sort CNT2 YEAR AGE
    save ENTA_ageprofiles/ageprofiles/lfs_`x', replace

}



