********************************************************************************
* Private consumption by COICOP
********************************************************************************

  if "$download"=="1" {
    cd ENTA_input_data\Original_input_data
	
    eurostatuse  nama_10_co3_p3, noflags clear 
    save nama_10_co3_p3, replace
	
    cd "$wkdir"
  }
  
    local lyear = 2024 // latest year
    clear

    use ENTA_input_data\Original_input_data/nama_10_co3_p3, clear
    keep if unit=="CP_MEUR" 
    keep if coicop=="CP042" | coicop=="CP06" | coicop=="CP10" | coicop=="TOTAL"
  
  **************************	
  * Make years to a variable (original each year as variable)
  **************************
  
	tempfile data
    save `data'
    forvalues y=1995/`lyear' {
      use `data', clear
      keep unit unit_label coicop coicop_label geo geo_label nama_10_co3_p3`y'
	  rename nama_10_co3_p3`y' NA
	  gen year = `y'
	  tempfile na`y'
	  save `na`y''
    }
	clear
    forvalues y=1995/`lyear' {
      append using `na`y''
    }
	
  
  * Make COICOP categories to variable
    local coicop "CP042 CP06 CP10"
	foreach cat of local coicop {
		preserve
		keep if coicop=="`cat'"
		rename NA `cat'
		sort geo year
		tempfile `cat'
		save ``cat''
		restore
	}
		
	keep if coicop=="TOTAL"
	rename NA CP00
	sort geo year
	merge 1:1 geo year using `CP06'
    drop _merge
	sort geo year
	merge 1:1 geo year using `CP10'
    drop _merge
	sort geo year
	merge 1:1 geo year using `CP042'
    drop _merge
	
	rename geo CNT2
	rename year YEAR
	keep CNT2 YEAR CP00 CP06 CP10 CP042
	sort CNT2 YEAR

  * Replace strings in the data. eurostatuse's current output already
  * stores these as clean numeric values (flags stripped at import) - guard
  * against that rather than assume string, so this still works if a future
  * eurostatuse version leaves flagged values as text instead.
	local variables "CP00 CP06 CP10 CP042"
	foreach var of local variables {
		capture confirm string variable `var'
		if !_rc {
			replace `var'="" if `var'==": "
			destring `var', ignore("p" ": " "e" ": @C") replace
		}
	}

  * Impute 2023 and 2024 where Eurostat has not published them yet: the
  * previous year's value grows with household consumption at basic prices
  * (Cb, sector S14_S15) from esa_aggregates. Carrying the last value forward
  * unchanged would freeze imputed rent (CHR = CP042) at its 2022 level while
  * all other consumption grew.
  * Applied per variable, so a published value is never
  * touched and a partly published year only fills its gaps; 2024 builds on
  * the (possibly imputed) 2023 value. Shares of CP00 are therefore kept at
  * the last published year.
  * REQUIRES esa_aggregates.dta: run Aggr_ESA2010.do before this file.

	fillin CNT2 YEAR
	drop _fillin

	preserve
	  use CNT2 YEAR sector Cb using ENTA_input_data\ENTA_input_datasets/esa_aggregates, clear
	  keep if sector=="S14_S15"
	  drop sector
	  tempfile cb
	  save `cb'
	restore
	merge 1:1 CNT2 YEAR using `cb', keep(master match) nogen

	sort CNT2 YEAR
	foreach y in 2023 2024 {
	  foreach var in CP00 CP06 CP10 CP042 {
	    by CNT2: replace `var' = `var'[_n-1] * Cb / Cb[_n-1] ///
	      if YEAR==`y' & YEAR[_n-1]==`y'-1 & missing(`var')
	  }
	}
	drop Cb

	save ENTA_input_data\ENTA_input_datasets/consumption_hh_coicop, replace
	
