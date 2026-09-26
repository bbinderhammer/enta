********************************************************************************
* Age-profiles of LFS-based quantities, such as employment
********************************************************************************

* Content
* 0. Load LFS data
* 1. Generate age-profiles

********************************************************************************
* 0. Load LFS data
********************************************************************************

global country "AT BE BG CY CZ DE DK EE EL ES FI FR HR HU IE IT LT LU LV NL PL PT RO SE SI SK" //
//global country "AT DE IT FR PL CZ ES SE DK"
//global country "CZ SI"

foreach x in $country {

  * Read data
  use $lfswd/lfs_`x'.dta, clear

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

  local vars "EMPL EMPLFT EMPLFTACT EMPLSTAT WHRUSU WHRUSUT WHRACT WHRACTT"

  * Total
  preserve
    collapse (mean) `vars' [pw=WEIGHTa], by(CNT2 YEAR AGE) 
    gen SEX = 0
    sort CNT2 YEAR AGE
    tempfile tot
    save `tot'
  restore

  * By gender
    collapse (mean) `vars'  [pw=WEIGHTa], by(CNT2 YEAR AGE SEX) 

  * Combine the data
    append using `tot'
  
  * Choose variables and change to wide format
  //local vars "WHRUSU WHRACT EMPL EMPL2 EMPLFTSH EMPLPTSH EMPLFT"
  
  preserve
    keep if SEX==0
	sort CNT2 YEAR AGE
	tempfile tot
	save `tot'
  restore
  
  preserve
    keep if SEX==1
    foreach var of local vars {
  	  rename `var' `var'm
    }
	sort CNT2 YEAR AGE
	tempfile men
	save `men'
  restore  
  
  keep if SEX==2
  keep CNT2 YEAR AGE `vars'
  foreach var of local vars {
  	rename `var' `var'f
  }
  sort CNT2 YEAR AGE
  merge 1:1 CNT2 YEAR AGE using `men'
  drop _merge
  sort CNT2 YEAR AGE
  merge 1:1 CNT2 YEAR AGE using `tot'
  drop _merge
  
  drop SEX
  sort CNT2 YEAR AGE
  save ENTA_ageprofiles/ageprofiles/lfs_`x', replace 
  
}  
  
  
  
