
********************************************************************************
* ENTA according to NTA concepts
********************************************************************************

* Output: ENTA_output_data/ENTA_nta_complete_wide.dta (all NTA series in wide
*         format) and ENTA_output_data/ENTA_nta (dta, csv, zip; long format,
*         NTA concepts). ENTA_nta holds the indicators that have a label in
*         Prog_ENTA_labels.do (the same file labels the NTA aggregates).
* Input:  ENTA_output_data/ENTA_priv_wide.dta, saved by ENTA_compilation1_esa.do.
* Requires ENTA_setup_TU.do / ENTA_setup.do (program gensex; $wkdir) and
*         ENTA_input_data/Prog_gen_country_name_from_CNT2.do.

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
* Save the published file


use ENTA_output_data/ENTA_priv_wide, clear


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

* NTA totals: asset income YA = YAF + YAG and primary income Y = YL + YA,
* as in NTA and AGENTA. The ESA file publishes the household values under
* the same codes (YA = property income plus operating surplus of
* households, Y = YEM + YA), so Y and YA mean different quantities in the
* two formats.
drop Y Ym Yf YA YAm YAf
gensex YA YAF + YAG
gensex Y YL + YA

* Control NTA private income
* gen Yc1 = YL + YAF
* gen Yc2 = Y + YAC
sort CNT2 YEAR AGE
* browse CNT2 YEAR AGE Yc*

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
* gen YDFc = YDH + YDC
* browse CNT2 YEAR YDF YDFc

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
* gen USEpriv = CF + SF
* browse CNT2 YEAR USEpriv CF CG SF YDF TFW CG CGE CGH CGX
* line YDF USEpriv AGE if YEAR==2019 & CNT2=="AT"

************************************************************
* Control household sector flow identity
************************************************************
* gen USEhh = CF + SF - SC
* browse CNT2 YEAR USEhh CF CG SH YDH TFW CG CGE CGH CGX
* line YDH USEhh AGE if YEAR==2019 & CNT2=="AT"

************************************************************
* Test NTA flow identity
************************************************************

sort CNT2 YEAR AGE
* gen YDnta = YL + YAF + YAG + TFB + TFW - TGO + TGI //
* gen USEnta = CF + CG + SF + SG //
* line YDnta USEnta AGE if YEAR==2019 & CNT2=="AT"

save ENTA_output_data/ENTA_nta_complete_wide, replace


********************************************************************************
* 12. Save NTA data in long format
********************************************************************************

use ENTA_output_data/ENTA_nta_complete_wide, clear

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

* The same file labels the NTA aggregates, so that code, number and label
* agree. Indicators without a label there are not published.
do ENTA_input_data/Prog_ENTA_labels.do nta


************************************************************
* Save the published file
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

do ENTA_input_data/Prog_gen_country_name_from_CNT2.do

sort INDICATOR COUNTRY YEAR SEX AGE
outsheet using ENTA_output_data/ENTA_nta.csv, delim(,) replace
save ENTA_output_data/ENTA_nta, replace


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




