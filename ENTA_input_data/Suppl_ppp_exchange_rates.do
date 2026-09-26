********************************************************************************
* Purchasing power and exchange rates
********************************************************************************

* Download data

  if "$download"=="1" {
  * PPP and exchange rate
    cd ENTA_input_data\Original_input_data
    eurostatuse prc_ppp_ind, noflags clear 
    save prc_ppp_ind, replace
	cd "$wkdir"
  }
  
  clear
  local lyear = 2024  // latest year in data 
  
  use  ENTA_input_data\Original_input_data/prc_ppp_ind, clear
  keep if na_item=="EXP_EUR" | na_item=="EXP_NAC"  | na_item=="PPP_EU27_2020" 
  keep if ppp_cat=="E011" // Household final consumption expenditure
  
 
  **************************	
  * Make years to a variable
  **************************
  
	tempfile data
    save `data'
    forvalues y=1995/`lyear' {
      use `data', clear
      keep na_item ppp_cat geo geo_label prc_ppp_ind`y'
	  rename prc_ppp_ind`y' NA
	  gen year = `y'
	  tempfile na`y'
	  save `na`y''
    }

	clear
    forvalues y=1995/`lyear' {
      append using `na`y''
    }
	
  * Keep only years with at least some information
    bysort year geo: egen yearmiss = count(NA) // number of non-missing values in variable NA
	drop if yearmiss==0
	drop yearmiss
	
	rename geo CNT2
	rename year YEAR
	
  * Make indicators to variables
 
    tempfile ppp
	save `ppp'
	
    use `ppp'
	local var "EXP_EUR"
	keep if na_item=="`var'" 
	rename NA `var'
	keep CNT2 YEAR `var'
	sort CNT2 YEAR
	tempfile `var'
	save ``var'', replace
	
    use `ppp'
	local var "EXP_NAC" 
	keep if na_item=="`var'" 
	rename NA `var'
	keep CNT2 YEAR `var'
	sort CNT2 YEAR
	tempfile `var'
	save ``var'', replace
	
    use `ppp'
	local var "PPP_EU27_2020"
	keep if na_item=="`var'" 
	rename NA `var'
	keep CNT2 YEAR `var'
	sort CNT2 YEAR
	
    * Merge the files with the distinct indicators
      sort CNT2 YEAR
	  merge 1:1 CNT2 YEAR using `EXP_NAC'
	  drop _merge
      sort CNT2 YEAR
	  merge 1:1 CNT2 YEAR using `EXP_EUR'
	  drop _merge

  * Calculate additional indicators
  
	gen EXR_NAC_EUR = EXP_NAC/EXP_EUR
	label var EXR_NAC_EUR "Exchange rate: LCU per Euro"
	
	* Exchange rate with base year 2020
	gen EXR_2020t = EXR_NAC_EUR if YEAR==2020
	bysort CNT2: egen EXR_2020 = mean(EXR_2020t)
	drop EXR_2020t
	label var EXR_2020 "Exchange rate in 2020: LCU per Euro"

	gen PPP_EUR = EXR_NAC_EUR/PPP_EU27_2020
	label var PPP_EUR "Purchasing power of one Euro in PPP"

	* PPP with base year 2020
	gen PPP_EUR_2020t = PPP_EUR if YEAR==2020
	bysort CNT2: egen PPP_EUR_2020 = mean(PPP_EUR_2020t)
	drop PPP_EUR_2020t
	label var PPP_EUR_2020 "PPP of one Euro in 2020"


  * Save the data

	keep CNT2 YEAR PPP_EUR PPP_EU27_2020 PPP_EUR_2020 EXR_NAC_EUR EXR_2020 // PPP_NAC
	sort CNT2 YEAR
		
	save ENTA_input_data\ENTA_input_datasets/ppp_exchange_rates, replace
	
