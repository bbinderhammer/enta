
********************************************************************************
* Estimate private transfers

* Input: EU-SILC and matched/imputed consumption data
* Output: Age-profiles of consumption and private transfers

* Content
* 1. Consumption of education and health based on HBS
*   1.1 Education and health age-profiles using iteration based on HBS
* 2. Integrate consumption into SILC
* 3. Intrahousehold transfers
*   3.1 First component: income is shared among partners
*   3.2 Intra household transfers 2: between generations, not partners
*   3.3 Transfers owner occupied housing
*   3.4 Combine and test transfers
* 4. Create age-profiles
********************************************************************************


********************************************************************************
* 1. Consumption of education and health based on HBS
********************************************************************************

  **************************
  * 1.1 Education and health age-profiles using iteration based on HBS 
  *************************

  * The iteration method is used to allocate spending within households: 
  * 1.) Estimate age profiles
  * 2.) use them to allocate spending within households;
  * 3.) repeat the process

  global country AT BE BG CY CZ DE DK EE EL ES FI FR HU HR IE IT LT LU LV NL PL PT RO SE SI SK // 
//global country "AT" //  DE SE LT FR

  foreach x in $country {	
  
    use "$hbswd/HBS_`x'", clear

    keep if YEAR!=2020 & CON==1

    * Average consumption per capita (CHXavg), used to standardise
    * consumption data below for changes in price/income levels across
    * years - CHXesa/POPtot come from ENTA_units.dta. HBS_`x' itself
    * doesn't carry CHXavg (Micro_HBS.do computes and drops its own,
    * internal to that file's own standardisation) - the capture drop
    * guards against a stale HBS_`x'.dta saved before that cleanup existed.
      capture drop CHXavg
      sort CNT2 YEAR
      merge m:1 CNT2 YEAR using ENTA_aggregates/ENTA_units, keepusing(CHXesa POPtot)
      keep if _merge==3
      drop _merge
      gen CHXavg = CHXesa * 1000000 / POPtot
      drop CHXesa POPtot

    * Standardise consumption data (control for inflation)
      gen CHEw = CHE/HHSIZE / CHXavg  // initial weight
      gen CHHw = CHH/HHSIZE / CHXavg

    * Allocation of spending within households
    forvalues i = 1/15 {
      preserve
        collapse (mean) CHEi=CHEw CHHi=CHHw [aw=WEIGHTa], by(AGEGR5 SEX)
        sort AGEGR5 SEX
        tempfile w
        save `w'
      restore
      sort AGEGR5 SEX
      merge m:1 AGEGR5 SEX using `w', nogenerate
    
      bysort YEAR HHID: egen CHEh = total(CHEi)
      bysort YEAR HHID: egen CHHh = total(CHHi)
    
      replace CHEw = CHEi / CHEh
      replace CHHw = CHHi / CHHh
    
      drop CHEi CHHi CHEh CHHh
    }

    replace CHE = CHESTD * CHEw
    replace CHH = CHHSTD * CHHw
  
    keep if YEAR!=2020
    collapse (mean) CHE CHH [pw=WEIGHTa], by(CNT2 AGEGR5 SEX)
	sort CNT2 AGEGR5 SEX
	save "ENTA_ageprofiles\ageprofiles/cfe_cfh_1015_`x'", replace 
	  
	// line CHE CHH AGEGR5 if SEX==1 ///
	// || line CHE CHH AGEGR5 if SEX==2
	
  }
  

********************************************************************************
* 2. Integrate consumption into SILC
********************************************************************************

global country AT BE BG CY CZ DE DK EE EL ES FI FR HU HR IE IT LT LU LV NL PL PT RO SE SI SK //
//global country "IT" //  DE SE LT FR

foreach x in $country {	
	
  use $silcwd/data/silc_`x', clear
  
  * Define NTA scale; How much of total household consumption each member consumes 
    gen alpha=1
      replace alpha=0.4 if AGEGR5<5 // children under 5 are assumed to consume 40% of an adult
      replace alpha=0.4+(1-0.4)*((AGE-4)/(20-4)) if AGE>=5 & AGE<=20
	  replace alpha = 0.9 if AGE==16 & CNT2=="DE" & YEAR>=2022
    bysort CNT2 YEAR HHID: egen hhmem = sum(alpha) // number of effective household members; (number of hh-members in terms of adult consumption)
    gen CSCALE = alpha / hhmem
  
  * Add the ageprofiles for CHE and CHH
    * In Portugal HBS ends at AGEGR5=75
    gen AGEGR5all=AGEGR5
	replace AGEGR5 = 75 if AGEGR5==80 & CNT2=="PT"
  
	sort CNT2 AGEGR5 SEX
    merge m:1 CNT2 AGEGR5 SEX using "ENTA_ageprofiles/ageprofiles/cfe_cfh_1015_`x'"
    keep if _merge==3
	drop _merge
	
	replace AGEGR5 = AGEGR5all
	drop AGEGR5all


  * Estimate age profiles for CHX
  
    * Add CHX (imputed avg per member) 
      gen CON = 0
      sort CNT2 CON YEAR HHID
      merge m:1 CNT2 CON YEAR HHID using $hbswd/CHX1015_`x'
      keep if _merge==3
      drop _merge CON
	
	* Average consumption per capita (CHXavg), used to standardise
	* consumption below - CHXesa/POPtot come from ENTA_units.dta.
      sort CNT2 YEAR
      merge m:1 CNT2 YEAR using ENTA_aggregates/ENTA_units, keepusing(CHXesa POPtot)
	  keep if _merge==3
	  drop _merge
	  gen CHXavg = CHXesa * 1000000 / POPtot
	  drop CHXesa POPtot

	* Calculate NTA-scale consumption per individual
      gen CHXPREDHH = CHXPRED * HHSIZE
	  gen CHX = CHXPREDHH * CHXavg * CSCALE
	  
	
  * Consumption in form of imputed rent
  
	gen CHR = YOest // YO is aggregate-adjusted to CHR 
	bysort CNT2 YEAR HHID: egen CHRhh=sum(YOest)
	replace CHR = CHR * CSCALE
	drop CHRhh
	
  * Adjust consumption to aggregates
	adjustaggr YDCASH CHR CHX CHE CHH
	
  * Define needed variabels
  
    * Con exc. imputed rent
	gen CHNR = CHX + CHH + CHE 
	
	* Consumption taxes
    gen TCON = CHNR // consumption taxes
	adjustaggr TCON
	
	* Adjust imputed rent to aggregate
	rename CHR YR
	bysort CNT2 YEAR HHID: egen YRhh = sum(YR)
	gen CHR = YRhh * CSCALE
	
	
  ******************************
  * Calculate individual disposable income bwfore intrahh-transfers (YDCASHIND)
  ******************************
  
    * Merge EMOD tax rates to EU-SILC
      sort CNT2 YEAR AGEGR10
      merge m:1 CNT2 YEAR AGEGR10 using ENTA_input_data\ENTA_input_datasets\taxr
      drop if _merge!=3
      drop _merge

    * Generate tax variables
      local vars "YEM BSPPEN BSN"
      foreach var of local vars {
	    replace T`var'r = 0 if T`var'r<0.01 // set zo zero if tax rate very small 
        gen T`var' = `var' * T`var'r // income from employment + selfemployment
      }
	  
	  gen YDCASHIND = YEM + YPr - YPp + BSP - TYEM - TBSPPEN - TBSN
	  
	  * Adjust YDCASHIND to YDCASH aggregate
        rename YDCASH YDCASHtemp
	    rename YDCASHIND YDCASH
	    adjustaggr YDCASH
	    rename YDCASH YDCASHIND
	    rename YDCASHtemp YDCASH

	

********************************************************************************
* 3. Intrahousehold transfers
********************************************************************************

  ***************************************
  * 3.1 First component: income is shared among partners
  ***************************************

    bysort CNT2 YEAR HHID COUPLEID: egen INCCOUPLE = mean(YDCASHIND) if COUPLEID!=.
	
	gen TFW0 = 0
	   replace TFW0 = INCCOUPLE - YDCASHIND if COUPLEID!=.
	gen TFW0I = 0
	  replace TFW0I = TFW0 if TFW0>0 & TFW0!=.
	gen TFW0O = 0
	  replace TFW0O = -TFW0 if TFW0<0 & TFW0!=. 
	gen YDCASHIND0 = YDCASHIND + TFW0
	
	* Plot estimates for control
    /*
    preserve
      collapse TFW0O TFW0I ADULT  [pw=WEIGHTa], by(YEAR AGE SEX)
	  twoway line TFW0O TFW0I AGE if SEX==1 & YEAR==2023 ///
	  || line TFW0O TFW0I AGE if YEAR==2023 & SEX==2
    restore
    */
	
	
  *****************************
  * 3.2 Intra household transfers 2: between generations, not partners
  *****************************
		
  * Individual Surplus/Deficit
  
    gen LCS = YDCASHIND0 - (CHNR + TCON)    
	
    gen SURIN = 0   // Surplus of Individual
      replace SURIN = LCS if LCS >= 0

    gen DEFIN = 0  // Deficit of the Individual
      replace DEFIN = -LCS if LCS <= 0 
	 
  * Household Surplus/Deficit
  
    sort CNT2 YEAR HHID
    by CNT2 YEAR HHID: egen SURHH = total(SURIN)  // Surplus of the Household
    by CNT2 YEAR HHID: egen DEFHH = total(DEFIN)  // Deficit of the Household


    * Household specific "Tax"-Rate; deficit in relation to surplus

      gen HHTAX = DEFHH/SURHH
      * Deficit is higher than surplus: tax rate is 1
        replace HHTAX = 1 if SURHH==0
	    replace HHTAX = 1 if DEFHH>SURHH
	
    * Part of surplus used to cover deficit
      by CNT2 YEAR HHID: egen SURTAXHH = total(SURIN*HHTAX)  
  
    * Share of deficit not covered by surplus
      gen DEFRESIDSHARE = (DEFHH-SURTAXHH)/DEFHH   
      replace DEFRESIDSHARE=0 if DEFHH==0
	
    * Individual deficit not covered by surplus
	  // all persons with deficit are treated equal: a share of it is covered by the surplus, part of it might remain
      gen DEFRESID=DEFIN*DEFRESIDSHARE 
      by CNT2 YEAR HHID: egen DEFRESIDHH=total(DEFRESID) 
  
    * Deficits are covered by adult income receiver in the household (hheads)
	  gen YHHEAD = ADULT * YDCASHIND0
	  bysort CNT2 YEAR HHID: egen NYHHEAD = sum(YHHEAD)
      gen INTRAHHTRANS = DEFRESIDHH*YHHEAD/NYHHEAD - DEFRESID // remaining defict per hhead less their own remaining deficit
	  bysort CNT2 YEAR HHID: egen cINTRAHHTRANS = total(INTRAHHTRANS)  // adds up to zero
	  // deficit of household financed by adult members less their own deficit
	
    * Intra-household transfer component 2

      gen TFW1O = 0
      gen TFW1I = 0
	  
    * Not covered deficit
	  replace TFW1O = INTRAHHTRANS if INTRAHHTRANS>0 // not covered deficit of others financed by hheads
	  replace TFW1I = -INTRAHHTRANS if INTRAHHTRANS<0 // non-hheads receive transfers form hheads to finance uncovered deficit
	  
	* Covered deficit
	  replace TFW1O = TFW1O + SURIN*HHTAX
      replace TFW1I = TFW1I + DEFIN*(1-DEFRESIDSHARE) // share od deficit that is covered by surplus
	  
  * Test
    /*
    sum TFW1I if YEAR==2019
	display `r(sum)'
	sum TFW1O if YEAR==2019
	display `r(sum)'

    preserve
      collapse TFW1O ADULT  [pw=WEIGHTa], by(YEAR AGE)
	  twoway line TFW1O AGE if YEAR==2017, col("48  122 133") ///
	  || line TFW1O AGE if YEAR==2022
	  twoway line ADULT AGE if YEAR==2017, col("48  122 133") ///
	  || line ADULT AGE if YEAR==2022
    restore

    preserve
      collapse TFW1O TFW1I ADULT  [pw=WEIGHTa], by(YEAR AGE SEX)
	  twoway line TFW1O TFW1I AGE if SEX==1 & YEAR==2023 ///
	  || line TFW1O TFW1I AGE if YEAR==2023 & SEX==2
    restore
    */

 
  ***************************************
  * 3.3 Transfers owner occupied housing
  ***************************************

    gen TFWRI = 0
	replace TFWRI = CHR - YR if CHR > YR
	
	bysort YEAR HHID: egen TFWRIhh = sum(TFWRI)
	//bysort YEAR HHID: egen YRhh = sum(YR)
	gen CHRtax = 0
	replace CHRtax = TFWRIhh / YRhh if YRhh!=0
	gen TFWRO = YR * CHRtax
	
  * Test
    /*
    sum TFWRI
	display `r(sum)'
	sum TFWRO
	display `r(sum)'

    preserve
      collapse TFWRO TFWRI ADULT  [pw=WEIGHTa], by(YEAR AGE SEX)
	  twoway line TFWRO TFWRI AGE if SEX==1 & YEAR==2023 ///
	  || line TFWRO TFWRI AGE if YEAR==2023 & SEX==2
    restore
    */
	
	
  ******************************************
  * 3.4 Combine and test transfers
  ******************************************
	
  gen TFWO = TFW0O + TFW1O + TFWRO
  gen TFWI = TFW0I + TFW1I + TFWRI
  
  * Test
    /*
    sum TFWI
	display `r(sum)'
	sum TFWO
	display `r(sum)'

  preserve
    collapse TFWO TFWI [pw=WEIGHTa], by(AGE)
	twoway line TFWO AGE, col("48  122 133") ///
	|| line TFWI AGE, ///
      graphregion(margin(l-4 r-1 t-3 b-3) color(white))  ///
      plotregion(margin(tiny))  ///
	  xsc(r(0 90)) ///
      title("Intra-household transfer inflows and outflows", size(medsmall)) ///
          legend(cols(1) order(1 2) label(1 "Outflows") label(2 "Inflows") ///
   	      bmargin(small) size(med) ring(0) position(1) )
	  graph display, ysize(5) xsize(8)
      //graph export graphs/TFW_in_out.png, replace
  restore
    */


********************************************************************************
* 4. Create age-profiles
********************************************************************************  

  //gen CH = CHR + CHNR
  local variables "TFWO TFWI CHR CHNR CHX CHE CHH YDCASH TCON"
  
  preserve
    collapse (mean) `variables' [pweight=WEIGHTa], by(CNT2 YEAR AGE)
    sort CNT2 YEAR AGE
    tempfile total
    save `total'
  restore 
  
  preserve
    keep if SEX==1
    collapse (mean) `variables' [pweight=WEIGHTa], by(CNT2 YEAR AGE)
    foreach var of local variables {
      rename `var' `var'm
    }
    sort CNT2 YEAR AGE  
    tempfile men
    save `men'
  restore
  
  keep if SEX==2
  collapse (mean) `variables' [pweight=WEIGHTa], by(CNT2 YEAR AGE)
  foreach var of local variables {
    rename `var' `var'f
  }
    sort CNT2 YEAR AGE  
  
  merge 1:1 CNT2 YEAR AGE using `total', nogenerate
  sort CNT2 YEAR AGE  
  merge 1:1 CNT2 YEAR AGE using `men', nogenerate
  sort CNT2 YEAR AGE  
  
  
  *************************************
  * Smooth consumption and intrahousehold transfers
  *************************************

  * Years for which data is available (years without a taxr match, e.g.
  * 2004-2005, were already dropped at the merge above)
    sum YEAR
    local min = `r(min)'
    local max = `r(max)'
	
	if "`x'"=="DE" {
		local max = 2021
	}
	
  local vars "CHR TCON CHNR CHX CHH CHE" // smoothed over all ages
  
  foreach var of local vars {
    gen s`var' = `var'
    gen s`var'm = `var'm
    gen s`var'f = `var'f
	
    forvalues yr = `min'/`max' { 
      supsmooth `var' AGE if YEAR==`yr', gen(s`var'1) bwcv nograph
      replace s`var' = s`var'1 if s`var'1!=. 
      supsmooth `var'm AGE if YEAR==`yr', gen(s`var'm1) bwcv nograph
      replace s`var'm = s`var'm1 if s`var'm1!=. 
      supsmooth `var'f AGE if YEAR==`yr', gen(s`var'f1) bwcv nograph
      replace s`var'f = s`var'f1 if s`var'f1!=. 
      // line `var' s`var' AGE if YEAR==`yr'
	  drop s`var'1 s`var'm1 s`var'f1 // sYL2
    }

	replace `var' = s`var'
	replace `var'f = s`var'f
	replace `var'm = s`var'm
	drop s`var' s`var'm s`var'f

	* Floor at zero. supsmooth can overshoot below zero where a profile falls
	* towards zero at the top of the age range: CZ CHE came out negative at
	* age 80 in 15 of 16 years (-2.75 against a peak of 111 at age 38), and it
	* then survived into the published profiles because `adjust` only rescales.
	* Consumption and consumption taxes cannot be negative. This is the same
	* guard ENTA_income.do applies to income, without its AGE<15 floor - that
	* one is income-specific and would be wrong here, since children consume.
	  replace `var'  = 0 if `var'  < 0
	  replace `var'm = 0 if `var'm < 0
	  replace `var'f = 0 if `var'f < 0
  }


 local vars "TFWO TFWI" // not smoothed until 18
  
  foreach var of local vars {
    gen s`var' = `var'
    gen s`var'm = `var'm
    gen s`var'f = `var'f
	
    forvalues yr = `min'/`max' { 
      supsmooth `var' AGE if YEAR==`yr', gen(s`var'1) bwcv nograph
      replace s`var' = s`var'1 if s`var'1!=. 
      supsmooth `var'm AGE if YEAR==`yr', gen(s`var'm1) bwcv nograph
      replace s`var'm = s`var'm1 if s`var'm1!=. 
      supsmooth `var'f AGE if YEAR==`yr', gen(s`var'f1) bwcv nograph
      replace s`var'f = s`var'f1 if s`var'f1!=. 
      // line `var' s`var' AGE if YEAR==`yr'
	  drop s`var'1 s`var'm1 s`var'f1 // sYL2  
    }

	replace `var' = s`var'
	replace `var'f = s`var'f
	replace `var'm = s`var'm
	drop s`var' s`var'm s`var'f
	  
  }
  
  
  * Adjust so that TFWI = TFWO
  
    * Modify age data for Germany: Age groups end with 73 from 2014-18 and are only 5-year from 2022
      preserve 
    
	    use ENTA_input_data/ENTA_input_datasets\population80w, clear
		
        recode AGE (0/4=0) (5/9=5) (10/14=10) (15/19=15) (20/24=20) (25/29=25) ///
          (30/34=30) (35/39=35) (40/44=40) (45/49=45) (50/54=50) (55/59=55) ///
         (60/64=60) (65/69=65) (70/74=70) (75/79=75) (80/max=80), gen(AGEGR5)
		
	    replace AGE = AGEGR5 if AGE>=20 & YEAR>=2022 & CNT2=="DE"
	    replace AGE = 16 if AGE>=16 & AGE<20 & YEAR>=2022 & CNT2=="DE"
	    replace AGE = 73 if AGE>=73 & YEAR>=2014 & YEAR<=2018 & CNT2=="DE"
		
		collapse (sum) POP POPm POPf, by(CNT2 YEAR AGE)
		sort CNT2 YEAR AGE
		tempfile pop
		save `pop'
		
      restore
		
    sort CNT2 YEAR AGE
	merge 1:1 CNT2 YEAR AGE using `pop'
	keep if _merge==3
	drop _merge 
	
    gen TFWI_pop = TFWI*POP
    gen TFWO_pop = TFWO*POP
    bysort CNT2 YEAR: egen TFWI_pop_sum = total(TFWI_pop)
    bysort CNT2 YEAR: egen TFWO_pop_sum = total(TFWO_pop)
    replace TFWO = TFWO * TFWI_pop_sum / TFWO_pop_sum
	drop TFWI_pop* TFWO_pop*
	adjustgender TFWI TFWO

	// line TFWO TFWI AGE if YEAR==2019

	// line TFWO AGE if YEAR==2019 || line TFWO AGE if YEAR==2023
	// line TFWI AGE if YEAR==2019 || line TFWI AGE if YEAR==2023

  gen C = CHNR + CHR + TCON
  sort CNT2 YEAR AGE
  // line C TFWI AGE if YEAR==2019
  drop C
	
  /*
  rename C CH
  rename Cm CHm
  rename Cf CHf
  */
  
  sort CNT2 YEAR AGE
  save "ENTA_ageprofiles/ageprofiles/ctpriv_`x'", replace  
  
}  

/*
*************************************************
 * Plot the data
*************************************************

  local x "AT"
  use "ENTA_ageprofiles/ageprofiles/ctpriv_`x'", clear  
    sort CNT2 YEAR AGE
	
	local var "TFWO" 
    local yr5 = 2005
    local yr6 = 2006
    local yr7 = 2007
    local yr8 = 2008
    local yr9 = 2009
    local yr10 = 2010
    local yr11 = 2011
    local yr12 = 2012
    local yr13 = 2013
    local yr14 = 2014
    local yr15 = 2015
    local yr16 = 2016
    local yr17 = 2017
    local yr18 = 2018
    local yr19 = 2019
    local yr20 = 2020
    local yr21 = 2021
    local yr22 = 2022
    local yr23 = 2023
	
    graph twoway line `var' AGE if YEAR==`yr8', lcol("230 210 80") ///
    || line `var' AGE if YEAR==`yr9', lcol("200 210 85") ///
    || line `var' AGE if YEAR==`yr10', lcol("165 205 90") ///
    || line `var' AGE if YEAR==`yr11', lcol("125 200 95") ///
    || line `var' AGE if YEAR==`yr12', lcol("90 200 100") ///
    || line `var' AGE if YEAR==`yr13', lcol("75 190 110") ///
    || line `var' AGE if YEAR==`yr14', lcol("60 180 120") ///
    || line `var' AGE if YEAR==`yr15', lcol("30 165 140") 	///
    || line `var' AGE if YEAR==`yr16', lcol("0 150 160") ///
    || line `var' AGE if YEAR==`yr17', lcol("0 125 150") ///
    || line `var' AGE if YEAR==`yr18', lcol("0 110 140") ///
    || line `var' AGE if YEAR==`yr19', lcol("0 80 130") ///
    || line `var' AGE if YEAR==`yr20', lcol("20 65 115") ///
    || line `var' AGE if YEAR==`yr21', lcol("45 45 100") ///
    || line `var' AGE if YEAR==`yr22', lcol("60 30 95") ///
    || line `var' AGE if YEAR==`yr23', lcol("75 20 85") 
  */
	 

	 
	 
	 