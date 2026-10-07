********************************************************************************
* Micro_EUROMOD.do - Tax rates by income type from EUROMOD output
*
* From EUROMOD microsimulation output, estimates how a person's taxes split
* across employment income, property income, pay-as-you-go pensions, funded
* pensions and non-pension benefits (taxable-base split).  Produces
* two ENTA input files:
*
*   (1) ENTA_input_datasets/inctax_nonempl_decomp.dta  (Section 4)
*       Ratios - tax per euro of transfer - of the income tax (tPAYG tFUND
*       tBEN), contributions ils_sicot (mPAYG mFUND mBEN) and credited
*       contributions ils_sicct (cPAYG cFUND cBEN) on pay-as-you-go pensions,
*       funded pensions and other benefits, by country and year.
*       ENTA_aggregates_compilation.do combines them with the composition of
*       TB from the national tax lists (Suppl_tax_list.do) to split TB into
*       TBSPEN, TBPPEN and TBSN.
*
*   (2) ENTA_input_datasets/taxr.dta  (Section 5)
*       Effective tax rates TYEMr, TYPr, TBSPENr, TBPPENr, TBSPPENr, TBSNr
*       by country, year and AGEGR10 (0-19, then 10-year groups).
*       ENTA_taxes.do applies them to EU-SILC incomes;
*       ENTA_consumption_intrahousehold_transfers.do reads TYEMr, TBSPPENr,
*       TBSNr.
*
* Both output files are aggregates without microdata and are published with
* the code; this file is needed only to rebuild them.
*
* Inputs (paths set in the setup file):
*   $emodout   Raw EUROMOD output (<CC>_<year>_std.txt) - Section 0 only
*   $emodwd    Working folder: emod_<cc>_std.dta (Section 0),
*              pop_adjust.dta (Section 0b), emod_<CC>.dta (Section 3,
*              read by Sections 4-5)
*   ENTA_input_datasets/population_agegr3 - Section 0b only
*
* Sections 0 and 0b are commented out.  Re-run them by hand when new
* EUROMOD output arrives (0) or the population data change (0b).
* Sections 1-5 run from the files they leave in $emodwd.
*
* Outline:
*   0   Import raw EUROMOD text files, append years       [inactive]
*   0b  Population-adjust the EUROMOD weights              [inactive]
*   1   Load country file, reconcile EUROMOD components
*   2   Define ENTA income variables
*   3   Split taxes by income source (taxable-base method)
*   4   Tax-per-euro-of-transfer ratios   -> inctax_nonempl_decomp.dta
*   5   Age-specific effective tax rates  -> taxr.dta

********************************************************************************


*********************************
* Country list
*********************************

* Every "foreach x in $country" loop below runs over this list (26 EU
* countries, uppercase two-letter codes).

global country AT BE BG CY CZ DE DK EE EL ES FI FR HR HU IE IT LT LU LV ///
    NL PL PT RO SE SI SK

* global country AT


********************************************************************************
* 0.  Import raw EUROMOD text files  [INACTIVE - re-run by hand]
********************************************************************************

* Reads one <CC>_<year>_std.txt per country and year from $emodout, adds
* standard variables, saves one .dta per year, then appends all years of a
* country into $emodwd/emod_<cc>_std.dta and erases the yearly files.
/*

  global countryl at be bg cy cz de dk ee el es fi fr hr hu ie it lt lu lv ///
                  nl pl pt ro se si sk
  global year 2005 2006 2007 2008 2009 2010 2011 2012 2013 2014 2015 2016 ///
              2017 2018 2019 2020 2021 2022 2023 2024 2025

  foreach x in $countryl {
    foreach y in $year {

      * Filenames mix upper- and lowercase country codes depending on year;
      * try uppercase first, then lowercase; skip if neither exists.
      local xu = upper("`x'")
      capture confirm file "$emodout/`xu'_`y'_std.txt"
      if _rc == 0 {
        local rawfile "$emodout/`xu'_`y'_std.txt"
      }
      else {
        capture confirm file "$emodout/`x'_`y'_std.txt"
        if _rc == 0 {
          local rawfile "$emodout/`x'_`y'_std.txt"
        }
        else continue
      }
      clear
      import delim "`rawfile'", decimalseparator(,)

      * Standard variables
      gen YEAR   = `y'
      gen AGE    = dag
      gen SEX    = cond(dgn == 1, 1, 2)
      gen WEIGHT = dwt
      gen CNT2   = strupper("`x'")
      gen ONE    = 1

      * Ten-year age groups (0-9 ... 80+)
      gen AGEGR10 = 10 * min(floor(AGE / 10), 8)

      * Three broad age groups for the population adjustment
      gen AGEGR3 = 0 if AGE < 20
        replace AGEGR3 = 1 if AGE >= 20 & AGE < 65
        replace AGEGR3 = 2 if AGE >= 65

      * Household structure
      bys idhh: gen  Nhh      = _N
      bys idhh: gen  nn       = _n
      bys idhh: egen NCHILD6  = total(AGE <= 6)
      bys idhh: egen NCHILD15 = total(AGE <= 15)
      bys idhh: egen NCHILD19 = total(AGE <= 19)

      * Person-level labour-status indicators (EUROMOD variable les)
      gen NUNEMP = (les == 5)
      gen NEMP   = (les == 2 | les == 3)
      gen NCHILD = (les == 0 | les == 6)
      gen NINACT = (les == 7 | les == 9)
      gen NPENS  = (les == 4 | les == 8)

      sort YEAR idhh idperson
      save "$emodwd/`x'_`y'_std", replace
    }

    * Append all years for one country
    clear
    foreach y in $year {
      capture confirm file "$emodwd/`x'_`y'_std.dta"
      if _rc == 0 {
        append using "$emodwd/`x'_`y'_std", force
        erase "$emodwd/`x'_`y'_std.dta"
      }
    }

    compress
    sort CNT2 YEAR idhh idperson
    save "$emodwd/emod_`x'_std", replace
  }

*/


********************************************************************************
* 0b. Population adjustment of the EUROMOD weights  [INACTIVE - re-run by hand]
********************************************************************************

* Sums EUROMOD weights by country x year x AGEGR3, merges the official
* population, computes ADJPOP = population / EUROMOD weight sum.
* Section 1 multiplies individual weights by ADJPOP so they sum to the true
* population.  Re-run when population data are updated.
/*

  foreach x in $country {
    local xl = lower("`x'")
    use "$emodwd/emod_`xl'_std", clear
    collapse (sum) WEIGHT, by(CNT2 YEAR AGEGR3)
    rename WEIGHT WEIGHTEMOD
    tempfile age_`x'
    save `age_`x''
  }

  clear
  foreach x in $country {
    append using `age_`x''
  }

  sort CNT2 YEAR AGEGR3
  merge 1:1 CNT2 YEAR AGEGR3 ///
    using ENTA_input_data/ENTA_input_datasets/population_agegr3
  keep if _merge == 3
  drop _merge

  gen ADJPOP = POP / WEIGHTEMOD
  keep CNT2 YEAR AGEGR3 ADJPOP
  sort CNT2 YEAR AGEGR3
  save "$emodwd/pop_adjust", replace

*/


********************************************************************************
*
*   SECTIONS 1-3: one loop over countries
*
*   Each iteration loads a country's pooled file (from Section 0), reconciles
*   the EUROMOD variables, defines the ENTA income concepts, splits each
*   person's taxes over income sources, and saves the result as
*   $emodwd/emod_<CC>.dta for Sections 4 and 5.
*
********************************************************************************

foreach x in $country {

    local xl = lower("`x'")
    use "$emodwd/emod_`xl'_std", clear


    *********************************
    * 1. Population-adjusted weights
    *********************************
    * Merge ADJPOP (by country x year x AGEGR3) and define WEIGHTa = WEIGHT x
    * ADJPOP, which sums to the total population.  WEIGHTa is used in all
    * later weighting.

    sort CNT2 YEAR AGEGR3
    merge m:1 CNT2 YEAR AGEGR3 using "$emodwd/pop_adjust"
    keep if _merge == 3
    drop _merge

    gen WEIGHTa = WEIGHT * ADJPOP
    gen SECTOR  = "Households"


    *********************************
    * 1b. Country-specific adjustments
    *********************************
    * Five "other" components (initialised to 0) hold income or benefit items
    * that EUROMOD books differently by country.  The programming-if blocks
    * below check the first observation; this is safe because each loop
    * iteration contains a single country.

    gen yem_earns_oth = 0   // employment income contributing to ils_earns
    gen yem_origy_oth = 0   // employment income in ils_origy but not ils_earns
    gen yse_origy_oth = 0   // self-employment income in ils_origy but not ils_earns
    gen bs_oth        = 0   // benefits in ils_origy, booked as BSP in ENTA
    gen x_oth         = 0   // other expenditure

    if CNT2 == "AT" {
        replace yot = yot01 + yot02               // military/civil service + under-16
        replace ypp = ypp01 + ypp02
        replace yem_origy_oth = yem_origy_oth + yemot  // tips
    }

    if CNT2 == "CY" {
        replace yot = yot + bml                   // military service
    }

    if CNT2 == "DE" {
        replace x_oth = xhi_s                     // self-employed health insurance
    }

    if CNT2 == "EL" {
        gen xmp = xmpam + xmpot                   // EL has no xmp: alimony + other
    }

    if CNT2 == "HR" {
        replace yem_origy_oth = yem_origy_oth + ymc  // caretaker/foster compensation
        replace yem_earns_oth = yem_earns_oth + yst  // student income
    }

    if CNT2 == "HU" {
        * Sickness benefit (bhl) is inside ils_pen in the Hungarian output but
        * should count as a non-pension benefit, as in AT, PL, CZ and SK.
        replace ils_pen = ils_pen - bhl
    }

    if CNT2 == "IE" {
        replace xmp = ils_udb_xmp
        replace ypp = ypp + poaps + poapu         // occupational pensions
    }

    if CNT2 == "IT" {
        replace yem_origy_oth = yem_origy_oth + yemnt
        replace yse_origy_oth = yse_origy_oth + ysenr_s
        replace ypp = ypp + ypp02 + ypp01
        replace yemaj = 0 if yemaj == .
        replace yem = yem + yempv + yemtj + yemxp + yemaj
        replace yse = yse + yseib + yseil
    }

    if CNT2 == "NL" {
        replace bs_oth = bs_oth + poacm           // occupational pensions
    }

    if CNT2 == "PL" {
        replace x_oth = ypt - yptmp               // private transfers excl. maintenance
    }

    if CNT2 == "SK" {
        replace yem_origy_oth = yem_origy_oth + yls       // lump sum
        replace yem_earns_oth = yem_earns_oth - yemcs + yemwg - yem
        * ils_earns holds wages (yemwg) less the company share (yemcs)
    }

    if CNT2 == "SI" {
        replace yem = yem00
        replace yse = yse00
        replace yem_earns_oth = yem_earns_oth + yaj + yst
        * yaj = additional jobs; yst = student income
    }


    *********************************
    * 1c. Reconciliation checks
    *********************************
    * Rebuild three EUROMOD aggregates from their parts.  The check variables
    * document the variable structure and are dropped immediately.
    *
    * Variable hierarchy:
    *   ils_dispy
    *     ils_origy
    *       ils_earns: yem + yse + yem_earns_oth
    *       yiy, ypr, ypp (asset income)
    *       yot, yem_origy_oth, yse_origy_oth, bs_oth
    *     ils_ben  (social benefits; bs_oth booked as BSP in ENTA)
    *     ils_tax
    *     ils_sicse, ils_sicer, ils_sicee, ils_sicot

    gen ils_earnsc = yem + yse + yem_earns_oth
    gen d_ils_earns = ils_earns - ils_earnsc

    * In Finland yiy is assigned within the household differently than in ils_origy
    gen ils_origyc = ils_earns + yem_origy_oth + yse_origy_oth + bs_oth ///
        + yiy + ypr + ypp + yot + ypt - xmp - x_oth
    gen d_ils_origy = ils_origy - ils_origyc

    gen ils_dispyc  = ils_origy + ils_ben - ils_tax - ils_sicee - ils_sicse - ils_sicot
    gen d_ils_dispy = ils_dispyc - ils_dispy

    drop ils_earnsc d_ils_earns ils_origyc d_ils_origy ils_dispyc d_ils_dispy


    *********************************
    * 2. Define ENTA income variables  (all annual = monthly x 12)
    *********************************

    * Labour income and mixed income
    gen YE    = (yem + yem_earns_oth + ils_sicer + yem_origy_oth + yot) * 12
    gen YEE = (yem + yem_earns_oth + yem_origy_oth + yot) * 12
    gen YER = ils_sicer * 12

    gen YM    = (yse + yse_origy_oth) * 12
    gen YEM   = (ils_earns + yem_origy_oth + yse_origy_oth + yot + ils_sicer) * 12
    gen YEMEE = (ils_earns + yem_origy_oth + yse_origy_oth + yot) * 12

    * Property income
    gen YP = (yiy + ypr + ypp) * 12
    gen Y  = YEM + YP

    * Public benefits + funded pensions
    gen BSP    = (ils_ben + bs_oth) * 12        // bs_oth mainly NL
    gen BSPPEN = (ils_pen + bs_oth) * 12
    gen BSN    = (ils_ben - ils_pen) * 12

    * Private transfers
    gen BPX = ypt * 12
    gen TPX = (xmp + x_oth) * 12

    * Taxes and contributions (check only - dropped below)
    gen TYT  = ils_tax * 12
    gen TYS  = (ils_sicee + ils_sicse + ils_sicot + ils_sicer) * 12
    gen TY   = TYT + TYS
    gen TYER = ils_sicer * 12

    * Disposable-income check
    gen YDc  = Y - TY + BSP + BPX - TPX
    gen YD   = ils_dispy * 12
    gen d_YD = YD - YDc

    drop Y YDc d_YD TYT TYS TY TYER



    *********************************
    * 3a. Separate funded from pay-as-you-go pensions
    *********************************
    * FUNDP is identified only where EUROMOD separates funded pensions:
    *   NL  occupational pensions (poacm, already in BSPPEN via bs_oth)
    *   DE  public + private occupational pensions (poapu, poaps, inside ils_pen)
    *   DK  labour-market supplementary pensions (ypp, inside YP)
    * Everywhere else FUNDP = 0 and the funded rate defaults to the PAYG rate
    * in Section 5.
    *
    * PAYG = pensions minus funded.  In DK the funded part sits inside YP
    * (not BSPPEN), so PAYG is unchanged and PROP is reduced instead.

    gen double FUNDP = 0
    foreach v in poacm poapu poaps {
        capture confirm variable `v'
        if _rc gen double `v' = 0
        replace `v' = 0 if missing(`v')
    }
    if CNT2 == "NL"  replace FUNDP = 12 * poacm
    if CNT2 == "DE"  replace FUNDP = 12 * (poapu + poaps)
    if CNT2 == "DK"  replace FUNDP = 12 * ypp

    gen double PAYG = BSPPEN - cond(CNT2 == "DK", 0, FUNDP)
    gen double PROP = YP     - cond(CNT2 == "DK", FUNDP, 0)
    gen double EMP  = YEMEE


    *********************************
    * 3b. Split non-pension benefits by function
    *********************************
    * EUROMOD's ils_b1_* groups add up to ils_ben.  Different functions have
    * different taxability, so they get separate coefficients.

    foreach v in ils_b1_bfa ils_b1_bun ils_b1_bhl ils_sicct {
        capture confirm variable `v'
        if _rc gen double `v' = 0
        replace `v' = 0 if missing(`v')
    }
    gen double BFAM = 12 * ils_b1_bfa
    gen double BUN  = 12 * ils_b1_bun
    gen double BHL  = 12 * ils_b1_bhl
    gen double BOTH = BSN - BFAM - BUN - BHL


    *********************************
    * 3c. Estimate taxability coefficients  b_k in [0, 1]
    *********************************
    * Per year: regress the annual tax base on the eight income components
    * (no constant, weighted by WEIGHTa).  The coefficient is the share of
    * each euro that enters the tax base.
    *
    * Tax-base variable: ils_base_tin for 19 countries; six use a country-
    * specific base (AT DK EL FI IT SI; R2 0.98-1.00 in 2019).  NL has
    * no single base variable (box 1 + people's insurances): fixed rule -
    * everything taxable except family benefits.
    *
    * Upper bound: a euro of income should not add more than a euro to
    * the base.  Exception: the Czech "super-gross" wage (gross + employer
    * SIC) until its abolition in 2021 - CZ EMP keeps its estimate (1.21-1.27)
    * up to 2020.

    local base "ils_base_tin"
    if "`x'" == "AT" local base "ils_base_tin01"
    if "`x'" == "DK" local base "ils_base_tmu"
    if "`x'" == "EL" local base "ils_base_tin00"
    if "`x'" == "FI" local base "ils_base_tinna"
    if "`x'" == "IT" local base "ils_base_tinna"
    if "`x'" == "SI" local base "ils_base_tin00"
    if "`x'" == "NL" local base ""

    local comps "EMP PROP PAYG FUNDP BFAM BUN BHL BOTH"
    foreach k of local comps {
        gen double b_`k' = .
    }

    if "`base'" != "" {
        replace `base' = 0 if missing(`base')
        gen double BASE = 12 * `base'
        levelsof YEAR, local(years)
        foreach y of local years {
            quietly reg BASE `comps' [aw=WEIGHTa] if YEAR == `y', nocons
            foreach k of local comps {
                replace b_`k' = max(0, _b[`k']) if YEAR == `y'
            }
        }
        * Bound at 1, except CZ EMP before 2021 (super-gross wage)
        foreach k of local comps {
            replace b_`k' = min(b_`k', 1) ///
                if !("`k'" == "EMP" & CNT2 == "CZ" & YEAR <= 2020)
        }
        drop BASE
    }
    else {
        * NL: everything taxable except family benefits
        foreach k of local comps {
            replace b_`k' = cond("`k'" == "BFAM", 0, 1)
        }
    }


    *********************************
    * 3d. Split each person's income tax  (ils_tax x 12)
    *********************************
    * Taxable amount per component: t_k = b_k x max(0, income_k).
    * Tax allocated in proportion t_k / sum of t_k.  If sum of t_k = 0 (nothing
    * taxable), all parts are 0 - below 1% of total income tax except
    * EL (2.4% in 2019).

    foreach k of local comps {
        gen double t_`k' = b_`k' * max(0, `k')
    }
    egen double TSUM = rowtotal(t_EMP t_PROP t_PAYG t_FUNDP t_BFAM t_BUN t_BHL t_BOTH)
    gen double ITX = 12 * ils_tax
    foreach k of local comps {
        gen double IT_`k' = cond(TSUM > 0, ITX * t_`k' / TSUM, 0)
    }
    gen double IT_BEN = IT_BFAM + IT_BUN + IT_BHL + IT_BOTH


    *********************************
    * 3e. Split other contributions (ils_sicot) and credited contributions
    *     (ils_sicct)
    *********************************
    * ils_sicot is split over all income the person has - earnings, property,
    * PAYG, funded pensions and non-pension benefits except family benefits -
    * in proportion to amounts.  Family benefits carry no contributions.
    * If nothing qualifies (SCB <= 0), all contributions fall on EMP as a
    * conservative default.
    *
    * ils_sicct (state-paid credited contributions) is split over pensions and
    * all non-pension benefits, family benefits included.  Credited
    * contributions of persons without any transfer (children, students) are
    * not attributed and enter only the per-euro ratios in Section 4.

    gen double SCO  = 12 * ils_sicot
    gen double SCC  = 12 * ils_sicct
    gen double BSNC = max(0, BSN - BFAM)                   // benefits carrying contributions
    gen double SCB  = max(0, EMP) + max(0, PROP) + max(0, PAYG) + max(0, FUNDP) + BSNC

    foreach k in EMP PROP PAYG FUNDP {
        gen double SC_`k' = cond(SCB > 0, SCO * max(0, `k') / SCB, 0)
    }
    gen double SC_BEN = cond(SCB > 0, SCO * BSNC / SCB, 0)
    replace SC_EMP   = SCO if SCB <= 0                      // fallback: attribute to employment

    gen double TRA = max(0, PAYG) + max(0, FUNDP) + max(0, BSN)
    foreach k in PAYG FUNDP BSN {
        gen double CC_`k' = cond(TRA > 0, SCC * max(0, `k') / TRA, 0)
    }
    rename CC_BSN CC_BEN


    *********************************
    * 3f. Assemble final tax components (annual)
    *********************************

    gen double TSYEM   = (ils_sicee + ils_sicse + ils_sicer) * 12
    gen double TTYEMEE = IT_EMP   + SC_EMP
    gen double TYEM    = TTYEMEE  + TSYEM
    gen double TYP     = IT_PROP  + SC_PROP
    gen double TBSPEN  = IT_PAYG  + SC_PAYG  + CC_PAYG
    gen double TBPPEN  = IT_FUNDP + SC_FUNDP + CC_FUNDP
    gen double TBSN    = IT_BEN   + SC_BEN   + CC_BEN
    gen double TBSPPEN = TBSPEN   + TBPPEN
    gen double TB      = TBSPPEN  + TBSN


    *********************************
    * 3g. Save for Sections 4 and 5
    *********************************

    keep idhh AGE AGEGR10 CNT2 SEX YEAR YEM YP PAYG FUNDP BSN BSPPEN ///
        TYEM TTYEMEE TSYEM TYP TBSPEN TBPPEN TBSPPEN TBSN TB         ///
        IT_PAYG IT_FUNDP IT_BEN SC_PAYG SC_FUNDP SC_BEN               ///
        CC_PAYG CC_FUNDP CC_BEN b_* WEIGHT*
    save "$emodwd/emod_`x'", replace
}


********************************************************************************
* 4. Composition of the taxes on transfers  -> inctax_nonempl_decomp.dta
********************************************************************************
* Per country x year, from all persons (WEIGHTa), compute tax per euro of
* each kind of transfer - PAYG pensions, funded pensions, non-pension
* benefits - for income tax, other contributions and credited contributions:
*
*   tPAYG  tFUND  tBEN     income tax per euro
*   mPAYG  mFUND  mBEN     ils_sicot per euro
*   cPAYG  cFUND  cBEN     ils_sicct per euro
*
* These are ratios, not shares.  ENTA_aggregates_compilation.do weights
* the ESA amounts (BSPEN, BPSOCfc, BSN) with these ratios and applies them
* to the parts of TB measured in the national tax lists (Suppl_tax_list.do).
* Where EUROMOD has no funded pensions (all except NL, DE, DK), the FUND
* ratio defaults to the PAYG ratio.

foreach x in $country {
    use "$emodwd/emod_`x'", clear
    gen double BEN = BSN
    collapse (sum) PAYG FUNDP BEN                                     ///
        IT_PAYG IT_FUNDP IT_BEN                            ///
        SC_PAYG SC_FUNDP SC_BEN                            ///
        CC_PAYG CC_FUNDP CC_BEN [iw=WEIGHTa], by(CNT2 YEAR)
    tempfile tb`x'
    save `tb`x''
}

clear
foreach x in $country {
    append using `tb`x''
}

foreach p in IT SC CC {
    local s = cond("`p'" == "IT", "t", cond("`p'" == "SC", "m", "c"))
    gen double `s'PAYG = `p'_PAYG  / PAYG  if PAYG  > 0
    gen double `s'FUND = `p'_FUNDP / FUNDP if FUNDP > 0
    replace    `s'FUND = `s'PAYG           if FUNDP <= 0
    gen double `s'BEN  = `p'_BEN   / BEN   if BEN   > 0
}
keep CNT2 YEAR tPAYG tFUND tBEN mPAYG mFUND mBEN cPAYG cFUND cBEN

* Croatia 2009-2010: no EUROMOD input before 2011; copy 2011 ratios back
count if CNT2 == "HR" & YEAR == 2011
if r(N) > 0 {
    preserve
    keep if CNT2 == "HR" & YEAR == 2011
    expand 2
    bysort CNT2: gen byte _y = _n
    replace YEAR = 2009 if _y == 1
    replace YEAR = 2010 if _y == 2
    drop _y
    tempfile hr_sh_back
    save `hr_sh_back'
    restore
    append using `hr_sh_back'
}

sort CNT2 YEAR
save ENTA_input_data/ENTA_input_datasets/inctax_nonempl_decomp, replace


********************************************************************************
* 5. Age-specific effective tax rates  -> taxr.dta
********************************************************************************
* Rates by ten-year age group (0-19, 20-29, ... 80+), from all persons:
*
*   TYEMr     taxes + contributions on employment income  / YEM
*   TYPr      tax on property income / YP  (one rate per country-year)
*   TBSPENr   on PAYG pensions / PAYG
*   TBPPENr   on funded pensions / FUNDP  (= TBSPENr if no funded pensions)
*   TBSPPENr  on all pensions / (PAYG + FUNDP)
*   TBSNr     on non-pension benefits / BSN

foreach x in $country {
    use "$emodwd/emod_`x'", clear

    * Age groups: 10 = ages 0-19, then 20, 30, ... 80 (= 80+)
    gen AGEGRTAX = cond(AGE < 20, 10, min(10 * floor(AGE / 10), 80))

    gen double PPEN = PAYG + FUNDP

    collapse (sum) YEM TYEM YP TYP PAYG TBSPEN FUNDP TBPPEN        ///
        PPEN TBSPPEN BSN TBSN [pw=WEIGHTa],              ///
        by(CNT2 YEAR AGEGRTAX)

    gen double TYEMr = TYEM / YEM if YEM > 0

    * Pension groups below 0.01% of the country-year total are treated as
    * having no pensions.  Without this rule, near-zero denominators
    * (e.g. NL PAYG below age 60) produce rates swinging between -2.7 and
    * 0.7 across years.
    foreach k in PAYG FUNDP PPEN {
        bysort CNT2 YEAR: egen double _`k'tot = total(`k')
        gen byte _`k'ok = `k' > 0.0001 * _`k'tot
    }
    gen double TBSPENr  = TBSPEN  / PAYG  if PAYG  > 0 & _PAYGok
    gen double TBPPENr  = TBPPEN  / FUNDP if FUNDP > 0 & _FUNDPok
    gen double TBSPPENr = TBSPPEN / PPEN  if PPEN  > 0 & _PPENok
    drop _PAYGtot _FUNDPtot _PPENtot _PAYGok _FUNDPok _PPENok

    gen double TBSNr = TBSN / BSN if BSN > 0

    * Where EUROMOD has no funded pensions at all, use the PAYG rate
    bysort CNT2 YEAR: egen double _FUNDtot = total(FUNDP)
    replace TBPPENr = TBSPENr if _FUNDtot == 0
    drop _FUNDtot

    * Property income: one rate per country-year (too few holders for
    * age-specific rates to be meaningful)
    bysort CNT2 YEAR: egen double _TYPtot = total(TYP)
    bysort CNT2 YEAR: egen double _YPtot  = total(YP)
    gen double TYPr = _TYPtot / _YPtot if _YPtot > 0
    drop _TYPtot _YPtot

    * Clean: missing or negative -> 0;  above 0.7 -> 0.7
    * (no effective rate on a single income component plausibly exceeds 0.7)
    foreach v in TYEMr TYPr TBSPENr TBPPENr TBSPPENr TBSNr {
        replace `v' = 0   if missing(`v') | `v' < 0
        replace `v' = 0.7 if `v' > 0.7
    }
    keep CNT2 YEAR AGEGRTAX TYEMr TYPr TBSPENr TBPPENr TBSPPENr TBSNr

    * Put the rates on the AGEGR10 grid (0, 10, 20, ... 80) that
    * ENTA_taxes.do merges on: duplicate the 0-19 group into 0 and 10.
    expand 2 if AGEGRTAX == 10
    bysort CNT2 YEAR AGEGRTAX: gen byte _j = _n
    gen AGEGR10 = AGEGRTAX
    replace AGEGR10 = 0 if AGEGRTAX == 10 & _j == 1
    drop _j AGEGRTAX
    isid CNT2 YEAR AGEGR10

    sort CNT2 YEAR AGEGR10
    tempfile taxr_`x'
    save `taxr_`x''
}

clear
foreach x in $country {
    append using `taxr_`x''
}

* Croatia 2009-2010: no EUROMOD input before 2011; carry 2011 rates back.
* Only the age shape is imputed; the level is scaled to the ESA aggregate
* afterwards.
count if CNT2 == "HR" & YEAR == 2011
if r(N) > 0 {
    preserve
    keep if CNT2 == "HR" & YEAR == 2011
    expand 2
    bysort CNT2 AGEGR10: gen byte _y = _n
    replace YEAR = 2009 if _y == 1
    replace YEAR = 2010 if _y == 2
    drop _y
    tempfile hr_taxr_back
    save `hr_taxr_back'
    restore
    append using `hr_taxr_back'
}

* Fill in missing 80+ rows (DE 2017-2018, ES 2006-2008 have none in
* EUROMOD).  fillin creates all CNT2 x YEAR x AGEGR10 combinations;
* country-years without any EUROMOD data are dropped; new 80+ rows copy
* the 70-79 rates.  Without an 80+ row ENTA_taxes.do would drop everyone
* aged 80+.
fillin CNT2 YEAR AGEGR10
bysort CNT2 YEAR: egen byte _has = max(!_fillin)
drop if !_has
drop _has
sort CNT2 YEAR AGEGR10
foreach v in TYEMr TYPr TBSPENr TBPPENr TBSPPENr TBSNr {
    by CNT2 YEAR: replace `v' = `v'[_n-1] if _fillin & AGEGR10 == 80
}
assert !_fillin | AGEGR10 == 80
drop _fillin
bysort CNT2 YEAR: assert _N == 9

sort CNT2 YEAR AGEGR10
save ENTA_input_data/ENTA_input_datasets/taxr, replace
