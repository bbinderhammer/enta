********************************************************************************
* cell_counts.do
*
* Content:  Sample sizes behind the age profiles from EU-SILC. Counts only, no
*           estimates:
*             1. EU-SILC, by country, income year, single age and sex (0 =
*                total, 1 = men, 2 = women), 2008-2023: persons, households
*                with a member of that age, the Kish effective sample size
*                (sum w)^2 / sum w^2 of WEIGHTa, and the RECEIVERS (value
*                above 1 euro, as in the outlier caps of ENTA_income.do and
*                ENTA_benefits.do) of each component with its own profile.
*                Summary per country (medians over the years): the figures
*                of the manual's table.
*             2. and 3. HBS and LFS: inactive, the manual reports the number
*                of observations for EU-SILC only.
*           Thin cells are marked with the thresholds in the locals below
*           (fewer than `thin1' observations: unreliable; fewer than `thin2':
*           to be read with care).
*
* Input:    $silcwd/data/silc_*.dta
* Output:   ENTA_microdata_checks/results/cell_counts/ (not kept, not
*           published; the counts appear only as the summary table of the
*           manual): silc_cells.csv, summary_silc.csv,
*           silc_receivers_year.csv, summary_silc_receivers.csv. No log is
*           written.
* Run:      after ENTA_setup.do / ENTA_setup_TU.do ($silcwd), from the ENTA
*           root. A few minutes.
********************************************************************************

version 19
set more off

cap mkdir ENTA_microdata_checks/results
cap mkdir ENTA_microdata_checks/results/cell_counts
local out "ENTA_microdata_checks/results/cell_counts"
* [INACTIVE] no log is written
* cap log close cc
* log using "`out'/cell_counts_log.txt", text replace name(cc)

global country "AT BE BG CY CZ DE DK EE EL ES FI FR HR HU IE IT LT LU LV NL PL PT RO SE SI SK"

local rec   "YE YM YEM YPr YPp BSU BSFAM BSPPEN BSX"  // components with a profile
local thin1 20   // thresholds for thin cells (observations); 20 = the
* 20-receiver rule
local thin2 50
local y0 2008    // years assessed: the published years of the age profiles
local y1 2023    // (SILC income years, LFS survey years)


********************************************************************************
* 1. EU-SILC
********************************************************************************

tempfile silc
local first 1
foreach x in $country {
    use CNT2 YEAR AGE SEX HHID WEIGHTa `rec' using $silcwd/data/silc_`x', clear
    keep if inrange(YEAR,`y0',`y1')
    foreach v of local rec {
        gen byte R_`v' = (`v'>1 & `v'<.)
    }
    gen double w2 = WEIGHTa^2

    * Total (SEX 0) and by sex
    expand 2, gen(dup)
    replace SEX = 0 if dup==1
    bysort CNT2 YEAR AGE SEX HHID: gen byte hh1 = (_n==1)
    gen byte one = 1
    collapse (sum) N=one NHH=hh1 SW=WEIGHTa SW2=w2 R_*, by(CNT2 YEAR AGE SEX)
    gen NEFF = SW^2 / SW2
    drop SW SW2

    if `first' {
        save `silc'
    }
    else {
        append using `silc'
        save `silc', replace
    }
    local first 0
}
use `silc', clear
sort CNT2 YEAR SEX AGE
export delimited using "`out'/silc_cells.csv", replace

di "SILC: ages " _c
sum AGE
tab YEAR if SEX==0, sum(N) means

* Summary per country-year, total population (SEX 0) unless stated
gen byte a2079 = inrange(AGE,20,79)
gen double N2079  = N if a2079 & SEX==0
gen double NE2079 = NEFF if a2079 & SEX==0
gen double N80    = N if AGE>=80 & SEX==0
gen double NALL   = N if SEX==0
gen double RBSU   = R_BSU    if inrange(AGE,25,59) & SEX==0
gen double RBSFAM = R_BSFAM  if inrange(AGE,25,44) & SEX==0
gen double RPEN   = R_BSPPEN if inrange(AGE,65,79) & SEX==0
gen double RYPR   = R_YPr    if inrange(AGE,30,79) & SEX==0
gen double RYPP   = R_YPp    if inrange(AGE,30,59) & SEX==0
gen double RYM    = R_YM     if inrange(AGE,30,64) & SEX==0
* Thin sex-specific cells at 18-79 (persons), and thin receiver cells of
* unemployment benefits by sex at 25-59
gen byte thinN   = (N < `thin2')   if inrange(AGE,18,79) & SEX>0
gen byte thinBSU = (R_BSU < `thin1') if inrange(AGE,25,59) & SEX>0

collapse (sum) NALL N80 (median) N2079 NE2079 RBSU RBSFAM RPEN RYPR RYPP RYM ///
    (min) N2079min=N2079 (mean) thinN thinBSU, by(CNT2 YEAR)
* Years below the 20-receiver rule: the median number of receivers
* per single age (over the ages of each profile) is below thin1
foreach v in RBSU RBSFAM RPEN RYPR RYPP RYM {
    gen byte lt_`v' = `v' < `thin1' if `v'<.
}
collapse (median) NALL N80 N2079 NE2079 N2079min RBSU RBSFAM RPEN RYPR RYPP RYM ///
    thinN thinBSU (sum) lt_* (count) nyears=YEAR ///
    (min) y0=YEAR (max) y1=YEAR, by(CNT2)
replace thinN   = round(100*thinN, 0.1)
replace thinBSU = round(100*thinBSU, 0.1)
label var NALL     "persons per year"
label var N80      "persons aged 80+ per year"
label var N2079    "persons per single age, 20-79 (median)"
label var NE2079   "effective sample size per single age, 20-79 (median)"
label var N2079min "persons per single age, 20-79 (smallest)"
label var RBSU     "receivers of unemployment benefits per age, 25-59"
label var RBSFAM   "receivers of family benefits per age, 25-44"
label var RPEN     "receivers of pensions per age, 65-79"
label var RYPR     "receivers of property income per age, 30-79"
label var RYPP     "receivers of property income paid per age, 30-59"
label var RYM      "receivers of self-employment income per age, 30-64"
label var thinN    "% of single-age x sex cells at 18-79 with < thin2 persons"
label var thinBSU  "% of single-age x sex cells at 25-59 with < thin1 BSU receivers"
foreach v in RBSU RBSFAM RPEN RYPR RYPP RYM {
    label var lt_`v' "years with fewer than thin1 receivers per age (`v')"
}
format NALL-RYM %9.0f
list, noobs clean abbreviate(8)
export delimited using "`out'/summary_silc.csv", replace

* Receivers per year over all ages, for the components whose age shape
* rests on few persons in some countries (RO BSU: 2-67 a year from 2011)
use `silc', clear
keep if SEX==0
collapse (sum) R_BSU R_BSFAM R_YM R_YPr R_YPp, by(CNT2 YEAR)
export delimited using "`out'/silc_receivers_year.csv", replace
collapse (min) minBSU=R_BSU minBSFAM=R_BSFAM minYM=R_YM minYPr=R_YPr ///
    minYPp=R_YPp (median) R_BSU R_BSFAM R_YM R_YPr R_YPp, by(CNT2)
list, noobs clean abbreviate(8)
export delimited using "`out'/summary_silc_receivers.csv", replace


* [INACTIVE] Sections 2 and 3 (HBS and LFS): the manual reports the number of
* observations for EU-SILC only.
/*
********************************************************************************
* 2. HBS (persons live in households; 5-year age groups only)
********************************************************************************

  tempfile hbs
  local first 1
  foreach x in $country {
    cap confirm file $hbswd/HBS_`x'.dta
    if _rc {
      di as error "HBS_`x' not found"
      continue
    }
    use CNT2 YEAR AGEGR5 SEX HHID using $hbswd/HBS_`x', clear
    expand 2, gen(dup)
    replace SEX = 0 if dup==1
    bysort CNT2 YEAR AGEGR5 SEX HHID: gen byte hh1 = (_n==1)
    gen byte one = 1
    collapse (sum) N=one NHH=hh1, by(CNT2 YEAR AGEGR5 SEX)
    if `first' {
      save `hbs'
    }
    else {
      append using `hbs'
      save `hbs', replace
    }
    local first 0
  }
  use `hbs', clear
  sort CNT2 YEAR SEX AGEGR5
  export delimited using "`out'/hbs_cells.csv", replace

  * Sex other than 1/2 (IT 2010: 9 for 25 persons) and a missing age group
  * occur in most countries in small numbers; counted separately, not in the
  * cells
    gen double NALL  = N if SEX==0
    gen double NG    = N if inrange(AGEGR5,20,75) & inlist(SEX,1,2)
    gen double NNOAGE = N if AGEGR5==. & SEX==0
    gen double NNOSEX = N if !inlist(SEX,0,1,2)
    collapse (sum) NALL NNOAGE NNOSEX (median) NG (min) NGmin=NG, by(CNT2 YEAR)
    label var NNOAGE "persons without age group"
    label var NNOSEX "persons with sex not 1/2"
    label var NALL  "persons per wave"
    label var NG    "persons per 5-year group x sex, 20-79 (median)"
    label var NGmin "persons per 5-year group x sex, 20-79 (smallest)"
    list, noobs clean
    export delimited using "`out'/summary_hbs.csv", replace


********************************************************************************
* 3. LFS
********************************************************************************

  tempfile lfs
  local first 1
  foreach x in $country {
    use CNT2 YEAR AGE SEX using $lfswd/lfs_`x', clear
    keep if inrange(YEAR,`y0',`y1')
    expand 2, gen(dup)
    replace SEX = 0 if dup==1
    gen byte one = 1
    collapse (sum) N=one, by(CNT2 YEAR AGE SEX)
    if `first' {
      save `lfs'
    }
    else {
      append using `lfs'
      save `lfs', replace
    }
    local first 0
  }
  use `lfs', clear
  sort CNT2 YEAR SEX AGE
  export delimited using "`out'/lfs_cells.csv", replace

    gen double NALL = N if SEX==0
    gen double NA   = N if inrange(AGE,20,79) & SEX>0
    collapse (sum) NALL (median) NA (min) NAmin=NA, by(CNT2 YEAR)
    collapse (median) NALL NA NAmin (min) y0=YEAR (max) y1=YEAR, by(CNT2)
    label var NALL  "persons per year"
    label var NA    "persons per age (group) x sex, 20-79 (median)"
    label var NAmin "persons per age (group) x sex, 20-79 (smallest)"
    format NALL NA NAmin %9.0f
    list, noobs clean
    export delimited using "`out'/summary_lfs.csv", replace
*/

* [INACTIVE] no log is written
* log close cc
