********************************************************************************
* Calculate income age profiles from EU-SILC
********************************************************************************

* Content
* 0. Load EU-SILC data
* 1. Generate age profiles
* 2. Smooth income data
 * 2.1 Smooth individual income
 * 2.1b Enforce non-decreasing income for ages 15-17
 * 2.2 Smooth equivalised household income
 * 2.3 Save smoothed income age-profiles


********************************************************************************
* 0. Load EU-SILC data
********************************************************************************

  * Load data
global country  AT BE BG CY CZ DE DK EE EL ES FI FR HU HR IE IT LT LU LV NL PL PT RO SE SI SK //

foreach x in $country {

  use $silcwd/data/silc_`x', replace

  * Generate means to identify outliers and generate caps
  
    capture drop POP
    bysort CNT2 YEAR: egen POP = total(WEIGHTa)
	
	replace YO = YOest
    local vars "YE YM YEM YPr YPp YO"
	// browse CNT2 YEAR `vars'

    foreach var of local vars {
	  replace `var' = 0 if `var'==.
	  replace `var' = 0 if `var'<0

	  * Average income per receiver
      gen `var'aggr = `var'*WEIGHTa
	  gen `var'pop = (`var'>1)*WEIGHTa
      bysort CNT2 YEAR: egen t`var'=total(`var'aggr) // total income by type and year
      bysort CNT2 YEAR: egen n`var'=total(`var'pop)  // total population
	  gen mean`var' = t`var'/n`var' // average

	  * Cap the income data
	  //gen `var'precap = `var'
	  replace `var' =  mean`var'*6 if `var'>mean`var'*6
	  display("`var'")
	  drop `var'aggr `var'pop t`var' n`var' mean`var'

	}

  * Private pensions (PY080G) as part of the capped YPr, for the IE 2018
  * repair in 1c
    gen YPpens = cond(PY080G>0 & PY080G<., min(PY080G, YPr), 0)

	  
********************************************************************************
* 1. Generate age profiles
********************************************************************************
  
  local vars "YE YM YEM YPp YPr YO EHI WHRUSU EMPLSTAT EMPLFT YPpens"
  
  * Total
    preserve
  
    collapse (median) EHIMED=EHI (mean) `vars' (sum) POPSILC = ONE [pw=WEIGHTa], by(CNT2 YEAR AGE)
	tempfile tot 
	sort CNT2 YEAR AGE
	save `tot', replace
	
    restore
  
  * Men
    preserve
  
	keep if SEX==1
    collapse (median) EHIMEDm=EHI (mean) `vars' (sum) POPSILCm = ONE [pw=WEIGHTa], by(CNT2 YEAR AGE)
	foreach v of local vars {
      rename `v' `v'm
	}
	tempfile men
	sort CNT2 YEAR AGE
	save `men', replace
	
    restore

  * Women
	keep if SEX==2
    collapse (median) EHIMEDf=EHI (mean) `vars' (sum) POPSILCf = ONE [pw=WEIGHTa], by(CNT2 YEAR AGE)
	foreach v of local vars {
      rename `v' `v'f
	}
	
  * Merge the sex-specific files
    sort CNT2 YEAR AGE
    merge 1:1 CNT2 YEAR AGE using `men', nogen
	
    sort CNT2 YEAR AGE
    merge 1:1 CNT2 YEAR AGE using `tot', nogen


  ************************************************************
  * 1b Repair country-years without mortgage-interest data
  ************************************************************

  * EU-SILC delivers no usable HY100G - the sole source of YPp - for a few
  * country-years, so the collapsed YPp profile comes out identically zero
  * and YA (= YO + YPr - YPp) is overstated for that year:
  *   HU 2018 (wave HU19: value 0 with flag 0 "no income" - looks like real
  *            data, so no missing-value check catches it)
  *   FR 2020 (wave FR21: blank, flag -8 "not collected")
  *   DE 2008 (wave DE09: blank, flag -1 "missing")
  * Micro_SILC.do's `replace HY100G = 0 if HY100G==.` turns the blanks into
  * zeros, making all three indistinguishable from a genuine zero downstream.
  * Replace the affected profile with the neighbouring years' average.
  * Germany 2007 is broken the same way and is deliberately left alone, so
  * DE 2008 has no usable earlier year and takes 2009 on its own.

    local badyear ""
    if "`x'"=="HU" local badyear 2018
    if "`x'"=="FR" local badyear 2020
    if "`x'"=="DE" local badyear 2008

    if "`badyear'"!="" {

      local before = `badyear' - 1
      local after  = `badyear' + 1
      if "`x'"=="DE" local before = `after' // 2007 is unusable as well

      preserve
        keep if YEAR==`before' | YEAR==`after'
        keep CNT2 AGE YPp YPpm YPpf
        collapse (mean) YPp YPpm YPpf, by(CNT2 AGE)
        rename (YPp YPpm YPpf) (iYPp iYPpm iYPpf)
        tempfile ypfix
        sort CNT2 AGE
        save `ypfix', replace
      restore

      sort CNT2 AGE
      merge m:1 CNT2 AGE using `ypfix', nogen keep(master match)
      replace YPp  = iYPp  if YEAR==`badyear' & iYPp <.
      replace YPpm = iYPpm if YEAR==`badyear' & iYPpm<.
      replace YPpf = iYPpf if YEAR==`badyear' & iYPpf<.
      drop iYPp iYPpm iYPpf
      sort CNT2 YEAR AGE
      display("`x' `badyear': YPp interpolated from `before' and `after'")

    }


  ************************************************************
  * 1c Replace Irish private pensions in 2018 by the neighbouring years
  ************************************************************

  * IE EU-SILC 2018 reports private pension income (PY080G) for 609 persons,
  * against 124-171 in 2016-2020, so its weighted total jumps to 3.10 bn from
  * about 0.5 bn. The cause is not established. PY080G is part of YPr: the
  * pension part of the 2018 YPr profile is replaced by the average of 2017
  * and 2019, rent and investment income stay as reported.

    if "`x'"=="IE" {

      preserve
        keep if YEAR==2017 | YEAR==2019
        keep CNT2 AGE YPpens YPpensm YPpensf
        collapse (mean) YPpens YPpensm YPpensf, by(CNT2 AGE)
        rename (YPpens YPpensm YPpensf) (iYPpens iYPpensm iYPpensf)
        tempfile pensfix
        sort CNT2 AGE
        save `pensfix', replace
      restore

      sort CNT2 AGE
      merge m:1 CNT2 AGE using `pensfix', nogen keep(master match)
      replace YPr  = YPr  - YPpens  + iYPpens  if YEAR==2018 & iYPpens <.
      replace YPrm = YPrm - YPpensm + iYPpensm if YEAR==2018 & iYPpensm<.
      replace YPrf = YPrf - YPpensf + iYPpensf if YEAR==2018 & iYPpensf<.
      drop iYPpens iYPpensm iYPpensf
      sort CNT2 YEAR AGE
      display("IE 2018: private pensions in YPr replaced by the 2017/2019 average")

    }
    drop YPpens YPpensm YPpensf

********************************************************************************
* 2. Smooth income data
********************************************************************************

  ************************************************************
  * 2.1 Smooth individual income
  ************************************************************

  * Years for which data is available
    sum YEAR
    local min = `r(min)'
    local max = `r(max)'
	display "`r(min)' `r(max)'"

  * Loop over property income with stronger smoothing
    local vars "YPp YPr"
	// browse CNT2 YEAR YPr YPp

    if "`x'"=="DE" {
	 * Germany's age-specific SILC data stops at 2021; later years are
	 * only available in 5-year age groups and are left unsmoothed.
	 local max = 2021
	 local vars ""
    }
    if "`x'"=="FR" {
	 * alpha(8) crashes supsmooth for France ("missing values encountered
	 * among smoothed values", 2019), so France stays on the weaker/default
	 * tier below rather than the standard stronger one.
	 local vars ""
    }
	local min = max(2007, `min')

    foreach var of local vars {
      replace `var' = 0 if `var'==.

      gen s`var' = `var'
      gen s`var'm = `var'm
      gen s`var'f = `var'f

	  * For YP use a stronger smoothing
      forvalues yr = `min'/`max' {

        supsmooth `var' AGE if YEAR==`yr' & AGE>=18, gen(s`var'1) bwcv alpha(8) nograph
        replace s`var' = s`var'1 if s`var'1!=.
        supsmooth `var'm AGE if YEAR==`yr' & AGE>=18, gen(s`var'm1) bwcv nograph alpha(8)
        replace s`var'm = s`var'm1 if s`var'm1!=.
        supsmooth `var'f AGE if YEAR==`yr' & AGE>=18, gen(s`var'f1) bwcv nograph alpha(8)
        replace s`var'f = s`var'f1 if s`var'f1!=.
	    drop s`var'1 s`var'm1 s`var'f1 // sYL2
	    display("`yr' `var'")
	    /*
	    twoway line `var' AGE if YEAR==`yr' ///
	    || line s`var' AGE if YEAR==`yr', ///
	    title("`var', `yr'")
	    sleep 3000
		*/
	  } // end loop for year
    } // end if clause for YP

	
  * For other variables the supsmooth default parameters are used

    local vars "YE YM YEM YO" 
		
    if "`x'"=="DE" {
	 local max = 2021
     local vars "YPr YPp YE YM YEM YO"
    }
    if "`x'"=="FR" {
     local vars "YPr YPp YE YM YEM YO"
    }

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
	  
	    drop s`var'1 s`var'm1 s`var'f1 // sYL2
	  
        /*
	    twoway line `var' AGE if YEAR==`yr' ///
	    || line s`var' AGE if YEAR==`yr', ///
	    title("`var', `yr'")
	    sleep 1000
        */
	  } // end loop for year
    } // end loop over variables
  
  
  * Open-ended top age group (80+; 73+ for DE 2014-2018): it stays in the
  * smoother, but keeps its raw mean. It averages several hundred persons per
  * sex over some 20 years of age, and is the edge point where the smoother
  * errs most.
    sort CNT2 YEAR AGE
    by CNT2 YEAR: egen _topage = max(AGE)

  * Replace original with smoothed profiles
    local vars "YPr YPp YE YM YEM YO"
    foreach var of local vars {

      replace s`var'  = `var'  if AGE==_topage & inrange(YEAR,`min',`max')
      replace s`var'm = `var'm if AGE==_topage & inrange(YEAR,`min',`max')
      replace s`var'f = `var'f if AGE==_topage & inrange(YEAR,`min',`max')

      replace `var' = s`var' if s`var'!=.
      replace `var'm = s`var'm if s`var'm!=.
      replace `var'f = s`var'f if s`var'f!=.
      drop s`var' s`var'm s`var'f
  
      replace `var' = 0 if `var'<0 | AGE<15
      replace `var'm = 0 if `var'm<0 | AGE<15
      replace `var'f = 0 if `var'f<0 | AGE<15
    }


  ************************************************************
  * 2.1b Enforce non-decreasing income for ages 15-17 (avoid spikes just
  *      before the smoothed region, which now starts at age 18 for every
  *      variable). Age 18 is never touched and acts as the anchor.
  ************************************************************

  local vars "YPr YPp YE YM YEM YO"
  gsort CNT2 YEAR -AGE
  foreach var of local vars {
    by CNT2 YEAR: replace `var'  = `var'[_n-1]  if AGE>=15 & AGE<=17 & `var'[_n-1]!=.  & `var'  > `var'[_n-1]
    by CNT2 YEAR: replace `var'm = `var'm[_n-1] if AGE>=15 & AGE<=17 & `var'm[_n-1]!=. & `var'm > `var'm[_n-1]
    by CNT2 YEAR: replace `var'f = `var'f[_n-1] if AGE>=15 & AGE<=17 & `var'f[_n-1]!=. & `var'f > `var'f[_n-1]
  }
  sort CNT2 YEAR AGE


  ************************************************************
  * 2.2 Smooth equivalised household income (all ages included in smoothing)
  ************************************************************
  
  local vars "EHI EHIMED"
  foreach var of local vars {
 
    gen s`var' = `var'
    gen s`var'm = `var'm
    gen s`var'f = `var'f
	
	* Loop over years
    forvalues yr = `min'/`max' { 
		
      supsmooth `var' AGE if YEAR==`yr', gen(s`var'1) bwcv nograph
      replace s`var' = s`var'1 if s`var'1!=. 
      supsmooth `var'm AGE if YEAR==`yr', gen(s`var'm1) bwcv nograph
      replace s`var'm = s`var'm1 if s`var'm1!=. 
      supsmooth `var'f AGE if YEAR==`yr', gen(s`var'f1) bwcv nograph
      replace s`var'f = s`var'f1 if s`var'f1!=. 

	  drop s`var'1 s`var'm1 s`var'f1 // sYL2  
	
	  /*
	  sort CNT2 YEAR AGE
	  twoway line `var' s`var' AGE if YEAR==`yr', title("`var', `yr'")
	  sleep 1000
	  */
	}
	
    * Replace original with smoothed profiles
    replace `var' = s`var'
    replace `var'm = s`var'm
    replace `var'f = s`var'f
	drop s`var' s`var'm s`var'f
  } // end loop over variables
  
  
  ************************************************************
  * 2.3 Save smoothed income age-profiles
  ************************************************************
  
  drop _topage
  sort CNT2 YEAR AGE
  local vars EMPLSTAT EMPLFT WHRUSU
  foreach var of local vars {
    rename `var' `var'silc
    rename `var'm `var'silcm
    rename `var'f `var'silcf
  }
  save ENTA_ageprofiles/ageprofiles/inc_`x', replace  
  
} 


