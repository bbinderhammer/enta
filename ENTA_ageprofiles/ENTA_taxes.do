********************************************************************************
* Calculate age profiles for taxes
********************************************************************************

* Content
* 0. Load and prepare EU-SILC data
* 1. Generate age profiles
* 2. Smooth the data

  global country AT BE BG CY CZ DE DK EE EL ES FI FR HU HR IE IT LT LU LV NL PL PT RO SE SI SK // SK // BG HR
  //global country DE

********************************************************************************
* 0. Load and prepare EU-SILC data
********************************************************************************

  foreach x in $country {	
    use $silcwd/data/silc_`x', replace
  
  * Merge EMOD tax rates to EU-SILC
    sort CNT2 YEAR AGEGR10
    merge m:1 CNT2 YEAR AGEGR10 using ENTA_input_data\ENTA_input_datasets\taxr
	keep if _merge==3
    drop _merge

  * Tax variables
    local vars "YEM BSPPEN BSN"
    foreach var of local vars {
	replace `var' = 0 if `var'==.
	replace `var' = 0 if `var'<0
	replace T`var'r = 0 if T`var'r<0.01 // set zo zero if tax rate very small

	* Where the cutoff above has zeroed the rate, the tax profile inherits a
	* hole. Fall back to the benefit profile itself as the shape - `adjust`
	* sets the level from the ESA aggregate afterwards, so that is equivalent
	* to applying one average tax rate across all ages.
	*
	* The fallback triggers on the rate being unusable WHERE THE BENEFITS
	* ACTUALLY ARE, not on every group being zeroed. Testing "all groups zero"
	* missed the case that matters: in CZ 2013 the rate cleared 1% only at
	* ages 30-50 and was zeroed at 60+, so the surviving rate sat where pension
	* benefits are negligible and `adjust` scaled it up to carry the whole
	* aggregate - giving 450 at age 50 and 1.3 at age 80, against a normal
	* profile that rises to ~750 by age 80.
	*   BSPPEN - pensions concentrate at 60+, so trigger on any zeroed rate there
	*   BSN    - other benefits concentrate at working age, so 20-60
	*   YEM    - keep the original all-groups-zero test; a zero rate at age 0
	*            is normal and must not trigger anything
	* Effect: TBSPPEN fallback fires in 118 of 482 country-years instead of 74,
	* TBSN in 220 instead of 135. Selective, not blanket - the zeroing is
	* strongly bimodal, with 96% (TBSPPEN) and 84% (TBSN) of country-years
	* having either no relevant group zeroed or all of them.
	if "`var'"=="BSPPEN" {
	  gen byte `var'_z = (T`var'r==0) & inlist(AGEGR10,60,70,80)
	}
	else if "`var'"=="BSN" {
	  gen byte `var'_z = (T`var'r==0) & inlist(AGEGR10,20,30,40,50,60)
	}
	else {
	  bysort CNT2 YEAR: egen double `var'_mx = max(T`var'r)
	  gen byte `var'_z = (`var'_mx==0)
	  drop `var'_mx
	}
	bysort CNT2 YEAR: egen byte `var'_fb = max(`var'_z)
    gen T`var' = cond(`var'_fb==1, `var', `var' * T`var'r) // income from employment + selfemployment
	drop `var'_z `var'_fb
    }

 * Generate means to identify outliers and generate caps

    local vars "TYEM TBSPPEN TBSN"
    foreach var of local vars {
		
	  * Average income per receiver
      gen `var'aggr = `var'*WEIGHTa
	  gen `var'pop = (`var'>1)*WEIGHTa
      bysort CNT2 YEAR: egen t`var'=total(`var'aggr) // total income by type and year
      bysort CNT2 YEAR: egen n`var'=total(`var'pop)  // total population
	  gen mean`var' = t`var'/n`var' // average

	  * Cap the income data
	  replace `var' =  mean`var'*6 if `var'>mean`var'*6
	  drop `var'aggr `var'pop t`var' n`var' mean`var'
	  
	}


********************************************************************************
* 1. Generate age profiles
********************************************************************************
	
  //local vars "TYEM TB TBSPPEN TBSN" // TYPHH TYP TA
  
  * Total
  preserve
  
    collapse (mean) `vars' (sum) POPSILC = ONE [pw=WEIGHTa], by(CNT2 YEAR AGE)
	tempfile tot 
	sort CNT2 YEAR AGE
	save `tot', replace
	
  restore
  
  * Men
  preserve
  
	keep if SEX==1
    collapse `vars' (sum) POPSILCm = ONE [pw=WEIGHTa], by(CNT2 YEAR AGE)
	foreach v of local vars {
      rename `v' `v'm
	}
	tempfile men
	sort CNT2 YEAR AGE
	save `men', replace
	
  restore

  * Women
	keep if SEX==2
    collapse `vars' (sum) POPSILCf = ONE [pw=WEIGHTa], by(CNT2 YEAR AGE)
	foreach v of local vars {
      rename `v' `v'f
	}
	
  * Merge the sex-specific files
  sort CNT2 YEAR AGE
  merge 1:1 CNT2 YEAR AGE using `men'
  drop _merge

  sort CNT2 YEAR AGE
  merge 1:1 CNT2 YEAR AGE using `tot'
  drop _merge
 
  
********************************************************************************
* 2. Smooth the data
********************************************************************************

  //local vars "TYEM TB TBSPPEN TBSN" // TYPHH  TYP TA
 
  * Years for which data is available
    sum YEAR
    local min = max(2007, `r(min)')
    local max = `r(max)'
	if "`x'"=="DE" {
		local max = 2021
	}
	if "`x'"=="HR" {
		local min = 2009   // Croatian EU-SILC starts at income reference 2009;
		                   // the 2009-2010 EUROMOD tax rates are imputed from
		                   // 2011 in Micro_EUROMOD.do
	}

  * Open-ended top age group (80+; 73+ for DE 2014-2018): it stays in the
  * smoother, but keeps its raw mean. It averages several hundred persons per
  * sex over some 20 years of age, and is the edge point where the smoother
  * errs most.
    sort CNT2 YEAR AGE
    by CNT2 YEAR: egen _topage = max(AGE)

  foreach var of local vars {
 
    gen s`var' = `var'
    gen s`var'm = `var'm
    gen s`var'f = `var'f
	
    forvalues yr = `min'/`max' { 
  	
      supsmooth `var' AGE if YEAR==`yr' & AGE>=18, gen(s`var'1) bwcv nograph
      replace s`var' = s`var'1 if s`var'1!=.
      supsmooth `var'm AGE if YEAR==`yr' & AGE>=18, gen(s`var'm1) bwcv nograph
      replace s`var'm = s`var'm1 if s`var'm1!=.
      supsmooth `var'f AGE if YEAR==`yr' & AGE>=18, gen(s`var'f1) bwcv nograph
      replace s`var'f = s`var'f1 if s`var'f1!=. 
      // line `var' s`var' AGE if YEAR==`yr'
	  drop s`var'1 s`var'm1 s`var'f1 // sYL2
	  
    }

    replace s`var'  = `var'  if AGE==_topage & inrange(YEAR,`min',`max')
    replace s`var'm = `var'm if AGE==_topage & inrange(YEAR,`min',`max')
    replace s`var'f = `var'f if AGE==_topage & inrange(YEAR,`min',`max')

	replace `var' = s`var'
	replace `var'f = s`var'f
	replace `var'm = s`var'm
	drop s`var' s`var'm s`var'f

	replace `var' = 0 if `var'<0 | AGE<15
	replace `var'f = 0 if `var'f<0 | AGE<15
	replace `var'm = 0 if `var'm<0 | AGE<15

  }


  ************************************************************
  * 2b. Enforce non-decreasing taxes for ages 15-17 (avoid spikes just
  *     before the smoothed region, which starts at age 18 for every
  *     variable). Age 18 is never touched and acts as the anchor.
  ************************************************************

  gsort CNT2 YEAR -AGE
  foreach var of local vars {
    by CNT2 YEAR: replace `var'  = `var'[_n-1]  if AGE>=15 & AGE<=17 & `var'[_n-1]!=.  & `var'  > `var'[_n-1]
    by CNT2 YEAR: replace `var'm = `var'm[_n-1] if AGE>=15 & AGE<=17 & `var'm[_n-1]!=. & `var'm > `var'm[_n-1]
    by CNT2 YEAR: replace `var'f = `var'f[_n-1] if AGE>=15 & AGE<=17 & `var'f[_n-1]!=. & `var'f > `var'f[_n-1]
  }
  sort CNT2 YEAR AGE

  ************************************************************
  * Rename the microdata-based TYEM to TYEMind (individual-level
  * calculation), since ENTA_compilation1_esa.do now also computes its
  * own TYEM directly from the YEM age profile using age-specific EMOD
  * tax rates. Keeping both lets the two approaches be compared.
  ************************************************************

  // rename TYEM TYEMind
  // rename TYEMm TYEMindm
  //rename TYEMf TYEMindf

  drop _topage
  save ENTA_ageprofiles/ageprofiles/tax_`x', replace
  
}  




