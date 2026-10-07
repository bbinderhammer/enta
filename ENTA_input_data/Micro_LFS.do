********************************************************************************
* Micro_LFS.do - EU Labour Force Survey: employment and working hours
*
* Reads the yearly EU-LFS files, builds employment and working-hours variables
* per person, and saves one file per country holding all years.
*   Input   $lfsin/<CC>_YEAR/<CC><year>_y.csv (EU-LFS scientific-use files)
*           ENTA_input_data/ENTA_input_datasets/population_agegr3.dta
*   Output  $lfswd/lfs_<CC>.dta, used only by
*           ENTA_ageprofiles/ENTA_employment.do, which averages EMPL EMPLFT
*           EMPLFTACT EMPLSTAT WHRUSU WHRUSUT WHRACT WHRACTT UNEMPL UNEMPLBEN
*           by country, year, age and sex, weighted with WEIGHTa.
*
* Key EU-LFS codes:
*   ILOSTAT  2 = ILO unemployed
*   REGISTER 1 = registered at a public employment office and receiving
*                unemployment benefits or assistance
*   Hours (HWUSUAL, HWACTUAL, HWUSU2J, HWACTU2J) are per week; 97 = usual hours
*   vary, 99 = not applicable
*   WKSTAT   1 = worked for pay/profit in the reference week, 2 = had a job but
*                was absent; ABSREAS gives the reason for the absence
*
* Age: the Netherlands, Czechia, Ireland and Slovakia deliver only five-year
* groups (AGE_GRP). AGE is then set to the lower bound of the group, and
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

        * Skip the year if there is no file for it
        capture confirm file "$lfsin/`x'_YEAR/`x'`year'_y.csv"
        if _rc!=0 {
            continue
        }

        clear
        import delimited "$lfsin/`x'_YEAR/`x'`year'_y.csv", case(preserve)

        * Identifiers and weights
        gen CNT2 = "`x'"
        gen HHID = HHNUM
        bysort YEAR HHNUM: gen WHHID = _n            // rank within the household
        egen ID = group(YEAR HHNUM WHHID)            // unique person ID
        gen WEIGHT = COEFFY * 1000
        gen ONE = 1

        * Migration status: native, born elsewhere in the EU, born outside the EU
        gen COB = .
        capture confirm string variable COUNTRYB
        if !_rc {
            replace COB = 0 if COUNTRYB=="NAT"
            replace COB = 1 if COUNTRYB=="EU27_2020"
            replace COB = 2 if COUNTRYB!="NAT" & COUNTRYB!="EU27_2020" & COUNTRYB!=""
        }
        gen MIGR = inlist(COB, 1, 2)

        * Five-year age group from the AGE_GRP string
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
        replace AGEGR5 = 85 if AGE_GRP=="Y_GE85" // EL
        replace AGEGR5 = 90 if AGE_GRP=="Y_GE90" // PL

        * Does this country-year have single years of age? (0 = AGE all missing)
        bysort YEAR: egen AGE_nonmiss = count(AGE)
        * Five-year groups only: use the group's lower bound as AGE
        replace AGE = AGEGR5 if AGE_nonmiss==0
        * Open top groups never have a single year of age, so set AGE directly
        replace AGE = 75 if AGE_GRP=="Y_GE75" & AGE_nonmiss!=0 & AGE==.
        replace AGE = 80 if AGE_GRP=="Y_GE80" & AGE_nonmiss!=0 & AGE==.
        replace AGE = 85 if AGE_GRP=="Y_GE85" & AGE_nonmiss!=0 & AGE==.
        replace AGE = 90 if AGE_GRP=="Y_GE90" & AGE_nonmiss!=0 & AGE==.

        * Broad age groups: 0-19, 20-64, 65+ (missing if the group is unknown)
        gen AGEGR3 = cond(AGEGR5 < 20, 0, cond(AGEGR5 < 65, 1, 2)) if !missing(AGEGR5)

        * WEIGHTa: survey weight scaled to the population of the broad age group.
        * The scaling mainly matters for the oldest group, many of whom live in
        * institutions outside the private households the survey covers. Ages 0-19
        * and unknown-age keep the survey weight. The
        * factor is constant within an age group, so it leaves the means by single
        * age in ENTA_employment.do unchanged.
        preserve
        collapse (sum) WEIGHT, by(CNT2 YEAR AGEGR3)
        rename WEIGHT POPLFS
        sort CNT2 YEAR AGEGR3
        tempfile agepop
        save `agepop'
        restore

        sort CNT2 YEAR AGEGR3
        merge m:1 CNT2 YEAR AGEGR3 using `agepop', nogenerate

        * Add the population totals
        sort CNT2 YEAR AGEGR3
        merge m:1 CNT2 YEAR AGEGR3 using "ENTA_input_data/ENTA_input_datasets/population_agegr3"
        keep if _merge==3 | (_merge==1 & missing(AGEGR3))
        drop _merge

        gen ADJPOP = POP / POPLFS
        replace ADJPOP = 1 if AGEGR3==0 | missing(AGEGR3)   // no scaling for 0-19 or unknown age
        gen WEIGHTa = WEIGHT * ADJPOP
        drop POP

        * 99 = not applicable -> missing
        foreach var in HWUSUAL HWUSU2J HWACTUAL HWACTU2J {
            replace `var' = . if `var'==99
        }

        * Usual weekly hours in the main job (WHRUSU)
        gen WHRUSU = HWUSUAL
        * Code 97 (hours vary): use the actual hours of the reference week if >=1
        replace WHRUSU = HWACTUAL if HWUSUAL==97 & HWACTUAL>=1 & HWACTUAL<=95
        * Code 97 but no usable actual hours: use the weighted mean usual hours of
        * those with fixed hours in the same country, year and sex.
        gen double _h = HWUSUAL if HWUSUAL>=1 & HWUSUAL<=95
        bysort YEAR SEX: egen double _hw = total(_h * WEIGHT)
        bysort YEAR SEX: egen double _w  = total(WEIGHT * !missing(_h))
        replace WHRUSU = _hw / _w if HWUSUAL==97 & !(HWACTUAL>=1 & HWACTUAL<=95)
        drop _h _hw _w
        replace WHRUSU = 0 if WHRUSU==.
        replace WHRUSU = 80 if WHRUSU>=80                   // cap at 80

        * Usual hours, main plus second job
        gen WHRUSUT = WHRUSU
        replace WHRUSUT = WHRUSUT + HWUSU2J if HWUSU2J>=1 & HWUSU2J<=95

        * Actual weekly hours in the main job
        gen WHRACT = HWACTUAL
        replace WHRACT = . if HWACTUAL>95
        replace WHRACT = WHRUSU if WKSTAT==1 & HWACTUAL==. & WHRUSU!=. // worked, actual hours not reported
        replace WHRACT = 0 if WHRACT==.
        replace WHRACT = 80 if WHRACT>80                    // cap at 80

        * Actual hours, main plus second job
        gen WHRACTT = WHRACT
        replace WHRACTT = WHRACTT + HWACTU2J if HWACTU2J>=1 & HWACTU2J<=95

        * Employment measures
        gen EMPL = 0                                        // ILO employed: usually works >=1 h/week
        replace EMPL = 1 if WHRUSU>=1

        gen EMPLFT = WHRUSUT / 35                           // full-time equivalents, usual hours
        replace EMPLFT = 1 if EMPLFT>1

        gen EMPLFTACT = WHRACTT / 35                        // full-time equivalents, actual hours
        replace EMPLFTACT = 1 if EMPLFTACT>1

        gen EMPLSTAT = 0                                    // worked, or absent for reasons 1, 2, 3, 5
        replace EMPLSTAT = 1 if WKSTAT==1 | (WKSTAT==2 & (ABSREAS==1 | ABSREAS==2 | ABSREAS==3 | ABSREAS==5))

        * Unemployment
        *   UNEMPL    = ILO unemployed (ILOSTAT 2)
        *   UNEMPLBEN = registered and receiving benefits/assistance (REGISTER 1)
        * Both are missing where the year lacks the variable. Only REGISTER code 1
        * is used: the other codes changed with the 2021 LFS reform in some
        * countries (e.g. DE 2021 uses 1, 2, 3, 9, with 3 for 72% of persons;
        * before, 3 meant "not registered, receiving"), while code 1 means the same
        * in both schemes. RO uses 1, 2, 4, 9 in every year 2007-2024, so code 3
        * never occurs there.
        *
        * UNEMPLBEN supplies the age shape of unemployment benefits (BSU) in
        * ENTA_compilation1_esa.do for countries where EU-SILC has almost no
        * receivers: RO, SK and EL. PL, HR and CZ keep EU-SILC. Checked 2008-2023: REGISTER
        * present every year, code 1 for 449-3,589 (PL), 270-763 (SK), 196-695
        * (HR), 207-2,834 (CZ), 360-4,917 (EL) persons a year; code 3 at most 35.
        * CY, EE, LU were also checked and are not used. Always check REGISTER
        * before using it for a new country.
        gen UNEMPL = .
        capture replace UNEMPL = (ILOSTAT==2) if !missing(ILOSTAT)
        gen UNEMPLBEN = .
        capture replace UNEMPLBEN = (REGISTER==1) if !missing(REGISTER)

        * Keep only the variables ENTA_employment.do needs and drop the raw EU-LFS
        * variables. This keeps the append in Section 1 clean: e.g. SIZEFIRM (never
        * used) is str3 in AT 1995-1997 but numeric from 1998 and would break the
        * append.
        keep CNT2 YEAR ID SEX AGE AGE_GRP AGEGR5 AGEGR3 COB MIGR ///
            WEIGHT ADJPOP WEIGHTa WHRUSU WHRUSUT WHRACT WHRACTT ///
            EMPL EMPLFT EMPLFTACT EMPLSTAT UNEMPL UNEMPLBEN

        * Save the single year
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
        * No "force": if a variable's type differs between years the run stops,
        * rather than silently turning the values into missing.
        append using $lfswd/`x'_`year'
        erase $lfswd/`x'_`year'.dta
    }

    * Save only if at least one year was appended
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
