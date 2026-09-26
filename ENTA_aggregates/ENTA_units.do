*******************************************************************************
* Generate standardisation units for comparing ENTA data
*
* Content:
*   1. Total population
*   2. Other data (HICP, exchange rates, primary income, GDP)
*   3. Combine and save
*
* Reads aggregates and supplementary data only, no age profile, so it runs
* right after ENTA_aggregates_compilation.do. The NTA and ENTA norms are
* averages of the income age profile and are therefore NOT built here:
* ENTA_compilation1_esa.do (Section 5) adds them to this file and publishes
* the result as ENTA_output_data/ENTA_units (dta, csv).
*
* Each saved variable feeds one specific unit choice in the ENTA dataexplorer:
*   Y, POPtot                   -> "Percent of primary inc."
*                                   (Y/POPtot*1e6 = per-capita primary income, total economy)
*   YH, POPtot                  -> "Percent of household prim. inc."
*                                   (YH/POPtot*1e6 = per-capita primary income, households)
*   GDP, POPtot                 -> "Percent of GDP"
*   CHXesa, POPtot               -> CHXavg = CHXesa/POPtot*1e6, used to
*                                   standardise consumption data across years
*                                   for changes in price/income levels
*                                   (Micro_HBS.do, Micro_impute_cons_into_
*                                   SILC.do, ENTA_consumption_intrahousehold_
*                                   transfers.do)
*   EXR_NAC_EUR, HICP, EXR_2020 -> "Euro p.c., real (HICP, 2020=100)"
*   PPP_EUR                     -> "PPS-Euro per capita"
*   PPP_EUR_2020                -> "PPS-Euro per capita, real (2020=100)"
*
* Output: ENTA_aggregates/ENTA_units.dta (internal, without the norms)
********************************************************************************


********************************************************************************
* 1. Total population
********************************************************************************

  use ENTA_input_data\ENTA_input_datasets\population80w, clear
  keep if YEAR>=1995

* population80w covers many non-ENTA countries/territories too - restrict to
* ENTA's own 26 countries. Section 3 keeps only the countries found here, so
* this list is what makes ENTA_units EU-only. (inlist() is capped at 10
* arguments for strings, hence the OR-chain.)
  keep if CNT2=="AT" | CNT2=="BE" | CNT2=="BG" | CNT2=="CY" | CNT2=="CZ" | ///
    CNT2=="DE" | CNT2=="DK" | CNT2=="EE" | CNT2=="EL" | CNT2=="ES" | ///
    CNT2=="FI" | CNT2=="FR" | CNT2=="HR" | CNT2=="HU" | CNT2=="IE" | ///
    CNT2=="IT" | CNT2=="LT" | CNT2=="LU" | CNT2=="LV" | CNT2=="NL" | ///
    CNT2=="PL" | CNT2=="PT" | CNT2=="RO" | CNT2=="SE" | CNT2=="SI" | ///
    CNT2=="SK"

* Named POPtot, not POP, because every consumer of this file already has its
* own age-specific POP - merging in a second "POP" for the country total
* would either collide or silently divide by the wrong population.
  collapse (sum) POPtot = POP, by(CNT2 YEAR)
  label variable POPtot "Total population, all ages (from population80w)"

  tempfile pop
  save `pop'

********************************************************************************
* 2. Other data (HICP, exchange rates, GDP and primary income)
********************************************************************************
* Starts fresh from the exchange-rate data; section 1 is merged on in
* section 3.

  use ENTA_input_data/ENTA_input_datasets/ppp_exchange_rates, clear

    * CPI
	sort CNT2 YEAR 
	merge 1:1 CNT2 YEAR using ENTA_input_data/ENTA_input_datasets/hicp
	keep if _merge==3
	drop _merge
	
   * Add primary income (kept as raw aggregates - consumers divide by POPtot
   * themselves for a per-capita or percentage figure)
    gen SECTOR="Households"
    gen IND="Y"
    sort CNT2 YEAR SECTOR IND
    merge 1:1 CNT2 YEAR SECTOR IND using ENTA_aggregates\ENTA_aggregates
    keep if _merge==3
    drop _merge IND SECTOR
	rename VALAGGR YH
	label variable YH "Primary income, household sector - ESA aggregate, million EUR (not per capita)"

    gen SECTOR="Total economy"
    gen IND="Y"
    sort CNT2 YEAR SECTOR IND
    merge 1:1 CNT2 YEAR SECTOR IND using ENTA_aggregates\ENTA_aggregates
    keep if _merge==3
    drop _merge IND SECTOR
	rename VALAGGR Y
	label variable Y "Primary income, total economy - ESA aggregate, million EUR (not per capita)"

    gen SECTOR="Total economy"
    gen IND="GDP"
    sort CNT2 YEAR SECTOR IND
    merge 1:1 CNT2 YEAR SECTOR IND using ENTA_aggregates\ENTA_aggregates
    keep if _merge==3
    drop _merge IND SECTOR
	rename VALAGGR GDP
	label variable GDP "GDP, total economy - ESA aggregate, million EUR (not per capita)"

    gen SECTOR="Households"
    gen IND="CHX"
    sort CNT2 YEAR SECTOR IND
    merge 1:1 CNT2 YEAR SECTOR IND using ENTA_aggregates\ENTA_aggregates
    keep if _merge==3
    drop _merge IND SECTOR
	rename VALAGGR CHXesa
	label variable CHXesa "Total consumption, other, household sector - ESA aggregate, million EUR (not per capita)"

	label variable HICP "Harmonised index of consumer prices, 2020=100"
	label variable PPP_EU27_2020 "Raw Eurostat PPP index, EU27=2020 basis (intermediate input for PPP_EUR)"


********************************************************************************
* 3. Combine and save
********************************************************************************

  sort CNT2 YEAR
  merge 1:1 CNT2 YEAR using `pop'

  * DO NOT relax this to "drop if _merge==2". Section 2 above starts from
  * ppp_exchange_rates, which carries non-ENTA reporting units (AL, IS, TR,
  * MT, EA21 ...); `pop' holds the 26 EU countries only, so requiring a match
  * is what keeps the file EU-only. 2024 is kept: every country with 2024
  * aggregates (all but BG) has a 2024 row.
  keep if _merge==3
  drop _merge

  keep CNT2 YEAR Y YH GDP CHXesa POPtot EXR_NAC_EUR EXR_2020 HICP PPP_EUR PPP_EUR_2020 PPP_EU27_2020
  sort CNT2 YEAR

  save ENTA_aggregates/ENTA_units, replace
