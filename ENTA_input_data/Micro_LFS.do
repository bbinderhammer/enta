********************************************************************************
* Micro_LFS.do - EU Labour Force Survey: employment and working hours
*
* Reads the EU-LFS yearly files, codes employment and working hours for every
* person, and saves one file per country with all years.
*   Input   $lfsin/<CC>_YEAR/<CC><year>_y.csv (EU-LFS scientific-use files)
*           ENTA_input_data/ENTA_input_datasets/population_agegr3.dta
*   Output  $lfswd/lfs_<CC>.dta, read only by ENTA_ageprofiles/ENTA_employment.do,
*           which averages EMPL EMPLFT EMPLFTACT EMPLSTAT WHRUSU WHRUSUT WHRACT
*           WHRACTT by country, year, age and sex, weighted with WEIGHTa.
*
* EU-LFS codes used here. Hours (HWUSUAL, HWACTUAL, HWUSU2J, HWACTU2J) are per
* week; 97 = usual hours vary, 99 = not applicable. WKSTAT 1 = worked for pay
* or profit in the reference week, 2 = had a job but was absent; ABSREAS is
* the reason for the absence.
*
* Age. The Netherlands, Czechia, Ireland and Slovakia deliver only five-year
* age groups (AGE_GRP). AGE is then the lower bound of the group, and
* ENTA_compilation1_esa.do handles these countries (manual, Chapter 5).
*
* Content
* 0. Prepare LFS data
* 1. Append data for all years
* 2. Check the data (commented out)
********************************************************************************

global country "AT BE BG CY CZ DE DK EE EL ES FI FR HR HU IE IT LT LU LV NL PL PT RO SE SI SK"

* Survey years read
  local firstyear = 1995
  local lastyear  = 2024


********************************************************************************
* 0. Prepare LFS data
********************************************************************************

foreach x in $country {
  display "`x'"

  forvalues year = `firstyear'/`lastyear' {

    * Data available?
      capture confirm file "$lfsin/`x'_YEAR/`x'`year'_y.csv"
      if _rc!=0 {
        continue
      }

    clear
    import delimited "$lfsin/`x'_YEAR/`x'`year'_y.csv", case(preserve)

    * General variables
      gen CNT2 = "`x'"
      gen HHID = HHNUM
      bysort YEAR HHNUM: gen WHHID = _n
      egen ID = group(YEAR HHNUM WHHID)
      gen WEIGHT = COEFFY * 1000
      gen ONE = 1

    * Migration status
      gen COB = .
      capture confirm string variable COUNTRYB
      if !_rc {
        replace COB = 0 if COUNTRYB=="NAT"
        replace COB = 1 if COUNTRYB=="EU27_2020"
        replace COB = 2 if COUNTRYB!="NAT" & COUNTRYB!="EU27_2020" & COUNTRYB!=""
      }
      gen MIGR = inlist(COB, 1, 2)

    * Age
      gen AGEGR5 = .
      replace AGEGR5 = 0 if AGE_GRP=="Y0-4"
      replace AGEGR5 = 5 if AGE_GRP=="Y5-9"
      replace AGEGR5 = 10 if AGE_GRP=="Y10-14"
      replace AGEGR5 = 15 if AGE_GRP=="Y15-19"
      replace AGEGR5 = 20 if AGE_GRP=="Y20-24"
      replace AGEGR5 = 25 if AGE_GRP=="Y25-29"
      replace AGEGR5 = 30 if AGE_GRP=="Y30-34"
      replace AGEGR5 = 35 if AGE_GRP=="Y35-39"
      replace AGEGR5 = 40 if AGE_GRP=="Y40-44"
      replace AGEGR5 = 45 if AGE_GRP=="Y45-49"
      replace AGEGR5 = 50 if AGE_GRP=="Y50-54"
      replace AGEGR5 = 55 if AGE_GRP=="Y55-59"
      replace AGEGR5 = 60 if AGE_GRP=="Y60-64"
      replace AGEGR5 = 65 if AGE_GRP=="Y65-69"
      replace AGEGR5 = 70 if AGE_GRP=="Y70-74"
      replace AGEGR5 = 75 if AGE_GRP=="Y75-79"
      replace AGEGR5 = 80 if AGE_GRP=="Y80-84"
      replace AGEGR5 = 85 if AGE_GRP=="Y85-89"
      replace AGEGR5 = 90 if AGE_GRP=="Y90-94"
      replace AGEGR5 = 95 if AGE_GRP=="Y95-99"
      replace AGEGR5 = 100 if AGE_GRP=="Y_GE100"
      replace AGEGR5 = 75 if AGE_GRP=="Y_GE75"
      replace AGEGR5 = 80 if AGE_GRP=="Y_GE80"

      * Number of persons with a single year of age (0 = AGE missing throughout)
        bysort YEAR: egen AGE_nonmiss = count(AGE)
      * AGE missing throughout (five-year groups only): lower bound of the group
        replace AGE = AGEGR5 if AGE_nonmiss==0
      * Open top groups, which have no single year of age
        replace AGE = 75 if AGE_GRP=="Y_GE75" & AGE_nonmiss!=0 & AGE==.
        replace AGE = 80 if AGE_GRP=="Y_GE80" & AGE_nonmiss!=0 & AGE==.

      * Broad age groups 0-19, 20-64, 65+ (missing if the age group is unknown)
        gen AGEGR3 = cond(AGEGR5 < 20, 0, cond(AGEGR5 < 65, 1, 2)) if !missing(AGEGR5)

    * Weight WEIGHTa: the survey weight scaled to the population of the broad
    * age group. The scaling is meant for the oldest group, many of whom live
    * in institutions outside the private households the survey covers. Ages
    * 0-19 keep the survey weight (project owner, 2026-09-27), as does anyone
    * whose age group is unknown. The factor is constant within an age group,
    * so it does not change the means by single age in ENTA_employment.do.
      preserve
        collapse (sum) WEIGHT, by(CNT2 YEAR AGEGR3)
        rename WEIGHT POPLFS
        sort CNT2 YEAR AGEGR3
        tempfile agepop
        save `agepop'
      restore

      sort CNT2 YEAR AGEGR3
      merge m:1 CNT2 YEAR AGEGR3 using `agepop', nogenerate

      * Add population data
        sort CNT2 YEAR AGEGR3
        merge m:1 CNT2 YEAR AGEGR3 using "ENTA_input_data/ENTA_input_datasets/population_agegr3"
        keep if _merge==3 | (_merge==1 & missing(AGEGR3))
        drop _merge

      gen ADJPOP = POP / POPLFS
      replace ADJPOP = 1 if AGEGR3==0 | missing(AGEGR3)
      gen WEIGHTa = WEIGHT * ADJPOP
      drop POP

    * Missing values: 99 = not applicable
      foreach var in HWUSUAL HWUSU2J HWACTUAL HWACTU2J {
        replace `var' = . if `var'==99
      }

    * Usual hours in main job (WHRUSU)
      gen WHRUSU = HWUSUAL
      * 97 = hours vary: the actual hours of the reference week, if at least 1
        replace WHRUSU = HWACTUAL if HWUSUAL==97 & HWACTUAL>=1 & HWACTUAL<=95
      * ... otherwise the weighted mean usual hours of those with fixed usual
      * hours, same country, year and sex. (Before 2026-09-27 these kept the
      * code 97 and were capped to 80 hours - 532 persons in IT 2019 - or got 0
      * hours, and so no employment, when absent in the reference week.)
        gen double _h = HWUSUAL if HWUSUAL>=1 & HWUSUAL<=95
        bysort YEAR SEX: egen double _hw = total(_h * WEIGHT)
        bysort YEAR SEX: egen double _w  = total(WEIGHT * !missing(_h))
        replace WHRUSU = _hw / _w if HWUSUAL==97 & !(HWACTUAL>=1 & HWACTUAL<=95)
        drop _h _hw _w
      replace WHRUSU = 0 if WHRUSU==.
      replace WHRUSU = 80 if WHRUSU>=80

    * Usual hours in main and second job
      gen WHRUSUT = WHRUSU
      replace WHRUSUT = WHRUSUT + HWUSU2J if HWUSU2J>=1 & HWUSU2J<=95

    * Actual hours in main job
      gen WHRACT = HWACTUAL
      replace WHRACT = . if HWACTUAL>95
      replace WHRACT = WHRUSU if WKSTAT==1 & HWACTUAL==. & WHRUSU!=. // worked in the reference week, actual hours not reported
      replace WHRACT = 0 if WHRACT==.
      replace WHRACT = 80 if WHRACT>80

    * Actual hours in main and second job
      gen WHRACTT = WHRACT
      replace WHRACTT = WHRACTT + HWACTU2J if HWACTU2J>=1 & HWACTU2J<=95

    * Employment measures
      gen EMPL = 0 // employed: usually works at least 1 hour a week (ILO)
        replace EMPL = 1 if WHRUSU>=1

      gen EMPLFT = WHRUSUT / 35 // full-time equivalents, usual hours
        replace EMPLFT = 1 if EMPLFT>1

      gen EMPLFTACT = WHRACTT / 35 // full-time equivalents, actual hours
        replace EMPLFTACT = 1 if EMPLFTACT>1

      gen EMPLSTAT = 0 // employed by status: worked, or absent for reasons 1, 2, 3 or 5
        replace EMPLSTAT = 1 if WKSTAT==1 | (WKSTAT==2 & (ABSREAS==1 | ABSREAS==2 | ABSREAS==3 | ABSREAS==5))

    * Save yearly data
      save $lfswd/`x'_`year', replace

  }
}


********************************************************************************
* 1. Append data for all years
********************************************************************************

foreach x in $country {

  clear
  forvalues year = `firstyear'/`lastyear' {

    capture confirm file "$lfswd/`x'_`year'.dta"
    if _rc!=0 {
      continue
    }
    * No "force": a variable whose type differs between years stops the run
    * rather than being turned into missing values without notice.
      append using $lfswd/`x'_`year'
      erase $lfswd/`x'_`year'.dta
  }

  * Only save if at least one year's data was actually appended
    if _N>0 {
      save $lfswd/lfs_`x'.dta, replace
    }

}


/*
********************************************************************************
* 2. Check the data
********************************************************************************

  local cnt "PL"
  use $lfswd/lfs_`cnt'.dta, clear

  browse CNT2 YEAR WHRUSUT WHRACTT EMPLFT EMPLSTAT EMPLFTACT
  bysort YEAR: sum WHRACTT WHRUSUT if AGE>=25 & AGE<60 & SEX==2
*/
