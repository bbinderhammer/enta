* Prepare data with age-specific population from EUROSTAT (incl. projections)

* Requires Suppl_population_UN.do to have been run first - Section 1 below
* merges against ENTA_input_data\Original_input_data\population_UN, which
* only that file produces (used as a fallback for older age groups missing
* from the Eurostat data).

***********************************
* Content
* 1. Actual population data
* 2. Population projections
***********************************

if "$download"=="1" {
* Download population data
    cd ENTA_input_data\Original_input_data
    clear
    eurostatuse demo_pjan, noflags clear 
    save demo_pjan, replace 
	cd "$wkdir"
}
	
********************************************************************************
* 1. Actual population data 
********************************************************************************
  
  local lyear = 2025  // latest year in data 
  use ENTA_input_data/Original_input_data/demo_pjan, clear 
  

  keep age sex geo demo_pjan*
  
  tempfile data
  save `data'
  forvalues y=1960/`lyear' {
      use `data', clear
      keep age sex geo demo_pjan`y'
	  rename demo_pjan`y' NA
	  gen year = `y'
	  tempfile na`y'
	  save `na`y''
    }
    use `na1960', clear
    forvalues y=1961/`lyear' {
      append using `na`y''
    }
	
	sort sex geo year
	
  * Keep only years with at least some information
    bysort year geo: egen yearmiss = count(NA) // number of non-missing values in variable NA
	drop if yearmiss==0 | yearmiss==1
	drop yearmiss
  
  * Relabel age variable
    forvalues i=1/99 {
	    replace age = "`i'" if age=="Y`i'"
	}
	replace age = "0" if age=="Y_LT1"
	replace age = "100" if age=="Y_OPEN"
		
	drop if age=="TOTAL" 
	drop if age=="UNK"  
	
 * Make age as numeric variable 
    rename age age_str
    destring age_str, gen(AGE)
    drop age_str
	
	gen SEX=0 if sex=="T"
	replace SEX=1 if sex=="M"
	replace SEX=2 if sex=="F"
	
	rename geo CNT2
	
	rename NA POP
	// gen YEAR = year-1 // EU-SILC refers to end of income reference period, demo_pjan to beginning of year
	gen YEAR = year
	sort CNT2 YEAR SEX AGE
  
	* Calculate population as average of population at 1st of january of consecutive years
	  preserve
	  replace YEAR = YEAR-1
	  rename POP POP1
	  sort CNT2 YEAR SEX AGE
	  tempfile pop
	  save `pop'
	  restore
	  sort CNT2 YEAR SEX AGE
	  merge 1:1 CNT2 YEAR SEX AGE using `pop'
	  
	  replace POP = (POP + POP1) / 2 if YEAR!=`lyear'
	  drop POP1 _merge
	  
  ******************************************************
  * If older age groups missing, use UN data
  ******************************************************
	
	drop if YEAR<1995
    bysort CNT2 YEAR: egen nmiss = sum(POP==.) // number of missing ages this country/year, across all sexes - if any sex/age is missing, replace all sexes (total, male, female) for that country/year

    sort CNT2 YEAR SEX AGE
	merge 1:1 CNT2 YEAR SEX AGE using ENTA_input_data\Original_input_data\population_UN
	drop if _merge==2

	replace POP = POPun if nmiss!=0

	* RO's open-age-interval (AGE=100) figures are implausibly high vs UN
	* through 2001 (ratio ~35-44x, e.g. 2000: 5249.5 vs 121.5), then drop
	* sharply from 2002 on (ratio ~2-8x, in line with normal cross-source
	* divergence at this age) - not a missing-data case (nmiss==0
	* throughout), so not caught by the replace above. Confirmed with user.
	replace POP = POPun if CNT2=="RO" & AGE==100 & YEAR<=2001

	drop nmiss _merge POPun sex year
	 
	 
  ******************************************************
  * Save the data
  ******************************************************
    
	* Age, sex, 100 age groups, long format
	sort CNT2 YEAR SEX AGE 
    save ENTA_input_data\ENTA_input_datasets/population100, replace

	* Age, sex, 100 age groups, wide format
    preserve
	  reshape wide POP, i(CNT2 YEAR AGE) j(SEX)
	  rename POP0 POP
	  rename POP1 POPm
      rename POP2 POPf
	  sort CNT2 YEAR AGE
	  save ENTA_input_data\ENTA_input_datasets/population100w, replace	
	restore
  
    * Age sex, 80 age groups, long format
    replace AGE = 80 if AGE>=80
    collapse (rawsum) POP, by(CNT2 YEAR SEX AGE)
	sort CNT2 YEAR SEX AGE
	save ENTA_input_data\ENTA_input_datasets/population80, replace
	
	* 15-year age groups, for use in HBS
    preserve
	  keep if SEX==0
	  gen AGEGR15 = 0 if AGE<15
	    replace AGEGR15 = 15 if AGE>=15 & AGE<=29
	    replace AGEGR15 = 30 if AGE>=30 & AGE<=44
	    replace AGEGR15 = 45 if AGE>=45 & AGE<=59
	    replace AGEGR15 = 60 if AGE>=60 	
	  collapse (sum) POP, by(CNT2 YEAR AGEGR15)
	  sort CNT2 YEAR AGEGR15
	  save ENTA_input_data\ENTA_input_datasets/population_agegr15, replace
    restore
	
	* Age sex, 80 age groups, wide format
	preserve
	  reshape wide POP, i(CNT2 YEAR AGE) j(SEX)
	  rename POP0 POP
	  rename POP1 POPm
      rename POP2 POPf
	  sort CNT2 YEAR AGE
	  save ENTA_input_data\ENTA_input_datasets/population80w, replace	
	restore
	
	* total, age ,sex, long format
	collapse (rawsum) POP, by(CNT2 YEAR SEX)
	gen AGE = 999
	sort CNT2 YEAR SEX AGE
	save ENTA_input_data\ENTA_input_datasets/population0, replace	  
	
	* Total
	keep if SEX==0
	collapse (rawsum) POP, by(CNT2 YEAR)
	gen AGE = 999
	sort CNT2 YEAR 
	save ENTA_input_data\ENTA_input_datasets/population0t, replace
	 
    * Three age groups, long format (for adjusting survey data to total population)
    use ENTA_input_data\ENTA_input_datasets/population80, clear
	keep if SEX==0
	gen AGEGR3 = 0 if AGE<20
	    replace AGEGR3= 1 if AGE>=20 & AGE<65
	    replace AGEGR3 = 2 if AGE>=65 
		
	collapse (sum) POP, by(CNT2 YEAR AGEGR3)
	sort CNT2 YEAR AGEGR3
	save ENTA_input_data\ENTA_input_datasets/population_agegr3, replace
