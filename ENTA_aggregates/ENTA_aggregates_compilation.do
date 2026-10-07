
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
*   - The published CSV: ENTA_output_data/ENTA_aggregates.csv
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
*   7. Clean missing data and save the published file
********************************************************************************

********************************************************************************
* 0. Write programmes for repeated tasks by sector
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

* Programme for output tables in per capita values [INACTIVE: only called in the commented-out overview tables]

/*
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
*/


********************************************************************************
* 1. Aggregates for household sector (incl. NPISH)
********************************************************************************

use ENTA_input_data/ENTA_input_datasets/esa_aggregates, clear
* Stops if esa_aggregates was built by an older Aggr_ESA2010.do, in which YD
* and C were at market prices (now YDmp and Cmp): run Aggr_ESA2010.do first.
confirm variable YDmp Cmp, exact
keep if sector=="S14_S15"
drop if CNT2=="EU27_2020" | CNT2=="EA20"


**********************************************
* 1.1 Income
**********************************************

* YEM: Employment income = YE (compensation of employees) + YM (mixed income)
* YA:  Asset income = YP (property income) + YO (operating surplus)

* Adjust income variables with income-based taxes on production: the payroll
* taxes of the employers are compensation of employees. TTYERr is the part
* on the wages of resident households; the part on the wages of
* non-residents (TTYERrow) is taken off the total economy in Section 4.
replace YE = YE + TTYERr
replace Y = Y + TTYERr - TTYERp

* Composite income measures
gen YEM = YE + YM // Employment income = compensation of employees (YE) and mixed income (YM)


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
* TYM taxes on capital, income of self-employed
* TYER taxes on labour, inc form employment, paid by employers
* TYEE taxes on labour, inc form employment, paid by employees
* TYP taxes on capital, income of households
* TB taxes on labour, paid by non-emploed

* Merge tax structure data

* sort CNT2 YEAR
* merge 1:1 CNT2 YEAR using ENTA_input_data/ENTA_input_datasets/taxstructure_wide, nogenerate keep(master match)

* Add imputed social contributions to TYER of tax statistic (originally not included)
replace TYER = TYER + D612p

* Adjustment of taxes on labour income: from "received by gov" to "paid by HH"
* tax stat is about gov received, ESA (and ENTA) about households paid, mostly relevant for LU
gen TYE = TYER + TYEE // received by gov
replace TYE = TYE - (D61rg - TYS) // (D61rg - TYS) = social contributions paid to ROW

* Reallocation of labour-based "other taxes on production" to "social contributions" (mostly relevant for AT, SE)
replace TPN = TPN - TTYERp
replace TPNp = TPNp - TTYERp
replace TYS = TYS + TTYERr

* Compare income taxes: ESA vs tax statistics
gen TYesa = TYT + TYS
gen TYtax = TYE + TYM + TYP + TB
gen TYAF = TYesa / TYtax // adjustment factor
* browse CNT2 YEAR TYesa TYtax TYAF

* Adjust taxes by function from tax data to ESA aggregates
* tax data = received by S13 in total, ESA data = paid by domestic to S13;

replace TYE = TYE * TYAF
replace TYM = TYM * TYAF
replace TYP = TYP * TYAF
replace TB = TB * TYAF
gen TYEM = TYE + TYM

* Control if data from tax statistic and ESA now add up
gen TYtax_check = TYE + TYM + TYP + TB
* browse CNT2 YEAR TYesa TYtax_check TYAF if YEAR==2023

* Calculate composite indicators for asset income and taxes on assets
* browse CNT2 YEAR YP YO TPNp
gen YA = YP + YO
replace YM = YM + TPNp
replace YEM = YEM + TPNp

gen TYA = TYP + TA
replace TYM = TYM + TPN
replace TYEM = TYEM + TPN

* Verify income identity
capture drop Yc
gen Yc = YEM + YA
* browse CNT2 YEAR Y Yc

* Total taxes
gen T = TYE + TYM + TYP + TA + TX + TCON + TB
* Without tax structure data: the same total from the ESA income taxes
* (TYesa = TYE + TYM + TYP + TB after the TYAF scaling) plus TPN, which
* TYM carries, and the other taxes
replace T = TYesa + TPN + TA + TX + TCON if TYE==.


* [INACTIVE] Split of TB with a single share of taxes on pensions; the
* split is done in Section 1.3 below
* sort CNT2 YEAR
* merge 1:1 CNT2 YEAR using ENTA_input_data/ENTA_input_datasets/inctax_nonempl_decomp
* drop if _merge==2
* drop _merge
* gen TBSPPEN = TB * TBSPPENsh
* gen TBSN = TB * (1 - TBSPPENsh)
* drop TBSPPENsh


*********************************
* 1.3 Social benefits
*********************************

* Merge social benefits by type (from gov expenditure by COFOG)
sort CNT2 YEAR
merge 1:1 CNT2 YEAR using ENTA_input_data/ENTA_input_datasets/gov_expenditure
drop if _merge==2
drop _merge
sort CNT2 YEAR
* browse

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
* browse BS BSP BPSOCfc

* Decompose the taxes on benefits TB into taxes on pay-as-you-go
* pensions (TBSPEN), funded pensions (TBPPEN) and non-pension benefits
* (TBSN). TB is DG TAXUD's LNON; its parts come from the national tax lists
* (Suppl_tax_list.do, shares sh_* of TB):
*   income tax on transfers (sh_PIT), split with EUROMOD's income tax per
*     euro of each kind of transfer (t*, Micro_EUROMOD.do Section 4) times
*     the ESA amounts BSPEN, BPSOCfc, BSN;
*   contributions by the non-employed (sh_MIX): the same with EUROMOD's
*     contributions ils_sicot (m*);
*   state-paid contributions (sh_STATE): with the credited contributions
*     ils_sicct (c*);
*   items on one kind of transfer: sh_PAYG, sh_FUND, sh_BEN directly;
*     sh_PEN over the two kinds of pension by amount;
*   items paid by people without a benefit (sh_OTHER): by amount.
* A weight set without EUROMOD values falls back to the amounts. Without
* EUROMOD at all (before 2005-2007) the parts are computed but not
* published (Section 6).
sort CNT2 YEAR
merge 1:1 CNT2 YEAR using ENTA_input_data/ENTA_input_datasets/tb_taxlist, keepusing(sh_*) keep(master match) nogen
merge 1:1 CNT2 YEAR using ENTA_input_data/ENTA_input_datasets/inctax_nonempl_decomp, keep(master match) nogen
* ESA amounts (EE's negative funded benefits count as 0 here)
gen double _aP = BSPEN
gen double _aF = max(0, BPSOCfc) if !missing(BPSOCfc)
gen double _aB = BSN
* Weights of the three kinds for each part: EUROMOD ratio x ESA amount,
* normalised; the amounts alone where EUROMOD gives nothing usable
foreach k in t m c a {
    if "`k'"=="a" {
        gen double _wP_a = _aP
        gen double _wF_a = _aF
        gen double _wB_a = _aB
    }
    else {
        gen double _wP_`k' = `k'PAYG * _aP
        gen double _wF_`k' = `k'FUND * _aF
        gen double _wB_`k' = `k'BEN  * _aB
    }
    gen double _w = _wP_`k' + _wF_`k' + _wB_`k'
    gen byte _nw = !(_w>0 & !missing(_w))
    replace _wP_`k' = _aP if _nw
    replace _wF_`k' = _aF if _nw
    replace _wB_`k' = _aB if _nw
    replace _w = _wP_`k' + _wF_`k' + _wB_`k'
    replace _wP_`k' = _wP_`k' / _w
    replace _wF_`k' = _wF_`k' / _w
    replace _wB_`k' = _wB_`k' / _w
    drop _w _nw
}
gen double _pF = _aF / (_aP + _aF)
gen double TBSPEN = TB * (sh_PIT*_wP_t + sh_MIX*_wP_m + sh_STATE*_wP_c + sh_OTHER*_wP_a + sh_PEN*(1-_pF) + sh_PAYG)
gen double TBPPEN = TB * (sh_PIT*_wF_t + sh_MIX*_wF_m + sh_STATE*_wF_c + sh_OTHER*_wF_a + sh_PEN*_pF     + sh_FUND)
gen double TBSN   = TB * (sh_PIT*_wB_t + sh_MIX*_wB_m + sh_STATE*_wB_c + sh_OTHER*_wB_a + sh_BEN)
gen double TBSPPEN = TBSPEN + TBPPEN                   // taxes on all pensions
gen double TBS     = TBSPPEN + TBSN                    // taxes on all benefits
* TB = 0 (BG): no shares, and the parts are 0 as well
foreach v in TBSPEN TBPPEN TBSN TBSPPEN TBS {
    replace `v' = 0 if TB==0
}
drop sh_PIT sh_PAYG sh_FUND sh_PEN sh_BEN sh_MIX sh_STATE sh_OTHER _a? _w?_? _pF ///
    tPAYG tFUND tBEN mPAYG mFUND mBEN cPAYG cFUND cBEN
* browse CNT2 YEAR TB TBSPPEN TBPPEN TBSPEN TBSN BSPPEN BSPEN BPSOCfc

* Control the sums
gen BSc1 = BSOA + BSS + BSF + BSU + BSX + BSD + BSE  //+ BPSOCfc // - TB
gen BSc2 = BSPEN + BSFAM + BSU + BSX  //- TB
* browse CNT2 YEAR BS BSc1 BSc2 BSP
drop BSc*

*****************************************
* 1.4 and 1.5 Funded pensions and private transfers
*****************************************

gen BPPEN = BPSOCfc - TPSOCfc
gen BPX = -TPX
gen BPB = BPSOCnfc - TPSOCnfc + BPX + BROW
* browse BPSOCnfc TPSOCnfc BPX BROW


*****************************************
* 1.7 Private consumption
*****************************************

* Merge private consumption by purpose
sort CNT2 YEAR
merge 1:1 CNT2 YEAR using ENTA_input_data/ENTA_input_datasets/consumption_hh_coicop
drop if _merge==2
drop _merge
* browse CNT2 YEAR Cmp C CP00

sort CNT2 YEAR
gen CHE = CP10/CP00 * C
gen CHH = CP06/CP00 * C
gen CHR = CP042
gen CHX = C - CHE - CHH - CHR

* [INACTIVE] Sweden: CHE folded into CHX and published as zero. This was
* needed while the age profile of CHE came from the HBS, which has no
* education consumption for Sweden. The profile now comes from enrollment
* and population (Suppl_consumption_educ_profile.do), so Sweden has a CHE
* like every other country (about 540 mio EUR a year).
* replace CHX = CHX + CHE if CNT2=="SE"
* replace CHE = 0 if CNT2=="SE"
gen CHNR = CHE + CHH + CHX

gen YDCASH = YD - CHR
gen YDCASHmk = YDmp - CHR


**************************************************
* 1.8 Test disposable income: YD = C + S
**************************************************

* At basic prices

* YD via ESA tax components
gen YDbc1 = YE + YM + YA - TYT - TYS - TA - TX - TPN + BS - TPSOC - TPX + BPSOC + BROW - TCON
* YD as sum of consumption and saving
gen YDbc2 = C + S
* YD with ENTA tax components
gen YDbc3 = Y - (TYE + TYM + TYA + TB) - TX + BS - TPSOC - TPX + BPSOC + BROW - TCON
* YD via ENTA tax components
gen YDbc4 = YE + YM + YA - TYEM - TYA - TB - TX + BS + BPB + BPPEN - TCON
gen YDbc5 = YEM + YA - T + BS + BPB + BPPEN

capture drop B
gen B = BS + BPB + BPPEN
* gen T = TYEM + TYA + TX + TCON + TB // TYE + TYM + TYP + TA + TX + TCON + TPN + TB
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

* browse geo sector YD YDbc1 YDbc2 YDbc3 YDbc4 YDbc5 YDbc6 d_YDb* TB* //if d_YDb>5
order  geo sector YD YDbc1 YDbc2 YDbc3 YDbc4 YDbc5 YDbc6 d_YDb* TB*

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
    // local vars "YD C CHE CHH CHX CHR S"

    percapita `vars'
    browse if CNT2=="LU" & YEAR==2023

  */


**************************************************
* 1.9 Change household data into long format
* (numbered 1.9, not 1.6, because it runs after 1.7/1.8 and depends on
* their output - CHE/CHH/CHR/CHX/CHNR/YDCASH/YDCASHmk are all created in 1.7)
**************************************************

local inc "Y YEM YE YM YA YO YP YPr YPp" // YEME YEE YER
* local taxesa "T TA TX TCON TPN" // TYLER TYLEE YN TYT TYS
* local taxempl " TYER" // TYLER TYLEE (= TYT + TYS) TYE TYM TYEMSOC TYEMT
local tax "T TYEM TYA TYP TB TBPPEN TBSPEN TBSN TBSPPEN TCON TX TXH TXNPISH TPN TA" // TYLER TYLEE (= TYT + TYS) TBSPP TA TYP TPN
local ben "B BS BSP BSU BSX BSPEN BSPPEN BSN BSFAM" // BSD BSOA BSS BSE BSF
local privt "BPPEN BPB BPX BROW TPSOCfc TPSOCnfc BPSOCnfc BPSOCfc D8"  // BPSOC  TPp TPr TROWp TROWr TPSOC TPX BSPBPSOC
* local pubc "CG CGE CGH CGX " // details for education groups needed for calculating age-profiles
* Household saving is SH throughout the project: the sector-generic
* S from Aggr_ESA2010 is renamed here, before the reshape that turns variable
* names into IND, so the Households rows of ENTA_aggregates carry SH. The
* Corporations, Government and Total economy sections keep S - there SECTOR
* disambiguates it, and adjustsec SC S Corporations / adjustsec SG S
* Government look the aggregate up by that name.
rename S SH
local use "YD C CHE CHH CHX CHR CHNR SH YDCASH YDCASHmk"
local indic `inc' `tax' `ben' `privt' `pubc' `use'

foreach ind of local indic {
    replace `ind' = 0 if `ind'==.
}

collapse (sum) `indic', by (CNT2 YEAR)

reshape_to_long `indic'

* drop if VALAGGR==-1
gen SECTOR = "Households"


* Household consumption is CH
replace IND ="CH" if IND=="C"

* Indicators of this sector that are published. The labels and the published
* codes are set in Prog_ENTA_labels.do and in Section 7.
gen INDICATOR = ""
local published "Y YEM YE YM YA YP YO T TYEM TYA TB TBSPEN TBSN TBPPEN TCON TX TXH TXNPISH BS BSPEN BSFAM BSU BSX BPPEN BPSOCfc TPSOCfc BPB YD CH CHE CHH CHR CHX SH"
foreach i of local published {
    replace INDICATOR = "published" if IND=="`i'"
}
tempfile hh
save `hh'



********************************************************************************
* 2. Corporations
********************************************************************************

use ENTA_input_data/ENTA_input_datasets/esa_aggregates, clear
keep if sector=="S11" | sector=="S12"

* browse CNT2 YEAR sector TYT TA TX TPN
gen T = TYT + TA + TX + TPN

* Adjustment for income taxes captured in taxes on production: the payroll
* taxes of the employers are compensation of employees and no longer taxes
* of the corporations
replace Y = Y - TTYERp
replace T = T - TTYERp

/*
* Why such high values of T relative to income for LU?
  browse YROW Y T TYT TA TX TPN S B8* if CNT2=="LU" & YEAR==2019
*/

* Combine corporation sectors
local indic "Y T TPSOC TPSOCfc TPSOCnfc TPX BPSOC BPSOCfc BPSOCnfc BROW YDmp YD S"
* browse CNT2 YEAR sector `indic'
* Missing where neither S11 nor S12 has a value: collapse (sum) alone
* would publish 0 there
foreach v of local indic {
    gen byte n_`v' = !missing(`v')
}
collapse (sum) `indic' n_*, by (CNT2 YEAR)
foreach v of local indic {
    replace `v' = . if n_`v'==0
    drop n_`v'
}

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

* browse CNT2 YEAR YDmp YDc1 YDc2 YDc3 YDc4 Y T BPSOC BROW TPSOC
order CNT2 YEAR YDmp YDc1 YDc2 YDc3 YDc4 Y T BPSOC BROW TPSOC
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
  local vars "Y T BPB TPSOCnfc BPSOCnfc BPX BROW BPPEN TPSOCfc BPSOCfc S TPSOC TPX YDmp"
  percapita `vars'
  browse if CNT2=="DE" & YEAR==2023
*/


* Reshape into long format

local indic "Y T BPPEN BPB BPX YDmp YD S BPSOCfc TPSOCfc BPSOCnfc BROW TPSOCnfc TPX"

reshape_to_long `indic'

drop if VALAGGR==.
gen SECTOR = "Corporations"

* Indicators of this sector that are published. The labels and the published
* codes are set in Prog_ENTA_labels.do and in Section 7.
gen INDICATOR = ""
local published "Y T BPPEN TPSOCfc BPSOCfc BPB YD S"
foreach i of local published {
    replace INDICATOR = "published" if IND=="`i'"
}
tempfile corp
save `corp'



********************************************************************************
* 3. Government
********************************************************************************

* Load data
use ENTA_input_data/ENTA_input_datasets/esa_aggregates, clear
keep if sector=="S13"

sort CNT2 YEAR
merge 1:1 CNT2 YEAR using ENTA_input_data/ENTA_input_datasets/taxstructure_wide
drop if _merge!=3
drop _merge

* Adjust for taxes on production paid on behalf of employees
* browse CNT2 YEAR Y TYT TYS TTYER* BROW
replace Y = Y - TTYERp //   // + TTYERr
replace TYS = TYS - TTYERhh //
replace TPN = TPN + TTYERrow - TTYERp + TTYERhh //   //
replace BROW = BROW + TTYERrow

* Total direct taxes & social benefits
* gen TD = TYT + TYS + TA + TX + TPN
gen T = TYT + TYS + TA + TX + TPN + TCON

local taxes "T TYT TYS TA TX TPN TCON B BS BROW"
foreach t of local taxes {
    replace `t' = -`t'
}
gen TROW = -BROW

* Public consumption

sort CNT2 YEAR
* Keep the government rows without COFOG data (SK before 2008): the ESA
* government accounts exist, only the breakdown by function is missing
merge 1:1 CNT2 YEAR using ENTA_input_data/ENTA_input_datasets/gov_expenditure
drop if _merge==2
drop _merge

* browse CNT2 YEAR CGEPP CGESEC CGEPSEC
replace CGEPSEC = 0 if (CGEPSEC==. | CGEPSEC<0) & CGESEC!=. // for Bulgaria CGEPSEC is missing

* Impute SK 2008/2009 public consumption by function: SK has no COFOG
* breakdown before 2010 (gov_expenditure.dta only carries SK's 2010 row
* back as a raw placeholder for 2008/2009 - see Suppl_gov_expenditure.do).
* Unlike the BS benefit categories above, there is no separate ESA
* aggregate here to rescale against afterwards, so assume each category's
* share relative to total consumption (C) is the same as in 2010, and
* scale explicitly by SK's actual C for 2008 and 2009.
local cg_vars "CGE CGH CGEPP CGESEC CGEPSEC CGETER"
qui sum C if CNT2=="SK" & YEAR==2010
local sk2010_cb = r(mean)
foreach v of local cg_vars {
    qui sum `v' if CNT2=="SK" & YEAR==2010
    local sh_`v' = r(mean) / `sk2010_cb'
    replace `v' = `sh_`v'' * C if CNT2=="SK" & inlist(YEAR,2008,2009)
}

* Secondary plus post-secondary non-tertiary education, the aggregate that
* the CGES profile (enrollment ISCED 2-4, ENTA_compilation1_esa.do) is scaled
* to. gov_expenditure has no CGES, and Stata would abbreviate `CGES' to
* CGESEC and leave CGEPSEC out of the profile CGE, so it is built explicitly.
gen CGES = CGESEC + CGEPSEC

gen CGX = C - CGE - CGH
gen CGHX = CGH - CGHIN - CGHOUT
gen CGEX = CGE - CGEPP - CGESEC - CGEPSEC - CGETER

* Control if variables add up
gen YDc1 = Y + T - BS + TROW
* browse CNT2 YEAR YDc1 Y TYT TA TX BS TROW TCON C S
gen YDc2 = C + S

gen d_YDc1 = YD - YDc1
gen d_YDc2 = YD - YDc2
* browse CNT2 YEAR YD YDc1 YDc2 d_YDc* Cmp C
drop YDc* d_YD*

* Save data for NTA aggregates
tempfile ntagov
save `ntagov'

/*
*******************************
* Overview tables
*******************************

* reshape file into long format
  local vars "Y T BS BROW C CGE CGH CGX S YD"
  percapita `vars'
  browse if CNT2=="DE" & YEAR==2023
*/

*******************************
* From wide to long format
*******************************

local indic "Y T TYT TA TX BS BROW TROW YDmp YD TCON C CGE CGEX CGEPP CGESEC CGES CGEPSEC CGETER CGH CGHOUT CGHIN CGHX CGX S" // CGEPRE CGEPRI
* browse CNT2 YEAR sector Y T BS BROW

* collapse (sum) `indic', by (CNT2 YEAR)
keep CNT2 YEAR `indic'

reshape_to_long `indic'

drop if VALAGGR==.
gen SECTOR = "Government"


*******************************
* Variable names
*******************************

* Indicators of this sector that are published. The labels and the published
* codes are set in Prog_ENTA_labels.do and in Section 7.
gen INDICATOR = ""
local published "Y T TROW BS YD C CGE CGH CGX S"
foreach i of local published {
    replace INDICATOR = "published" if IND=="`i'"
}
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
* = YDmp
* - C
* = S

* Load and prepare data
use ENTA_input_data/ENTA_input_datasets/esa_aggregates, clear
keep if sector=="S1"

* Generate aggregates

* One row per country and year, so keep rather than collapse (sum),
* which would turn a missing value into 0
isid CNT2 YEAR
keep YEAR CNT2 GDP YEROW YPROW CFC TPSp TPSr TPNr TPNp Y YE BROW TYT TA TX TCON BS YDmp YD C S B1Nr B5Np D8 TTYERrow
* browse YEAR CNT2 TPSp TPSr B1Nr Y

* Payroll taxes of the employers on the wages of non-residents (TTYERrow):
* as part of compensation of employees they are income paid to the rest of
* the world, and the non-residents pay them to government as a transfer
* from the rest of the world. Primary income is then the sum of the sectors.
replace YEROW = YEROW - TTYERrow
replace Y = Y - TTYERrow
replace BROW = BROW + TTYERrow

* Compare ENTA aggregates and ESA aggregates of income
gen Yc = GDP - CFC + YEROW + YPROW - TPSp // NONY = CFC + TPSp + YROW
gen Yc1 = B5Np - TPSr - TPNr + TPNp // D8 is not part of Y
sort CNT2 YEAR
gen DY = Y - Yc
gen DTPS = TPSr - TPSp
* browse CNT2 YEAR Y Yc Yc1 DY DTPS D8 TTYER*

* Test if generation of income and use-based disposable income are equal
gen YDc1 = Y + BROW // Y = YL + YO + YM + YP + TPNp
gen YDc2 = C + S
sort CNT2 YEAR
* browse YEAR CNT2 Y Yc Yc1 YDmp YD YDc1 YDc2 B1N
order YEAR CNT2 Y Yc Yc1 YDmp YD YDc1 YDc2 B1N

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
  local vars "GDP CFC YEROW YPROW TPSp Y BROW C S"
  percapita `vars'
  browse if CNT2=="DE" & YEAR==2023
  browse if CNT2=="IE" & YEAR==2023
  browse if CNT2=="LU" & YEAR==2023
*/

* Change into long format
local indic "GDP YE YEROW YPROW CFC TPSp Y BROW YD C S"

reshape_to_long `indic'

drop if VALAGGR==.
gen SECTOR = "Total economy"


* Indicators of this sector that are published. The labels and the published
* codes are set in Prog_ENTA_labels.do and in Section 7.
gen INDICATOR = ""
local published "GDP YEROW YPROW CFC TPSp Y BROW YD C S"
foreach i of local published {
    replace INDICATOR = "published" if IND=="`i'"
}
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
* browse CNT2 YEAR SECTOR Y YAF YAG YA

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
gen TGOTH = TGOT if SECTOR=="Households"
gen TGOTC = TGOT if SECTOR=="Corporations"
* browse T Tcesa Tg TGOT

* replace TYS = 0 if SECTOR!="Households"
* replace TYT = 0 if SECTOR!="Households"

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

* gen TGI = BS + CG if SECTOR=="Households"
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
gen TPEN = BPSOCfc-TPSOCfc if SECTOR=="Households"
gen TFPH = BPSOCfc-TPSOCfc if SECTOR=="Households"
gen TFPC = BPSOCfc-TPSOCfc if SECTOR=="Corporations"


***********************************************
* 5.5 Private transfers
***********************************************

gen TFB = BPSOCnfc + BROW - TPSOCnfc - TPX if SECTOR=="Households"
replace TFB = BPSOCnfc + BROW - TPSOCnfc - TPX if SECTOR=="Corporations"
gen TFBH = TFB if SECTOR=="Households"
gen TFBC = TFB if SECTOR=="Corporations"
gen TF = TFB // transfers within households add up to zero in the total

* browse TFB TFP D8 BPB BPP


*************************************************
* 5.6 Disposable income
*************************************************

gen YDF = YD if SECTOR=="Households" | SECTOR=="Corporations"
gen YDG = YD if SECTOR=="Government"
gen YDH = YD if SECTOR=="Households"
gen YDHA = YD if SECTOR=="Households"
replace YDHA = C if SECTOR=="Government"
capture drop YDC // corporate disposable income; the household cash concept is YDCASH
gen YDC = YD if SECTOR=="Corporations"

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
* 5.7 Consumption and saving
*********************************************

gen CF = C if SECTOR=="Households"
gen CFE = CHE if SECTOR=="Households"
gen CFH = CHH if SECTOR=="Households"
gen CFR = CHR if SECTOR=="Households"
gen CFX = CHX if SECTOR=="Households"
gen CG = C if SECTOR=="Government"
replace CGE = 0 if SECTOR!="Government"
replace CGH = 0 if SECTOR!="Government"
replace CGX = 0 if SECTOR!="Government"
* replace CGS = 0 if SECTOR!="Government"

* replace S = . if SECTOR!="Households" & SECTOR!="Corporations" & SECTOR!="Government"
* browse YEAR CNT2 sector S SF SC BPSOCfc TPSOCfc
gen SF = S if SECTOR=="Households" | SECTOR=="Corporations"
* replace SF = S + TPSOCfc - BPSOCfc if SECTOR=="Corporations"
gen SH = S if SECTOR=="Households"
gen SC = S if SECTOR=="Corporations" // + TPSOCfc - BPSOCfc
gen SG = S if SECTOR=="Government"


* NTA indicators
local inc "Y YL YLE YLS YA YAH YAC YAG YAF" // YKFC YKFH
local tax "TGOT TGOTYL TGOTYA TGOTYAH TGOTYAC TGOTCON TGOTB TGOTBSPEN TGOTBSN TGOTBPPEN TGOTX Tg TGOTSOC TGOTY TYS TYT TGOTH TGOTC"
local ben "TGIC TGICg TGICF TGICU TGICPEN  TGICX TGNF TFB TFBH TFBC TFP TFPO TFPI TPEN TF"
local use "YD YDF YDH YDC YDHA C CF CFE CFH CFR CFX CG CGE CGH CGX S SF SH SC SG"
local indic `inc' `tax' `ben' `use'
* browse YEAR SECTOR CNT2 `indic'

foreach var of local indic {
    replace `var' = 0 if `var'==.
}


***********************************************
* 5.8 Generate NTA aggregates, control the data
***********************************************

* Test if flow equation is fulfilled at sector level

* browse CNT2 YEAR SECTOR Y YL YAH YAC YA T TGOT BS TGIC TFP BPP TFB BPB TGNF CF C CG SG S SF
order CNT2 YEAR SECTOR Y YL YAH YAC YA T TGOT BS TGIC TFP BPP TFB BPB TGNF CF C CG SG S SF

gen YDntac1 = YL + YAH - TGOT + TGIC + TFB + TFP if SECTOR=="Households"
replace YDntac1 = YAC - TGOT + TFB + TFP if  SECTOR=="Corporations" //
replace YDntac1 = YAG - Tg + TGICg + TGNF if SECTOR=="Government"

gen YDntac2 = CG + SG if SECTOR=="Government"
replace YDntac2 = CF + SF  if SECTOR=="Households" | SECTOR=="Corporations"

gen D_YD = YDntac1 - YDntac2
* browse CNT2 YEAR SECTOR YD YDntac1 YDntac2 TGNF D_YD TB TFP
order CNT2 YEAR SECTOR YD YDntac1 YDntac2 TGNF D_YD TB  TFP


* Generate NTA aggregates

* browse CNT2 YEAR SECTOR YL YAH YAC YAG TGOT Tg TGIC TGICg TGNF TFB TFP CF SF CG SG // S
sort CNT2 YEAR SECTOR
drop if SECTOR=="Total"
* browse CNT2 YEAR SECTOR YL YA TGO TGOg TGSI TGSIg TGNF TFB YDntac1 YDntac2
collapse (sum) `indic' YDntac*, by(CNT2 YEAR)

* NTA total asset income: YA = YAF + YAG, as the NTA profile in
* ENTA_compilation2_nta.do. The sum over sectors above adds the household
* YA of the ESA format to the government's.
replace YA = YAF + YAG

* Test if flow equation is fulfilled in total

gen YDc1 = YL + YAH + YAC + YAG + TGNF + TFB
gen YDc2 = CF + SF + CG + SG
* browse CNT2 YEAR YDc1 YDc2 YDntac*

* NTA totals that are sums of other NTA totals, defined as the profiles in
* ENTA_compilation2_nta.do
gen TGI = TGIC + CG
gen TGOABR = YAG - SG
gen TGO = TGOT + TGOABR
gen TG = TGI - TGO
local indic `indic' TGI TGOABR TGO TG


************************************
* 5.9 Save NTA data in long format
************************************

reshape_to_long `indic'

drop if VALAGGR==.
gen SECTOR = "NTA Aggregates"

replace VALAGGR = . if VALAGGR==0

* Indicator labels: the same file labels the NTA age profiles, so that code,
* number and label agree. Indicators without a label there are not published.
do ENTA_input_data/Prog_ENTA_labels.do nta

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

do ENTA_input_data/Prog_gen_country_name_from_CNT2.do
sort CNT2 YEAR SECTOR IND


* Suppress the split of the taxes on benefits wherever EUROMOD, which the
* split rests on, has no data. TB itself comes from DG TAXUD and runs from
* 1995; the split into TBSPEN, TBPPEN and TBSN (Section 1.3) uses the
* EUROMOD ratios of inctax_nonempl_decomp, which start in 2005-2007 (AT
* and DE 2007, BE/CZ/EE/EL/ES/HU/IT/LT/PL 2005, the rest 2006; HR 2009
* after the carry-back in Micro_EUROMOD.do). Where they are missing, the
* zero-fill of Section 1.9 would publish a split of zeros that was never
* measured. A split without microdata behind it is not published; TB alone
* is. The rule is keyed on tPAYG, EUROMOD's income tax per euro of
* pensions, so it follows the EUROMOD coverage without hard-coded years.
merge m:1 CNT2 YEAR using ENTA_input_data/ENTA_input_datasets/inctax_nonempl_decomp, ///
    keepusing(tPAYG) keep(master match) nogen
foreach var in TBSPPEN TBSN TBSPEN TBPPEN {
    replace VALAGGR = . if missing(tPAYG) & IND=="`var'"
}
drop tPAYG

*******************
* Save nominal data
*******************
* INTERNAL file, deliberately saved BEFORE the cleaning in Section 7.
* adjustaggr/adjust (ENTA_setup.do) and ENTA_units.do read this file, so
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
* BSX) is zero-filled in Section 1.9 wherever gov_expenditure has no row, so
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
* 2007) are correct as 0.
local vars "BSPEN BSFAM BSU BSOA BSX"
foreach var of local vars {
    replace VALAGGR=. if YEAR<=2000 & inlist(CNT2,"BE","EL","FI","IT","LV","PL","RO","SE") & IND=="`var'"
    replace VALAGGR=. if YEAR<2000  & inlist(CNT2,"DE","LT")                               & IND=="`var'"
    replace VALAGGR=. if YEAR<1999  & CNT2=="PT"                                           & IND=="`var'"
    replace VALAGGR=. if YEAR<2008  & CNT2=="SK"                                           & IND=="`var'"
    replace VALAGGR=. if YEAR==2002 & CNT2=="BG"                                           & IND=="`var'"
}

* The split of TB uses BSPEN, BPSOCfc and BSN (Section 1.3). Where the COFOG
* breakdown is missing, BSPEN is missing, the split is missing and the
* zero-fill of Section 1.9 writes 0, so that TB would no longer equal its
* parts. Blank the three parts wherever the published BSPEN is missing
* (just above).
bysort CNT2 YEAR SECTOR: egen byte nobspen = max(IND=="BSPEN" & missing(VALAGGR))
replace VALAGGR = . if nobspen & inlist(IND,"TBSPEN","TBPPEN","TBSN")
drop nobspen

* TXNPISH is zero until the source's NPISH sector split starts: IE to 2009,
* DE to 2011. Every other country reports it from 1995.
replace VALAGGR=. if YEAR<=2009 & CNT2=="IE" & IND=="TXNPISH"
replace VALAGGR=. if YEAR<=2011 & CNT2=="DE" & IND=="TXNPISH"

* [INACTIVE] Blank the split of TB where a single share of taxes on
* pensions (TBSPPENsh) is zero. The split of Section 1.3 has values in
* every EUROMOD year, and years without EUROMOD are blanked in Section 6.
* merge m:1 CNT2 YEAR using ENTA_input_data/ENTA_input_datasets/inctax_nonempl_decomp, ///
*    keepusing(TBSPPENsh) keep(master match) nogen
* gen byte nosplit = (TBSPPENsh==0 & !missing(TBSPPENsh))
* bysort CNT2 YEAR: egen byte TBzero = max(IND=="TB" & VALAGGR==0)
* foreach var in TBSN TBPPEN {
*    replace VALAGGR = . if nosplit & !TBzero & IND=="`var'"
* }
* drop TBSPPENsh nosplit TBzero

* Unit conversion (per capita, real HICP, PPS, %GDP, %primary income, NTA/
* ENTA norm, etc.) is not computed here - the ENTA dataexplorer does it on
* the fly from the raw VALAGGR (nominal aggregate total, million EUR, per
* CNT2/YEAR/SECTOR/IND) saved below, combined with the conversion factors
* in ENTA_units (built by ENTA_units.do, published with the norms by
* ENTA_compilation1_esa.do).
/*
* Add supplementary data on population, prices, ppps, exchange rate....

  sort CNT2 YEAR
  merge m:1 CNT2 YEAR using ENTA_input_data/ENTA_input_datasets/population0t, update
  drop AGE
  drop if _merge==2
  drop _merge

  sort CNT2 YEAR
  merge m:1 CNT2 YEAR using ENTA_aggregates/ENTA_units
  keep if _merge==3
  drop _merge

* Calculate aggregate values in different units

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

* The published file (CSV for Zenodo; the data explorer reads the Parquet
* copy written by ENTA_compilation3_parquet.R and sorts the indicators by
* their number itself)
drop if INDICATOR==""

* Published indicator codes. The internal file saved above keeps the codes
* that the scaling programs look up; the published file uses the codes of
* the age profiles.
* Corporations: the codes end with C
foreach c in Y T BPB S {
    replace IND = "`c'C" if SECTOR=="Corporations" & IND=="`c'"
}
replace IND = "BPPC"     if SECTOR=="Corporations" & IND=="BPPEN"
replace IND = "YDC"      if SECTOR=="Corporations" & IND=="YD"
replace IND = "TPSOCfcC" if SECTOR=="Corporations" & IND=="TPSOCfc"
replace IND = "BPSOCfcC" if SECTOR=="Corporations" & IND=="BPSOCfc"
* Public consumption: CG in the government sector
replace IND = "CG" if SECTOR=="Government"    & IND=="C"
* Private transfers of households in total (BP), as in the age profiles.
* Transfers within households add up to zero, so the total equals BPB.
expand 2 if SECTOR=="Households" & IND=="BPB", gen(copy)
replace IND = "BP" if copy==1
drop copy

* Labels of the ESA sectors from Prog_ENTA_labels.do (the NTA aggregates were
* labelled in Section 5). Every published indicator must have a label.
preserve
keep if SECTOR=="NTA Aggregates"
tempfile pubnta
save `pubnta'
restore
drop if SECTOR=="NTA Aggregates"
drop INDICATOR
do ENTA_input_data/Prog_ENTA_labels.do esa
assert INDICATOR!=""
append using `pubnta'
isid CNT2 YEAR SECTOR IND
sort INDICATOR YEAR CNT2 SECTOR
* No capture: a CSV that cannot be written (open in Excel) must stop the
* run, not leave the old file in place
outsheet using ENTA_output_data/ENTA_aggregates.csv, delim(,) replace

* Aggregate output file, dta only - deliberate column order for readability
sort CNT2 YEAR INDICATOR SECTOR
order  COUNTRY CNT2 YEAR INDICATOR IND SECTOR
save "ENTA_output_data/ENTA_aggregates.dta", replace
