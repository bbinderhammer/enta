********************************************************************************
* UN population data - single age, by sex, ENTA countries only, 1995 onward
********************************************************************************

* Source: UN Population Division Data Portal API, indicator 47 ("Population
* by 1-year age groups and sex"), filtered to just ENTA's 26 countries and
* 1995 onward - scoped this way (not the whole world, all years) so a
* local copy is practical to keep in the project at all.
*
* Requires a free API token (valid 1 year - request a new one before it
* expires by emailing population@un.org, subject "Data Portal Token
* Request"). The token itself is NOT stored in this file - it lives in
* ENTA_input_data/Original_input_data/un_api_token.txt (gitignored, not
* published) and is read at runtime.
*
* Commented out, and not covered by the download switch in ENTA_setup.do:
* the API needs a personal token, and population_UN.dta is provided with the
* code instead. Re-run manually to refresh. The raw downloaded CSV is deleted
* again right after processing (it carries ~17 projection variants for the
* most recent 1-2 years, so it is much larger than the ~3MB processed output),
* so this whole block must be re-run together rather than split into a
* download step and a separately-runnable processing step.

/*
* Download and process UN population data (re-run manually to refresh)

  local tokenfile "ENTA_input_data/Original_input_data/un_api_token.txt"
  file open tf using "`tokenfile'", read text
  file read tf token
  file close tf

  * ENTA's 26 countries, as UN Data Portal numeric location Ids (same order
  * as $country elsewhere in the project: AT BE BG CY CZ DE DK EE EL ES FI
  * FR HR HU IE IT LT LU LV NL PL PT RO SE SI SK)
  local locs "40,56,100,196,203,276,208,233,300,724,246,250,191,348,372,380,440,442,428,528,616,620,642,752,705,703"

  * Stata's copy command can't send a custom Authorization header, so shell
  * out to curl (built into Windows 10+) instead.
  cd ENTA_input_data\Original_input_data
  shell curl -s -H "Authorization: Bearer `token'" "https://population.un.org/dataportalapi/api/v1/data/indicators/47/locations/`locs'/start/1995/end/2025?format=csv" -o population_UN_raw.csv
  cd $wkdir

  * varnames(2): the API's CSV starts with a "sep =|" hint line (row 1),
  * real headers are row 2 - rows before the header row are skipped
  * automatically.
  import delimited using ENTA_input_data/Original_input_data/population_UN_raw.csv, ///
      delimiter("|") varnames(2) clear

  * Keep only the historical/best-estimate variant. Years up to the WPP
  * revision's latest actual-data year have just one variant (Median);
  * years beyond that add dozens of projection scenarios (low/high/
  * constant-fertility/etc.) under the same Iso2/Year/Sex/Age - this filter
  * keeps the result to one row per combination regardless of where that
  * boundary currently falls.
  keep if variant=="Median"

  rename iso2 CNT2
  * Eurostat (and the rest of this project) uses EL for Greece, not the ISO
  * 3166-1 code GR the UN API returns - the one country where they diverge
  * within ENTA's scope.
  replace CNT2 = "EL" if CNT2=="GR"
  rename agestart AGE
  * timelabel comes in already numeric on some pulls, as a string on
  * others - handle either case rather than assuming one.
  capture confirm string variable timelabel
  if !_rc {
      destring timelabel, replace
  }
  rename timelabel YEAR
  rename value POPun

  gen SEX=0 if sex=="Both sexes"
  replace SEX=1 if sex=="Male"
  replace SEX=2 if sex=="Female"

  keep CNT2 YEAR SEX AGE POPun
  sort CNT2 YEAR SEX AGE
  save ENTA_input_data\Original_input_data\population_UN, replace

  erase ENTA_input_data/Original_input_data/population_UN_raw.csv
*/
