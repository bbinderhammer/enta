********************************************************************************
* Calculate age profiles for public benefits
********************************************************************************

* Content
* 0. Load and prepare EU-SILC data
* 1. Generate age profiles by sex
* 2. Smooth the data
 * 2a. BSU: age at which unemployment benefits end (cliff)
 * 2b. Pensions around the BSU cliff

********************************************************************************
* 0. Load and prepare EU-SILC data
********************************************************************************

  * Load data
  global country AT BE BG CY CZ DE DK EE EL ES FI FR HU HR IE IT LT LU LV NL PL PT RO SE SI SK  //// BG HR 
  //global country "SI"

  local vars "BSP BSFAM BSU BSPPEN BSX"
  
  foreach x in $country {	
    use $silcwd/data/silc_`x', replace
		
  * Generate means to identify outliers and generate caps

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
	  replace `var' =  mean`var'*6 if `var'>mean`var'*6
	  drop `var'aggr `var'pop t`var' n`var' mean`var'

	}
********************************************************************************
* 1. Generate age profiles by sex
********************************************************************************
  /*
  * Control data
    gen BSPc = BSFAM + BSU + BSPEN + BSX
	sum BSP BSPc
  */
  
  * Total
  preserve
  
    collapse (mean) `vars' ADULT (sum) POPSILC = ONE [pw=WEIGHTa], by(CNT2 YEAR AGE)
	tempfile tot 
	sort CNT2 YEAR AGE
	save `tot', replace
	
  restore
  
  * Men
  preserve
  
	keep if SEX==1
    collapse (mean) `vars' ADULT (sum) POPSILCm = ONE [pw=WEIGHTa], by(CNT2 YEAR AGE)
	foreach v of local vars {
      rename `v' `v'm
	}
	rename ADULT ADULTm
	tempfile men
	sort CNT2 YEAR AGE
	save `men', replace
	
  restore

  * Women
	keep if SEX==2
    collapse (mean) `vars' ADULT (sum) POPSILCf = ONE [pw=WEIGHTa], by(CNT2 YEAR AGE)
	foreach v of local vars {
      rename `v' `v'f
	}
	rename ADULT ADULTf
	
  * Merge the sex-specific files
  sort CNT2 YEAR AGE
  merge 1:1 CNT2 YEAR AGE using `men', nogen
  merge 1:1 CNT2 YEAR AGE using `tot', nogen
  

********************************************************************************
* 2. Smooth the data
********************************************************************************

 
  // local vars "BSP BSF BSE BSFAM BSU BSOA BSD BSS BSPPEN BSX"

 
  * Years for which data is available
    sum YEAR
    local min = max(2007, `r(min)')
    local max = `r(max)'
	if "`x'"=="DE" {
		local max = 2021
	}

  * Open-ended top age group (80+; 73+ for DE 2014-2018): it stays in the
  * smoother, but keeps its raw mean. It averages several hundred persons per
  * sex over some 20 years of age, and is the edge point where the smoother
  * errs most (DE 2018 and ES 2019 pensions by sex).
    sort CNT2 YEAR AGE
    by CNT2 YEAR: egen _topage = max(AGE)

  * Raw sum of BSU and pensions, for the window around the BSU cliff (2b)
    gen RSUM  = BSU  + BSPPEN
    gen RSUMm = BSUm + BSPPENm
    gen RSUMf = BSUf + BSPPENf

  ************************************************************
  * 2a. BSU: age at which unemployment benefits end (cliff)
  ************************************************************
  * Unemployment benefits end within a year when the unemployed move into
  * (pre-)retirement schemes; the age differs by country, sex and year (PL
  * women 57 -> 63, IT women 60 -> 67, men mostly 65-66). The cliff is the first
  * age from 57 at which BSU stays at or below 15% of its ages-50-56 mean for
  * three ages in a row, per year and for the total, men and women separately.
  * It is replaced by the median over the previous, current and next year, so
  * a noisy year does not move it; 62 where no cliff is found (e.g. RO, with
  * next to no BSU). Only smoothed years enter the median (DE 2022+ has 5-year
  * age groups).
    foreach s in "" m f {
      local k = cond("`s'"=="", "0", "`s'")
      tempvar ref low l1 l2 cand cut
      by CNT2 YEAR: egen double `ref' = mean(cond(inrange(AGE,50,56), BSU`s', .))
      gen byte `low' = BSU`s' <= 0.15*`ref'
      by CNT2 YEAR: gen byte `l1' = `low'[_n+1] if AGE[_n+1]==AGE+1
      by CNT2 YEAR: gen byte `l2' = `low'[_n+2] if AGE[_n+2]==AGE+2
      gen `cand' = AGE if `low' & `l1'==1 & `l2'==1 & inrange(AGE,57,72) & `ref'>0
      by CNT2 YEAR: egen `cut' = min(`cand')
      replace `cut' = 62 if `cut'==.
      replace `cut' = . if YEAR<`min' | YEAR>`max'
      preserve
        keep CNT2 YEAR `cut'
        duplicates drop
        sort CNT2 YEAR
        by CNT2: gen _cm1 = `cut'[_n-1] if YEAR[_n-1]==YEAR-1
        by CNT2: gen _cp1 = `cut'[_n+1] if YEAR[_n+1]==YEAR+1
        egen _BSUCUT`k' = rowmedian(_cm1 `cut' _cp1)
        keep CNT2 YEAR _BSUCUT`k'
        tempfile cut`k'
        save `cut`k'', replace
      restore
      merge m:1 CNT2 YEAR using `cut`k'', nogen
      sort CNT2 YEAR AGE
      drop `ref' `low' `l1' `l2' `cand' `cut'
    }

  foreach var of local vars {
 
    gen s`var' = `var'
    gen s`var'm = `var'm
    gen s`var'f = `var'f
	
    forvalues yr = `min'/`max' { 
  	
    if "`var'"!="BSU" {
      supsmooth `var' AGE if YEAR==`yr' & AGE>=18, gen(s`var'1) bwcv nograph
      replace s`var' = s`var'1 if s`var'1!=.
      supsmooth `var'm AGE if YEAR==`yr' & AGE>=18, gen(s`var'm1) bwcv nograph
      replace s`var'm = s`var'm1 if s`var'm1!=.
      supsmooth `var'f AGE if YEAR==`yr' & AGE>=18, gen(s`var'f1) bwcv nograph
      replace s`var'f = s`var'f1 if s`var'f1!=.
      // line `var' s`var' AGE if YEAR==`yr'
	  drop s`var'1 s`var'm1 s`var'f1 // sYL2
	}
    if "`var'"=="BSU" {
      * BSU: smoothed up to four years before the cliff (2a); the last three
      * years before it get a moving average below; raw from the cliff on.
      foreach s in "" m f {
        local k = cond("`s'"=="", "0", "`s'")
        quietly sum _BSUCUT`k' if YEAR==`yr'
        if r(N)>0 {
          local c = r(mean) - 3
          supsmooth `var'`s' AGE if YEAR==`yr' & AGE>=18 & AGE<`c', gen(s`var'`s'1) bwcv nograph
          replace s`var'`s' = s`var'`s'1 if s`var'`s'1!=.
          drop s`var'`s'1
        }
      }
	}

    }

	sort CNT2 YEAR AGE
	// twoway line `var' s`var' `var'm s`var'm `var'f s`var'f AGE if YEAR==2019
	// sleep 4000

    * BSU: 1-2-1 moving average of the raw values in the last three years
    * before the cliff, using only ages inside that range (never across it)
    if "`var'"=="BSU" {
      foreach s in "" m f {
        local k = cond("`s'"=="", "0", "`s'")
        tempvar prv nxt ma
        by CNT2 YEAR: gen double `prv' = `var'`s'[_n-1] if AGE[_n-1]==AGE-1 & AGE-1>=_BSUCUT`k'-3
        by CNT2 YEAR: gen double `nxt' = `var'`s'[_n+1] if AGE[_n+1]==AGE+1 & AGE+1<_BSUCUT`k'
        gen double `ma' = (`prv' + 2*`var'`s' + `nxt')/4 if `prv'<. & `nxt'<.
        replace `ma' = (2*`var'`s' + `nxt')/3 if `prv'==. & `nxt'<.
        replace `ma' = (`prv' + 2*`var'`s')/3 if `prv'<. & `nxt'==.
        replace `ma' = `var'`s' if `ma'==.
        replace s`var'`s' = `ma' if AGE>=_BSUCUT`k'-3 & AGE<_BSUCUT`k' & inrange(YEAR,`min',`max')
        drop `prv' `nxt' `ma'
      }
    }

    * Open-ended top age group keeps its raw mean (see above)
    replace s`var'  = `var'  if AGE==_topage & inrange(YEAR,`min',`max')
    replace s`var'm = `var'm if AGE==_topage & inrange(YEAR,`min',`max')
    replace s`var'f = `var'f if AGE==_topage & inrange(YEAR,`min',`max')

	replace `var' = s`var'
	replace `var'f = s`var'f
	replace `var'm = s`var'm
	drop s`var' s`var'm s`var'f
	
	replace `var' = 0 if `var'<0
	replace `var'f = 0 if `var'f<0
	replace `var'm = 0 if `var'm<0
  }

  ************************************************************
  * 2b. Pensions around the BSU cliff
  ************************************************************
  * BSU keeps its cliff (2a), but the pension step at the same age is spread
  * by the smoother, so the two overlap before the cliff and leave a gap after
  * it (DK: BS spike at 65, dip at 66; smaller in BE, FI, IE). The raw sum is
  * smooth - early-retirement pay in BSU hands over to pensions - so from
  * cliff-3 to cliff+2 pensions are the smoothed sum minus the published BSU.
  * Tested on all 26 countries, no country worse.
    foreach s in "" m f {
      local k = cond("`s'"=="", "0", "`s'")
      gen sRSUM`s' = .
      forvalues yr = `min'/`max' {
        supsmooth RSUM`s' AGE if YEAR==`yr' & AGE>=18, gen(tmp) bwcv nograph
        replace sRSUM`s' = tmp if tmp<.
        drop tmp
      }
      replace BSPPEN`s' = max(0, sRSUM`s' - BSU`s') ///
        if inrange(AGE, _BSUCUT`k'-3, _BSUCUT`k'+2) & inrange(YEAR,`min',`max')
      drop RSUM`s' sRSUM`s'
    }

  drop _topage _BSUCUT0 _BSUCUTm _BSUCUTf
  sort CNT2 YEAR AGE
  save ENTA_ageprofiles/ageprofiles/ben_`x', replace
  
}  



