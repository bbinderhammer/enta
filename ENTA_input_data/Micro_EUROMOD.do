********************************************************************************
* Micro_EUROMOD.do - tax rates by income type from EUROMOD output
*
* Estimates, from EUROMOD microsimulation output, how the taxes a person pays
* split across employment income, property income, pensions and non-pension
* benefits, and turns that split into two inputs of ENTA:
*   - ENTA_input_datasets/inctax_nonempl_decomp.dta (Section 4): TBSPPENsh,
*     the share of pensions (pay-as-you-go and funded) in the taxes paid on
*     benefits, by country and year. ENTA_aggregates_compilation.do uses it to
*     split the DG TAXUD total TB into TBSPPEN and TBSN.
*   - ENTA_input_datasets/taxr.dta (Section 5): effective tax rates TYEMr,
*     TYPr, TBSPPENr, TBSNr by country, year and AGEGR10. ENTA_taxes.do
*     applies them to EU-SILC incomes.
* Both files are aggregates without microdata and are published with the
* code, so this file is only needed to rebuild them.
*
* Inputs (paths in the setup file):
*   $emodout   raw EUROMOD output, one <CC>_<year>_std.txt per country and
*              year - read only by Section 0
*   $emodwd    working folder: emod_<cc>_std.dta (Section 0), pop_adjust.dta
*              (Section 0b), emod_<CC>.dta (Section 3, read by 4 and 5)
*   ENTA_input_datasets/population_agegr3 - read only by Section 0b
* Sections 0 and 0b are commented out: re-run them by hand when new EUROMOD
* output arrives (0) or the population data change (0b). Sections 1-5 run
* from the files they leave in $emodwd.
*
* Content:
*   0.  Load original data / combine all years in single file / Generate general variables
*   0b. Population adjustment of the EUROMOD weights
*   1.  Analyse relationship between EUROMOD variables: income, taxes, benefits
*   2.  Define GSA/ENTA income variables
*   3.  Taxes by source
*   4.  Decompose income taxes paid by the non-employed
*   5.  Age-specific tax rates based on EUROMOD
********************************************************************************
  

* Countries
  global country AT BE BG CY CZ DE DK EE EL ES FI FR HR HU IE IT LT LU LV NL PL PT RO SE SI SK

/*
  global countryl at be bg cy cz de dk ee el es fi fr hr hu ie it lt lu lv nl pl pt ro se si sk  // uk
  //global countryl "nl"
  
* Years
  global year 2005 2006 2007 2008 2009 2010 2011 2012 2013 2014 2015 2016 2017 2018 2019 2020 2021 2022 2023 2024 2025

  
********************************************************************************
* 0. Load original data / combine all years in single file / Generate general variables
********************************************************************************
	
foreach x in $countryl {
  foreach y in $year {
	    

  * Import if year/country exists - $emodout filenames mix upper- and
  * lowercase country codes depending on year (no consistent convention -
  * some countries are uppercase throughout, some switch from lowercase
  * to uppercase partway through their year range, with no overlap) - try
  * both rather than assuming one.
    local xu = upper("`x'")
    capture confirm file "$emodout/`xu'_`y'_std.txt"
    if _rc==0 {
      local rawfile "$emodout/`xu'_`y'_std.txt"
    }
    else {
      capture confirm file "$emodout/`x'_`y'_std.txt"
      if _rc==0 {
        local rawfile "$emodout/`x'_`y'_std.txt"
      }
      else continue
    }
    clear
    import delim "`rawfile'", decimalseparator(,)

  * Generate general variables
    gen YEAR = `y'
    gen AGE = dag
	gen SEX = 1 if dgn==1
	replace SEX = 2 if dgn==0
	gen WEIGHT = dwt
    gen CNT2 = strupper("`x'")
	gen ONE = 1
	
  * Age
	gen AGEGR10 = 0 if AGE<10
	    replace AGEGR10 = 10 if AGE>=10 & AGE<20
	    replace AGEGR10 = 20 if AGE>=20 & AGE<30
	    replace AGEGR10 = 30 if AGE>=30 & AGE<40
	    replace AGEGR10 = 40 if AGE>=40 & AGE<50
	    replace AGEGR10 = 50 if AGE>=50 & AGE<60
	    replace AGEGR10 = 60 if AGE>=60 & AGE<70
	    replace AGEGR10 = 70 if AGE>=70 & AGE<80
	    replace AGEGR10 = 80 if AGE>=80
		
	gen AGEGR3 = 0 if AGE<20
	    replace AGEGR3 = 1 if AGE>=20 & AGE<65
	    replace AGEGR3 = 2 if AGE>=65 

  
  * Number of household members and household indicator
	bys idhh: gen Nhh = _N  // number of household members
	bys idhh: gen nn = _n   // Within household ID
	bys idhh: egen NCHILD6 = total(AGE<=6)   
	bys idhh: egen NCHILD15 = total(AGE<=15) 
	bys idhh: egen NCHILD19 = total(AGE<=19) 
	  
  * Labour status (self-defined)
    gen NUNEMP = (les==5)
	gen NEMP = (les==2 | les==3)
	gen NCHILD = (les==0 | les==6)
	gen NINACT = (les==7 | les==9)
	gen NPENS = (les==4 | les==8)
	
	
  * Save microdata for single year
    sort YEAR idhh idperson
    save "$emodwd/`x'_`y'_std", replace 
	  
  }
  
  * Append all years for each country ************************************
  
    clear

    foreach y in $year {
      capture confirm file $emodwd/`x'_`y'_std.dta // is there a data set for the year and country
	  if (_rc==0) {      
        append using $emodwd/`x'_`y'_std, force
	    erase $emodwd/`x'_`y'_std.dta
	  }
		
	}
 
  * Save data in one file for each country
    compress
    sort CNT2 YEAR idhh idperson
    save $emodwd/emod_`x'_std, replace
	  
}

*/

/*
********************************************************************************
* 0b. Population adjustment of the EUROMOD weights
********************************************************************************
  * Re-run this whenever population data is updated (Suppl_population.do /
  * Suppl_population_UN.do) - Section 1 below depends on $emodwd/pop_adjust.

    foreach x in $country {

      * Same $emodwd/emod_<cc>_std source as Section 1 below, built by
      * Section 0 (commented out, not run every time - see the comment
      * there).
      local xl = lower("`x'")
      use "$emodwd/emod_`xl'_std", clear

	  collapse (sum) WEIGHT, by(CNT2 YEAR AGEGR3)
	  rename WEIGHT WEIGHTEMOD
	  tempfile age_`x'
	  save `age_`x''

    }

    clear
    foreach x in $country {
  	  append using `age_`x''
    }

    sort CNT2 YEAR AGEGR3
    merge 1:1 CNT2 YEAR AGEGR3 using ENTA_input_data\ENTA_input_datasets/population_agegr3
    keep if _merge==3
    drop _merge

    gen ADJPOP = POP / WEIGHTEMOD
    keep CNT2 YEAR AGEGR3 ADJPOP
    sort CNT2 YEAR AGEGR3
    save $emodwd/pop_adjust, replace
  */

	
********************************************************************************
* 1. Analyse relationship between EUROMOD variables: income, taxes, benefits
********************************************************************************


foreach x in $country {

  * Section 0 above (commented out, re-run manually when new raw EUROMOD
  * data arrives) builds $emodwd/emod_`x'_std - lowercase filename even
  * though $country here is uppercase.
  local xl = lower("`x'")
  use "$emodwd/emod_`xl'_std", clear

  * Population-adjusted weights

    * Add adjusted population data

      sort CNT2 YEAR AGEGR3
      merge m:1 CNT2 YEAR AGEGR3 using $emodwd/pop_adjust
      keep if _merge==3
      drop _merge

    * Generate adjusted WEIGHT that sums up to total population
      gen WEIGHTa = WEIGHT * ADJPOP
	 
	gen SECTOR = "Households"


  *********************************
  * Country specific adjustments
  *********************************
  
	gen yem_earns_oth = 0 // other income from employment contributing to ils_earns
    gen yem_origy_oth = 0 // other income from employment not in ils_earns but ils_origy
    gen yse_origy_oth = 0 // other income from selfemployment not in ils_earns but in ils_origy
    gen bs_oth = 0 // other benefit not in ils_ben but in ils_origy
	gen x_oth = 0 // other expenditure category

    if CNT2=="AT" {
	    replace yot = yot01 + yot02  // yot01 = military/civil service, yot02 = income of those below 16,
        replace ypp = ypp01 + ypp02
		replace yem_origy_oth = yem_origy_oth + yemot // tips (Trinkgeld)
		
	}
	
    if CNT2=="CY" {
	    replace yot = yot + bml // military service
	}
	
    if CNT2=="DE" {
	  replace x_oth = xhi_s // expenditure of self-employed for health insurance 
	}
	
    if CNT2=="EL" {
	  gen xmp = xmpam + xmpot // EL output has no xmp: maintenance payments = alimony (xmpam) + other (xmpot)
	}
	
    if CNT2=="HR" {
		replace yem_origy_oth = yem_origy_oth + ymc // compensation for caretakers and foster parents
		replace yem_earns_oth = yem_earns_oth + yst  // income of students
	}	
	
    if CNT2=="HU" {
	  * Sickness benefit (bhl) is inside ils_pen in the Hungarian EUROMOD
	  * output, so it would be booked as a pension in BSPPEN and left out of
	  * BSN below. AT, PL, CZ and SK put the same variable in the non-pension
	  * part; HU is the exception. Proven on emod_hu_std: for the 12,673
	  * observations whose only benefit component is sickness,
	  * ils_pen = ils_ben = bhl cell by cell.
	  replace ils_pen = ils_pen - bhl
	}

    if CNT2=="IE" {
	  replace xmp = ils_udb_xmp
	  replace ypp = ypp + poaps + poapu
	}
	
    if CNT2=="IT" {
	  replace yem_origy_oth = yem_origy_oth + yemnt //+ ypp02 + ypp01
	  replace yse_origy_oth = yse_origy_oth + ysenr_s //+ ypp02 + ypp01
	  replace ypp = ypp + ypp02 + ypp01
	  replace yemaj = 0 if yemaj==. // yaj income from additional jobs
	  replace yem = yem + yempv + yemtj + yemxp + yemaj
	  replace yse = yse + yseib + yseil
	  //gen tin_s =  tinktgb_s + tinrg_s + tinktbd_s + tinsv_s + tinrt02_s + tinktcp_s + tinktdt_s + tinxe_s + tinto_s + tinrt01_s + tinna_s + tinktdv_s - tintceent_s // tintceent_s = negative taxes

	}
	
    if CNT2=="NL" {
	  replace bs_oth = bs_oth + poacm
	}
	
    if CNT2=="PL" {
	  replace x_oth = ypt - yptmp // in Poland ypt (private transfers) not part of ils_origy but maintenance payment yes
	}

    if CNT2=="SK" {
	  replace yem_origy_oth = yem_origy_oth + yls // income lump sum
	  replace yem_earns_oth = yem_earns_oth - yemcs + yemwg - yem  // ils_earns holds wages (yemwg) less the company share (yemcs), not yem
	}
	
    if CNT2=="SI" {
	  replace yem = yem00 
	  replace yse = yse00
	  replace yem_earns_oth = yem_earns_oth + yaj + yst // - yem + yem00
	  // yaj income form additional jobs; yem00 basic employment, yst income student // in 2010 and 2012 is something different
	}


	
  **********************************
  * Identifying subcomponents
  **********************************
  
  * Variable structure:
  
  * ils_dispy // disposable income
    
	  * ils_origy // primary income plus transfers between households
	
	      * ils_earns // income from employment incl. self employment
		      * yem
			  * yse
			  * yem_earns_oth // other income components contributing to ils_earns
			  
	      * yiy, ypr, ypp // asset income
		  
		  * yot
		  * yem_origy_oth, yse_origy_oth, bs_oth
	
	  * ils_ben // social benefits
	  * bs_oth // other social benefits: in ils_origy in EUROMOD, booked as a benefit (BSP) in ENTA
	
	  * ils_tax
	  * ils_sicse, ils_sicer, ils_sicee, ils_sicot // social contributions
	 

  * Components of ils_earns
    gen ils_earnsc = yem + yse + yem_earns_oth
	
	  gen d_ils_earns = ils_earns - ils_earnsc
	  // browse AGE SEX YEAR idhh ils_earns ils_earnsc d_ils_earns yem* yse*  if d_ils_earns>1 | d_ils_earns<-1
	  
  * Components of ils_origy
	// In Finland yiy is within the household assigned differently in yiy than in ils_origy
    gen ils_origyc = ils_earns + yem_origy_oth + yse_origy_oth + bs_oth + yiy + ypr + ypp + yot + ypt - xmp - x_oth //- xmpam - xmpot 
	
	  gen d_ils_origy = ils_origy - ils_origyc
	  // browse YEAR CNT2 AGE SEX idhh ils_origy ils_origyc d_ils_origy ils_earns bs_oth yot ypp* ypt* ypr yiy xmp  x_oth ils_sicse if d_ils_origy>1 | d_ils_origy<-1
	  
  * Components of disposable income
	gen ils_dispyc = ils_origy + ils_ben - ils_tax - ils_sicee - ils_sicse - ils_sicot
	
	  gen d_ils_dispy = ils_dispyc - ils_dispy
	  // browse YEAR CNT2 idhh ils_dispy ils_dispyc d_ils_dispy if d_ils_dispy>1 | d_ils_dispy<-1

  * The checks are done; their variables are not needed below
    drop ils_earnsc d_ils_earns ils_origyc d_ils_origy ils_dispyc d_ils_dispy
	  
 
  
********************************************************************************
* 2. Define GSA/ENTA income variables
********************************************************************************

  * Labour income and mixed income 
    // yot income of below-16-year-olds and income during military service
	
	gen YE = (yem + yem_earns_oth + ils_sicer + yem_origy_oth + yot)*12
	  gen YEE = (yem + yem_earns_oth + yem_origy_oth + yot)*12
	  gen YER = (ils_sicer)*12
	
	gen YM = (yse + yse_origy_oth)*12
    gen YEM = (ils_earns + yem_origy_oth + yse_origy_oth + yot + ils_sicer)*12
    gen YEMEE = (ils_earns + yem_origy_oth + yse_origy_oth + yot)*12
	gen YEMc = YE + YM
	// browse YEM YEMc
	drop YEMc

    gen YP = (yiy + ypr + ypp)*12
	gen Y = YEM + YP
	
	
  * Public benefits + funded pensions
	gen BSP = (ils_ben + bs_oth)*12 // bs_oth mainly relevant for Netherlands
	  gen BSPPEN = (ils_pen + bs_oth)*12
	  gen BSN = (ils_ben - ils_pen)*12
	  // browse CNT2 YEAR BSPPEN
	
  * Private transfers 	
    // xmp alimony payments
    // ypt alimony received
	// gen BPSOCfc = bs_oth*12
    gen BPX = ypt*12
	gen TPX = (xmp + x_oth)*12
	//gen BPPEN = (ypp + bs_oth)*12 // bs_oth for Netherlands
	
  * Taxes and social benefits
    gen TYT = (ils_tax)*12
	gen TYS = (ils_sicee + ils_sicse + ils_sicot + ils_sicer)*12
	gen TY = TYT + TYS
	gen TYER = ils_sicer*12
	
  * Other income components (if YE, YM or YP depends on country)
    gen YDc = Y - TY + BSP + BPX - TPX 
	
	gen YD = ils_dispy*12
	gen d_YD = YD - YDc
	// browse CNT2 YEAR idhh AGE YD YDc yot ils_sicot YM // if d_YD>1 | d_YD<-1
	drop Y YDc d_YD TYT TYS TY TYER // check above; not used below
	
	
********************************************************************************
* 3. Taxes by source
********************************************************************************

  	gen TAXES = (ils_tax + ils_sicot)*12 // sicot included, because unclear who pays them
	  replace TAXES = 0 if TAXES<0
	  
 * Restrict the sample to those with sufficient taxable income
 
    gen double TAXBASE = YEM + YP + BSPPEN + BSN
	
	* TAXPOP is indicator for population with taxable income
    gen TAXPOP = 1
	replace TAXPOP = 0 if TAXBASE<=1 | TAXBASE==.
  
    bysort CNT2 YEAR TAXPOP: egen double TAXBASEP10x = pctile(TAXBASE), p(10)
	replace TAXBASEP10x = . if TAXPOP==0
    bysort CNT2 YEAR: egen double TAXBASEP10  = max(TAXBASEP10x)
    drop TAXBASEP10x
	
	replace TAXPOP = 0 if TAXBASE < TAXBASEP10
	replace TAXPOP = 0 if TAXES > 0.7*TAXBASE

  * Distinguish income of richest and poorest half of population
  
    * Identify quartiles of disposable income
    preserve 
	  drop if TAXPOP==0
      drop if AGE<20
      collapse (p25) q1=YD (median) q2=YD (p75) q3=YD [pw=dwt], by(CNT2 YEAR)
	  sort CNT2 YEAR
	  tempfile quartiles
	  save `quartiles'
    restore
	  
    sort CNT2 YEAR
    merge m:1 CNT2 YEAR using `quartiles'
	drop _merge
  
    * Variable QUARTILE
    gen QUARTILE = 1
    replace QUARTILE = 2 if YD>=q1 & YD<q2
    replace QUARTILE = 3 if YD>=q2 & YD<q3
    replace QUARTILE = 4 if YD>=q3
	
	* Variable HALF1 - HALF2
	gen HALF = 1 if QUARTILE==1 | QUARTILE==2
    replace HALF = 2 if QUARTILE==3 | QUARTILE==4
	
  * Adapt variable number of children below 15
    replace NCHILD15 = 3 if NCHILD15>=3
	replace NCHILD15 = 0 if ils_tax<=1
  
  * Generate composite variables: income components in each half of income distribution
    local vars "YEMEE BSPPEN BSN NCHILD15" 
	
	foreach var of local vars {
      forvalues q = 1/2 {
        gen `var'H`q' = 0
	      replace `var'H`q' = `var' if HALF==`q' 
	  }
	}
	
    forvalues q = 1/2 {
	  gen H`q'N15 = 0
	  replace H`q'N15 = NCHILD15 if HALF==`q'
	}

	
  *********************************	
  * Estimate tax burden by source
  *********************************
 
 
  * coefficients, updated in the loop over years
    gen TAXESest = 0 // estimate of taxes
	gen yemee = 0
	gen yp = 0
	gen bsppen = 0
	gen bsn = 0
	gen nchild15 = 0

  * Loop over years (different starting year)
	local min = 2007
	if "`x'"=="HR" {
		local min = 2011 
	}


	sum YEAR
	
  * Estimate tax burden by component
    forvalues y = `min'/`r(max)' {
		
	  display("`y'")
        reg TAXES YEMEEH1 YEMEEH2 YP BSPPENH1 BSPPENH2 BSN  /// BSPPENH1 BSPPENH2 BSNPENH1 BSNPENH2
		  H1N15 H2N15 if YEAR==`y' & TAXPOP==1, nocons

      * Predict taxes based on model
	  predict PRED
	  replace TAXESest = PRED if YEAR==`y'
	  drop PRED

      * Negative coefficients are set to 0.0001, not 0, and nothing is
      * re-estimated - for employment income, property income, pensions and
      * non-pension benefits alike. A negative coefficient is not a negative
      * tax: family benefits go to parents who also receive child tax credits,
      * and tax-free unemployment/sickness benefits replace taxed earnings, so
      * recipients pay less tax on their other income.
      * The small positive value matters for TADJ below: a person with other
      * income gets practically all tax on that income, a person living only
      * on benefits gets the full tax on the benefits. With 0, that tax would
      * be lost.
      * The child coefficients (H1N15, H2N15) are the exception: they are
      * meant to be negative (child tax credits) and are kept as estimated.

      * YEM
	    replace yemee = _b[YEMEEH1] if  YEAR==`y' & HALF==1
	    replace yemee = _b[YEMEEH2] if  YEAR==`y' & HALF==2
	    replace yemee = 0.0001 if yemee<0 & YEAR==`y'
	
	  * YP
	    replace yp = _b[YP] if YEAR==`y'
	    replace yp = 0.0001 if yp<0 & YEAR==`y'
		
      * BSPPEN
	    replace bsppen = _b[BSPPENH1] if YEAR==`y' & HALF==1 
	    replace bsppen = _b[BSPPENH2] if YEAR==`y' & HALF==2 
	    replace bsppen = 0.0001 if bsppen<0 & YEAR==`y'
		
	  * BSN
	    replace bsn = _b[BSN] if YEAR==`y' 
	    replace bsn = 0.0001 if bsn<0 & YEAR==`y'
		
	  * NCHILD
	    replace nchild15 = _b[H1N15] if YEAR==`y' & HALF==1
        replace nchild15 = nchild15 + _b[H2N15] if YEAR==`y' & HALF==2

    }
	
  * Tax components, based on model estimates
	gen TTYEMEE = yemee*YEMEE + nchild15*NCHILD15
	  replace TTYEMEE = 0 if TTYEMEE<0
	gen TYP = yp*YP
	gen TBSPPEN = bsppen*BSPPEN	 
	gen TBSN = bsn*BSN	
	gen TB = TBSPPEN + TBSN
	// browse CNT2 YEAR TB*
	  
	gen TAXESest2 = TTYEMEE + TYP + TB 
	// browse CNT2 YEAR idhh AGE TAXES TAXESest TAXESest2 TYT TTYEMEE TYP TB YE YM YP BSPPEN BSN NCHILD15
	// order CNT2 YEAR idhh AGE TAXES TAXESest TAXESest2 TYT TTYEMEE TYP TB YE YM YP BSPPEN BSN NCHILD15
	
  * Check if income exceeds actual or estimated taxes
    gen INCbase = YEMEE + YP + BSPPEN + BSN
    browse TAXES TAXESest INCbase
	// browse CNT2 YEAR YEMEE YP BSPPEN BSN INCbase TAXES TAXESest if TAXES>INCbase
	drop INCbase TAXESest // checks above
	
  * Adjust estimated tax components to EUROMOD total taxes
    gen TADJ = TAXES/TAXESest2

    replace TADJ = 0 if TAXESest2<=0
	
    replace TTYEMEE = TTYEMEE * TADJ
    replace TYP = TYP * TADJ	
    replace TB = TB * TADJ
    replace TBSPPEN = TBSPPEN * TADJ
    replace TBSN = TBSN * TADJ
	// browse CNT2 YEAR TAXES TAXESest INC TAXPOP if TADJ>5

  * Control tax estimates; 
	gen TAXESc = TTYEMEE + TYP + TBSPPEN + TBSN 
	gen TAXESc1 = TTYEMEE + TYP + TB 
	// browse TAXES TAXESc TTYEMEE TYP TB TADJ YEM YP BSPPEN BSN
	// order TAXES TAXESc TTYEMEE TYP TB TADJ YEM YP BSPPEN BSN
	drop TAXESc TAXESc1
	
  * Add social benefits
	
	gen TSYEM = ils_sicee*12 + ils_sicse*12 +  ils_sicer*12
	gen TYEM = TTYEMEE + TSYEM
	
	* Control
	  gen TYc2 = (ils_tax + ils_sicee + ils_sicer + ils_sicse + ils_sicot)*12 // differences because of negative tax rates
	  gen TYc3 = TYEM + TYP + TB 
	  gen TYc4 = TAXES + TSYEM
	  gen d_TY = TYc2 - TYc3
	  // browse CNT2 YEAR AGE TYc2 TYc3 TYc4 ils_tax ils_sicot
	  drop TYc2 TYc3 TYc4 d_TY

  * Save data for Sections 4 and 5 below (decomposition of taxes paid by
  * nonemployed, age-specific tax rates)

     keep idhh AGE AGEGR10 CNT2 SEX YEAR YEM YM YE YEE YER YP TB TBSPPEN TBSN TSYEM TTYEMEE TYEM TYP BSP BSPPEN BSN WEIGHT* TAXPOP
     save $emodwd/emod_`x', replace
}
 


********************************************************************************
* 4. Decompose income taxes paid by the non-employed
********************************************************************************
	
  //global country AT BE BG CY CZ DE DK EE EL ES FI FR HR HU IE IT LT LU LV NL PL PT RO SE SI SK	
  //global country DE 
  foreach x in $country {
	    use $emodwd/emod_`x', clear
		keep if TAXPOP==1
        collapse (sum) TBSPPEN TBSN [iw=WEIGHTa], by(CNT2 YEAR)
	    sort CNT2 YEAR
	    tempfile tb`x'
	    save `tb`x''
  }
	  
  clear
  foreach x in $country {
    append using `tb`x''
  }
	  
  gen TBSPPENsh = TBSPPEN / (TBSPPEN + TBSN)  // pension share in taxes on non-employed
    replace TBSPPENsh = 0 if (TBSPPEN + TBSN)==0
    replace TBSPPENsh = 0 if TBSPPENsh<0
  keep CNT2 YEAR TBSPPENsh

  * Croatia 2009-2010: same gap, same treatment as taxr in Section 5 - carry the
  * 2011 pension share back. This share splits the DG TAXUD total TB into
  * TBSPPEN and TBSN in ENTA_aggregates_compilation.do; the total itself is
  * unaffected.
    preserve
      keep if CNT2=="HR" & YEAR==2011
      expand 2
      bysort CNT2: gen byte _y = _n
      replace YEAR = 2009 if _y==1
      replace YEAR = 2010 if _y==2
      drop _y
      tempfile hr_sh_back
      save `hr_sh_back'
    restore
    append using `hr_sh_back'

  sort CNT2 YEAR
  save ENTA_input_data\ENTA_input_datasets/inctax_nonempl_decomp, replace
  
 
********************************************************************************
* 5. Age-specific tax rates based on EUROMOD
********************************************************************************

  foreach x in $country {	
      use $emodwd/emod_`x', clear
  
	    // browse CNT2 YEAR idhh YEM TYEM YP TYP TBSPPEN BSPPEN BSN TBSN WEIGHTa AGEGR10

      ************************************************************
      * Age grouping for the tax rates: four groups, not nine.
      *   0-19, 20-29, 30-59, 60+
      ************************************************************
	  
        gen AGEGRTAX = 10 if AGE<20
          replace AGEGRTAX = 20 if AGE>=20 & AGE<30
          replace AGEGRTAX = 30 if AGE>=30 & AGE<60
          replace AGEGRTAX = 60 if AGE>=60

		keep if TAXPOP==1
        collapse (sum) YEM TYEM YP TYP TBSPPEN BSPPEN BSN TBSN  [pw=WEIGHTa], by(CNT2 YEAR AGEGRTAX)

	    gen TYEMr = TYEM / YEM
		  replace TYEMr = 0 if YEM==0
		  replace TYEMr = 0 if TYEMr<0
	    gen TBSPPENr = TBSPPEN/BSPPEN
	      replace TBSPPENr = 0 if TBSPPEN==0
	      replace TBSPPENr = 0.7 if TBSPPEN>BSPPEN // above 100%: set to the ceiling below
		  replace TBSPPENr = 0 if TBSPPENr<0
	    gen TBSNr = TBSN/BSN
	      replace TBSNr = 0 if TBSN==0
	      replace TBSNr = 0.7 if TBSN>BSN // above 100%: set to the ceiling below
		  replace TBSNr = 0 if TBSNr<0

      ************************************************************
      * Tax on property income: one rate per country-year, no age differences.
      * Property income is held by few
      * households and concentrates at older ages, so an age-specific TYP/YP
      * mostly reflects who happens to hold the assets in a thin cell rather
      * than any age-varying tax treatment. The rate is therefore built from
      * the country-year totals and applied unchanged to every age group.
      ************************************************************
	  
        bysort CNT2 YEAR: egen double _TYPtot = total(TYP)
        bysort CNT2 YEAR: egen double _YPtot  = total(YP)
        gen TYPr = _TYPtot / _YPtot
          replace TYPr = 0 if _TYPtot==0
          replace TYPr = 0.7 if _TYPtot>_YPtot // above 100%: set to the ceiling below
          replace TYPr = 0 if TYPr<0
        drop _TYPtot _YPtot


      ************************************************************
      * Ceiling of 0.7. What matters for the published profiles
      * is not how large the rescale TADJ (Section 3) gets but whether the RATE
      * that comes out is credible, and no effective rate on an income
      * component plausibly reaches 0.7 - TYEMr is a share of total labour
      * cost, employer contributions included on both sides.
      ************************************************************
	  
        foreach v in TYEMr TBSPPENr TBSNr TYPr {
          replace `v' = 0.7 if `v' > 0.7 & !missing(`v')
        }

	    drop YEM TYEM YP TYP TBSPPEN BSPPEN BSN TBSN

      ************************************************************
      * Expand back onto the nine-group AGEGR10 grid that ENTA_taxes.do and
      * ENTA_compilation1_esa.do merge on, so the interface is unchanged:
      * 0/10 carry the 0-19 rate, 30/40/50 the 30-59 rate, 60/70/80 the 60+
      * rate. Every country-year thus has all nine AGEGR10 rows.
      ************************************************************
	  
        expand 2 if AGEGRTAX==10
        expand 3 if inlist(AGEGRTAX,30,60)
        bysort CNT2 YEAR AGEGRTAX: gen byte _j = _n
        gen AGEGR10 = AGEGRTAX
        replace AGEGR10 =  0 + 10*(_j-1) if AGEGRTAX==10
        replace AGEGR10 = 30 + 10*(_j-1) if AGEGRTAX==30
        replace AGEGR10 = 60 + 10*(_j-1) if AGEGRTAX==60
        drop _j AGEGRTAX

	    sort CNT2 YEAR AGEGR10
		tempfile taxr_`x'
	    save `taxr_`x''
  }
  
  clear
  foreach x in $country {	
  	append using `taxr_`x''
  }
  
  ************************************************************
  * Croatia 2009-2010: impute the tax rates from 2011
  *
  * EUROMOD has no Croatian input before 2011, so the regression above cannot
  * estimate rates for the first two years of Croatian EU-SILC (income
  * reference 2009 and 2010, from the 2010 and 2011 surveys). Without a taxr
  * row those two country-years are dropped by the `keep if _merge==3` in
  * ENTA_taxes.do and by the keep(3) merges in ENTA_compilation1_esa.do, which
  * is why Croatia had no published data at all before 2011 even though
  * inc_HR and ben_HR already cover 2009 onwards (15 years, not 13).
  *
  * The earliest estimated year is carried back over the two missing ones.
  * What is imputed is only the AGE SHAPE of the tax profile: its level is set
  * afterwards by `adjust`, which scales the profile to the published ESA
  * aggregate of that same year. Documented in the manual, Chapter 5
  * (Limitations, Croatia).
  ************************************************************

    preserve
      keep if CNT2=="HR" & YEAR==2011
      expand 2
      bysort CNT2 AGEGR10: gen byte _y = _n
      replace YEAR = 2009 if _y==1
      replace YEAR = 2010 if _y==2
      drop _y
      tempfile hr_taxr_back
      save `hr_taxr_back'
    restore
    append using `hr_taxr_back'

  sort CNT2 YEAR AGEGR10
  save ENTA_input_data\ENTA_input_datasets/taxr, replace  
 
