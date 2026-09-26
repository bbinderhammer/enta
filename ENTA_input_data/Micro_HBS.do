* Prepare HBS data for use in ENTA

* Run the file Micro_HBS_Austria.do first - it builds HBS_AT_2010.dta and
* HBS_AT_2015.dta, which this file appends in Section 2 (the "add data for
* Austria, 2010 and 2015" block). Without those files already on disk,
* this file will halt with a "file not found" error while processing AT.

* Content
* 1. Import EXCEL-files, merge household and individual data
* 2. Generate needed variables

* Input: Original HBS data from EUROSTAT (set path in ENTA_setup.do)
* Output: HBS_[CNT2] in the HBS working directory  (set path in ENTA_setup.do)

********************************************************************************
* 0. Helper programmes
********************************************************************************

* Make variable numeric if string (differences across countries)

capture program drop numvar
program define numvar
    args srcvar newvar
    capture confirm numeric variable `srcvar'
    if !_rc {
        clonevar `newvar' = `srcvar'
    }
    else {
		replace `srcvar' = "" if `srcvar'=="NA"
        destring `srcvar', gen(`newvar')
		//clonevar `newvar' = `newvar'num
		//drop `newvar'num
    }
end


********************************************************************************
* 1. Import EXCEL-files, merge household and individual data
********************************************************************************

* Classify countries according to data availability 
  set excelxlsxlargefile on

  global country10       "BE BG CY CZ DE DK EE EL ES FI FR HR HU IE IT LT LU LV    PL PT RO SE SI SK UK" // 
  global country15       "BE BG CY CZ DE DK EE EL ES FI FR HR HU IE IT LT LU LV NL PL PT RO SE SI SK"  //  
  global country20    "AT BE BG CY CZ DE DK EE EL ES FI FR HR HU IE IT LT LU LV NL       RO    SI SK" // 

  global countryall      "BE BG CY CZ DE DK EE EL ES FI FR HR HU IE IT LT LU LV          RO    SI SK" // 
  global country1015     "PL PT SE" 
  global country1520     "NL" 
  global country20only     "AT"


******************************
* 2010 HBS
******************************

//global country10 "PL"
foreach x in $country10 {

  clear
  import excel "$hbsin/HBS2010/`x'_HBS_hh.xlsx", firstrow
  numvar HA04 HHID
  drop if HHID==.
  sort HHID
  save "$hbswd/HBS_`x'_hh.dta", replace
  
  clear
  import excel "$hbsin/HBS2010/`x'_HBS_hm.xlsx", firstrow
  numvar MA04 HHID
  //browse MA04 HHID
  
  sort HHID
  merge m:1 HHID using $hbswd/HBS_`x'_hh.dta
  keep if _merge==3
  drop _merge

  * Weight
  numvar HA10 WEIGHT

  * Household income
  numvar EUR_HH095 YDCASHh
  numvar EUR_HH099 YDh

  save "$hbswd/HBS_`x'_2010.dta", replace
  erase "$hbswd/HBS_`x'_hh.dta"
}  

  
*************************************
* 2015 HBS
*************************************

//global country15 "RO"
foreach x in $country15 {

  clear
  import excel "$hbsin/HBS2015/`x'_MFR_hh.xlsx", firstrow
  capture confirm numeric variable HA04
    if !_rc {
      clonevar HHID = HA04
    }
	else {
	  replace HA04 = subinstr(HA04,"H","",1)
      destring HA04, gen(HA04num)
      clonevar HHID = HA04num
	}

  sort HHID
  save "$hbswd/HBS_`x'_hh.dta", replace
 
  clear
  import excel "$hbsin/HBS2015/`x'_MFR_hm.xlsx", firstrow
  capture confirm numeric variable MA04
    if !_rc {
      clonevar HHID = MA04
    }
	else {
      replace MA04 = subinstr(MA04,"H","",1)
	  replace MA04 = "" if MA04=="NA"
      destring MA04, gen(MA04num)
      clonevar HHID = MA04num
	}

  sort HHID

  merge m:1 HHID using $hbswd/HBS_`x'_hh.dta
  keep if _merge==3
  drop _merge

  * Weight
  numvar HA10 WEIGHT

  * Household income
  numvar EUR_HH095 YDCASHh
  numvar EUR_HH099 YDh

  save "$hbswd/HBS_`x'_2015.dta", replace
  erase "$hbswd/HBS_`x'_hh.dta"
}


**********************************
* 2020 HBS
**********************************

* DELIBERATE, not a leftover debug override: Austria is the only country that
* needs an HBS 2020 file. The 2020 appends for $countryall and $country1520
* are commented out below, so no other country reads HBS_XX_2020.dta, while
* $country20only builds HBS1_AT.dta from HBS_AT_2020.dta alone and Section 2
* appends the Konsumerhebung onto it. Restoring the full $country20 list here
* would import some 20 Excel files that nothing downstream reads.
global country20 "AT"
foreach x in $country20 {
	
  clear
  import excel "$hbsin/HBS2020/HBS_HH_`x'.xlsx", firstrow
  numvar HA04 HHID

  sort HHID
  save "$hbswd/HBS_`x'_hh.dta", replace

  clear
  import excel "$hbsin/HBS2020/HBS_HM_`x'.xlsx", firstrow
  numvar MA04 HHID
 
  capture confirm numeric variable MB02
   if _rc {
      destring MB02, gen(MB02num)
	  drop MB02
	  rename MB02num MB02
    }

  sort HHID

  merge m:1 HHID using $hbswd/HBS_`x'_hh.dta
  keep if _merge==3
  drop _merge

  numvar HA10 WEIGHT
  numvar EUR_HH095 YDCASHh
  numvar EUR_HH099 YDh

  save "$hbswd/HBS_`x'_2020.dta", replace  
  erase "$hbswd/HBS_`x'_hh.dta"
  
}

********************************
* Combine all years for each country
********************************

//global countryall "RO"
foreach x in $countryall {

  clear
  append using "$hbswd/HBS_`x'_2010.dta"
  append using "$hbswd/HBS_`x'_2015.dta", force
  //append using "$hbswd/HBS_`x'_2020.dta", force
  save "$hbswd/HBS1_`x'.dta", replace

  erase "$hbswd/HBS_`x'_2010.dta" 
  erase "$hbswd/HBS_`x'_2015.dta" 
  //erase "$hbswd/HBS_`x'_2020.dta"
}

  //browse EUR_HH095 EUR_HH099 YDh YDCASHh

foreach x in $country1015 {
	
  clear
  append using "$hbswd/HBS_`x'_2010.dta"
  append using "$hbswd/HBS_`x'_2015.dta", force
  save "$hbswd/HBS1_`x'.dta", replace

  erase "$hbswd/HBS_`x'_2010.dta" 
  erase "$hbswd/HBS_`x'_2015.dta" 

}

foreach x in $country1520 {
	
  clear
  append using "$hbswd/HBS_`x'_2015.dta", force
  //append using "$hbswd/HBS_`x'_2020.dta", force
  save "$hbswd/HBS1_`x'.dta", replace

  erase "$hbswd/HBS_`x'_2015.dta" 
  //erase "$hbswd/HBS_`x'_2020.dta"

}


global country20only "AT"
foreach x in $country20only {
	
  clear
  append using "$hbswd/HBS_`x'_2020.dta"
  gen MB03_Recoded_5YearsClasses = ""
  save "$hbswd/HBS1_`x'.dta", replace 
  erase "$hbswd/HBS_`x'_2020.dta"
}


********************************************************************************
* 2. Generate needed variables
********************************************************************************

global country "AT BE DE BG CY CZ DK EE EL ES FI FR HR HU IE IT LT LU LV NL PL PT RO  SE SI SK" // " 
// global country "SI" //  DE SE LT FR

foreach x in $country {

  use "$hbswd/HBS1_`x'.dta", clear
  //browse EUR_HH095 EUR_HH099 YDh YDCASHh

  * Country
    gen CNT2 = "`x'"	

  * Household representative
    egen HHTAG = tag(YEAR HHID) 	
	
  * Age
    gen AGEGR5 = 0 if MB03_Recoded_5YearsClasses=="0_4"
    replace AGEGR5 = 5 if MB03_Recoded_5YearsClasses=="5_9" 
    replace AGEGR5 = 10 if MB03_Recoded_5YearsClasses=="10_14"
    replace AGEGR5 = 15 if MB03_Recoded_5YearsClasses=="15_19"
    replace AGEGR5 = 20 if MB03_Recoded_5YearsClasses=="20_24"
    replace AGEGR5 = 25 if MB03_Recoded_5YearsClasses=="25_29"
    replace AGEGR5 = 30 if MB03_Recoded_5YearsClasses=="30_34"
    replace AGEGR5 = 35 if MB03_Recoded_5YearsClasses=="35_39"
    replace AGEGR5 = 40 if MB03_Recoded_5YearsClasses=="40_44"
    replace AGEGR5 = 45 if MB03_Recoded_5YearsClasses=="45_49"
    replace AGEGR5 = 50 if MB03_Recoded_5YearsClasses=="50_54"
    replace AGEGR5 = 55 if MB03_Recoded_5YearsClasses=="55_59"
    replace AGEGR5 = 60 if MB03_Recoded_5YearsClasses=="60_64" | MB03_Recoded_5YearsClasses=="60_Inf" | MB03_Recoded_5YearsClasses=="60_inf"
    replace AGEGR5 = 65 if MB03_Recoded_5YearsClasses=="65_69"
    replace AGEGR5 = 70 if MB03_Recoded_5YearsClasses=="70_74"
    replace AGEGR5 = 75 if MB03_Recoded_5YearsClasses=="75_79"
    replace AGEGR5 = 80 if MB03_Recoded_5YearsClasses=="80_84" | MB03_Recoded_5YearsClasses=="85_Inf"
    * Portugal combines everyone 75+ into a single "75_Inf" bucket instead of
    * splitting 75-79 vs 80+ like other countries - mapped to 75 (the bucket's
    * lower bound, matching this file's own labeling convention) since the
    * source data doesn't support a finer split. Without this, ~9.7% of PT's
    * HBS records (its entire 75+ population) fell through with AGEGR5 missing.
    replace AGEGR5 = 75 if MB03_Recoded_5YearsClasses=="75_Inf"
	
    gen AGEGR15 = 0 if MB03_Recoded_5Classes=="0_14" // This is the only age variable available in 2020
    replace AGEGR15 = 15 if MB03_Recoded_5Classes=="15_29"
    replace AGEGR15 = 30 if MB03_Recoded_5Classes=="30_44"
    replace AGEGR15 = 45 if MB03_Recoded_5Classes=="45_59"
    replace AGEGR15 = 60 if MB03_Recoded_5Classes=="60_Inf" | MB03_Recoded_5Classes=="60_inf"

  * Sex
    gen SEX = MB02
  
  * Household size
    bysort YEAR HHID: gen HHSIZE = _N

	
  ***********************************
  * Population adjusted weights
  *************************************
  
  preserve
  
	  collapse (sum) WEIGHT, by(CNT2 YEAR AGEGR15)
	  rename WEIGHT WEIGHTHBS
	  tempfile agew
	  save `agew'
  
      sort CNT2 YEAR AGEGR15
      merge 1:1 CNT2 YEAR AGEGR15 using ENTA_input_data/ENTA_input_datasets/population_agegr15
      keep if _merge==3
      drop _merge

      gen ADJPOP = POP / WEIGHTHBS
      keep CNT2 YEAR AGEGR15 ADJPOP
      sort CNT2 YEAR AGEGR15
      save $hbswd/pop_adjust, replace

  restore

  sort CNT2 YEAR AGEGR15
  merge m:1 CNT2 YEAR AGEGR15 using $hbswd/pop_adjust
	keep if _merge==3
	drop _merge
	
  gen WEIGHTa = WEIGHT*ADJPOP
  
  
  *******************************
  * Income and consumption
  *******************************
  
  //browse MB03* EUR_HH099
  //browse YDCASHh EUR_HH099 EUR_HH095 EUR_HH095 EUR_MF099 EUR_HH032 EUR_HE042 EUR_HE10 EUR_HE06

  * Disposable income in cash
  replace YDCASHh = EUR_HE00 if CNT2=="IT" | (CNT2=="LU" & YEAR==2010) | (CNT2=="CZ" & (YEAR==2010 | YEAR==2020)) // no income data, approx with consumption 
  gen YDCASH = YDCASHh / HHSIZE
  adjustaggr YDCASH
	
  * Consumption
  gen CHR = EUR_HE042
    replace CHR = 0 if CHR==.
  gen CHH = EUR_HE06
  gen CHE = EUR_HE10
  gen CHX = EUR_HE00 - CHR - CHH - CHE
  gen CH = EUR_HE00


 
  ***************************************
  * add data for Austria, 2010 and 1015
  ***************************************
  if "`x'"=="AT" {
    append using "$hbswd/HBS_AT_2015.dta"
    append using "$hbswd/HBS_AT_2010.dta"
  }
  

  ***************************************
  * Other variables
  ***************************************
  
  * Age structure of household
    bysort YEAR HHID: egen NCHILD14 = total(AGEGR15<15)

  * Income percentiles, per capita at household level
   
    gen PERC = .
	sum YEAR
    forvalues y = `r(min)'(5)`r(max)' {
      sumdist YDCASH [aw=WEIGHTa] if YEAR==`y' & HHTAG==1, ng(100) qgp(PERC1)  
      replace PERC = PERC1 if PERC==. & YEAR==`y' & HHTAG==1
	  drop PERC1
	}
	
  * Standardized consumption to be able to choose from all years for estimating age-profiles
 
    local variables "CHX CHH CHE CHR"
	foreach var of local variables {
      replace `var' = 0 if HHTAG!=1
      adjustaggr `var'
	  rename `var' `var'hh
	  bysort CNT2 YEAR HHID: egen `var' = max(`var'hh)
	  drop `var'hh
	}
	
  * Average consumption per capita (CHXavg), used to standardise consumption
  * data below - CHXesa/POPtot come from ENTA_units.dta.
    sort CNT2 YEAR
    merge m:1 CNT2 YEAR using ENTA_aggregates/ENTA_units, keepusing(CHXesa POPtot)
	keep if _merge==3
	drop _merge
	gen CHXavg = CHXesa * 1000000 / POPtot

	foreach var of local variables {
	  gen `var'STD = `var' / CHXavg
	}
  drop CHXavg CHXesa POPtot // internal to this computation only; CH* below
              // would otherwise sweep it into HBS_`x'.dta unintentionally

  gen CON = 1 // identifier of consumption survey observations
  
  //browse  CNT2 YEAR HHID HHSIZE WEIGHT AGEGR* SEX  YDCASH CH*
  //rename YD YDHH
  keep CNT2 YEAR HHID HHSIZE HHTAG WEIGHT* AGEGR* SEX  YDh YDCASHh YDCASH CH* CON NCHILD* PERC 
  save "$hbswd/HBS_`x'.dta", replace
}

