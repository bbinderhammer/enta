****************************************************************
* Information on the tax structure in each country based on Taxation Trends in Europe
****************************************************************
  
*************************************
* 1. Taxes by function
*************************************
  
* Download and read data

  * Tax revenue by economic function (DG TAXUD's REDISSTAT platform - a
  * separate SDMX 2.1 API from Eurostat's own, so the eurostatuse package
  * used by sibling Suppl_*.do files doesn't apply here; fetched directly
  * instead). Commented out, and not covered by the download switch in
  * ENTA_setup.do: the csv is provided with the code, and a new download would
  * overwrite the version used. Re-run manually to refresh; keeps a local copy
  * of the raw file in case the API changes shape or goes away.
  /*
    cd ENTA_input_data\Original_input_data
    copy "https://webgate.ec.europa.eu/taxation_customs/redisstat/api/dissemination/sdmx/2.1/data/tax_ec_func?format=SDMX-CSV" taxud_tax_ec_func_en.csv, replace
    cd $wkdir
  */

  clear
  import delimited using ENTA_input_data\Original_input_data/taxud_tax_ec_func_en.csv, delim(",")

  gen CNT2 = substr(geo,1,2)
  gen YEAR = time_period
  split ef, parse(:)
  drop ef
  rename ef1 ef
  * Match on the code only (same approach as ef above), not the combined
  * "code:label" string - robust to Eurostat tweaking the label text.
  split unit, parse(:)
  drop unit
  rename unit1 unit
  keep if unit=="MIO_EUR"
  gen VALAGGR = obs_value
 
* ENTA terminology of taxes by economic function (tax source) 

  gen FUNCTION = "TYEB" if ef=="LAB" // taxes on labour, inc from employment
  replace FUNCTION = "TYEE" if ef=="LEES" // taxes on labour, inc from employment, paid by employees
  replace FUNCTION = "TYER" if ef=="LEYRS" // taxes on labour, inc from employment, paid by employers 
  replace FUNCTION = "TB" if ef=="LNON"  // taxes on labour, inc from employment, paid by non-emploed
  //replace FUNCTION = "TA" if ef=="CAP" // taxes on capital total
  replace FUNCTION = "TYP" if ef=="KIH" // taxes on cpaital, income of households
  //replace FUNCTION = "TYAC" if ef=="KIC" // taxes on capital, income of corporations
  replace FUNCTION = "TYM" if ef=="KISE" // taxes on capital, income of selfemployed
  //replace FUNCTION = "TSA" if ef=="KS" // taxes on capital, stock of capital
  
  //replace FUNCTION = "TCON" if ef=="C:Taxes on consumption" // taxes on consumption
  //replace FUNCTION = "TPR" if ef=="PROP" // taxes on property

  keep if FUNCTION!=""
  
* Reshape and save the data

  keep CNT2 YEAR FUNCTION VALAGGR

  reshape wide VALAGGR, i(CNT2 YEAR) j(FUNCTION) string
  
  local variables "TYEB TB TYEE TYER TYP TYM" // TCON
  foreach var of local variables {
  	rename VALAGGR`var' `var'
  }
  
  sort CNT2 YEAR
  save ENTA_input_data\ENTA_input_datasets/taxstructure_wide, replace
    
