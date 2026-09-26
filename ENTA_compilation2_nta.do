
********************************************************************************
* ENTA according to NTA concepts
********************************************************************************

* Builds on ENTA_output_data\ENTA_priv_wide, saved by ENTA_compilation1_esa.do
* (must be run first).

* Content

* 1. NTA income variables
* 2. Taxes
* 3. Public transfers received, cash
* 4. Private "transfers", private pensions
* 5. Private transfers
* 6. Disposable income, adjusted and final (incl. intra-household transfers)
* 7. Government consumption
* 8. Private consumption
* 9. Saving
* 10. NTA quantities
* 11. Test flow identity

  * Control private sector flow identity
  * Control household sector flow identity
  * Test NTA flow identity

* 12. Save NTA data in long format

  * Generate indicator names
  * Calculate ENTA in different units
  * Save data for dataexplorer

 
use ENTA_output_data\ENTA_priv_wide, clear
  

********************************************************************************
* 1. NTA income variables
********************************************************************************

  * Labour income
    gensex YL YE + 2/3 * YM
 
  * Private asset income
  
    gensex YAH YA + 1/3 * YM 
    gensex YAF YAH + YC
	
	rename YC YAC
	rename YCm YACm
	rename YCf YACf
	
  * Control NTA private income
    //gen Yc1 = YL + YAF
	//gen Yc2 = Y + YAC
	sort CNT2 YEAR AGE
	//browse CNT2 YEAR AGE Yc*
  
********************************************************************************
* 2. Taxes
********************************************************************************

    gen TGOT = T + TC
    gen TGOTm = Tm + TCm
    gen TGOTf = Tf + TCf
	
    rename TC TGOTC
    rename TCm TGOTCm
    rename TCf TGOTCf
	
	rename T TGOTH
	rename Tm TGOTHm
	rename Tf TGOTHf

********************************************************************************
* 3. Public transfers received, cash
********************************************************************************
  
  * Public transfer benefits, cash
    gensex TGIC BS // BSP - TB
  * Public transfer benefits, pensions
    gensex TGICPEN BSPEN  
  * Public transfer benfits, family 
    gensex TGICF BSFAM 
  * Public transfer benefits, unemployment
    gensex TGICU BSU
  * Public transfer benefits, cash other
    gensex TGICX BSX


********************************************************************************
* 4. Private "transfers", private pensions
********************************************************************************

    gensex TPEN BPPEN 

********************************************************************************
* 5. Private transfers
********************************************************************************

    gen TFB = BPB + BPBC
    gen TFBm = BPBm + BPBCm
    gen TFBf = BPBf + BPBCf

  * transfers within households
    gensex TFWO TPW
    gensex TFWI BPW
    gensex TFW TFWI - TFWO
	gensex TF TFB + TFW

********************************************************************************
* 6. Disposable income, adjusted and final (incl. intra-household transfers)
********************************************************************************

    capture drop YDC YDCm YDCf
    gensex YDF YL + YAF + TFB + TFW - TGOT + TGIC 
    gensex YDH YL + YAF - YAC + TFB - BPBC + TFW - TGOTH + TGIC + TPEN
	gensex YDC YAC - TGOTC + BPBC - TPEN
	//gen YDFc = YDH + YDC
	//browse CNT2 YEAR YDF YDFc
	
    gensex YDHA YDH + CG 
  
********************************************************************************
* 7. Government consumption
********************************************************************************
 
********************************************************************************
* 8. Private consumption
********************************************************************************

  gensex CF CHE + CHH + CHR + CHX
  
  rename CHE CFE
  rename CHH CFH
  rename CHR CFR
  rename CHX CFX
 
  rename CHEm CFEm
  rename CHHm CFHm
  rename CHRm CFRm
  rename CHXm CFXm
  
  rename CHEf CFEf
  rename CHHf CFHf
  rename CHRf CFRf
  rename CHXf CFXf
  

********************************************************************************
* 9. Saving
********************************************************************************

  gen SF = SH + SC //+ SFPEN //- BPSOCfc //+ TPSOCfcC
  gen SFm = SHm + SCm // + SFPENm  //- BPSOCfcm //+ TPSOCfcCm
  gen SFf = SHf + SCf //+ SFPENf //- BPSOCfcf //+ TPSOCfcCf
  
  * Household saving arrives from compilation1 already named SH, so that it is
  * SH throughout the project and does not collide with the total S built just
  * below.
  
  gen S = SF + SG 
  gen Sm = SFm + SGm 
  gen Sf = SFf + SGf 
  
  
********************************************************************************
* 10. NTA quantities
********************************************************************************

  * Total government transfers
    gensex TGI TGIC + CG 
  *  Consumption, total
    capture drop C
    gensex C CF + CGE + CGH + CGX 
  * Public reallocations
    gensex TGO TGOT + YAG - SG
	gensex TG TGI - TGO
  * Asset part of government outflows
    gensex TGOABR YAG - SG

********************************************************************************
* 11. Test flow identity
********************************************************************************
  
  ************************************************************
  * Control private sector flow identity
  ************************************************************
  //gen USEpriv = CF + SF
  //browse CNT2 YEAR USEpriv CF CG SF YDF TFW CG CGE CGH CGX
  //line YDF USEpriv AGE if YEAR==2019 & CNT2=="AT"

  ************************************************************
  * Control household sector flow identity
  ************************************************************
  //gen USEhh = CF + SF - SC
  //browse CNT2 YEAR USEhh CF CG SH YDH TFW CG CGE CGH CGX
  //line YDH USEhh AGE if YEAR==2019 & CNT2=="AT"

  ************************************************************
  * Test NTA flow identity
  ************************************************************

  sort CNT2 YEAR AGE
  //gen YDnta = YL + YAF + YAG + TFB + TFW - TGO + TGI //
  //gen USEnta = CF + CG + SF + SG //
  //line YDnta USEnta AGE if YEAR==2019 & CNT2=="AT"

  save ENTA_output_data\ENTA_nta_complete_wide, replace
  
  
********************************************************************************
* 12. Save NTA data in long format
********************************************************************************

  use ENTA_output_data\ENTA_nta_complete_wide, clear  

  local inc "Y YL YA YAF YAH YAC YAG YDF YDH YDC YDHA" // YD YDF YDA YDAF" // YLM
  local out "TGO TGOT TGOABR TGNF TPEN TFB TGOTH TGOTC" // TB TF TFB TFW TFWI TFWO TPEN "
  * TFB and TGO are already in the out list; listing them here too would append
  * each twice to the long file
  local in "TGIC TGICPEN TGICF TGICU TGICX TF TFW TFWI TFWO TGI TG" // TB TF TFB TFW TFWI TFWO TPEN "
  local use "C CF CFE CFH CFX CFR CG CGE CGH CGX S SF SH SC SG"
  local variables `inc' `out' `in' `use'
  
  foreach var of local variables {
  	
  	preserve
	
	keep CNT2 COUNTRY YEAR AGE `var' POP
	gen IND = "`var'"
	gen SEX = 0
	rename `var' VALUE
	tempfile d`var'
	save `d`var''
	restore 

  	preserve
	keep CNT2 COUNTRY YEAR AGE `var'm POPm
	gen IND = "`var'"
	gen SEX = 1
	rename `var'm VALUE
	rename POPm POP
	tempfile d`var'm
	save `d`var'm'
	restore 
	
  	preserve
	keep CNT2 COUNTRY YEAR AGE `var'f POPf
	gen IND = "`var'"
	gen SEX = 2
	rename `var'f VALUE
	rename POPf POP
	tempfile d`var'f
	save `d`var'f'
	restore 
	
  }

  * Population itself, as its own indicator (not just the per-variable
  * weight column carried above, which is dropped before the final save)
    preserve
      keep CNT2 COUNTRY YEAR AGE POP
      gen IND = "POP"
      gen SEX = 0
      rename POP VALUE
      tempfile dPOP
      save `dPOP'
    restore

    preserve
      keep CNT2 COUNTRY YEAR AGE POPm
      gen IND = "POP"
      gen SEX = 1
      rename POPm VALUE
      tempfile dPOPm
      save `dPOPm'
    restore

    preserve
      keep CNT2 COUNTRY YEAR AGE POPf
      gen IND = "POP"
      gen SEX = 2
      rename POPf VALUE
      tempfile dPOPf
      save `dPOPf'
    restore

  clear
  foreach var of local variables {
  	append using `d`var''
  	append using `d`var'm'
  	append using `d`var'f'
  }
  append using `dPOP'
  append using `dPOPm'
  append using `dPOPf'

  ************************************************************
  * Generate indicator names
  ************************************************************
  
  gen INDICATOR = ""
	replace INDICATOR = "0 Population (POP)" if IND=="POP"

	replace INDICATOR = "1 Primary income (Y)" if IND=="Y"
	replace INDICATOR = "1.1 Labour inc (YL)" if IND=="YL"
	replace INDICATOR = "1.2 Asset inc, private (YAF)" if IND=="YAF"
	replace INDICATOR = "1.2.1 Asset inc, households (YAH)" if IND=="YAH"
	replace INDICATOR = "1.2.2 Asset inc, corporations (YAC)" if IND=="YAC"
	replace INDICATOR = "1.3 Asset inc, government (YAG)" if IND=="YAG"
	replace INDICATOR = "1.4 Asset inc, total (YA)" if IND=="YA"
	
	replace INDICATOR = "2 Public transfers, outflows (TGOT)" if IND=="TGOT" 
	replace INDICATOR = "2.1 Public transfers, out, househ (TGOTH)" if IND=="TGOTH" 
	replace INDICATOR = "2.2 Public transfers, out, corp (TGOTC)" if IND=="TGOTC" 
	replace INDICATOR = "2.3 Public trans, net from ROW (TGNF)" if IND=="TGNF" 
	
	replace INDICATOR = "3 Public transfers, inflows in cash (TGIC)" if IND=="TGIC" 
	replace INDICATOR = "3.1 Public trans, pensions (TGICPEN)" if IND=="TGICPEN" 
	replace INDICATOR = "3.2 Public trans, family (TGICF)" if IND=="TGICF" 
	replace INDICATOR = "3.3 Public trans, unempl (TGICU)" if IND=="TGICU" 
	replace INDICATOR = "3.4 Public trans, other (TGICX)" if IND=="TGICX" 

	replace INDICATOR = "4 Funded pensions, benefits less contr (TPEN)" if IND=="TPEN" 
	//replace INDICATOR = "4.1 Contribution to mandatory funded pensions" if IND=="TFBPO" 
	//replace INDICATOR = "4.2 Benefits from mandatory funded pensions" if IND=="TFBPI" 	

	replace INDICATOR = "5 Transfers private (TF)" if IND=="TF" 
	replace INDICATOR = "5.1 Trans priv between HH, net received (TFB)" if IND=="TFB" 
	replace INDICATOR = "5.2 Trans priv within HH, net received (TFW)" if IND=="TFW" 
	replace INDICATOR = "5.2.1 Trans priv within HH, received (TFWI)" if IND=="TFWI" 
	replace INDICATOR = "5.2.2 Trans priv within HH, paid (TFWO)" if IND=="TFWO" 

	replace INDICATOR = "6.0 Disposable income, NTA (YDF)" if IND=="YDF"
	replace INDICATOR = "6.0.1 Disposable income, NTA, househ (YDH)" if IND=="YDH"
	replace INDICATOR = "6.0.2 Disposable income, NTA, corp (YDC)" if IND=="YDC"
	
	replace INDICATOR = "7 Public consumption (CG)" if IND=="CG"
	replace INDICATOR = "7.1 Public cons, education (CGE)" if IND=="CGE"
	replace INDICATOR = "7.2 Public cons, health (CGH)" if IND=="CGH"
	replace INDICATOR = "7.3 Public cons, other (CGX)" if IND=="CGX"
	replace INDICATOR = "7.4 Adjusted disp inc (incl. pub cons, YDHA)" if IND=="YDHA"
	
	//replace INDICATOR = "6 Private consumption (C)" if IND=="C"
	replace INDICATOR = "8 Private consumption (CF)" if IND=="CF"
	replace INDICATOR = "8.1 Private cons, education (CFE)" if IND=="CFE"
	replace INDICATOR = "8.2 Private cons, health (CFH)" if IND=="CFH"
	replace INDICATOR = "8.3 Private cons, imp rent (CFR)" if IND=="CFR"
	replace INDICATOR = "8.4 Private cons, other (CFX)" if IND=="CFX"
	
	replace INDICATOR = "9 Saving, total (S)" if IND=="S"
	replace INDICATOR = "9.1 Saving, private (SF)" if IND=="SF"
	replace INDICATOR = "9.1.1 Saving, househ (SH)" if IND=="SH"
	replace INDICATOR = "9.1.2 Saving, corp (SC)" if IND=="SC"
	replace INDICATOR = "9.2 Saving, public (SG)" if IND=="SG"

	replace INDICATOR = "10.1 Total government transfers, net (TG)" if IND=="TG"
	replace INDICATOR = "10.2 Total government transfers, inflows (TGI)" if IND=="TGI"
	replace INDICATOR = "10.3 Public age reallocations, outflows (TGO)" if IND=="TGO"
	replace INDICATOR = "10.3.1 Public age realloc, outflows, asset-based (TGOABR)" if IND=="TGOABR"
	replace INDICATOR = "10.4 Total consumption (C)" if IND=="C"


  ************************************************************
  * Save data
  ************************************************************

  * Sex from numeric to string
      gen SEXstr = "Total"
      replace SEXstr = "Men" if SEX==1
      replace SEXstr = "Women" if SEX==2
      drop SEX
      rename SEXstr SEX

    keep CNT2 YEAR IND INDICATOR SEX AGE VALUE
	drop if VALUE==.
	drop if INDICATOR==""
	drop if YEAR<2008
    foreach var of varlist _all {
	  label var `var' ""
    }
	
    do ENTA_input_data/PROG_gen_country_name_from_CNT2.do

    sort INDICATOR COUNTRY YEAR SEX AGE
    outsheet using ENTA_output_data\ENTA_nta.csv, delim(,) replace
	save ENTA_output_data\ENTA_nta, replace


  * Compressed copy for Zenodo upload (file size), with Stata's built-in
  * zipfile and NOT 7-Zip via `shell', which does nothing in batch mode. Built
  * from inside ENTA_output_data so the archive holds a bare ENTA_nta.csv - see
  * the full note in ENTA_compilation1_esa.do.
    cd ENTA_output_data
    zipfile ENTA_nta.csv, saving(ENTA_nta.zip, replace)
    cd $wkdir
  
  /*
  sort CNT2 YEAR AGE SEX
  //local var "YL"
  //line VALUE AGE if IND=="`var'" & YEAR==2015 & SEX=="Total" ///
  //|| line VALUE AGE if IND=="`var'" & YEAR==2022 & SEX=="Total"
  */
  
  
  
  
