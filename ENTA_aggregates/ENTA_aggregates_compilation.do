
********************************************************************************
* Generate aggregate data for ENTA
*
* Purpose:
*   Summarise and organise ESA 2010 data for European National Transfer Accounts.
*   Prepare aggregate measures of income, taxes, benefits, consumption, and saving.
*
* Input:
*   - Eurostat non-financial sector accounts (ESA 2010)
*   - Supplementary data: government expenditure (COFOG), tax structure
*
* Output:
*   - Nominal aggregates in long format: ENTA_aggregates/ENTA_aggregates.dta
*     (internal - the aggregate database adjustaggr/adjust/adjustsec merge
*     against; distinct from the two output files below despite the name.
*     Saved before the missing-data cleaning on purpose, see Section 7)
*   - Cleaned long-format output: ENTA_output_data/ENTA_aggregates.dta
*   - Single canonical CSV, for the dataexplorer and external publication
*     (e.g. Zenodo): ENTA_output_data/ENTA_aggregates.csv
*
* Unit conversion (per capita, real HICP, PPS, %GDP, %primary income, NTA/
* ENTA norm) is not done in this file - all values here are nominal
* aggregate totals (million EUR). The ENTA dataexplorer calculates each unit
* on demand from these totals plus the conversion factors saved separately
* by ENTA_units.do (ENTA_aggregates/ENTA_units.dta), published together with
* the norms by ENTA_compilation1_esa.do (ENTA_output_data/ENTA_units).
*
* Contents:
*   0. Write programmes for repeated tasks by sector
*   1. Aggregates for household sector (incl. NPISH)
*   2. Aggregates for corporations
*   3. Aggregates for government
*   4. Aggregates for total economy
*   5. NTA aggregates
*   6. Combine sectors and save nominal aggregate data
*   7. Clean missing data and save for different purposes (dataexplorer,
*      long-format output) - folded in from the former ENTA_aggregates_save.do
********************************************************************************

********************************************************************************
* 0. Write programmes for repated tasks by sector
********************************************************************************

* Programme: reshape wide to long
*   Converts a set of variables from wide format to long format with IND/VALAGGR

capture program drop reshape_to_long
program define reshape_to_long
    syntax namelist
    foreach ind of local namelist {
        tempfile `ind'
        preserve
        keep CNT2 YEAR `ind'
        gen IND = "`ind'"
        rename `ind' VALAGGR
        save ``ind''
        restore
    }
    keep CNT2 YEAR
    foreach ind of local namelist {
        append using ``ind''
    }
end

* Programme for output table in percapuita values

capture program drop percapita
program define percapita
    syntax namelist
	
  * Translate to long format
    gen IND = ""
    foreach var of local namelist {
      preserve
        keep CNT2 YEAR `var' IND
        rename `var' VALUE
        replace IND = "`var'"
        tempfile d`var'
        save `d`var'', replace
      restore
    }

    clear
    foreach var of local namelist {
        append using `d`var''
    }

  * Merge population data
    sort CNT2 YEAR
    merge m:1 CNT2 YEAR using "ENTA_input_data/ENTA_input_datasets/population0t"
    keep if _merge == 3
    drop _merge

  * Calculate per capita values
    replace VALUE = VALUE * 1000000 / POP
	
    sort  CNT2 YEAR IND
    order CNT2 YEAR IND VALUE

end

	
********************************************************************************
* 1. Aggregates for household sector (incl. NPISH)
********************************************************************************
	
  use ENTA_input_data\ENTA_input_datasets/esa_aggregates, clear
  keep if sector=="S14_S15"
  drop if CNT2=="EU27_2020" | CNT2=="EA20"
	
	
  **********************************************
  * 1.1 Income 
  ********************************************** 
  
  * YEM: Employment income = YE (compensation of employees) + YM (mixed income)
  * YA:  Asset income = YP (property income) + YO (operating surplus)
  
  * Adjust income variables with income-based taxes on production
	replace YE = YE + (TTYERr - TTYERrow) 
	replace Y = Y + (TTYERr - TTYERrow) - TTYERp 
	
  * Composite income measures
    gen YEM = YE + YM // Employment income = compensation of emloyees (YE) and mixed income (YM)
	
	
  *****************************************
  * 1.2 Taxes 
  *****************************************
  
  * ENTA taxes combine information from ESA and information on tax revenues by 
  * function from the EU tax and customs union (see Taxation Trends or Annual
  * Report on Taxation) 
  
    * Income taxes in ESA
      * TYT income taxes (D51)
      * TYS Social contributions (D61)
      *   - TYSER (employer, D611 D611)
      *   - TYSHH (households - employees and non-employed, D613, D614)
	  
    * Other taxes in ESA
      * TPNp taxes on production (D29, D39)
      * TA Taxes on stock of assets (D59)
      * TCON Taxes on products (D21, D31)
	  * TX other current transfers
  
    * Income taxes in tax statistic
      * TYM taxes on capital, income of selfemployed
      * TYER taxes on labour, inc form employment, paid by employers 
      * TYEE taxes on labour, inc form employment, paid by employees
      * TYP taxes on capital, income of households
      * TB taxes on labour, paid by non-emploed
		
  * Merge tax structure data
		
    //sort CNT2 YEAR
    //merge 1:1 CNT2 YEAR using ENTA_input_data\ENTA_input_datasets/taxstructure_wide, nogenerate keep(master match)
  
  * Add imputed social contributions to TYER of tax statistic (originally not included)
	replace TYER = TYER + D612p
	  
  * Adjustment of taxes on labour income: from "received by gov" to "paid by HH" 
	// tax stat is about gov received, ESA (and ENTA) about households paid, mostly relevant for LU
	gen TYE = TYER + TYEE // received by gov
    replace TYE = TYE - (D61rg - TYS) // (D62rg - TYS) = social contributions paid to ROW
		
  * Reallocation of labour-based "other taxes on production" to "social contributions" (mostly relevant for AT, SE)
    replace TPN = TPN - TTYERp
	replace TPNp = TPNp - TTYERp 
	replace TYS = TYS + (TTYERr - TTYERrow) 
	
* Compare income taxes: ESA vs tax statistics
    gen TYesa = TYT + TYS 
    gen TYtax = TYE + TYM + TYP + TB
    gen TYAF = TYesa / TYtax // adjustment factor
    browse CNT2 YEAR TYesa TYtax TYAF	
	
  * Adjust taxes by function from tax data to ESA aggregates 
	// tax data = received by S13 in total, ESA data = paid by domestic to S13; 

    replace TYE = TYE * TYAF
    replace TYM = TYM * TYAF
    replace TYP = TYP * TYAF
    replace TB = TB * TYAF
    gen TYEM = TYE + TYM
	
  * Control if data from tax statistic and ESA now add up
    gen TYtax_check = TYE + TYM + TYP + TB
    browse CNT2 YEAR TYesa TYtax_check TYAF if YEAR==2023
	
  * Calculate composite indicators for asset income and taxes on assets
    browse CNT2 YEAR YP YO TPNp
    gen YA = YP + YO
	replace YM = YM + TPNp
	replace YEM = YEM + TPNp
	
	gen TYA = TYP + TA
	replace TYM = TYM + TPN
	replace TYEM = TYEM + TPN

  * Verify income identity
	capture drop Yc
	gen Yc = YEM + YA
	browse CNT2 YEAR Y Yc 
	
  * Total taxes
	gen T = TYE + TYM + TYP + TA + TX + TCON + TB
	replace T = TYesa if TYE==.
  
	
  * Distinguish between taxes paid on (public and private) pensions and non-pensions
  
    sort CNT2 YEAR
    merge 1:1 CNT2 YEAR using ENTA_input_data\ENTA_input_datasets/inctax_nonempl_decomp
	drop if _merge==2
	drop _merge
	
  * Decompose taxes on benefits: pensions vs non-pensions
	gen TBSPPEN = TB * TBSPPENsh
	gen TBSN = TB * (1 - TBSPPENsh)
	drop TBSPPENsh 

	
  *********************************
  * 1.3 Social benefits 
  *********************************
  
  * Merge social benefits by type (from gov expenditure by COFOG)
    sort CNT2 YEAR 
	merge 1:1 CNT2 YEAR using ENTA_input_data\ENTA_input_datasets/gov_expenditure
	drop if _merge==2
	drop _merge
	sort CNT2 YEAR
	browse
	
  * Control: compare ESA-based benefits with COFOG-based sum
    gen BSc = BSOA + BSS + BSF + BSU + BSX + BSE + BSD

  * Adjust benefit components to match ESA aggregate
    foreach var in BSOA BSS BSF BSU BSD BSE BSX {
      replace `var' = `var' * BS / BSc
    }
    drop BSc BScofog
	
  * Generate categories consistent with microdata
    gen BSPPEN = BSOA + BSD + BSS + BPSOCfc  // pensions, incl. mandatory funded
    gen BSPEN  = BSOA + BSD + BSS            // pensions, excl. funded
    gen BSFAM  = BSF + BSE                   // family and education
    gen BSP    = BSPPEN + BSFAM + BSU + BSX
    gen BSN    = BSF + BSE + BSU + BSX   // non-pension	
	browse BS BSP BPSOCfc
	
  * Decompose taxes on benefits: public vs funded pensions
    gen TBSPEN = TBSPPEN * BSPEN / (BSPEN + BPSOCfc)    // taxes on PAYG pensions
    gen TBPPEN   = TBSPPEN * BPSOCfc / (BSPEN + BPSOCfc)   // taxes on funded pensions
    gen TBS    = TBSPPEN + TBSN                         // taxes on all benefits
    browse CNT2 YEAR TB TBSPPEN TBPPEN TBSPEN TBSN BSPPEN BSPEN BPSOCfc

  * Control the sums
	gen BSc1 = BSOA + BSS + BSF + BSU + BSX + BSD + BSE  //+ BPSOCfc // - TB
	gen BSc2 = BSPEN + BSFAM + BSU + BSX  //- TB
	browse CNT2 YEAR BS BSc1 BSc2 BSP 
	drop BSc*
	
  *****************************************
  * 1.4 and 1.5 Funded pensions and private transfers
  *****************************************

	gen BPPEN = BPSOCfc - TPSOCfc
	gen BPX = -TPX
	gen BPB = BPSOCnfc - TPSOCnfc + BPX + BROW
	browse BPSOCnfc TPSOCnfc BPX BROW
	

  *****************************************
  * 1.7 Private consumption
  *****************************************
	  
  * Merge private consumption by purpose
	sort CNT2 YEAR
    merge 1:1 CNT2 YEAR using ENTA_input_data/ENTA_input_datasets/consumption_hh_coicop
	drop if _merge==2
	drop _merge
	browse CNT2 YEAR C Cb CP00
	
	sort CNT2 YEAR
	gen CHE = CP10/CP00 * Cb
	gen CHH = CP06/CP00 * Cb
	gen CHR = CP042
	gen CHX = Cb - CHE - CHH - CHR

  * Sweden: no HBS data on private education consumption, so
  * ENTA_compilation1_esa.do folds CHE into CHX and publishes CHE as zero. The
  * aggregate does the same, so that the two sides agree; otherwise the
  * published CHE aggregate (about 540 mio EUR a year) would have no age profile
  * behind it and CHX could not be reconciled either.
  * CHE is 0.34-0.39% of CHX for Sweden, so CHX is barely affected; CHNR and
  * Cb are unchanged by construction, since the fold only moves money between
  * two of their components.
    replace CHX = CHX + CHE if CNT2=="SE"
    replace CHE = 0 if CNT2=="SE"
	gen CHNR = CHE + CHH + CHX
	
	gen YDCASH = YDb - CHR
	gen YDCASHmk = YD - CHR
	
	
  **************************************************
  * 1.8 Test disposable income: YD = C + S
  **************************************************
	  
  * At basic prices
  
    * YDb via ESA tax components
	  gen YDbc1 = YE + YM + YA - TYT - TYS - TA - TX - TPN + BS - TPSOC - TPX + BPSOC + BROW - TCON
	* YDb as sum of consumption and saving
	  gen YDbc2 = Cb + S
	* YDb with ENTA tax components
	  gen YDbc3 = Y - (TYE + TYM + TYA + TB) - TX + BS - TPSOC - TPX + BPSOC + BROW - TCON
	* YDb via ENTA tax components
	  gen YDbc4 = YE + YM + YA - TYEM - TYA - TB - TX + BS + BPB + BPPEN - TCON
	  gen YDbc5 = YEM + YA - T + BS + BPB + BPPEN
	  
	  capture drop B 
	  gen B = BS + BPB + BPPEN
	  //gen T = TYEM + TYA + TX + TCON + TB // TYE + TYM + TYP + TA + TX + TCON + TPN + TB
	  gen YDbc6 = Y - T + B
	  
	* Difference income and use
	  gen d_YDb = YDbc1 - YDbc2
	  
    * Test both tails: a one-sided test on r(max) would miss a gap that is
    * negative (a gap of exactly D8 went unseen that way).
    * Tolerance 10 mio EUR: ESA values are rounded to the million and the
    * identity sums about 15 of them, so gaps of 5-6 are rounding.
    summarize d_YDb, meanonly
    if max(abs(r(min)), abs(r(max))) > 10 {
      display as error "WARNING: Disposable income identity violated for households"
      list CNT2 YEAR d_YDb if abs(d_YDb) > 10 & !missing(d_YDb)
    }
	
	browse geo sector YDb YDbc1 YDbc2 YDbc3 YDbc4 YDbc5 YDbc6 d_YDb* TB* //if d_YDb>5
    order  geo sector YDb YDbc1 YDbc2 YDbc3 YDbc4 YDbc5 YDbc6 d_YDb* TB*
	  
	drop  YDbc* // YDc* d_YD*
   
  * Save data for NTA aggregates
    tempfile ntahh
    save `ntahh'
  

/*
  *******************************
  * Overview tables
  *******************************
  
  * reshape file into long format
    local vars "Y YEM YE YM YA YP YO"
    // local vars "T TYEM TYA TB TBSN TBSPEN TBPPEN TCON TX"
	// local vars "BS BSPEN BSFAM BSU BSH BSX"
	// local vars "BPPEN BPSOCfc TPSOCfc BPB BPSOCnfc TPSOCnfc BROW BPX"
    // local vars "YDb Cb CHE CHH CHX CHR S"
	
    percapita `vars'
	browse if CNT2=="LU" & YEAR==2023	

  */
  
	
  **************************************************
  * 1.9 Change household data into long format
  * (numbered 1.9, not 1.6, because it runs after 1.7/1.8 and depends on
  * their output - CHE/CHH/CHR/CHX/CHNR/YDCASH/YDCASHmk are all created in 1.7)
  **************************************************
  
  local inc "Y YEM YE YM YA YO YP YPr YPp" // YEME YEE YER
  //local taxesa "T TA TX TCON TPN" // TYLER TYLEE YN TYT TYS
  //local taxempl " TYER" // TYLER TYLEE (= TYT + TYS) TYE TYM TYEMSOC TYEMT
  local tax "T TYEM TYA TYP TB TBPPEN TBSPEN TBSN TBSPPEN TCON TX TXH TXNPISH TPN TA" // TYLER TYLEE (= TYT + TYS) TBSPP TA TYP TPN
  local ben "B BS BSP BSU BSX BSPEN BSPPEN BSN BSFAM" // BSD BSOA BSS BSE BSF
  local privt "BPPEN BPB BPX BROW TPSOCfc TPSOCnfc BPSOCnfc BPSOCfc D8"  // BPSOC  TPp TPr TROWp TROWr TPSOC TPX BSPBPSOC
  //local pubc "CG CGE CGH CGX " // details for education groups needed for calculating age-profiles
  * Household saving is SH throughout the project: the sector-generic
  * S from Aggr_ESA2010 is renamed here, before the reshape that turns variable
  * names into IND, so the Households rows of ENTA_aggregates carry SH. The
  * Corporations, Government and Total economy sections keep S - there SECTOR
  * disambiguates it, and adjustsec SC S Corporations / adjustsec SG S
  * Government look the aggregate up by that name.
    rename S SH
  local use "YDb Cb CHE CHH CHX CHR CHNR SH YDCASH YDCASHmk"
  local indic `inc' `tax' `ben' `privt' `pubc' `use'
  
  foreach ind of local indic {
  	replace `ind' = 0 if `ind'==.
  }
  
  collapse (sum) `indic', by (CNT2 YEAR)
  
  reshape_to_long `indic'
	
  //drop if VALAGGR==-1
  gen SECTOR = "Households"
	
	
  *******************************
  * Name variables
  *******************************
 
  gen INDICATOR = ""
  
  * Income
	replace INDICATOR = "1 Primary income (Y)" if IND=="Y" 
	replace INDICATOR = "1.1 Employment income (YEM)" if IND=="YEM" 
	replace INDICATOR = "1.1.1 Compensation of employees (YE)" if IND=="YE" 
	replace INDICATOR = "1.1.2 Mixed income (YM)" if IND=="YM" 
	replace INDICATOR = "1.2 Asset income (YA)" if IND=="YA" 
	replace INDICATOR = "1.2.1 Property income (YP)" if IND=="YP" 
	replace INDICATOR = "1.2.2 Operating surplus (YO)" if IND=="YO" 
	//replace INDICATOR = "1.4 Taxes on production" if IND=="TPNp" 
	
  * Taxes
	replace INDICATOR = "2 Taxes (T)" if IND=="T" 
	//replace INDICATOR = "2.1 Direct taxes (TD)" if IND=="TD" 
	replace INDICATOR = "2.1 Taxes on employment income (TYEM)" if IND=="TYEM" 	
	//replace INDICATOR = "2.1.1 Taxes on employment income (TYE)" if IND=="TYL" 	
	//replace INDICATOR = "2.1.2 Taxes on self-empl income (TYM)" if IND=="TYM" 	
	replace INDICATOR = "2.2 Taxes on assets and asset inc (TYA)" if IND=="TYA" 	
	//replace INDICATOR = "2.4 Taxes on stock of assets (TA)" if IND=="TA" 
	replace INDICATOR = "2.3 Taxes on income of non-employed (TB)" if IND=="TB" 	
	replace INDICATOR = "2.3.1 Taxes on pay-as-you-go pensions (TBSP)" if IND=="TBSP" 	
	replace INDICATOR = "2.3.2 Taxes on non-pension social beneftis (TBSN)" if IND=="TBSN" 
	replace INDICATOR = "2.3.3 Taxes on benefits, funded pensions (TBPPEN)" if IND=="TBPPEN" 	
	replace INDICATOR = "2.4 Taxes on consumption (TCON)" if IND=="TCON" 
	replace INDICATOR = "2.5 Other current transfers (TX)" if IND=="TX"
	replace INDICATOR = "2.5.1 Other current transfers, households (TXH)" if IND=="TXH"
	replace INDICATOR = "2.5.2 Other current transfers, NPISH (TXNPISH)" if IND=="TXNPISH" 

	
  * Public benefits
	replace INDICATOR = "3. Social benefits, cash (BS)" if IND=="BS" 
	replace INDICATOR = "3.1 Social benefits, pensions (BSPEN)" if IND=="BSPEN" 	
	replace INDICATOR = "3.2 Social benefits, family and children (BSFAM)" if IND=="BSFAM" 
	replace INDICATOR = "3.3 Social benefits, unemployment (BSU)" if IND=="BSU" 
	replace INDICATOR = "3.4 Social benefits, other social protection (BSX)" if IND=="BSX" 	
	
  * Mandatory pensions
	replace INDICATOR = "4 Funded pensions, rec less paid (BPPEN)" if IND=="BPPEN" 
	replace INDICATOR = "4.1 Funded pens, beneftis (BPSOCfc)" if IND=="BPSOCfc" 
	replace INDICATOR = "4.2 Funded pens, contributions (TPSOCfc)" if IND=="TPSOCfc" 
	* D8 is not part of any ENTA income, transfer or saving concept and is not
	* published (dropped in Section 7). The label only shows up in the internal
	* file, where D8 serves as the bridge S + D8 = ESA net saving B8N.
	replace INDICATOR = "Internal: Adjustment, pension entitlements (D8)" if IND=="D8"

  * Private transfers
	replace INDICATOR = "5 Private transfers, rec less paid (BP)" if IND=="BP" 
	replace INDICATOR = "5.1 Private transfers, rec less paid (BPB)" if IND=="BPB" 
	//replace INDICATOR = "5.1.1 Social contr, private (TPSOCnfc)" if IND=="TPSOCnfc" 
	//replace INDICATOR = "5.1.2 Social benefits, private (BPSOCnfc)" if IND=="BPSOCnfc" 
	//replace INDICATOR = "5.1.3 Other private transfers (BPX)" if IND=="BPX" 
	//replace INDICATOR = "5.1.4 Transfers from ROW (BROW)" if IND=="BROW" 

	
  * Balancing items; disposable income
	replace INDICATOR = "7 Disposable income (basic price) (YDb)" if IND=="YDb" 
    //replace INDICATOR = "7.1 Adjusted disposable income (incl health + educ in kind) (YDA)" if IND=="YDA" 
	
  * Consumption
    replace IND ="CH" if IND=="Cb"
	replace INDICATOR = "8 Private consumption (basic price) (CH)" if IND=="CH" 
	replace INDICATOR = "8.1 Private cons, education (CHE)" if IND=="CHE" 
	replace INDICATOR = "8.2 Private cons, health (CHH)" if IND=="CHH" 
	replace INDICATOR = "8.3 Private cons, imputed rent (CHR)" if IND=="CHR" 
	replace INDICATOR = "8.4 Private cons, other (CHX)" if IND=="CHX" 
	
  * 9. Saving
	replace INDICATOR = "9 Saving, households (SH)" if IND=="SH"
	
	tempfile hh
	save `hh'

	
	
********************************************************************************
* 2. Corporations
********************************************************************************
  
   use ENTA_input_data/ENTA_input_datasets/esa_aggregates, clear
    keep if sector=="S11" | sector=="S12"
	
	browse CNT2 YEAR sector TYT TA TX TPN
	gen T = TYT + TA + TX + TPN 
	
  * Adjustment for income taxes captured in taxes on production
	replace Y = Y - TTYERp
	replace T = T - TTYERp if sector=="S12"
    replace T = T - (TTYERp - TTYERrow) if sector=="S11"	
	replace BROW = BROW + TTYERrow if sector=="S11"
	
  /*
  * Why such high values of T relative to income for LU?
	browse YROW Y T TYT TA TX TPN S B8* if CNT2=="LU" & YEAR==2019
  */
  
  * Combine corporation sectors	
    local indic "Y T TPSOC TPSOCfc TPSOCnfc TPX BPSOC BPSOCfc BPSOCnfc BROW YD YDb S"
	//browse CNT2 YEAR sector `indic'
	collapse (sum) `indic', by (CNT2 YEAR)
	
  * Composite indicators
	gen BPPEN = BPSOCfc - TPSOCfc
	gen BPX = -TPX  
	gen BPB = BPSOCnfc - TPSOCnfc + BPX + BROW

  * Control if variables add up
	gen YDc1 = Y - T - TPSOC - TPX + BPSOC + BROW
	gen YDc3 = Y - T - TPSOC - TPX + BPSOCnfc + BPSOCfc + BROW
	gen YDc4 = Y - T + BPB + BPPEN
	gen YDc2 = S
    gen d_YD = YDc1 - YDc2	
	
    * Both tails, tolerance 10 mio EUR (rounding), as for households.
    summarize d_YD, meanonly
    if max(abs(r(min)), abs(r(max))) > 10 {
      display as error "WARNING: Disposable income identity violated for corporations"
      list CNT2 YEAR d_YD if abs(d_YD) > 10 & !missing(d_YD)
    }
	
	browse CNT2 YEAR YD YDc1 YDc2 YDc3 YDc4 Y T BPSOC BROW TPSOC
	order CNT2 YEAR YD YDc1 YDc2 YDc3 YDc4 Y T BPSOC BROW TPSOC
    drop YDc* d_YD
	 
  * Save data for NTA aggregates
	gen sector = "S11_S12"
	tempfile ntacorp
	save `ntacorp'
	
  /*
  *******************************
  * Overview tables
  *******************************
  
  * reshape file into long format
    local vars "Y T BPB TPSOCnfc BPSOCnfc BPX BROW BPPEN TPSOCfc BPSOCfc S TPSOC TPX YD"
    percapita `vars'
	browse if CNT2=="DE" & YEAR==2023
  */
  

  * Reshape into long format
  
    local indic "Y T BPPEN BPB BPX YD YDb S BPSOCfc TPSOCfc BPSOCnfc BROW TPSOCnfc TPX"
  
    reshape_to_long `indic'
	
	drop if VALAGGR==.
	gen SECTOR = "Corporations"
	
  * Variable names
	gen INDICATOR = ""	
	
	replace INDICATOR = "1 Primary income (Y)" if IND=="Y" & SECTOR=="Corporations"
	
	replace INDICATOR = "2 Taxes (T)" if IND=="T" & SECTOR=="Corporations"
	
	replace INDICATOR = "4 Net benefits, funded pensions (BPP)" if IND=="BPP" & SECTOR=="Corporations"
	replace INDICATOR = "4.1 Social contr, funded pensions (TPSOCfc)" if IND=="TPSOCfc" & SECTOR=="Corporations"
	replace INDICATOR = "4.2 Social beneftis, funded pensions (BPSOCfc)" if IND=="BPSOCfc" & SECTOR=="Corporations"
	
	replace INDICATOR = "5 Private transfers, net received (BPB)" if IND=="BPB" & SECTOR=="Corporations"

	replace INDICATOR = "7 Disposable income (YD)" if IND=="YD" & SECTOR=="Corporations"
	
	replace INDICATOR = "9 Saving (S)" if IND=="S" & SECTOR=="Corporations"
	
	tempfile corp
	save `corp'

	
	
********************************************************************************
* 3. Government
********************************************************************************
  
  * Load data
    use ENTA_input_data/ENTA_input_datasets/esa_aggregates, clear
    keep if sector=="S13"
	
	sort CNT2 YEAR
	merge 1:1 CNT2 YEAR using ENTA_input_data\ENTA_input_datasets/taxstructure_wide
	drop if _merge!=3
	drop _merge
	
  * Adjust for taxes on production paid on behalf of employees
    browse CNT2 YEAR Y TYT TYS TTYER* BROW
	replace Y = Y - TTYERp //   // + TTYERr
	replace TYS = TYS - TTYERhh //  
	replace TPN = TPN + TTYERrow - TTYERp + TTYERhh //   // 
	replace BROW = BROW + TTYERrow 

  * Total direct taxes & social benefits 
	//gen TD = TYT + TYS + TA + TX + TPN 
	gen T = TYT + TYS + TA + TX + TPN + TCON
	
	local taxes "T TYT TYS TA TX TPN TCON B BS BROW"
	foreach t of local taxes {
		replace `t' = -`t'
	}
	gen TROW = -BROW
	
  * Public consumption
  
	sort CNT2 YEAR
	merge 1:1 CNT2 YEAR using ENTA_input_data\ENTA_input_datasets/gov_expenditure
	drop if _merge!=3
	drop _merge
	
	browse CNT2 YEAR CGEPP CGESEC CGEPSEC
	replace CGEPSEC = 0 if (CGEPSEC==. | CGEPSEC<0) & CGESEC!=. // for Bulgaria CGEPSEC is missing

  * Impute SK 2008/2009 public consumption by function: SK has no COFOG
  * breakdown before 2010 (gov_expenditure.dta only carries SK's 2010 row
  * back as a raw placeholder for 2008/2009 - see Suppl_gov_expenditure.do).
  * Unlike the BS benefit categories above, there is no separate ESA
  * aggregate here to rescale against afterwards, so assume each category's
  * share relative to total consumption (Cb) is the same as in 2010, and
  * scale explicitly by SK's actual Cb for 2008 and 2009.
    local cg_vars "CGE CGH CGEPP CGESEC CGEPSEC CGETER"
    qui sum Cb if CNT2=="SK" & YEAR==2010
    local sk2010_cb = r(mean)
    foreach v of local cg_vars {
        qui sum `v' if CNT2=="SK" & YEAR==2010
        local sh_`v' = r(mean) / `sk2010_cb'
        replace `v' = `sh_`v'' * Cb if CNT2=="SK" & inlist(YEAR,2008,2009)
    }

  * Secondary plus post-secondary non-tertiary education, the aggregate that
  * the CGES profile (enrollment ISCED 2-4, ENTA_compilation1_esa.do) is scaled
  * to. gov_expenditure has no CGES, and Stata would abbreviate `CGES' to
  * CGESEC and leave CGEPSEC out of the profile CGE, so it is built explicitly.
	gen CGES = CGESEC + CGEPSEC

	gen CGX = Cb - CGE - CGH
	gen CGHX = CGH - CGHIN - CGHOUT
	gen CGEX = CGE - CGEPP - CGESEC - CGEPSEC - CGETER
	
  * Control if variables add up
	  gen YDc1 = Y + T - BS + TROW
	  browse CNT2 YEAR YDc1 Y TYT TA TX BS TROW TCON Cb S
	  gen YDc2 = Cb + S
	  
	  gen d_YDc1 = YDb - YDc1
	  gen d_YDc2 = YDb - YDc2
	  browse CNT2 YEAR YDb YDc1 YDc2 d_YDc* C Cb
      drop YDc* d_YD*
	  
  * Save data for NTA aggregates
	tempfile ntagov
	save `ntagov'
	
  /*
 *******************************
  * Overview tables
  *******************************
  
  * reshape file into long format
    local vars "Y T BS BROW Cb CGE CGH CGX S YDb"
    percapita `vars'
	browse if CNT2=="DE" & YEAR==2023
  */
  
  *******************************
  * From wide to long format
  *******************************
  
    local indic "Y T TYT TA TX BS BROW TROW YD YDb TCON C CGE CGEX CGEPP CGESEC CGES CGEPSEC CGETER CGH CGHOUT CGHIN CGHX CGX S" // CGEPRE CGEPRI
	browse CNT2 YEAR sector Y T BS BROW
  
	// collapse (sum) `indic', by (CNT2 YEAR)
	keep CNT2 YEAR `indic'
	
	reshape_to_long `indic'
	
	drop if VALAGGR==.
	gen SECTOR = "Government"
	
	
  *******************************
  * Variable names
  *******************************
  
	gen INDICATOR = ""	
	replace INDICATOR = "1 Primary income (Y)" if IND=="Y" 
	replace INDICATOR = "2 Taxes received (T)" if IND=="T"  
	replace INDICATOR = "2.6 Government to ROW transfers (TROW)" if IND=="TROW"
	//replace INDICATOR = "2.1 Direct taxes received (TD)" if IND=="TD" 
	//replace INDICATOR = "2.2 Consumption taxes received (TCON)" if IND=="TCON" 
	//replace INDICATOR = "2.3 Net primary income (YN)" if IND=="YN" 
	//replace INDICATOR = "3 Benefits paid (B)" if IND=="B" 
	replace INDICATOR = "3 Social benefits paid (BS)" if IND=="BS" 
	replace INDICATOR = "6 Disposable income (YDb)" if IND=="YDb" 
	replace INDICATOR = "7 Consumption (C)" if IND=="C"
	replace INDICATOR = "7.1 Consumption (CGE)" if IND=="CGE"
	replace INDICATOR = "7.2 Consumption (CGH)" if IND=="CGH"
	replace INDICATOR = "7.3 Consumption (CGX)" if IND=="CGX"
	replace INDICATOR = "9 Saving (S)" if IND=="S" 
	tempfile gov
	save `gov'
	
	
********************************************************************************
* 4. Total economy
********************************************************************************

  * Variable
    * GDP 
	* - YLROW
	* - YPROW
	* - CFC
	* - TPSp
	* = Y
	* + BROW (All type of transfers from ROW less transfers paid to ROW)
	* = YD
	* - C
	* = S
  
  * Load and prepare data
    use ENTA_input_data\ENTA_input_datasets/esa_aggregates, clear
    keep if sector=="S1"
  
  * Generate aggregates 
	
	collapse (sum) GDP YEROW YPROW CFC TPSp TPSr TPNr TPNp Y YE BROW TYT TA TX TCON BS YD YDb Cb S B1Nr B5Np D8 TTYERrow, by(YEAR CNT2)
	browse YEAR CNT2 TPSp TPSr B1Nr Y
	
  * Compare ENTA aggregates and ESA aggregates of income
	gen Yc = GDP - CFC + YEROW + YPROW - TPSp // NONY = CFC + TPSp + YROW
	gen Yc1 = B5Np - TPSr - TPNr + TPNp // D8 is not part of Y
	sort CNT2 YEAR
	gen DY = Y - Yc
	gen DTPS = TPSr - TPSp
	browse CNT2 YEAR Y Yc Yc1 DY DTPS D8 TTYER*
	
  * Test if generation of income and use-based disposable income are equal
	gen YDc1 = Y + BROW // Y = YL + YO + YM + YP + TPNp
	gen YDc2 = Cb + S
	sort CNT2 YEAR
	browse YEAR CNT2 Y Yc Yc1 YD YDb YDc1 YDc2 B1N
    order YEAR CNT2 Y Yc Yc1 YD YDb YDc1 YDc2 B1N
  
	drop Yc* YDc*
	
  * Save data input for NTA aggregates
	gen sector="S1"
	tempfile ntatot
	save `ntatot'
	
  /*	
 *******************************
  * Overview tables
  *******************************
  
  * reshape file into long format
    local vars "GDP CFC YEROW YPROW TPSp Y BROW Cb S"
    percapita `vars'
	browse if CNT2=="DE" & YEAR==2023
	browse if CNT2=="IE" & YEAR==2023
	browse if CNT2=="LU" & YEAR==2023
  */	
  
  * Change into long format
    local indic "GDP YE YEROW YPROW CFC TPSp Y BROW YDb Cb S"
    
	reshape_to_long `indic'

	drop if VALAGGR==.
	gen SECTOR = "Total economy"
	
	
  * Long name for variables
    gen INDICATOR = ""	
	replace INDICATOR = "0 GDP" if IND=="GDP" & SECTOR=="Total economy"
	//replace INDICATOR = "0 Non-income components of GDP (NONY)" if IND=="NONY" & SECTOR=="Total economy"	
	replace INDICATOR = "0.1 Net labour income recieved from ROW (YEROW)" if IND=="YEROW" & SECTOR=="Total economy"	
	replace INDICATOR = "0.2 Net property income received from ROW (YPROW)" if IND=="YPROW" & SECTOR=="Total economy"	
	replace INDICATOR = "0.3 Consumption of fixed capital (CFC)" if IND=="CFC" & SECTOR=="Total economy"	
	replace INDICATOR = "0.4 Taxes less subs on products" if IND=="TPSp" & SECTOR=="Total economy"	
	replace INDICATOR = "1 Primary income (Y)" if IND=="Y" & SECTOR=="Total economy"	
	replace INDICATOR = "5 Net transfers from ROW (BROW)" if IND=="BROW" & SECTOR=="Total economy"	
	replace INDICATOR = "7 Disposable income (basic price) (YDb)" if IND=="YDb" & SECTOR=="Total economy"	
	replace INDICATOR = "8 Consumption (C)" if IND=="Cb" & SECTOR=="Total economy"	
	replace INDICATOR = "9 Saving (S)" if IND=="S" & SECTOR=="Total economy"
	
	tempfile total
	save `total'
	
	
********************************************************************************
* 5. NTA aggregates
********************************************************************************
	
  * Load data
    clear
    append using `ntagov'
    append using `ntahh'
    append using `ntacorp'
	append using `ntatot'
  
    gen SECTOR = "Households" if sector=="S14_S15"
	replace SECTOR = "Corporations" if sector=="S11_S12"
	replace SECTOR = "Government" if sector=="S13"
	replace SECTOR = "Total" if sector=="S1"	
	
  ****************************
  * 5.1 Income variables
  ****************************
  
* Initialize missing values to zero
  foreach v in YM YA {
    replace `v' = 0 if `v' == .
  }

* Labour income: wages + 2/3 of mixed income
  gen YLE = YE
  gen YLS = (2/3) * YM
  gen YL  = YLE + YLS

* Asset income by sector
  gen YAH = cond(SECTOR == "Households",   YA + (1/3) * YM, 0)
  gen YAC = cond(SECTOR == "Corporations", Y,               0)
  gen YAG = cond(SECTOR == "Government",   Y,               0)

* Overwrite YA with sector-specific values
  replace YA = YAH if SECTOR == "Households"
  replace YA = YAC if SECTOR == "Corporations"
  replace YA = YAG if SECTOR == "Government"

* Private sector asset income
  gen YAF = cond(SECTOR == "Households", YA, cond(SECTOR == "Corporations", Y, .))

* Sort and inspect
  sort  CNT2 YEAR SECTOR
  order CNT2 YEAR SECTOR Y YL YLE YLS YA YAH YAC YAG YAF
  browse CNT2 YEAR SECTOR Y YAF YAG YA
	 
	  /*
	  preserve
	  drop if SECTOR=="Total"
	  collapse (sum) Y YA YAH YAC YAG YL YLE YLS, by(CNT2 YEAR)
	  gen Yc1 = YA + YL
	  gen Yc2 = YL + YAH + YAC + YAG
	  browse CNT2 YEAR Y Yc1 Yc2
	  restore
      */
	
  ********************************
  * 5.2 Taxes
  ********************************

	
	gen TGOTYL =  TYEM - 1/3*TYM if SECTOR=="Households"
	gen TGOTYAH = TYA + 1/3*TYM if SECTOR=="Households"
	gen TGOTYAC = T if SECTOR=="Corporations"
	gen TGOTYA = TGOTYAH if SECTOR=="Households"
	  replace TGOTYA = TGOTYAC if SECTOR=="Corporations"
	gen TGOTCON =  TCON if SECTOR=="Households"
	gen TGOTB = TB if SECTOR=="Households"
	gen TGOTBSN = TBSN if SECTOR=="Households"
	gen TGOTBSPEN = TBSPEN if SECTOR=="Households"
	gen TGOTBPPEN = TBPPEN if SECTOR=="Households"
	gen TGOTX = TX if SECTOR=="Households"
	
  * Additional information
	gen TGOTSOC = TYS if SECTOR=="Households"
	gen TGOTY = TYT if SECTOR=="Households"
	
  * Control the data
	gen Tcesa = TYT + TYS + TA + TX + TPN + TCON if SECTOR=="Households" 
	  replace Tcesa = T if SECTOR=="Corporations"
	gen Tg = -T  if SECTOR=="Government" // + TBadj
	gen TGOT = TGOTYL + TGOTYA + TGOTCON + TGOTB + TGOTX if SECTOR=="Households" 
	  replace TGOT = TGOTYA if SECTOR=="Corporations"
	browse T Tcesa Tg TGOT 
	
	//replace TYS = 0 if SECTOR!="Households"
	//replace TYT = 0 if SECTOR!="Households"
	
	/*
	drop if SECTOR=="Total"
	collapse (sum) T Tcesa Tg TGOT TGOTYL TGOTYA TGOTYAH TGOTYAC TGOTB TGOTCON TGOTX, by(YEAR CNT2)
	gen TGOTc1 = TGOTYL + TGOTYAH + TGOTB + TGOTCON + TGOTX + TGOTYAC
	browse CNT2 YEAR TGOT TGOTc1
	sort CNT2 YEAR
	*/
	
  ******************************************
  * 5.3 Public benefits
  ******************************************
 
	//gen TGI = BS + CG if SECTOR=="Households" 
	gen TGIC = BS if SECTOR=="Households" 
	gen TGICF = BSFAM if SECTOR=="Households" 
	gen TGICU = BSU if SECTOR=="Households" 
	gen TGICPEN = BSPEN if SECTOR=="Households" 
	gen TGICX = BSX if SECTOR=="Households"  
	gen TGICg = -BS  if SECTOR=="Government"  // + TBadj
	
	/*
	preserve
	collapse (sum) TGIC TGICg TGICF TGICU TGICPEN TGICX , by(YEAR CNT2)
	gen TGICc1 = TGICU + TGICF + TGICPEN + TGICX
	browse TGIC TGICg TGICc1
	restore
	*/
	
	gen TGNF = -BROW if SECTOR=="Government" 
	
  ***********************************************
  * 5.4 Funded pensions
  ***********************************************
	
	gen TFP = BPSOCfc-TPSOCfc if SECTOR=="Households" | SECTOR=="Corporations" 
	gen TFPI = BPSOCfc if SECTOR=="Households" 
	gen TFPO = TPSOCfc if SECTOR=="Households" 
	gen TFPH = BPSOCfc-TPSOCfc if SECTOR=="Households" 
	gen TFPC = BPSOCfc-TPSOCfc if SECTOR=="Corporations" 

	
  ***********************************************
  * 5.5 Private transfers
  ***********************************************
	
	gen TFB = BPSOCnfc + BROW - TPSOCnfc - TPX if SECTOR=="Households" 
	replace TFB = BPSOCnfc + BROW - TPSOCnfc - TPX if SECTOR=="Corporations" 
	gen TFBH = TFB if SECTOR=="Households"
	gen TFBC = TFB if SECTOR=="Corporations"
	
	browse TFB TFP D8 BPB BPP
	

  *************************************************
  * 5.5 Disposable income 
  *************************************************
	
	replace YD = YDb if SECTOR=="Households" | SECTOR=="Corporations" | SECTOR=="Government"
	gen YDF = YDb if SECTOR=="Households" | SECTOR=="Corporations"
	gen YDG = YDb if SECTOR=="Government"
	gen YDH = YDb if SECTOR=="Households"
	gen YDHA = YDb if SECTOR=="Households"
	  replace YDHA = Cb if SECTOR=="Government"
	  capture drop YDC // corporate disposable income; the household cash concept is YDCASH
	gen YDC = YDb if SECTOR=="Corporations"

	/*
	* Test data
	drop if SECTOR=="Total"
	collapse (sum) Y YL YA YAF YAG YDF YDG TGOT TGIC TGNF TFP TFB YD, by(CNT2 YEAR)
	gen YDc1 = Y + TGNF + TFP + TFB 
	gen YDFc1 = YL + YAF - TGOT + TGIC + TFB 
	gen YDGc1 = YAG + TGOT - TGIC + TGNF 

	browse CNT2 YEAR YD YDc1 YDF YDFc1 YDG YDGc1 TGNF
	order CNT2 YEAR YD YDc1 YDF YDFc1 YDG YDGc1
	sort CNT2 YEAR
    */
	

  *********************************************
  * 5.6 Consumption and saving
  *********************************************
  
	replace C = Cb if SECTOR=="Households" | SECTOR=="Government" 
	gen CF = Cb if SECTOR=="Households"
	gen CFE = CHE if SECTOR=="Households" 
	gen CFH = CHH if SECTOR=="Households" 
	gen CFR = CHR if SECTOR=="Households" 
	gen CFX = CHX if SECTOR=="Households" 
	gen CG = Cb if SECTOR=="Government" 
	replace CGE = 0 if SECTOR!="Government"
	replace CGH = 0 if SECTOR!="Government"
	replace CGX = 0 if SECTOR!="Government"
	//replace CGS = 0 if SECTOR!="Government"

	// replace S = . if SECTOR!="Households" & SECTOR!="Corporations" & SECTOR!="Government" 
	//browse YEAR CNT2 sector S SF SC BPSOCfc TPSOCfc
	gen SF = S if SECTOR=="Households" | SECTOR=="Corporations" 
	//replace SF = S + TPSOCfc - BPSOCfc if SECTOR=="Corporations" 
	gen SH = S if SECTOR=="Households" 
	gen SC = S if SECTOR=="Corporations" // + TPSOCfc - BPSOCfc 
	gen SG = S if SECTOR=="Government"	
	

  * NTA indicators
    local inc "Y YL YLE YLS YA YAH YAC YAG YAF" // YKFC YKFH
	local tax "TGOT TGOTYL TGOTYA TGOTYAH TGOTYAC TGOTCON TGOTB TGOTBSPEN TGOTBSN TGOTBPPEN TGOTX Tg TGOTSOC TGOTY TYS TYT"
	local ben "TGIC TGICg TGICF TGICU TGICPEN  TGICX TGNF TFB TFBH TFBC TFP TFPO TFPI" 
	local use "YD YDF YDH YDC YDHA C CF CFE CFH CFR CFX CG CGE CGH CGX S SF SH SC SG"
  	local indic `inc' `tax' `ben' `use' 
	browse YEAR SECTOR CNT2 `indic'

	foreach var of local indic {
	  replace `var' = 0 if `var'==.
	}

  
  ***********************************************
  * 5.7 Generate NTA aggregates, control the data
  ***********************************************
  
  * Test if flow equation is fulfilled at sector level
  
	browse CNT2 YEAR SECTOR Y YL YAH YAC YA T TGOT BS TGIC TFP BPP TFB BPB TGNF CF Cb CG SG S SF
	order CNT2 YEAR SECTOR Y YL YAH YAC YA T TGOT BS TGIC TFP BPP TFB BPB TGNF CF Cb CG SG S SF
	
	gen YDntac1 = YL + YAH - TGOT + TGIC + TFB + TFP if SECTOR=="Households" 
    replace YDntac1 = YAC - TGOT + TFB + TFP if  SECTOR=="Corporations" // 
	replace YDntac1 = YAG - Tg + TGICg + TGNF if SECTOR=="Government"
	
	gen YDntac2 = CG + SG if SECTOR=="Government"
	replace YDntac2 = CF + SF  if SECTOR=="Households" | SECTOR=="Corporations"
	
	gen D_YD = YDntac1 - YDntac2 
	browse CNT2 YEAR SECTOR YD YDntac1 YDntac2 TGNF D_YD TB TFP
	order CNT2 YEAR SECTOR YD YDntac1 YDntac2 TGNF D_YD TB  TFP
	

  * Generate NTA aggregates
  
    //browse CNT2 YEAR SECTOR YL YAH YAC YAG TGOT Tg TGIC TGICg TGNF TFB TFP CF SF CG SG // S
    sort CNT2 YEAR SECTOR
	drop if SECTOR=="Total"
    //browse CNT2 YEAR SECTOR YL YA TGO TGOg TGSI TGSIg TGNF TFB YDntac1 YDntac2
	collapse (sum) `indic' YDntac*, by(CNT2 YEAR)
	
  * Test if flow equation is fulfilled in total

	gen YDc1 = YL + YAH + YAC + YAG + TGNF + TFB
    gen YDc2 = CF + SF + CG + SG
	browse CNT2 YEAR YDc1 YDc2 YDntac*
	
	gen TGI = TGIC + CG

  
  ************************************
  * 5.9 Save NTA data in long format
  ************************************
	
  reshape_to_long `indic'
  
	drop if VALAGGR==.
	gen SECTOR = "NTA Aggregates"
	
	replace VALAGGR = . if VALAGGR==0
	
	* Generate idicator names
	
	gen INDICATOR = ""
	
	replace INDICATOR = "1 Primary income (Y)" if IND=="Y" 
	  replace INDICATOR = "1.1 Labour income (YL)" if IND=="YL" 
	  //replace INDICATOR = "1.1.1 Labour income, employees (YLE)" if IND=="YLE" 
	  //replace INDICATOR = "1.1.2 Labour income, selfemployed (YLS)" if IND=="YLS" 
	  replace INDICATOR = "1.2 Asset income, private (YAF)" if IND=="YAF" 
	  replace INDICATOR = "1.2.1 Asset inc, households (YAH)" if IND=="YAH" 
	  replace INDICATOR = "1.2.2 Asset inc, corp (YAC)" if IND=="YAC" 
	  //replace INDICATOR = "1.3.2 Asset income, corporations (YKFC)" if IND=="YKFC" 
	  replace INDICATOR = "1.3 Asset income, government (YAG)" if IND=="YAG" 
	  
	replace INDICATOR = "2 Taxes (TGOT)" if IND=="TGOT" 
	//replace INDICATOR = "2.1 Taxes on labour income (TGOTYL)" if IND=="TGOTYL" 
	//replace INDICATOR = "2.2 Taxes on self-empl income (TGOTYLS)" if IND=="TGOTYLS"
	//replace INDICATOR = "2.2 Taxes on asset income (TGOTYA)" if IND=="TGOTYA" 
	//replace INDICATOR = "2.2.1 Taxes on asset inc, househ (TGOTYAH)" if IND=="TGOTYAH" 
	//replace INDICATOR = "2.2.2 Taxes on asset inc, corp (TGOTYAC)" if IND=="TGOTYAC" 
	//replace INDICATOR = "2.3 Taxes on social benefits (TGOTB)" if IND=="TGOTB" 
	//replace INDICATOR = "2.4.1 Taxes, gov pens (TGOTBGP)" if IND=="TGOTBGP" 
	//replace INDICATOR = "2.4.2 Taxes, non-pens ben (TGOTBNP)" if IND=="TGOTBNP" 
	//replace INDICATOR = "2.4.3 Taxes, private pens (TGOTBPP)" if IND=="TGOTBPP" 
	//replace INDICATOR = "2.4 Taxes on consumption (TGOTCON)" if IND=="TGOTCON"
	//replace INDICATOR = "2.5 Other current transfers (TGOTX)" if IND=="TGOTX" 
	
	//replace INDICATOR = "2.a Social contributions (TGOTSOC)" if IND=="TGOTSOC"
	//replace INDICATOR = "2.b Taxes on income (TGOTY)" if IND=="TGOTY" 
	// replace INDICATOR = "A.3 Social contr, empl + mixed  (TYEMSOC)" if IND=="TYEMSOC"
	// replace INDICATOR = "A.4 Taxes on income, empl + mixed (TYLMT)" if IND=="TYLMT" 

    replace INDICATOR = "3 Public transfers, inflows in cash (TGIC)" if IND=="TGIC" 
	replace INDICATOR = "3.1 Public trans, pensions (TGICPEN)" if IND=="TGICPEN" 
	// replace INDICATOR = "3.1.1 Social benefits, old age (TGICOA)" if IND=="TGICOA" 
	// replace INDICATOR = "3.1.2 Social benefits, survivor (TGICS)" if IND=="TGICS" 
	// replace INDICATOR = "3.1.3 Social benefits, disability (TGICD)" if IND=="TGICD" 
	replace INDICATOR = "3.2 Public trans, family (TGICF)" if IND=="TGICF" 
	replace INDICATOR = "3.3 Public trans, unempl (TGICU)" if IND=="TGICU" 
	replace INDICATOR = "3.4 Public trans, other" if IND=="TGICX" 
	// replace INDICATOR = "3.5 Taxes on social benefits (TB)" if IND=="TB" 	
	replace INDICATOR = "3.5 Public trans, net from ROW (TGNF)" if IND=="TGNF" 
	
	replace INDICATOR = "4 Funded pensions (rec less paid)" if IND=="TFP" 
	replace INDICATOR = "4.2 Funded pensions, benefits" if IND=="TFPI"	
	replace INDICATOR = "4.1 Funded pensions, contributions" if IND=="TFPO" 

	//replace INDICATOR = "4.1 Funded pensions, contributions" if IND=="TFPH" 
	//replace INDICATOR = "4.2 Funded pensions, beneftis" if IND=="TFPC"	

	replace INDICATOR = "5.1 Private transfers, betw hh" if IND=="TFB" 
	//replace INDICATOR = "5 Private transfers, hh" if IND=="TFBH" 
	//replace INDICATOR = "5 Private transfers, corp" if IND=="TFBC" 
	// replace INDICATOR = "5.1 Net private transfers from ROW (TFB)" if IND=="TFB" 
	
	//replace INDICATOR = "5.1 Private transfers between HH, net received (TFB)" if IND=="TFB" 
	// replace INDICATOR = "5.2 Private transfers between HH, paid (TFBO)" if IND=="TFBO"
	// replace INDICATOR = "5.3 Private transfers between HH, received (TFBI)" if IND=="TFBI"
	
	replace INDICATOR = "7 Disposable income" if IND=="YD"
	//replace INDICATOR = "7.0 Disposable income, private" if IND=="YDF"
	//replace INDICATOR = "7.1 Disposable inc, househ" if IND=="YDH"
	//replace INDICATOR = "7.2 Disposable inc, corp" if IND=="YDC"
	//replace INDICATOR = "7.3 Adjusted disp income, hh (incl. public trans, YDHA)" if IND=="YDHA"
	//replace INDICATOR = "7.4 Government transfer inflow, total (TGI)" if IND=="TGI"
	
	replace INDICATOR = "6 Public consumption (CG)" if IND=="CG"
	replace INDICATOR = "6.1 Public consumption, education (CGE)" if IND=="CGE"
	replace INDICATOR = "6.2 Public consumption, health (CGH)" if IND=="CGH"
	replace INDICATOR = "6.3 Public consumption, other (CGX)" if IND=="CGX"
	
	replace INDICATOR = "8 Private consumption (CF)" if IND=="CF"
	//replace INDICATOR = "8.1 Private cons, education (CFE)" if IND=="CFE"
	//replace INDICATOR = "8.2 Private cons, health (CFH)" if IND=="CFH"
	//replace INDICATOR = "8.3 Private cons, imputed rent (CFR)" if IND=="CFR"
	//replace INDICATOR = "8.4 Private cons, other (CFX)" if IND=="CFX"

	replace INDICATOR = "9 Saving (S)" if IND=="S"
	replace INDICATOR = "9.1 Saving, private (SF)" if IND=="SF"
	replace INDICATOR = "9.2 Saving, private, households (SH)" if IND=="SH"
	replace INDICATOR = "9.3 Saving, private, corporations (SC)" if IND=="SC"
	replace INDICATOR = "9.4 Saving, public (SG)" if IND=="SG"

	sort INDICATOR
	tempfile nta
	save `nta'


********************************************************************************
* 6. Prepare total aggregate data 
********************************************************************************

  clear
  append using `hh'
  append using `corp'
  append using `total'
  append using `nta'
  append using `gov'
	
  do ENTA_input_data/PROG_gen_country_name_from_CNT2.do
  sort CNT2 YEAR SECTOR IND

  
  * Suppress the benefit-tax decomposition wherever the microdata behind it
  * does not exist. TB itself comes from DG TAXUD and runs from 1995; its
  * pension/non-pension split is TB x TBSPPENsh, and that share comes from
  * EUROMOD via inctax_nonempl_decomp. Where the share is absent the
  * multiplication yields missing and the blanket zero-fill above (line 384)
  * turns it into a zero, so the published file asserted a split that was
  * never measured.
  *
  * The rule applies to every country. The EUROMOD share starts in 2005-2007
  * (AT and DE 2007, BE/CZ/EE/EL/ES/HU/IT/LT/PL 2005, the rest 2006; HR 2009
  * after the carry-back in Micro_EUROMOD.do), while TBSN and TBPPEN are
  * published from 1995 for all countries - as zeros, e.g. 4,025 mio EUR of tax
  * on benefits in Austria in 1995 of which zero on pensions and zero on
  * non-pensions. A split with no microdata behind it is not published: TB
  * alone is.
  *
  * Driven by the share file rather than hard-coded years, so it follows
  * EUROMOD coverage automatically instead of going stale - and so the
  * Croatian 2009-2010 carry-back is picked up without a special case.
    merge m:1 CNT2 YEAR using ENTA_input_data\ENTA_input_datasets/inctax_nonempl_decomp, ///
        keepusing(TBSPPENsh) keep(master match) nogen
    foreach var in TBSPPEN TBSN TBSPEN TBPPEN {
      replace VALAGGR = . if missing(TBSPPENsh) & IND=="`var'"
    }
    drop TBSPPENsh

  *******************
  * Save nominal data
  *******************
  * INTERNAL file, deliberately saved BEFORE the cleaning in Section 7.
  * adjustaggr/adjust (ENTA_setup.do), ENTA_units.do, the
  * diagnostic scan and ENTA_generate_manual_tables.do all read this file, so
  * it is kept complete: every indicator has a value to scale to, including
  * years and countries (NO, IS, UK, RS, CH) the published files leave out.
  * The published files saved in Section 7 blank out unreliable values instead,
  * so users see honest gaps. The two files therefore differ on purpose.
  * RULE: any restriction that must reach the age profiles goes ABOVE this
  * save (as the Croatia rule just above does). Section 7 changes only the
  * published output - a rule placed there is silently ignored by `adjust`.
  save ENTA_aggregates/ENTA_aggregates, replace


********************************************************************************
* 7. Clean missing data and save for different purposes
********************************************************************************
* Continues directly on the dataset just saved above.
* Everything below affects the PUBLISHED files only, never the internal
* ENTA_aggregates/ENTA_aggregates.dta - see the note at the save above.

  * D8 is internal only. It is not part of any ENTA concept; it is kept in the
  * internal file so ENTA saving can be reconciled with ESA net saving
  * (S + D8 = B8N), but it is not published.
    drop if IND=="D8"

  * Set missing data to missing: aggregates that are 0 only because their
  * source has not started yet are published as missing, not as 0.
  *
  * The COFOG benefit breakdown (BSOA BSD BSS BSF BSE, hence BSPEN BSFAM BSU
  * BSX) is zero-filled in Section 6 wherever gov_expenditure has no row, so
  * without this the published file would assert e.g. Belgian social benefits
  * of 34,060 mio EUR in 1995 of which zero pensions, while BSPEN is 69% of BS
  * in the first year it exists. BS itself is ESA and is present throughout, so
  * only the breakdown is suppressed: publish the total and not a split that has
  * no data behind it. The bounds are per country because each source starts in
  * a different year (FI's BSFAM/BSU/BSX are 0 in 2000 and material in 2001,
  * hence <=2000; PT, SK and the BG 2002 interior hole need their own rules).
  *
  * NOT TOUCHED - true zeros: funded pensions before the second pillar started
  * (BPPEN/BPSOCfc/TPSOCfc, EE LV to 1999, BG to 2002, LT to 2003/04, RO to
  * 2007) are correct as 0. Measurements: bug report #260.
    local vars "BSPEN BSFAM BSU BSOA BSX"
    foreach var of local vars {
        replace VALAGGR=. if YEAR<=2000 & inlist(CNT2,"BE","EL","FI","IT","LV","PL","RO","SE") & IND=="`var'"
        replace VALAGGR=. if YEAR<2000  & inlist(CNT2,"DE","LT")                               & IND=="`var'"
        replace VALAGGR=. if YEAR<1999  & CNT2=="PT"                                           & IND=="`var'"
        replace VALAGGR=. if YEAR<2008  & CNT2=="SK"                                           & IND=="`var'"
        replace VALAGGR=. if YEAR==2002 & CNT2=="BG"                                           & IND=="`var'"
    }

  * TXNPISH is zero until the source's NPISH sector split starts: IE to 2009,
  * DE to 2011. Every other country reports it from 1995.
    replace VALAGGR=. if YEAR<=2009 & CNT2=="IE" & IND=="TXNPISH"
    replace VALAGGR=. if YEAR<=2011 & CNT2=="DE" & IND=="TXNPISH"

  * The benefit-tax split is also unmeasured where the EUROMOD share exists but
  * is ZERO. Micro_EUROMOD.do sets TBSPPENsh = 0 when TBSPPEN + TBSN == 0, i.e.
  * when the country-year has no decomposition at all, so the missing() test in
  * Section 6 does not catch it and the file would publish TBSN == TB to the
  * euro with TBPPEN == 0. That is every country's first one or two years of
  * EUROMOD coverage: 2005-06 for BE CZ EE EL ES HU IT LT PL, 2006 for CY FR IE
  * LV NL PT SE SI SK.
  * GUARDED ON TB != 0. Bulgaria's TB is zero for the whole 1995-2022 span, but
  * that is a REPORTED zero: BG has 90 LNON rows in taxud_tax_ec_func_en.csv,
  * the same count as AT, all of them 0. Without the guard this rule would
  * blank honest zeros.
    merge m:1 CNT2 YEAR using ENTA_input_data\ENTA_input_datasets/inctax_nonempl_decomp, ///
        keepusing(TBSPPENsh) keep(master match) nogen
    gen byte nosplit = (TBSPPENsh==0 & !missing(TBSPPENsh))
    bysort CNT2 YEAR: egen byte TBzero = max(IND=="TB" & VALAGGR==0)
    foreach var in TBSN TBPPEN {
        replace VALAGGR = . if nosplit & !TBzero & IND=="`var'"
    }
    drop TBSPPENsh nosplit TBzero

  * Unit conversion (per capita, real HICP, PPS, %GDP, %primary income, NTA/
  * ENTA norm, etc.) is not computed here - the ENTA dataexplorer does it on
  * the fly from the raw VALAGGR (nominal aggregate total, million EUR, per
  * CNT2/YEAR/SECTOR/IND) saved below, combined with the conversion factors
  * in ENTA_units (built by ENTA_units.do, published with the norms by
  * ENTA_compilation1_esa.do).
  /*
  * Add supplementary data on population, prices, ppps, exchange rate....

    sort CNT2 YEAR
    merge m:1 CNT2 YEAR using ENTA_input_data\ENTA_input_datasets/population0t, update
	drop AGE
    drop if _merge==2
    drop _merge

    sort CNT2 YEAR
    merge m:1 CNT2 YEAR using ENTA_aggregates/ENTA_units
	keep if _merge==3
    drop _merge

  * Calculate aggregatvalues in different units

    gen VALAGGRn = VALAGGR / 1000  // in billion Euro
    replace VALAGGR = VALAGGR * 1000000 * 1/POP // p.c. in Euro
    gen VALAGGRrh = VALAGGR * EXR_NAC_EUR * 1/HICP*100 * 1/EXR_2020
	gen VALAGGRpp = VALAGGR * PPP_EUR // purchasing power, current prices
	gen VALAGGRrpp = VALAGGRrh * PPP_EUR_2020 // purchasing power 2020 prices

    gen VALAGGRgdp = VALAGGRn*1000/GDP*100 // percent of GDP
    gen VALAGGRy = VALAGGRn*1000/Y*100 // percent of primary income
    gen VALAGGRyh = VALAGGR*1000/YH*100 // percent of primary income of households
  */

    sort CNT2 YEAR SECTOR IND
    drop if VALAGGR==.


  ********************************************
  * Save data for different purposes
  ********************************************

    keep CNT2 YEAR SECTOR IND INDICATOR COUNTRY VALAGGR

  * Year cutoff for the PUBLISHED aggregates: 2024. The internal file carries
  * the same 52 household indicators in 2024 as in 2023, for every country that
  * has 2023 and all five sectors. HICP and population also reach 2024, so
  * nominal, real, per-capita and %GDP all work for it.
  * The age profiles end in 2023 (EU-SILC income reference 2023), so
  * the NTA/ENTA norms (built from the income profile in ENTA_compilation1_esa.do,
  * Section 5) are missing for 2024 by construction. The unit choices built from
  * aggregates (HICP, exchange rates, Y, YH, GDP, POPtot) are not. That is intended:
  * 2024 is an aggregate-only year.
    keep if YEAR<=2024
    drop if COUNTRY==""
    drop if CNT2=="UK" | CNT2=="RS" | CNT2=="CH" | CNT2=="NO" | CNT2=="IS"
    sort CNT2 YEAR SECTOR IND

   /*
   * Save for adjustment to aggregates
    save ENTA_aggregates/ENTA_aggregates_units, replace
  */

  * Save for dataexplorer - also the canonical CSV for external
  * publication (e.g. Zenodo): aggr_server.R derives its own indicator
  * ordering from the data (str_sort, numeric=TRUE), not from this file's
  * row order, so one comma-delimited file serves both purposes.
    drop if INDICATOR==""
    sort INDICATOR YEAR CNT2 SECTOR
    cap noi outsheet using ENTA_output_data/ENTA_aggregates.csv, delim(,) replace

  * Aggregate output file, dta only - deliberate column order for readability
    sort CNT2 YEAR INDICATOR SECTOR
	order  COUNTRY CNT2 YEAR INDICATOR IND SECTOR
    save "ENTA_output_data\ENTA_aggregates.dta", replace
