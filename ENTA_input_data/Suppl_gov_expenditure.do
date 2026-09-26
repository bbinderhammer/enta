********************************************************************************
* Government expenditure by function and type
********************************************************************************

* Input:  Eurostat gov_10a_exp
* Output: ENTA_input_data\ENTA_input_datasets\gov_expenditure.dta

********************************************************************************
* 0. Load data
********************************************************************************

  if "$download"=="1" {
  * Government finance statistics
    cd ENTA_input_data\Original_input_data
    eurostatuse gov_10a_exp, noflags clear
    save gov_10a_exp, replace
    cd "$wkdir"
  }

use "ENTA_input_data/Original_input_data/gov_10a_exp", clear

keep if sector == "S13" & unit == "MIO_EUR" ///
    & inlist(na_item, "D62", "P3", "D62_D632")

keep if inlist(cofog99, "TOTAL", "GF07", "GF0701", "GF0702", "GF0703", ///
    "GF09", "GF0901", "GF0902", "GF0903") ///
    | inlist(cofog99, "GF0904", "GF10", "GF1001", "GF1002", "GF1003", ///
    "GF1004", "GF1005", "GF1006", "GF1007") ///
    | inlist(cofog99, "GF1008", "GF1009")

********************************************************************************
* 1. Reshape wide years to long
********************************************************************************

reshape long gov_10a_exp, i(cofog99 geo na_item) j(year)
rename gov_10a_exp NA_str
rename geo CNT2
rename year YEAR

* Clean and convert to numeric. eurostatuse stores the values as numbers with
* the flags stripped at import; older downloads were strings carrying flags
* such as ": m". Handle both - flagged-missing and plain ":" both end up as
* missing either way.
capture confirm string variable NA_str
if !_rc {
  destring NA_str, ignore(":" "m" "b" "p" "n" " ") gen(NA)
  drop NA_str
}
else {
  rename NA_str NA
}

* Drop country-years with no data at all except Slovakia 2008 and 2009
bysort YEAR CNT2: egen yearmiss = count(NA)
drop if yearmiss == 0 & !(CNT2=="SK" & inlist(YEAR, 2008, 2009))
drop yearmiss

keep cofog99 CNT2 YEAR na_item NA
sort CNT2 cofog99 YEAR

********************************************************************************
* 2. Reshape indicators to variables
********************************************************************************

* Variable name for each cofog99 x na_item combination

gen varname = ""

* --- Total ---
replace varname = "BScofog"  if cofog99 == "TOTAL"    & na_item == "D62"
replace varname = "BScofoga" if cofog99 == "TOTAL"    & na_item == "D62_D632"
replace varname = "CGcofog"  if cofog99 == "TOTAL"    & na_item == "P3"

* --- Education ---
replace varname = "BSE"      if cofog99 == "GF09"     & na_item == "D62"
replace varname = "BSEa"     if cofog99 == "GF09"     & na_item == "D62_D632"
replace varname = "CGE"      if cofog99 == "GF09"     & na_item == "P3"
replace varname = "CGEPP"    if cofog99 == "GF0901"   & na_item == "P3"
replace varname = "CGESEC"   if cofog99 == "GF0902"   & na_item == "P3"
replace varname = "CGEPSEC"  if cofog99 == "GF0903"   & na_item == "P3"
replace varname = "CGETER"   if cofog99 == "GF0904"   & na_item == "P3"

* --- Health (GF07 only for D62/D62_D632; GF07+GF1001 for P3) ---
* BSH is kept for reference only; it is part of the residual BSX (section 5)
replace varname = "BSH"      if cofog99 == "GF07"     & na_item == "D62"
replace varname = "BSHa"     if cofog99 == "GF07"     & na_item == "D62_D632"
* CGH = GF07 P3 + GF1001 P3 (summed in the collapse below)
replace varname = "CGH"      if cofog99 == "GF07"     & na_item == "P3"
replace varname = "CGH"      if cofog99 == "GF1001"   & na_item == "P3"
replace varname = "CGHOUT"   if inlist(cofog99, "GF0701", "GF0702") & na_item == "P3"
replace varname = "CGHIN"    if cofog99 == "GF0703"   & na_item == "P3"

* --- Sickness and disability ---
replace varname = "BSD"      if cofog99 == "GF1001"   & na_item == "D62"
replace varname = "BSDa"     if cofog99 == "GF1001"   & na_item == "D62_D632"

* --- Old age ---
replace varname = "BSOA"     if cofog99 == "GF1002"   & na_item == "D62"
replace varname = "BSOAa"    if cofog99 == "GF1002"   & na_item == "D62_D632"
replace varname = "CGOA"     if cofog99 == "GF1002"   & na_item == "P3"

* --- Survivor ---
replace varname = "BSS"      if cofog99 == "GF1003"   & na_item == "D62"
replace varname = "BSSa"     if cofog99 == "GF1003"   & na_item == "D62_D632"
replace varname = "CGS"      if cofog99 == "GF1003"   & na_item == "P3"

* --- Family ---
replace varname = "BSF"      if cofog99 == "GF1004"   & na_item == "D62"
replace varname = "BSFa"     if cofog99 == "GF1004"   & na_item == "D62_D632"
replace varname = "CGF"      if cofog99 == "GF1004"   & na_item == "P3"

* --- Unemployment ---
replace varname = "BSU"      if cofog99 == "GF1005"   & na_item == "D62"
replace varname = "BSUa"     if cofog99 == "GF1005"   & na_item == "D62_D632"
replace varname = "CGU"      if cofog99 == "GF1005"   & na_item == "P3"

* --- Other social protection (GF1006-GF1009) ---
* BSX is replaced by the residual in section 5
replace varname = "BSX"  if inlist(cofog99,"GF1006","GF1007","GF1008","GF1009") & na_item == "D62"
replace varname = "BSXa" if inlist(cofog99,"GF1006","GF1007","GF1008","GF1009") & na_item == "D62_D632"
replace varname = "CGSX" if inlist(cofog99,"GF1006","GF1007","GF1008","GF1009") & na_item == "P3"

drop if varname == ""

* Collapse groups that need summing (CGH, CGHOUT, BSX, BSXa, CGSX)
preserve
  collapse (sum) NA if inlist(varname, "CGH", "CGHOUT", "BSX", "BSXa", "CGSX"), by(CNT2 YEAR varname)
  tempfile coll
  save `coll'
restore
drop if inlist(varname, "CGH", "CGHOUT", "BSX", "BSXa", "CGSX")
keep NA CNT2 YEAR varname
append using `coll'

* Reshape to wide
reshape wide NA, i(CNT2 YEAR) j(varname) string

* Clean up variable names (remove "NA" prefix)
rename NA* *

********************************************************************************
* 3. Replace missing values
********************************************************************************

* Bulgaria: set missing values to zero
replace BSE     = 0 if CNT2=="BG" & BSE==.
replace BSEa    = 0 if CNT2=="BG" & BSEa==.
replace BSH     = 0 if CNT2=="BG" & BSH==.
replace CGEPSEC = 0 if CNT2=="BG" & CGEPSEC==.
replace CGS     = 0 if CNT2=="BG" & CGS==.

* DE, PL, PT: impute missing D62 from D62_D632, using the ratio D62/D62_D632
* of a reference year (DE, PL: 2012; PT: 1999)
local bs_vars "BScofog BSE BSH BSD BSS BSOA BSF BSU BSX"
foreach ind of local bs_vars {
    gen `ind'sh1 = .
    replace `ind'sh1 = `ind' / `ind'a if inlist(CNT2, "DE", "PL") & YEAR == 2012
    replace `ind'sh1 = `ind' / `ind'a if CNT2 == "PT" & YEAR == 1999
    bysort CNT2: egen `ind'sh = max(`ind'sh1)
    drop `ind'sh1
}

* Years without breakdown by function
gen imp = inlist(CNT2, "DE", "PL", "PT") & BSOA==. & YEAR>=2000

* Components from 2000. BSX (GF1006-GF1009) is 0 instead of missing after the
* collapse in section 2, so it is imputed in the years flagged above.
local bs_sub "BSH BSD BSS BSOA BSF BSU BSE"
foreach ind of local bs_sub {
    replace `ind' = `ind'a * `ind'sh if inlist(CNT2, "DE", "PL", "PT") & `ind'==. & YEAR>=2000
}
replace BSX = BSXa * BSXsh if imp

* Total: D62_D632 minus the D632 part of each imputed function, so that total
* and components are consistent. A single ratio for the total does not fit:
* D632 (mainly health in kind) grows as a share of D62_D632, so the 2012 ratio
* understates the total in earlier years (PL 2001: by about 900 mio EUR).
* Ratio of the total only where the components are missing (before 2000).
replace BScofog = BScofoga - (BSOAa - BSOA) - (BSSa - BSS) - (BSDa - BSD) ///
    - (BSFa - BSF) - (BSUa - BSU) - (BSEa - BSE) - (BSHa - BSH) - (BSXa - BSX) ///
    if inlist(CNT2, "DE", "PL", "PT") & BScofog==.
replace BScofog = BScofoga * BScofogsh if inlist(CNT2, "DE", "PL", "PT") & BScofog==.

* Drop temporary variables
drop *sh imp

********************************************************************************
* 4. Imputation for Slovakia
********************************************************************************

* Slovakia has no COFOG-by-function breakdown of government expenditure for
* 2008/2009 (Eurostat's gov_10a_exp does not cover SK before 2010). The BS
* variables get rescaled to the ESA aggregate anyway in
* ENTA_aggregates_compilation.do (section 1.3), so a precise imputation here
* isn't needed - simply carry SK's 2010 values back to 2008 and 2009 as a
* placeholder input for that later rescaling step.

preserve
  keep if CNT2=="SK" & YEAR==2010
  expand 2
  bysort CNT2: gen _rep = _n
  replace YEAR = 2008 if _rep==1
  replace YEAR = 2009 if _rep==2
  drop _rep
  tempfile sk0809
  save `sk0809'
restore

* Section 1 keeps all-missing rows for Slovakia 2008/2009 - drop them now so
* the imputed rows are the only ones, not duplicates.
drop if CNT2=="SK" & inlist(YEAR,2008,2009)

append using `sk0809'
sort CNT2 YEAR

********************************************************************************
* 5. Corrections, residual BSX and save
********************************************************************************

* Ireland: shift from secondary to primary education in 2022; use shares from 2021
gen CGEPPSEC = CGESEC + CGEPP
replace CGESEC = CGEPPSEC * 40/84 if CNT2=="IE" & YEAR>=2022
replace CGEPP  = CGEPPSEC * 44/84 if CNT2=="IE" & YEAR>=2022
drop CGEPPSEC

* Other social benefits (BSX): residual of COFOG TOTAL D62 after old age,
* survivors, sickness/disability, family, unemployment and education. It
* contains:
*   GF07          health (BSH, not used separately downstream)
*   GF1006-GF1009 housing, social exclusion n.e.c., R&D, social protection n.e.c.
*   D62 recorded under all other functions (e.g. up to 1.1 bn EUR a year in BE,
*   4-6 bn in DE since 2012)
* The residual can be slightly negative by rounding (BG 2009/2015, -0.1) and
* is set to zero there; ENTA_aggregates_compilation.do rescales all
* components to the ESA aggregate BS.
replace BSX = BScofog - (BSOA + BSS + BSF + BSU + BSE + BSD)
replace BSX = 0 if BSX<0

sort CNT2 YEAR
save "ENTA_input_data/ENTA_input_datasets/gov_expenditure", replace
