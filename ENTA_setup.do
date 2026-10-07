
********************************************************************************
* Setup for ENTA calculation: directories and programs

* Content
* 1. Define directories
* 2. Adjust microdata to aggregates: adjustaggr [varlist]
* 3. Adjustment of age-profiles to aggregates: adjust [list of variables]
* 4. Adjustment of gender-specific profiles to total profile (f+m): adjustgender [list of variables]
* 5. Adjustment of selected profile to aggregates from defined sector: adjustsec [profile (to which) aggregate (from) sector]
* 6. Total, male and female version of a new variable: gensex [newvar expression]

* Software (versions used for V.2.0.0, recorded 2026-10-02)
*   Stata/SE 19.0 (revision 03 Jun 2026), Windows 64-bit.
*   User-written Stata commands:
*     supsmooth 1.0.1 (16 June 2015)  age-profile smoothing     ssc install supsmooth
*     sumdist 1.0.1 (STB-48 sg104)    income percentiles        net install sg104, from(http://www.stata.com/stb/stb48)
*     eurostatuse (no version number; Eurostat downloads, only with download 1)
*                                                               ssc install eurostatuse
*   R 4.6.1 for 2026_ENTA_Manual_V_2_0_0/Manual_quality_tables.R (base R only).
*   The microdata versions are listed in README.md and in the manual
*   ("Data versions").

********************************************************************************
* 1. Define directories
********************************************************************************

************************************************************
* WHAT YOU NEED TO ENTER
*
* Edit ONLY the lines marked "<<SET ...>>" below. Everything else in this file
* (the programs from Section 2 on) works as it is. Use full paths, without a
* trailing backslash.
*
*   Global    What it is                                  Needed for
*   --------  ------------------------------------------  ----------------------
*   wkdir     The ENTA folder (contains this file).       Everything. Optional:
*                                                         defaults to the folder
*                                                         Stata is started in.
*   silcin    Original EU-SILC cross-sectional data       Micro_SILC.do
*             from Eurostat (read only).
*   silcwd    Empty working folder for processed SILC.    Micro_SILC.do and every
*                                                         file that reads SILC.
*   hbsin     Original Household Budget Survey data       Micro_HBS.do
*             from Eurostat (read only).
*   hbswd     Empty working folder for processed HBS.     Micro_HBS.do, Micro_
*                                                         impute_cons_into_SILC.do
*   lfsin     Original Labour Force Survey data           Micro_LFS.do
*             from Eurostat (read only).
*   lfswd     Empty working folder for processed LFS.     Micro_LFS.do,
*                                                         ENTA_employment.do
*   emodwd    Working folder for EUROMOD results.         Micro_EUROMOD.do
*   emodout   Folder with the raw EUROMOD output          Micro_EUROMOD.do,
*             files (.txt, one per country and year).     Section 0 only
*   cesin     Austrian consumption survey (Konsumerhebung)  Micro_HBS.do,
*             from Statistics Austria; must hold the      Austria only
*             subfolders nta2010\data and nta2015\data.
*   download  1 = download the Eurostat tables again,     Suppl_*.do,
*             0 = use the stored copies (default).        Aggr_ESA2010.do
*
* You only need to fill in the globals for the steps you actually run. The
* microdata (SILC, HBS, LFS, EUROMOD, Konsumerhebung) are licensed and are NOT
* part of this repository: request them from Eurostat / Statistics Austria /
* the EUROMOD team. The "...in" folders are only ever READ by this code; all
* files the code writes go to the matching "...wd" folder or to the ENTA
* folder. Point the "...wd" folders at a location you can write to.
************************************************************

* Working directory that contains the ENTA file structure (this file's folder).
* Leave the next line as it is to use the folder Stata was started in, or
* replace "`c(pwd)'" by your path, e.g. "C:\projects\ENTA".
if "$wkdir"=="" global wkdir "`c(pwd)'"
cd "$wkdir"
capture confirm file "ENTA_compilation1_esa.do"
if _rc {
    display as error "ENTA_setup.do: $wkdir is not the ENTA folder (ENTA_compilation1_esa.do not found)."
    display as error "Start Stata in the ENTA folder or set global wkdir above."
    exit 601
}

* Output folders. Git does not store empty folders, so a fresh copy of the
* repository lacks them, and the first save into them would fail.
cap mkdir "ENTA_output_data"
cap mkdir "ENTA_ageprofiles/ageprofiles"

* EU-SILC
global silcin "<<SET: folder with the original EU-SILC files>>"
global silcwd "<<SET: empty working folder for processed SILC data>>"

* HBS
global hbsin  "<<SET: folder with the original HBS files>>"
global hbswd  "<<SET: empty working folder for processed HBS data>>"

* LFS
global lfsin  "<<SET: folder with the original LFS files>>"
global lfswd  "<<SET: empty working folder for processed LFS data>>"

* EUROMOD
global emodwd  "<<SET: working folder for EUROMOD results>>"
global emodout "<<SET: folder with the raw EUROMOD output files>>"

* Austrian consumption survey (Konsumerhebung), provided by Statistics
* Austria; holds the nta2010\data and nta2015\data subfolders with ces_orig.
* Only needed for Austria.
global cesin  "<<SET: folder with the Konsumerhebung, Austria only>>"

* Supplementary data (output of Suppl_*.do scripts) - relative to wkdir,
* do not change.
global supplout "ENTA_input_data/ENTA_input_datasets"

* Eurostat downloads. 0 (default): use the tables already stored in
* ENTA_input_data\Original_input_data. 1: download them again with the
* eurostatuse package (needs an internet connection) and overwrite the
* stored copies. Eurostat revises its tables, so a new download will not
* reproduce the published ENTA exactly; the manual lists the download date
* of every table used for the published version. Not covered by the
* switch: the World Bank CPI, the DG TAXUD tax data and the UN population
* data, which are stored in the repository.
global download 0

* The CSV exports are compressed for Zenodo with Stata's built-in zipfile,
* so no external archiver is needed (see ENTA_compilation1_esa.do).

* Report the globals that are still unset, so a missing path is seen here and
* not as a cryptic "file not found" hours into a run. This is a note, not an
* error: you only need the paths of the steps you actually run.
foreach g in silcin silcwd hbsin hbswd lfsin lfswd emodwd emodout cesin {
    if strpos("${`g'}", "<<SET")>0 display as text "ENTA_setup.do: global `g' is not set (only needed if you run the step listed in Section 1)."
}


********************************************************************************
* 2. Adjustment of microdata to aggregates: adjustaggr [varlist]
********************************************************************************

* Adjustment of microdata to aggregate
capture program drop adjustaggr
program define adjustaggr
    syntax namelist
    local variables `namelist'

    capture gen SECTOR = "Households"

    foreach var of local namelist {
        display("`var'")

        * Aggregate values based on microdata
        gen `var'POP1 = `var'*WEIGHTa
        bysort CNT2 YEAR: egen `var'POP = sum(`var'POP1)
        drop `var'POP1

        * Aggregates from ESA
        gen IND = "`var'"
        sort CNT2 YEAR SECTOR IND
        merge m:1 CNT2 YEAR SECTOR IND using ENTA_aggregates/ENTA_aggregates, ///
            keepusing(VALAGGR) keep(match) nogenerate

        * Rescale
        gen `var'esa = VALAGGR*1000000

        gen a`var' = `var' * `var'esa / `var'POP if `var'POP!=0
        replace a`var' = 0 if a`var'==.
        replace `var' = a`var'
        drop IND `var'POP* VALAGGR a`var' `var'esa
    }
    drop SECTOR
end

*****************************************
* 3. Adjustment of age-profiles to aggregates: adjust [list of variables]
*****************************************

* Adjustment to aggregates for household sector
capture program drop adjust
program define adjust
    syntax namelist
    local variables `namelist'

    capture gen SECTOR = "Households"
    foreach var of local namelist {

        capture gen IND = "`var'"
        display("`var'")
        sort CNT2 YEAR SECTOR IND
        merge m:1 CNT2 YEAR SECTOR IND using ENTA_aggregates/ENTA_aggregates
        keep if _merge!=2
        drop _merge

        /*
        * [INACTIVE] Test version of the merge, for debugging by hand
          capture gen SECTOR = "Households"
          local var "YE"
          capture gen IND = "`var'"
          display("`var'")
          sort CNT2 YEAR SECTOR IND
          merge CNT2 YEAR SECTOR IND using ENTA_aggregates/ENTA_aggregates
          keep if _merge==3
          drop _merge

          use ENTA_aggregates/ENTA_aggregates, clear
        */

        gen `var'_pop = `var'*POP
        bysort CNT2 YEAR: egen `var'_pop_sum = total(`var'_pop)
        gen `var'_adj = VALAGGR * 1000000 / `var'_pop_sum if `var'_pop_sum!=0
        replace `var'_adj = 0 if `var'_adj==.
        replace `var' = `var' * `var'_adj
        drop `var'_pop `var'_pop_sum IND VALAGGR `var'_adj

    }
    drop SECTOR
end


*******************************************
* 4. Adjustment of gender-specific profiles to total profile (f+m): adjustgender [list of variables]
*******************************************

capture program drop adjustgender
program define adjustgender
    syntax namelist
    local variables `namelist'

    foreach var of varlist `variables' {
        gen `var'_pop = `var'*POP
        gen `var'_popm = `var'm*POPm
        gen `var'_popf = `var'f*POPf
        gen `var'_popt = `var'_popf + `var'_popm
        gen `var'_sharem = `var'_popm / `var'_popt
        gen `var'_sharef = `var'_popf / `var'_popt
        * Both sexes 0 at an age where the total is not: no sex shares exist,
        * so split by population (both sexes get the total per-capita value)
        * instead of losing that part of the total
        replace `var'_sharem = POPm/POP if `var'_popt==0 // replace missing values due to division by 0
        replace `var'_sharef = POPf/POP if `var'_popt==0
        replace `var'm = `var'_pop*`var'_sharem/POPm
        replace `var'f = `var'_pop*`var'_sharef/POPf
        drop `var'_pop* `var'_share*
    }
end


**********************************************
* 5. Adjustment of selected profile to aggregates from defined sector: adjustsec [profile (to which) aggregate (from) sector]; e.g. asset income to corporation-aggregate
**********************************************

capture program drop adjustsec
program define adjustsec
    args prof aggr sec // which profile to which aggregate form which sector

    gen SECTOR = "`sec'"
    capture drop IND
    gen IND = "`aggr'"
    sort CNT2 YEAR SECTOR IND
    merge m:1 CNT2 YEAR SECTOR IND using ENTA_aggregates/ENTA_aggregates
    keep if _merge==3
    drop _merge

    /*
    * [INACTIVE] Test version of the merge, for debugging by hand
    local sec "NTA aggregates"
    local aggr "YL"
    gen SECTOR = "`sec'"
    capture drop IND
    gen IND = "`aggr'"
    sort CNT2 YEAR SECTOR IND
    merge CNT2 YEAR SECTOR IND using ENTA_aggregates/ENTA_aggregates
    keep if _merge==3
    drop _merge

    use ENTA_aggregates/ENTA_aggregates, clear
    */

    gen `prof'_pop = `prof'*POP
    bysort CNT2 YEAR: egen `prof'_pop_sum = total(`prof'_pop)
    gen `prof'_adj = VALAGGR * 1000000 / `prof'_pop_sum
    replace `prof' = `prof' * `prof'_adj
    drop `prof'_pop `prof'_pop_sum IND VALAGGR SECTOR `prof'_adj
end


********************************************************************************
* 6. Total, male and female version of a new variable: gensex [newvar expression]
********************************************************************************
* gensex BSFAM BSF + BSE generates BSFAM = BSF + BSE, BSFAMm = BSFm + BSEm and
* BSFAMf = BSFf + BSEf: every variable in the expression gets the suffix of
* the sex. Used by the two compilations.

capture program drop gensex
program define gensex
    gettoken newvar 0 : 0            // newvar, then the expression
    foreach suf in "" "m" "f" {
        local sexpr "`0'"
        foreach word of local 0 {
            capture confirm variable `word'
            if !_rc {
                local sexpr = subinstr("`sexpr'", "`word'", "`word'`suf'", .)
            }
        }
        gen `newvar'`suf' = `sexpr'
    }
end
