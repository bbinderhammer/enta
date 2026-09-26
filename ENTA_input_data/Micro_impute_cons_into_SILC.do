* Impute consumption in EU-SILC

* Requires Micro_SILC.do and Micro_HBS.do to have been run first (Micro_HBS.do
* itself requires Micro_HBS_Austria.do to be run first - see its own header).

* Content
* 0. Combine SILC and HBS data
* 1. Impute consumption in EU-SILC using multiple imputation (regression-based
*    prediction of standardised consumption, rescaled to Euro), without HBS 2020
* 2. Compare original (HBS) and imputed (EU-SILC) consumption values


global country "DE AT BE BG CY CZ DK EE EL ES FI FR HR HU IE IT LT LU LV NL PL PT RO SE SI SK" // 
//global country "IT"

foreach x in $country { 
	
	
********************************************************************************
* 0. Combine EU-SILC and HBS data
********************************************************************************

  *****************
  * Load EU-SILC
  *****************
  
  use "$silcwd/data/silc_`x'", clear
	
  gen CON = 0
  keep CNT2 YEAR HHID HHSIZE HHTAG WEIGHTa WEIGHT AGE* SEX YDCASH CON NCHILD* PID* PERC YEM BSPPEN BSN YPr YPp YO

  *******************
  * Append HBS
  *******************
  
  append using "$hbswd/HBS_`x'.dta"
  replace YDCASH = 0 if YDCASH<0

  
  *******************
  * Variables available in both sources
  *******************
	
  * Variables available in HBS 2010 and 2015
	
	bysort YEAR HHID: egen NCHILD20 = total(AGEGR5<20)
	  replace NCHILD20 = 3 if NCHILD20>3
	
	* Generate variables for age age-structure 
	bysort YEAR HHID: egen NAGE25 = total(AGEGR5==20 | AGEGR5==25 | AGEGR5==30)
	bysort YEAR HHID: egen NAGE65 = total(AGEGR5==65)
	bysort YEAR HHID: egen NAGE70 = total(AGEGR5==70)	
	bysort YEAR HHID: egen NAGE75 = total(AGEGR5==75)	
	bysort YEAR HHID: egen NAGE80 = total(AGEGR5==80)	

  /*
  * Variables avialable in HBS 2020
	bysort YEAR HHID: egen NO60 = total(AGEGR15>=60) 
	gen NO60SH = NO60/HHSIZE
	bysort YEAR HHID: egen NWA1560 = total(AGEGR15>=15 & AGEGR15<60)
  */
  
  * Average consumption per capita (CHXavg), used to standardise
  * consumption below - CHXesa/POPtot come from ENTA_units.dta. The
  * capture drop guards against a stale HBS_`x'.dta (appended in above)
  * saved before Micro_HBS.do's own CHXavg cleanup existed.
    capture drop CHXavg
    sort CNT2 YEAR
    merge m:1 CNT2 YEAR using ENTA_aggregates/ENTA_units, keepusing(CHXesa POPtot)
	keep if _merge==3
	drop _merge
	gen CHXavg = CHXesa * 1000000 / POPtot
	drop CHXesa POPtot

  save $hbswd/SILC_HBS_`x', replace
}


********************************************************************************
* 1. Impute consumption in EU-SILC using regression, without HBS 2020
********************************************************************************

global country "AT BE BG CY CZ DE DK EE EL ES FI FR HR HU IE IT LT LU LV NL PL PT RO SE SI SK" // AT DE BE 
//global country "IT" 

foreach x in $country { 

  use $hbswd/SILC_HBS_`x', clear
  drop if (CON==1 & YEAR==2020) 
	
	  
  * Compare age-specific incomes: ENTA, disposable income in EU-SILC (HY020) and HBS (EUR_HH095)
	/*
	preserve
      collapse (mean) YDCASH [pw=WEIGHTa], by(CON YEAR AGEGR5)
	  sort YEAR CON AGEGR5
      twoway line YDCASH AGEGR5 if YEAR==2015 & CON==0, lcol(red) ///
	  || line YDCASH AGEGR5 if YEAR==2015 & CON==1, lcol(blue)
    restore
	*/

  * Replace high income values with max from HBS
    bysort CON: sum YDCASH if HHTAG==1 & (YEAR==2010 | YEAR==2015) [aw=WEIGHTa], det
    gen YDCASHHBS = YDCASH if CON==1
    egen YDCASHMAX = max(YDCASHHBS)
    replace YDCASH = YDCASHMAX if YDCASH>YDCASHMAX
	drop YDCASHHBS YDCASHMAX
	
  * Check the data
    // browse CHXSTD PERC HHSIZE NCHILD20 NAGE70 NAGE75 NAGE80 HHTAG CON

  * Estimate values for EU SILC
    replace CHXSTD = CHXSTD / HHSIZE
    * Linear OLS could predict negative consumption (confirmed: min -0.70
    * in a real run) since nothing constrains it to the valid range.
    * Replaced with a GLM (gamma family, log link): the log link makes
    * predictions positive by construction, and unlike a plain log-OLS +
    * exp() transform, `predict` after `glm` returns the fitted mean
    * directly (no retransformation/smearing bias correction needed).
    //reg CHXSTD PERC HHSIZE NCHILD20 NAGE25 NAGE65 NAGE70 NAGE75 NAGE80 if HHTAG==1 & CHXSTD<10
    //predict CHXPRED, xb
    glm CHXSTD PERC HHSIZE NCHILD20 NAGE25 NAGE65 NAGE70 NAGE75 NAGE80 if HHTAG==1 & CHXSTD<10, family(gamma) link(log)
    predict CHXPRED
	
	/*
	browse YEAR CNT2 HHID CHXIHH CHXSTD PERC 
	bysort YEAR CON: sum CHXIHH CHXSTD
    */
	
	keep if HHTAG==1
    keep CNT2 CON YEAR HHID CHXPRED

    sort CNT2 CON YEAR HHID
    save $hbswd/CHX1015_`x', replace
}

/*
********************************************************************************
* 2. Compare original and imputed values
********************************************************************************

global country "AT BE BG CY CZ DE DK EE EL ES FI FR HR HU IE IT LT LU LV NL PL PT RO SE SI SK" // AT DE BE 
//global country "IT" 

foreach x in $country { 

  use $hbswd/SILC_HBS_`x', clear
  drop if (CON==1 & YEAR==2020)	
  
  sort CNT2 CON YEAR HHID
  merge m:1 CNT2 CON YEAR HHID using $hbswd/CHX1015_`x'
}
  
  
  * NTA equivalence scales
    * Two versions, since HBS only ever has AGEGR5 (never single-year AGE):
    * CSCALE  - single-year AGE based, only valid where AGE exists (SILC)
    * CSCALE5 - AGEGR5 based, valid for both SILC and HBS - used for any
    * comparison between the two surveys 
	
    gen alpha=1
      replace alpha=0.4 if AGEGR5<5 // children under 5 are assumed to consume 40% of an adult
      replace alpha=0.4+(1-0.4)*((AGE-4)/(20-4)) if AGE>=5 & AGE<=20
	  replace alpha = 0.9 if AGE==16 & CNT2=="DE" & YEAR>=2022
    bysort CNT2 YEAR CON HHID: egen hhmem = sum(alpha) // number of effective household members; (number of hh-members in terms of adult consumption)
    gen CSCALE = alpha / hhmem

    gen alpha5=1
      replace alpha5=0.4 if AGEGR5<5 // children under 5 are assumed to consume 40% of an adult
      replace alpha5=0.4+(1-0.4)*((7-4)/(20-4)) if AGEGR5==5
      replace alpha5=0.4+(1-0.4)*((12-4)/(20-4)) if AGEGR5==10
      replace alpha5=0.4+(1-0.4)*((17-4)/(20-4)) if AGEGR5==15
    bysort CNT2 YEAR CON HHID: egen hhmem5 = sum(alpha5)
    gen CSCALE5 = alpha5 / hhmem5

  * NTA-scale consumption in Euro
    gen CHXPREDHH = CHXPRED * HHSIZE
    bysort CNT2 YEAR CON HHID: egen CHXIHH = mean(CHXPREDHH)
	gen CHXI = CHXIHH * CHXavg * CSCALE
	gen CHXI5 = CHXIHH * CHXavg * CSCALE5
    gen CHXNTA = CHX*CSCALE5
	browse CNT2 YEAR HHID CHXI CHXI5 CHX HHSIZE

  local variables "CHX CHXNTA CHXI CHXI5 CHXSTD"
  collapse (mean) `variables' [pweight=WEIGHTa], by(CNT2 CON YEAR AGEGR5)
  
  * Comparison HBS SILC
  line CHXI5 AGEGR5 if YEAR==2015 & CON==0, lcol(blue) ///
  || line CHXNTA AGEGR5 if YEAR==2015 & CON==1, lcol(red) 
  
  * Comparison HBS: Original vs imputed
  line CHXI5 AGEGR5 if YEAR==2015 & CON==1, lcol(blue) ///
  || line CHXNTA AGEGR5 if YEAR==2015 & CON==1, lcol(red) 
*/

	
	