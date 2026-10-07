* Prepare HBS data for use in ENTA
*
* Output: $hbswd/HBS_[CNT2].dta, one file per country for HBS 2010 and 2015
*         (Austria: Konsumerhebung 2010 and 2015), one row per person.
*         Variables: CNT2 YEAR HHID HHSIZE HHTAG WEIGHT WEIGHTa AGEGR5 AGEGR15
*         (AGEGR3 for AT) SEX YDh YDCASHh YDCASH CH CHX CHH CHE CHR CHXSTD
*         CHHSTD CHESTD CHRSTD CON NCHILD14 PERC. For Austria WEIGHT, YDh and
*         YDCASHh are missing.
* Read by: ENTA_input_data/Micro_impute_cons_into_SILC.do and
*         ENTA_ageprofiles/ENTA_consumption_intrahousehold_transfers.do.
* Input:  $hbsin/HBS2010, HBS2015 (Eurostat HBS Excel files; HBS 2020 is not
*         used); $hbswd/HBS_AT_2010.dta and HBS_AT_2015.dta from
*         Micro_HBS_Austria.do, which must run first;
*         ENTA_input_data/ENTA_input_datasets/population_agegr15.dta
*         (Suppl_population.do); ENTA_aggregates/ENTA_aggregates.dta and
*         ENTA_aggregates/ENTA_units.dta (step 3 of the run order).
* Requires ENTA_setup_TU.do / ENTA_setup.do (globals $hbsin $hbswd, program
*         adjustaggr) and the user command sumdist (ssc install sumdist).
*
* Content
* 0. Helper programmes
* 1. Import Excel files, merge household and individual data (INACTIVE once
*    run: its output HBS1_[CNT2].dta only changes with the source data)
* 2. Generate needed variables

********************************************************************************
* 0. Helper programmes
********************************************************************************

* numvar: copy a variable as numeric, destringing it first if it is a string
* (the same column arrives as string in some countries, numeric in others)

capture program drop numvar
program define numvar
    args srcvar newvar
    capture confirm numeric variable `srcvar'
    if !_rc {
        clonevar `newvar' = `srcvar'
    }
    else {
        replace `srcvar' = "" if `srcvar'=="NA"
        destring `srcvar', gen(`newvar')
        * clonevar `newvar' = `newvar'num
        * drop `newvar'num
    }
end


********************************************************************************
* 1. Import EXCEL-files, merge household and individual data
********************************************************************************

* INACTIVE once run. The Excel import is slow and only needs rerunning when the
* source data change (new HBS delivery, different variables). Section 2 starts
* from the saved HBS1_[CNT2].dta. Uncomment this section to import again.

/*
* Country lists by which waves are available
  set excelxlsxlargefile on

  global country10       "BE BG CY CZ DE DK EE EL ES FI FR HR HU IE IT LT LU LV    PL PT RO SE SI SK" //
  global country15       "BE BG CY CZ DE DK EE EL ES FI FR HR HU IE IT LT LU LV NL PL PT RO SE SI SK"  //
  * [INACTIVE] HBS 2020 is not imported. Eurostat delivers it for most
  * countries, but it records age only as 0-14 ... 60+, and ENTA uses 2010 and
  * 2015. Austria (Eurostat HBS covers only 2020) uses the Konsumerhebung 2010
  * and 2015 instead (Section 2).
  //global country20       "AT"

  global countryall      "BE BG CY CZ DE DK EE EL ES FI FR HR HU IE IT LT LU LV          RO    SI SK" //  waves 2010+2015
  global country1015     "PL PT SE"   // waves 2010+2015
  global country1520     "NL"         // wave 2015 only
  //global country20only     "AT"


******************************
* 2010 HBS
******************************

//global country10 "PL"
foreach x in $country10 {

  clear
  import excel "$hbsin/HBS2010/`x'_HBS_hh.xlsx", firstrow
  numvar HA04 HHID
  drop if HHID==.
  sort HHID
  save "$hbswd/HBS_`x'_hh.dta", replace

  clear
  import excel "$hbsin/HBS2010/`x'_HBS_hm.xlsx", firstrow
  numvar MA04 HHID
  //browse MA04 HHID

  sort HHID
  merge m:1 HHID using $hbswd/HBS_`x'_hh.dta
  keep if _merge==3
  drop _merge

  * Weight
  numvar HA10 WEIGHT

  * Household income
  numvar EUR_HH095 YDCASHh
  numvar EUR_HH099 YDh

  save "$hbswd/HBS_`x'_2010.dta", replace
  erase "$hbswd/HBS_`x'_hh.dta"
}


*************************************
* 2015 HBS
*************************************

//global country15 "RO"
foreach x in $country15 {

  clear
  import excel "$hbsin/HBS2015/`x'_MFR_hh.xlsx", firstrow
  * HHID: numeric where available, otherwise strip the leading "H" and destring
  capture confirm numeric variable HA04
    if !_rc {
      clonevar HHID = HA04
    }
    else {
      replace HA04 = subinstr(HA04,"H","",1)
      destring HA04, gen(HA04num)
      clonevar HHID = HA04num
    }

  sort HHID
  save "$hbswd/HBS_`x'_hh.dta", replace

  clear
  import excel "$hbsin/HBS2015/`x'_MFR_hm.xlsx", firstrow
  capture confirm numeric variable MA04
    if !_rc {
      clonevar HHID = MA04
    }
    else {
      replace MA04 = subinstr(MA04,"H","",1)
      replace MA04 = "" if MA04=="NA"
      destring MA04, gen(MA04num)
      clonevar HHID = MA04num
    }

  sort HHID

  merge m:1 HHID using $hbswd/HBS_`x'_hh.dta
  keep if _merge==3
  drop _merge

  * Weight
  numvar HA10 WEIGHT

  * Household income
  numvar EUR_HH095 YDCASHh
  numvar EUR_HH099 YDh

  save "$hbswd/HBS_`x'_2015.dta", replace
  erase "$hbswd/HBS_`x'_hh.dta"
}


**********************************
* 2020 HBS
**********************************
* [INACTIVE] Not imported, see the country lists above.

//foreach x in $country20 {
//
//  clear
//  import excel "$hbsin/HBS2020/HBS_HH_`x'.xlsx", firstrow
//  numvar HA04 HHID
//
//  sort HHID
//  save "$hbswd/HBS_`x'_hh.dta", replace
//
//  clear
//  import excel "$hbsin/HBS2020/HBS_HM_`x'.xlsx", firstrow
//  numvar MA04 HHID
//
//  capture confirm numeric variable MB02
//   if _rc {
//      destring MB02, gen(MB02num)
//      drop MB02
//      rename MB02num MB02
//    }
//
//  sort HHID
//
//  merge m:1 HHID using $hbswd/HBS_`x'_hh.dta
//  keep if _merge==3
//  drop _merge
//
//  numvar HA10 WEIGHT
//  numvar EUR_HH095 YDCASHh
//  numvar EUR_HH099 YDh
//
//  save "$hbswd/HBS_`x'_2020.dta", replace
//  erase "$hbswd/HBS_`x'_hh.dta"
//
//}

********************************
* Combine all years for each country
********************************

* [INACTIVE] The 2020 appends/erases are commented out: HBS 2020 is not
* imported.

//global countryall "RO"
foreach x in $countryall {

  clear
  append using "$hbswd/HBS_`x'_2010.dta"
  append using "$hbswd/HBS_`x'_2015.dta", force
  //append using "$hbswd/HBS_`x'_2020.dta", force
  save "$hbswd/HBS1_`x'.dta", replace

  erase "$hbswd/HBS_`x'_2010.dta"
  erase "$hbswd/HBS_`x'_2015.dta"
  //erase "$hbswd/HBS_`x'_2020.dta"
}

  //browse EUR_HH095 EUR_HH099 YDh YDCASHh

foreach x in $country1015 {

  clear
  append using "$hbswd/HBS_`x'_2010.dta"
  append using "$hbswd/HBS_`x'_2015.dta", force
  save "$hbswd/HBS1_`x'.dta", replace

  erase "$hbswd/HBS_`x'_2010.dta"
  erase "$hbswd/HBS_`x'_2015.dta"

}

foreach x in $country1520 {

  clear
  append using "$hbswd/HBS_`x'_2015.dta", force
  //append using "$hbswd/HBS_`x'_2020.dta", force
  save "$hbswd/HBS1_`x'.dta", replace

  erase "$hbswd/HBS_`x'_2015.dta"
  //erase "$hbswd/HBS_`x'_2020.dta"

}


* [INACTIVE] Austria-only base file of HBS 2020, not built.
//foreach x in $country20only {
//
//  clear
//  append using "$hbswd/HBS_`x'_2020.dta"
//  gen MB03_Recoded_5YearsClasses = ""
//  save "$hbswd/HBS1_`x'.dta", replace
//  erase "$hbswd/HBS_`x'_2020.dta"
//}
*/


********************************************************************************
* 2. Generate needed variables
********************************************************************************

global country "AT BE DE BG CY CZ DK EE EL ES FI FR HR HU IE IT LT LU LV NL PL PT RO  SE SI SK" // "
* global country "SI" //  DE SE LT FR

foreach x in $country {

    * Austria uses the Konsumerhebung 2010 and 2015 (Micro_HBS_Austria.do) in
    * place of the Eurostat HBS, which for Austria covers only 2020. Those
    * files already hold ages, sex, household size, weights (WEIGHTa), income
    * (YDCASH) and consumption (CH CHX CHH CHE CHR), so the steps that build these
    * from the Eurostat variables are skipped. WEIGHT, YDh and YDCASHh do not
    * exist there and are set missing.
    if "`x'"=="AT" {
        use "$hbswd/HBS_AT_2015.dta", clear
        append using "$hbswd/HBS_AT_2010.dta"
        gen WEIGHT = .
        gen YDh = .
        gen YDCASHh = .
    }
    else {

        * Eurostat HBS, all other countries. This block (not indented) closes after
        * the consumption variables.

        use "$hbswd/HBS1_`x'.dta", clear
        * browse EUR_HH095 EUR_HH099 YDh YDCASHh

        * Country
        gen CNT2 = "`x'"

        * One row per household
        egen HHTAG = tag(YEAR HHID)

        * Five-year age group from the recoded class string
        gen AGEGR5 = 0 if MB03_Recoded_5YearsClasses=="0_4"
        replace AGEGR5 = 5 if MB03_Recoded_5YearsClasses=="5_9"
        replace AGEGR5 = 10 if MB03_Recoded_5YearsClasses=="10_14"
        replace AGEGR5 = 15 if MB03_Recoded_5YearsClasses=="15_19"
        replace AGEGR5 = 20 if MB03_Recoded_5YearsClasses=="20_24"
        replace AGEGR5 = 25 if MB03_Recoded_5YearsClasses=="25_29"
        replace AGEGR5 = 30 if MB03_Recoded_5YearsClasses=="30_34"
        replace AGEGR5 = 35 if MB03_Recoded_5YearsClasses=="35_39"
        replace AGEGR5 = 40 if MB03_Recoded_5YearsClasses=="40_44"
        replace AGEGR5 = 45 if MB03_Recoded_5YearsClasses=="45_49"
        replace AGEGR5 = 50 if MB03_Recoded_5YearsClasses=="50_54"
        replace AGEGR5 = 55 if MB03_Recoded_5YearsClasses=="55_59"
        replace AGEGR5 = 60 if MB03_Recoded_5YearsClasses=="60_64" | MB03_Recoded_5YearsClasses=="60_Inf" | MB03_Recoded_5YearsClasses=="60_inf"
        replace AGEGR5 = 65 if MB03_Recoded_5YearsClasses=="65_69"
        replace AGEGR5 = 70 if MB03_Recoded_5YearsClasses=="70_74"
        replace AGEGR5 = 75 if MB03_Recoded_5YearsClasses=="75_79"
        replace AGEGR5 = 80 if MB03_Recoded_5YearsClasses=="80_84" | MB03_Recoded_5YearsClasses=="85_Inf"
        * Portugal reports a single 75+ bucket ("75_Inf") instead of 75-79 / 80+.
        * Mapped to 75 (its lower bound), since a finer split is not possible from
        * the source. Without this, PT's entire 75+ population (~9.7% of records)
        * would have AGEGR5 missing.
        replace AGEGR5 = 75 if MB03_Recoded_5YearsClasses=="75_Inf"

        gen AGEGR15 = 0 if MB03_Recoded_5Classes=="0_14" // the only age variable available in 2020
        replace AGEGR15 = 15 if MB03_Recoded_5Classes=="15_29"
        replace AGEGR15 = 30 if MB03_Recoded_5Classes=="30_44"
        replace AGEGR15 = 45 if MB03_Recoded_5Classes=="45_59"
        replace AGEGR15 = 60 if MB03_Recoded_5Classes=="60_Inf" | MB03_Recoded_5Classes=="60_inf"

        * Sex
        gen SEX = MB02

        * Household size
        bysort YEAR HHID: gen HHSIZE = _N


        *******************************
        * Income
        *******************************

        * Cash disposable income. The delivered files have no household income for
        * IT 2010 and LU 2010 (variable absent) and IT 2015 (0 for every household),
        * so consumption (EUR_HE00) is used instead.
        replace YDCASHh = EUR_HE00 if CNT2=="IT" | (CNT2=="LU" & YEAR==2010)
        gen YDCASH = YDCASHh / HHSIZE

        * Drop the few households with no income (BE, CY, HR 2010: 16 households,
        * 38 persons). adjustaggr would otherwise set them to 0 and place them in the
        * lowest percentile. Dropped before the weights so the rest represent the
        * population.
        drop if missing(YDCASH)


        ***********************************
        * Population adjusted weights
        *************************************

        * WEIGHTa: survey weight scaled so each AGEGR15 group sums to the population
        bysort YEAR AGEGR15: egen double WEIGHTHBS = total(WEIGHT)
        merge m:1 CNT2 YEAR AGEGR15 using ENTA_input_data/ENTA_input_datasets/population_agegr15, ///
            keepusing(POP) keep(match) nogenerate
        gen ADJPOP = POP / WEIGHTHBS
        gen WEIGHTa = WEIGHT*ADJPOP
        drop WEIGHTHBS POP ADJPOP


        *******************************
        * Consumption
        *******************************

        * browse MB03* EUR_HH099
        * browse YDCASHh EUR_HH099 EUR_HH095 EUR_HH095 EUR_MF099 EUR_HH032 EUR_HE042 EUR_HE10 EUR_HE06

        gen CHR = EUR_HE042          // imputed rent / housing
        replace CHR = 0 if CHR==.
        gen CHH = EUR_HE06           // health
        gen CHE = EUR_HE10           // education
        gen CHX = EUR_HE00 - CHR - CHH - CHE   // all other consumption
        gen CH = EUR_HE00            // total consumption

    }  // end else: Eurostat HBS, countries other than AT


    * Scale income to the aggregate, Austria included
    adjustaggr YDCASH


    ***************************************
    * Other variables
    ***************************************

    * Children under 15 in the household
    bysort YEAR HHID: egen NCHILD14 = total(AGEGR15<15)

    * Income percentiles, per capita at household level.
    * Weighted with the household mean of WEIGHTa: WEIGHTa varies by member
    * (ADJPOP by age group) and the HHTAG member depends on the sort order, which
    * Stata breaks randomly, so the tagged member's own weight would move
    * households to a different percentile between runs.
    bysort YEAR HHID: egen double WEIGHTh = mean(WEIGHTa)

    gen PERC = .
    sum YEAR
    forvalues y = `r(min)'(5)`r(max)' {
        sumdist YDCASH [aw=WEIGHTh] if YEAR==`y' & HHTAG==1, ng(100) qgp(PERC1)
        replace PERC = PERC1 if PERC==. & YEAR==`y' & HHTAG==1
        drop PERC1
    }
    drop WEIGHTh

    * Consumption scaled to the aggregate, so any year can be used to estimate
    * the age profiles.
    local variables "CHX CHH CHE CHR"
    foreach var of local variables {
        * Household consumption is the same on every member. Scale it to the
        * aggregate with the household's mean WEIGHTa: divide by HHSIZE so
        * the weighted sum over persons in adjustaggr equals household consumption
        * x mean WEIGHTa, then multiply back.
        replace `var' = `var' / HHSIZE
        adjustaggr `var'
        replace `var' = `var' * HHSIZE
    }

    * Standardise consumption by average consumption per capita (CHXavg).
    * CHXesa and POPtot come from ENTA_units.dta.
    sort CNT2 YEAR
    merge m:1 CNT2 YEAR using ENTA_aggregates/ENTA_units, keepusing(CHXesa POPtot)
    keep if _merge==3
    drop _merge
    gen CHXavg = CHXesa * 1000000 / POPtot

    foreach var of local variables {
        gen `var'STD = `var' / CHXavg
    }
    drop CHXavg CHXesa POPtot   // internal only; the CH* keep below would
    * otherwise pull these into HBS_`x'.dta

    gen CON = 1 // marks consumption-survey observations

    * browse  CNT2 YEAR HHID HHSIZE WEIGHT AGEGR* SEX  YDCASH CH*
    * rename YD YDHH
    keep CNT2 YEAR HHID HHSIZE HHTAG WEIGHT* AGEGR* SEX  YDh YDCASHh YDCASH CH* CON NCHILD* PERC
    save "$hbswd/HBS_`x'.dta", replace
}
