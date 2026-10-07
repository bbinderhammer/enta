
* This file combines age-profiles to complete European NTA
*
* Output: ENTA_output_data/ENTA_priv_wide.dta (all series in wide format, one
*         row per country, year and age 0-80); ENTA_output_data/ENTA_esa
*         (dta, csv, zip; long format, ESA concepts); ENTA_output_data/
*         ENTA_units (dta, csv; ENTA_aggregates/ENTA_units.dta plus the NTA and
*         ENTA norms, Section 5). Which indicators ENTA_esa holds is decided by
*         the labels in Prog_ENTA_labels.do: a reshaped variable without a
*         label there is dropped before the save.
* Read by: ENTA_compilation2_nta.do - ENTA_priv_wide.
* Input:  the age profiles in ENTA_ageprofiles/ageprofiles (inc_, tax_, ben_,
*         ctpriv_ and lfs_[CNT2].dta); ENTA_aggregates/ENTA_aggregates.dta and
*         ENTA_units.dta; population80w, CGH_AWG and enrollment in
*         ENTA_input_data/ENTA_input_datasets.
* Requires ENTA_setup_TU.do / ENTA_setup.do (programs adjust, adjustgender,
*         adjustsec and gensex; $wkdir) and
*         ENTA_input_data/Prog_gen_country_name_from_CNT2.do.
* Commented "line ..." commands are plots for checking a profile by hand.

* NOTE: numbered inline comments like "1.1 YEM" or "3.1 BSPEN" refer to the
* NTA/ESA indicator classification (matching the INDICATOR labels built in
* Section 4, "Generate indicator names"), not to this file's own section
* numbers below.

**************************************
* Content

* 0. Population data as basis for ENTA

* 1. ENTA for household sector

* Import basic age-profiles
* Quantities based on other age-profiles
* Adjustment to aggregates
* Generate derived and composite variables
* Test flow identities

* 2. Corporation sector

* 3. Government sector

* Government transfers, saving and other consumption
* Health
* Education

* 4. Save data in long format, ENTA by sector

* Reshape to long format
* Generate indicator names
* Save the published file

* 5. NTA and ENTA norms; publish ENTA_units

*****************************************


********************************************************************************
* Loop over all countries
********************************************************************************

global country AT BE BG CY CZ DE DK EE EL ES FI FR HR HU IE IT LT LU LV NL PL PT RO SE SI SK //
* global country "AT" //  FR IT PL SE DK

foreach x in $country {


    ********************************************************************************
    * 0. Population data as basis for ENTA
    ********************************************************************************

    * Population data (POP)

    use ENTA_input_data/ENTA_input_datasets/population80w, clear

    keep if CNT2=="`x'"
    keep if YEAR>=1995

    * 5-year age groups
    gen AGEGR5 = min(int(AGE/5) * 5, 80)
    sort CNT2 YEAR AGE

    * Modify age data for Germany: Age groups end with 73 from 2014-18 and are only 5-year from 2022
    if "`x'"=="DE" {
        gen AGEt = AGE if CNT2=="DE"

        * Only five year age groups from 2022
        replace AGE = AGEGR5 if AGE>=20 & YEAR>=2022
        replace AGE = 16 if AGE>=16 & AGE<20 & YEAR>=2022

        * Only until age 73 in 2014 - 2018
        replace AGE = 73 if AGE>=73 & YEAR>=2014 & YEAR<=2018
    }


    ********************************************************************************
    * 1. ENTA for household sector
    ********************************************************************************

    ************************************************************
    * Import basic age-profiles
    ************************************************************

    ****************************************
    * 1. Income
    ****************************************

    * 1.1 YEM Income from employment
    * 1.1.1 YE - Income of employees
    * 1.1.2 YM - mixed income
    * 1.2.1 YP - property income of households
    * 1.2.2 YO - operating surplus of households
    * 1.3 EHI - equivalised household income

    sort CNT2 YEAR AGE
    merge m:1 CNT2 YEAR AGE using "ENTA_ageprofiles/ageprofiles/inc_`x'", keep(3) nogen  // YEM YE YM YP YO

    ****************************************
    * Taxes
    ****************************************

    * 2.1 TYEM - taxes on employment income
    * 2.3 TB - taxes on benefits
    * 2.3.1 TBSPEN - taxes on pay-as-you-go pensions
    * 2.3.2 TBSN - taxes on non-pension benefits
    * 2.3.3 TBPPEN - taxes on funded pensions

    sort CNT2 YEAR AGE
    merge m:1 CNT2 YEAR AGE using "ENTA_ageprofiles/ageprofiles/tax_`x'", keep(3) nogen

    /*
    ************************************************************
    * [INACTIVE] TYEM calculated directly from the YEM age profile with the
    * EUROMOD tax rates by 10-year age group. The compilation uses the TYEM
    * profile from ENTA_taxes.do instead, which applies the rates in the
    * microdata.
    ************************************************************

    gen AGEGR10 = 10*int(AGE/10)
    replace AGEGR10 = 80 if AGE>=80

    sort CNT2 YEAR AGEGR10
    merge m:1 CNT2 YEAR AGEGR10 using ENTA_input_data/ENTA_input_datasets/taxr, keep(3) nogen

    gen TYEM  = YEM  * TYEMr
    gen TYEMm = YEMm * TYEMr
    gen TYEMf = YEMf * TYEMr

    drop AGEGR10 TYEMr TBSPPENr TBSNr TYPr
    sort CNT2 YEAR AGE
    */

    ****************************************
    * Benefits
    ****************************************

    * BSP - social benefits, government and funded pensions
    * 3.1 BSPEN - Government pensions, unfunded
    * 3.2 BSFAM - Family and children
    * 3.3 BSU - Unemployment
    * 3.4 BSX - Other
    * BSPPEN - social benefits, pensions, government and funded pensions

    sort CNT2 YEAR AGE
    merge m:1 CNT2 YEAR AGE using "ENTA_ageprofiles/ageprofiles/ben_`x'", keep(3) nogen


    ****************************************
    * Private consumption and private transfers
    ****************************************

    * 2.4 TCON - taxes on consumption
    * 8.1 CHE - Private consumption, education
    * 8.2 CHH Private consumption, health
    * 8.3 CHR - Private consumption, imputed rent
    * 8.4 CHX - Private consumption, other
    * 5.2.1 TFWI - Private transfers within HH, received
    * 5.2.2 TFWO - Private transfers within HH, paid

    sort CNT2 YEAR AGE
    merge m:1 CNT2 YEAR AGE using "ENTA_ageprofiles/ageprofiles/ctpriv_`x'", keep(3) nogen


    ****************************************
    * Change german age data to single years from 0 to 80
    ****************************************

    if "`x'"=="DE" {
        replace AGE = AGEt
    }


    ****************************************
    * Labour force
    ****************************************

    * 1.E.5 EMPLFT Employment rates in fulltime equivalents

    * The LFS microdata of NL, CZ, SK and IE report only 5-year age groups
    * (Micro_LFS.do sets AGE to the lower bound of the group), so lfs_`x'.dta
    * of these four countries is indexed by AGEGR5. Merge on AGEGR5, then
    * restore the single-year AGE: each single year within a group takes the
    * value of the group.
    if ("`x'"=="NL" | "`x'"=="CZ" | "`x'"=="SK" | "`x'"=="IE") {
        gen AGE1Y = AGE
        replace AGE=AGEGR5
        sort CNT2 YEAR AGE
        merge m:1 CNT2 YEAR AGE using "ENTA_ageprofiles/ageprofiles/lfs_`x'"
        replace AGE = AGE1Y
    }
    else {
        sort CNT2 YEAR AGE
        merge m:1 CNT2 YEAR AGE using "ENTA_ageprofiles/ageprofiles/lfs_`x'"
    }
    drop if _merge==2
    drop _merge

    local vars "EMPL EMPLFT EMPLFTACT EMPLSTAT WHRUSU WHRUSUT WHRACT WHRACTT" // EMPL2. The zero fill below is AGE>=75, not >75: a profile that ends before 75 (the SE LFS in 1995 only, before the published years) gets 0 from 75
    * Open top group 75+: AT, HR and IT deliver no single age above 75 (AGE 75
    * holds everyone aged 75 and over), SK merges on 5-year groups and has none
    * above the 75-79 group. Ages above 75 without a value take the value of the
    * age before them, i.e. the 75+ rate, not 0. A profile that ends
    * before 75 is not extended.
    sort CNT2 YEAR AGE
    foreach var of local vars {
        by CNT2 YEAR: replace `var' = `var'[_n-1] if `var'==. & AGE>75 & AGE[_n-1]>=75
        by CNT2 YEAR: replace `var'm = `var'm[_n-1] if `var'm==. & AGE>75 & AGE[_n-1]>=75
        by CNT2 YEAR: replace `var'f = `var'f[_n-1] if `var'f==. & AGE>75 & AGE[_n-1]>=75
    }

    foreach var of local vars {
        replace `var' = 0 if `var'==. & AGE>=75
        replace `var'm = 0 if `var'm==. & AGE>=75
        replace `var'f = 0 if `var'f==. & AGE>=75
    }

    * Symmetric fill at the BOTTOM of the age range. Without it a country-year
    * publishes ages 0-14 only where lfs_`x'.dta happens to carry rows there: the
    * merge keeps the master's full 0-80 range, but an unmatched age stays
    * missing and is dropped at export, so the age range of a series would change
    * within a country's own series.
    * ZERO IS THE RIGHT FILL: nobody below 15 is in the EU-LFS universe, so an
    * employment rate or an hours total is 0 there, and it matches the project's
    * convention of flooring to 0 below 15 in ENTA_income.do / ENTA_taxes.do.
    * Nothing else moves: none of these indicators is ever passed to adjust,
    * adjustaggr or adjustsec - they are pure profiles, not scaled to an
    * aggregate - so the fill changes no total and no identity.
    foreach var of local vars {
        replace `var' = 0 if `var'==. & AGE<15
        replace `var'm = 0 if `var'm==. & AGE<15
        replace `var'f = 0 if `var'f==. & AGE<15
    }

    * Romania, Slovakia and Greece, unemployment benefits: EU-SILC has fewer
    * than 20 receivers per single age in most years (RO 0, SK 3.5, EL 13; RO
    * also only 2-28% of the aggregate from income year 2011) and the LFS
    * clearly more (the 20-receiver rule, decided per country, not per year),
    * so the age shape of BSU is the LFS share receiving unemployment benefits
    * or assistance instead (UNEMPLBEN, REGISTER 1; smoothed in
    * ENTA_employment.do for RO and EL; SK in five-year groups), in every year,
    * so that the method does not change between years. PL, HR and CZ keep
    * EU-SILC: their EU-SILC profile has 34-50% of BSU at 55-64 every year
    * (early retirement for labour-market reasons and severance pay are in
    * PY090, and in the COFOG aggregate), the LFS only 17-25%. CY, EE and LU
    * keep EU-SILC: their LFS has no more receivers. The LFS year is taken for
    * the income year of the same number. adjust/adjustgender below scale it
    * to the BSU aggregate: the same benefit per receiver at every age. 0
    * where the LFS has no value. UNEMPL and UNEMPLBEN are internal and
    * dropped here.
    if inlist("`x'", "RO", "SK", "EL") {
        foreach s in "" m f {
            replace BSU`s' = cond(missing(UNEMPLBEN`s'), 0, UNEMPLBEN`s')
        }
    }
    drop UNEMPL UNEMPLm UNEMPLf UNEMPLBEN UNEMPLBENm UNEMPLBENf


    ************************************************************
    * Quantities based on other age-profiles
    ************************************************************

    * Private transfers: social benefits of non-financial corporations (mostly health benefits)
    * Source: Eurostat report on the subsectoring of non-financial
    * corporations (report-subsectoring-nfcs.pdf).

    * Other taxes/transfers (2.5 TX)
    * TX is split into households (TXH) and NPISH (TXNPISH) in Aggr_ESA2010.do.
    * Each is scaled to its OWN aggregate below and TX is then rebuilt as their
    * sum, rather than scaling the combined TX directly. The two aggregates can
    * differ in sign - TXH is a net payment in DK and IE where TXNPISH is a
    * receipt - so scaling them separately is not the same as scaling the
    * combined total, and it means the NPISH part can be given its own age
    * shape, or moved out of the household account entirely, without touching
    * anything here.
    * SHAPE, not level: each template below is rescaled to its own aggregate by
    * `adjust' further down, so what is set here decides only how the total is
    * spread across ages, never its level. Both parts take the RECEIPT shape
    * RECSHAPE = YEM + BSPPEN (labour income plus pensions), the same one BPX and
    * BROW use; it is defined here because all four need it and dropped after BROW.
    * WHY A RECEIPT SHAPE. TX is already inside the resources the intrahousehold
    * transfer distributes: every YD control in ENTA_aggregates_compilation.do
    * carries `- TX', YDCASH = YD - CHR, and
    * ENTA_consumption_intrahousehold_transfers.do runs `adjustaggr YDCASH' on
    * YDCASHIND. A child's own YDCASHIND - YEM + YPr - YPp + BSP less taxes - is
    * about zero, so the household's net TX receipt lands on the earners and
    * reaches the child as BPW. Crediting the child again here would be a double
    * count.
    * WHY NOT A CONSUMPTION SHAPE FOR TXNPISH. The NPISH final consumption that
    * TXNPISH finances does sit inside C (Aggr_ESA2010.do builds C = P3p - TPSp_g
    * on the S14_S15 row), which is right for the aggregate. But the NPISH part of
    * a child's CH is financed by BPW like the rest of it: consumption and
    * consumption taxes are scaled to their aggregates BEFORE the transfers are
    * computed (adjustaggr YDCASH CHR CHX CHE CHH and adjustaggr TCON in the
    * consumption file). Crediting the child through TXNPISH as well would pay
    * for the same consumption twice, and the second payment would survive as
    * child saving. No choice of shape removes a flow that should not be on the
    * child at all.
    * Levels are untouched - `adjust TXH TXNPISH' below scales each part to its
    * own aggregate, so this only moves them across ages.
    gen double RECSHAPE = YEM + BSPPEN
    * Denmark 2008-2018: early-retirement pay (efterlon) is recorded in BSU at
    * ages 60-65 until income year 2018, and as an old-age benefit from 2019
    * (Statistics Denmark 2021). It replaces labour income like a
    * pension, so it belongs in the receipt shape; without it the shape dips at
    * 60-65 and jumps 13% at 66. The UDB does not separate it
    * from ordinary unemployment benefits (both in PY092). Where efterlon is
    * paid, BSU is 3 to 5 times its level at 55-59 (e.g. 2017: 4,990 euro per
    * person at 63 against 1,227 at 58); at the ages where it had not started
    * yet (60-62 from about 2014, when the entry age rose) BSU is ordinary
    * unemployment benefit, which also replaces labour income. So all BSU at
    * 60-65 is added.
    replace RECSHAPE = RECSHAPE + BSU if CNT2=="DK" & YEAR<=2018 & inrange(AGE, 60, 65) & BSU<.
    gen TXH = RECSHAPE
    gen TXHm = TXH
    gen TXHf = TXH
    gen TXNPISH = RECSHAPE
    gen TXNPISHm = TXNPISH
    gen TXNPISHf = TXNPISH
    * TX itself is not built here - it is rebuilt from TXH + TXNPISH after the
    * adjustment.

    * Taxes on asset income (part of 2.2 TYA)
    gensex TYP YPr

    * Social contributions and benefits of non-financial corporations (5.1.1 and 5.1.2)
    gensex BPSOCnfc YEM
    gensex TPSOCnfc TYEM

    * Private transfers: mandatory private pensions (4.1 and 4.2)
    gensex BPSOCfc BSPPEN
    gensex TPSOCfc TYEM
    * line TYEM AGE if YEAR==2023

    * BPX and BROW take the receipt shape RECSHAPE (defined with the TX block
    * above). It is deliberately the TOTAL profile for both sexes, not
    * YEMm/BSPPENm: the sex-specific version would push remittances towards men,
    * and the household member who receives them is as often a woman.
    * adjustgender then splits by population, as it does for TX.
    * WHY A RECEIPT SHAPE and not the consumption shape. These flows come from
    * outside the household and are already inside the resources the
    * intrahousehold transfer distributes: YDCASHIND is adjustaggr'd to the
    * YDCASH aggregate (YD - CHR, and YD is ESA disposable income, so it
    * contains D7 and hence BROW and BPX). That income lands on the earners,
    * because a child's YDCASHIND is about zero, and reaches the child as BPW,
    * which already covers the child's whole consumption. Crediting the child a
    * second time here would be a double count that surfaces as child saving.
    * It matters most in the high-emigration countries, where BROW was 425 EUR per
    * child in HR, 339 in PT and 294 in LV under the consumption shape.
    * Levels are untouched - BPX and BROW are in `local ben' and are each scaled
    * to their own aggregate below, so this only moves them across ages.

    * Private transfers, other (5.1.4)
    gen BPX  = RECSHAPE
    gen BPXm = RECSHAPE
    gen BPXf = RECSHAPE

    * Transfer from/to ROW (5.1.3)
    gen BROW  = RECSHAPE
    gen BROWm = RECSHAPE
    gen BROWf = RECSHAPE
    drop RECSHAPE

    * Taxes on public and private pensions (2.3.1 and 2.3.3)
    * [INACTIVE] both with the shape of TBSPPEN; tax_`x' brings TBSPEN and
    * TBPPEN with their own rates
    * gensex TBSPEN TBSPPEN
    * gensex TBPPEN TBSPPEN

    ************************************************************
    * Adjustment to aggregates
    ************************************************************

    * [INACTIVE] Sweden had no profile of education consumption while it came
    * from the HBS; it now comes from enrollment and population
    * (Suppl_consumption_educ_profile.do), as in every other country.
    * replace CHE = CHX if CNT2=="SE"

    local inc "YE YM YEM YO YPr YPp"
    local tax "TYEM TYP TPSOCfc TPSOCnfc TBSPEN TBPPEN TBSN" // TPSOC
    local ben "BSP BSFAM BSU BSPPEN BSX BPSOCnfc BPSOCfc BPX BROW" //  BSE BSX BSPEN BSFAM BPSOCfc BPSOCnfc BSF
    local con "CHNR CHR TCON CHE CHH CHX"
    local tpriv "TFWI TFWO"
    local vars `inc' `ben' `tax' `con'

    adjust `vars'
    adjust TXH TXNPISH
    adjustgender `vars' `tpriv' TXH TXNPISH

    * Rebuild TX from its two separately adjusted parts
    capture drop TX TXm TXf
    gensex TX TXH + TXNPISH

    * [INACTIVE] Sweden: CHE set to 0 and added to CHX (see above)
    * replace CHX = CHX + CHE if CNT2=="SE"
    * replace CHXm = CHXm + CHEm if CNT2=="SE"
    * replace CHXf = CHXf + CHEf if CNT2=="SE"
    * replace CHE = 0 if CNT2=="SE"
    * replace CHEm = 0 if CNT2=="SE"
    * replace CHEf = 0 if CNT2=="SE"


    ************************************************************
    * Generate derived and composite variables
    ************************************************************

    * Calculate YM as difference between YEM and YE (YEM is the more reliable smoothed profile)
    * Total: YEM split by the YM share. Where YE + YM = 0 there is no share
    * (0/0 left YE and YM missing); all of YEM is then booked as YE. No
    * `if YEM!=0' guard: where YEM is 0, YM must be 0 too, or YE = -YM.
    replace YM = cond(YE + YM!=0, YEM * YM / (YE + YM), 0)
    * line YEM AGE if YEAR==2023 || line YEM AGE if YEAR==2019
    replace YE = YEM - YM
    * Rescale YM to its own aggregate after the split. The split moves income
    * between YE and YM at each age, so neither adds up to its aggregate any
    * more, while YEM does. YM is scaled to the YM aggregate and capped at
    * YEM, so that YE = YEM - YM is never negative; capped ages are held and
    * the rest of YM is rescaled to what is left of the aggregate, until no
    * age exceeds YEM. YE then reconciles as well, because YEM = YE + YM holds
    * for the aggregates and YEM is unchanged.
    preserve
    use ENTA_aggregates/ENTA_aggregates, clear
    keep if SECTOR=="Households" & IND=="YM"
    keep CNT2 YEAR VALAGGR
    rename VALAGGR YMaggr
    tempfile ymaggr
    save `ymaggr'
    restore
    merge m:1 CNT2 YEAR using `ymaggr', keep(master match) nogen
    gen byte YMcap = 0
    forvalues it = 1/50 {
        replace YMcap = 1 if YM > YEM
        replace YM = YEM if YMcap
        bysort CNT2 YEAR: egen double YMfix  = total(YM * POP * YMcap)
        bysort CNT2 YEAR: egen double YMfree = total(YM * POP * (1 - YMcap))
        gen double YMfac = (YMaggr * 1000000 - YMfix) / YMfree if YMfree!=0
        replace YM = YM * YMfac if !YMcap & YMfac<.
        drop YMfix YMfree YMfac
        count if YM > YEM + 1e-9
        if r(N)==0 continue, break
    }
    count if YM > YEM + 1e-9
    if r(N)>0 display as error "YM still exceeds YEM in " r(N) " cells after 50 rounds"
    replace YE = YEM - YM
    drop YMcap YMaggr

    * Men and women: same split, but the total profile is fixed. The split is
    * done per sex, so the sexes must be scaled back to the total: split, set
    * negative values to 0, then scale the sex profiles to the total at each
    * age. Guarding with `if YEMx!=0' instead would leave YM unscaled where YEM
    * of a sex is 0 and make YE of that sex negative.
    foreach s in m f {
        replace YM`s' = cond(YE`s' + YM`s'!=0, YEM`s' * YM`s' / (YE`s' + YM`s'), 0)
        replace YE`s' = YEM`s' - YM`s'
        replace YM`s' = 0 if YM`s'<0
        replace YE`s' = 0 if YE`s'<0
    }
    adjustgender YE YM
    * YE and YM are scaled separately, so rebuild YEM by sex from them;
    * otherwise the NTA identities by sex break (YL and YAH use YE/YM, the
    * disposable income side uses YEM). The total YEM is unchanged.
    replace YEMm = YEm + YMm
    replace YEMf = YEf + YMf

    * Taxes less subs on production (part of taxes on asset income)
    gensex TPN YEM
    adjust TPN
    adjustgender TPN

    * Taxes on benefits (2.3)
    * Rebuild TBSPPEN from its two adjusted parts, the same way TX is rebuilt
    * from TXH + TXNPISH above. The version carried down from the microdata is
    * never scaled to an aggregate (TBSPEN and TBPPEN are, their parent is
    * not), so it would disagree with its own published aggregate. The copies
    * taken earlier are made before this point and only their shape matters
    * there, so rebuilding here is safe.
    capture drop TBSPPEN TBSPPENm TBSPPENf
    gensex TBSPPEN TBSPEN + TBPPEN

    gensex TB TBSPEN + TBPPEN + TBSN

    * Asset income (1.2 YA)
    gensex YP YPr - YPp
    gensex YA YO + YPr - YPp //+ TPNp
    * line YA YP AGE if YEAR==2023 || line YA YP AGE if YEAR==2019

    * Total primary income (1 Y))
    gensex Y YEM + YA
    * line Y AGE if YEAR==2023 || line Y AGE if YEAR==2019

    * Taxes on assets and asset income (2.2 TYA)
    * Allocated by GROSS asset income (YPr + YO), not net (YP + YO). A net
    * profile is not usable as a proportional allocation key: YPp drags the
    * mortgage-paying ages negative, so the shape partly cancels itself out
    * and the scale factor becomes unstable and sign-fragile. Economically gross
    * is also the right base here: D59
    * is mostly recurrent tax on gross asset value, not on net wealth, so
    * deducting mortgage interest from the allocator is wrong anyway.
    gensex TA YPr + YO
    adjust TA
    adjustgender TA
    * TPN is deliberately NOT included here. It already reaches the household
    * side through TYEM: the TYEM aggregate that `adjust` targets contains it
    * (ENTA_aggregates_compilation.do), so adding it again would count it twice
    * and TYA would miss its aggregate by exactly TPN. It belongs in TYEM on the
    * concept too: the primary-income gross-up TPNp is booked in YM/YEM, YA
    * excludes it, and the TPN profile is itself shaped by YEM.
    gensex TYA TYP + TA

    * Public pension benefits (3.1 BSPEN)
    capture drop BSPEN*
    gensex BSPEN BSPPEN - BPSOCfc

    * Total social benefits from government sector (3. BS)
    gensex BS BSPEN + BSFAM + BSU + BSX
    * line BS AGE if YEAR==2023 ///
    * || line BS AGE if YEAR==2008

    * Transfer benefits, private (5.1 BPB). TFBHI and TFBHO are the domestic
    * inter-household transfers received and paid (EU-SILC HY080/HY130, from
    * ENTA_consumption_intrahousehold_transfers.do). They have no ESA
    * aggregate - transfers between resident households cancel within the
    * sector - and are equal in total, so BPB keeps its aggregate; they move
    * transfers between ages, consistent with the intrahousehold transfers,
    * which use the same amounts.
    gensex BPB BPSOCnfc + BROW + BPX - TPSOCnfc + TFBHI - TFBHO
    * line BPB AGE if YEAR==2023 || line BPB AGE if YEAR==2019

    * Funded pensions (4. BPPEN)
    gensex BPPEN BPSOCfc - TPSOCfc

    * D8 (adjustment for the change in pension entitlements) has no age profile.
    * ENTA ignores it in all income, transfer and saving concepts; funded
    * pensions enter disposable income gross through BPPEN, as in ESA B6N.
    * ENTA saving + D8 = ESA net saving B8N (aggregate level only).
    * line BPPEN AGE if YEAR==2023 || line BPPEN AGE if YEAR==2019

    * Total taxes households (2 T)
    gensex T TYEM + TYA + TX + TCON + TB // + TFWO + TP

    * Intra-household transfer outflows (5.2.2 TFWO)
    rename TFWO TPW
    rename TFWOm TPWm
    rename TFWOf TPWf

    * Intra-household transfer inflows (5.2.1 TFWI)
    rename TFWI BPW
    rename TFWIm BPWm
    rename TFWIf BPWf
    * line BPW TPW AGE if YEAR==2023
    * line BPW BPWm BPWf AGE if YEAR==2023

    * Total private transfers (5 BP)
    gensex BP BPB + BPW - TPW // - TB
    * line BP AGE if YEAR==2023

    * Total benefits
    gensex B BS + BPB + BPPEN + BPW - TPW // - TB

    * Disposable income, ESA
    gensex YD0 Y - T + BS + BPB + BPPEN
    * line YD0 AGE if YEAR==2023

    * Disposable income, NTA (incl. intrahousehold transfers)
    gensex YD YD0 - TPW + BPW
    * line YD AGE if YEAR==2019

    * Disposable income, employment income and transfers
    gen YD1 = YEM + BS + BPPEN - TYEM - TB - TCON
    gen YD1m = YEMm + BSm + BPPENm - TYEMm - TBm - TCONm
    gen YD1f = YEMf + BSf + BPPENf - TYEMf - TBf - TCONf
    * line YD1 AGE if YEAR==2019

    * Disposable income, YD1 plus transfers within households
    gen YD2 = YD1 - TPW + BPW
    gen YD2m = YD1m - TPWm + BPWm
    gen YD2f = YD1f - TPWf + BPWf
    * line YD2 AGE if YEAR==2019

    * Disposable income, employment income and transfers + operating surplus
    gen YD3 = YD2 + YO
    gen YD3m = YD2m + YOm
    gen YD3f = YD2f + YOf
    * line YD3 AGE if YEAR==2019
    * browse CNT2 YEAR YD YD1 YD2 YD3

    * Consumption at basic prices (8 CH)
    gensex CH CHE + CHH + CHX + CHR
    * line CH AGE if YEAR==2019

    * Consumption at market prices
    capture drop C
    gen C = CH + TCON
    * line BPW CH C TCON AGE if YEAR==2019
    drop C

    * Saving, households (9 SH)
    gensex SH YD - CH


    ************************************************************
    * Test flow identities
    ************************************************************

    * Saving profile
    * line SH SHm SHf AGE if YEAR==2015

    * Plot basic quantities
    /*
    * BPSOCnfc + BROW + BPX - TPSOCnfc
    local var "SH"
    line `var' AGE if YEAR==2015, lcol(yellow) ///
    || line `var' AGE if YEAR==2019, lcol(orange) ///
    || line `var' AGE if YEAR==2023, lcol(blue)
    */

    * Flow equation
    gen DI = Y - T + B
    gen USE = SH + CH
    * line DI USE AGE if YEAR==2019

    gen DIm = Ym - Tm + Bm
    gen USEm = SHm + CHm
    * line DIm USEm AGE if YEAR==2019

    gen DIf = Yf - Tf + Bf
    gen USEf = SHf + CHf
    * line DIf USEf AGE if YEAR==2019

    /*
    line SH SHf SHm AGE if YEAR==2019
    line Y Yf Ym AGE if YEAR==2019
    line B Bf Bm AGE if YEAR==2019
    line BS BSf BSm AGE if YEAR==2019
    line TFWI TFWIf TFWIm AGE if YEAR==2019
    */

    * Flow equation in NTA terminology
    gen DIc = YE + YM + YA - T + B
    * line DIc USE AGE if YEAR==2015 ///
    * || line DIc USE AGE if YEAR==2019 ///
    * || line DIc USE AGE if YEAR==2023
    drop DI DIc USE DIm DIf USEm USEf



    ********************************************************************************
    * 2. Corporation sector
    ********************************************************************************

    * Corporation variables end with C
    capture drop YDC YDCm YDCf
    * The corporate sector is allocated across ages by property income
    * RECEIVED, not by net property income YP (= YPr - YPp). Corporate income
    * accrues to households in proportion to asset ownership; YPp is mortgage
    * interest, a liability-side flow, and does not belong in an ownership
    * key. YP is also unusable as a key because it can be negative in the
    * aggregate (Ireland and Romania in 2008): adjustsec rescales by
    * VALAGGR / sum(profile * POP) with no sign guard, so a negative
    * denominator mirrors the whole profile. YPr is floored at 0 per age and
    * its aggregate is positive in every country and year; it also keeps
    * adjustgender's sex shares inside [0,1].
    * The key is YPrX, YPr without private pensions (PY080G, built in
    * ENTA_income.do): pensions are paid out of pension assets, not from the
    * ownership of corporations, and would put the key above age 60 (EU-SILC
    * 2010, ages 60-69 relative to 30-49: ES 2.16 without, 3.75 with them).
    * YPrX is a shape only and is dropped after this block.
    local varcor "Y T BPB S" // BPSOCnfc BROW TPSOCnfc TPX
    foreach var of local varcor {
        gen `var'C = YPrX
        gen `var'Cm = YPrXm
        gen `var'Cf = YPrXf

        adjustsec `var'C `var' Corporations
        adjustgender `var'C
    }
    drop YPrX YPrXm YPrXf

    * Funded pensions and private transfers
    gensex BPSOCfcC - BPSOCfc
    gensex TPSOCfcC - TPSOCfc
    gensex BPPC - BPSOCfc + TPSOCfc

    * Total disposable income, no funded pensions
    gensex YDCX YC - TC + BPBC

    * Total disposable income
    gensex YDC YC - TC + BPBC + BPPC

    * Saving, funded pensions not included
    * rename SC SCc
    gensex SCX YDCX

    * Saving, funded pensions
    gensex SCP BPPC

    * Saving, corporations total
    capture drop SC SCm SCf
    gensex SC SCX + SCP
    * line SC YDC AGE if YEAR==2019

    * Flow equation
    gen DI = YC - TC + BPBC + BPPC
    gen USE = SC
    * line DI USE AGE if YEAR==2019
    drop DI USE


    ************************************************************
    * Save ENTA private sector data in wide format, combine private sector data for all countries
    ************************************************************

    sort CNT2 YEAR AGE
    save ENTA_output_data/ENTA_priv_wide_`x', replace
}


* global country "FR"
clear
foreach x in $country {
    append using ENTA_output_data/ENTA_priv_wide_`x'
}

* The 26 per-country files are intermediates of this file alone: written by
* the loop above, appended here, read by nothing else. They are erased once
* the append has succeeded, so a failure part-way through leaves them on
* disk. To re-run the append alone, comment the erase out for that session.
foreach x in $country {
    cap erase ENTA_output_data/ENTA_priv_wide_`x'.dta
}


********************************************************************************
* 3. Government sector
********************************************************************************

************************************************************
* Government transfers, saving and other consumption
************************************************************

* Asset income of government (distributed according to tax profile)
gensex YAG T
adjustsec YAG Y Government
adjustgender YAG

* Public transfers, net received from the Rest of the World (TGNF =
* -BROW of the Government sector, which is net paid)
gensex TGNF T
adjustsec TGNF TGNF "NTA Aggregates"
adjustgender TGNF

* Saving (or rather dissaving) of government
gensex SG T
adjustsec SG S Government
adjustgender SG

* Other public consumption
gen CGX = 1
gen CGXm = 1
gen CGXf = 1
adjustsec CGX CGX Government
adjustgender CGX

************************************************************
* Health
************************************************************

* Health data has been combined from different sources
sort CNT2 YEAR AGE
merge m:1 CNT2 YEAR AGE using ENTA_input_data/ENTA_input_datasets/CGH_AWG, update
drop if _merge==2
drop _merge
adjustsec CGH CGH Government
adjustgender CGH
sort CNT2 YEAR AGE
* line CGH AGE if YEAR==2019


************************************************************
* Education
************************************************************

sort CNT2 YEAR AGE
merge 1:1 CNT2 YEAR AGE using ENTA_input_data/ENTA_input_datasets/enrollment
keep if _merge==3 | _merge==1
drop _merge
* The published data start in 2008: enrollment starts in 2008, so 2007
* would have no education consumption. This is the cut for all published
* files, ENTA_priv_wide included (the drop before the long files is only
* a guard).
drop if YEAR<=2007

local enr "CGEPP CGESEC CGEPSEC CGETER"
foreach var of local enr {
    replace `var' = `var' / POP
    replace `var'm = `var'm / POPm
    replace `var'f = `var'f / POPf
}

gen CGEX = 1
gen CGES = CGESEC + CGEPSEC // becasue of mismatch between post-secondary expenditure and enrollment
gen CGESm = CGESECm + CGEPSECm
gen CGESf = CGESECf + CGEPSECf

local vars "CGEPP CGES CGETER"
foreach var of local vars {
    replace `var' = 1 if `var'>1
    replace `var'm = 1 if `var'm>1
    replace `var'f = 1 if `var'f>1
}

* browse CNT2 YEAR CGEPP CGES CGESEC CGEPSEC
adjustsec CGEPP CGEPP Government
adjustsec CGES CGES Government
adjustsec CGESEC CGESEC Government
adjustsec CGEPSEC CGEPSEC Government
adjustsec CGETER CGETER Government
adjustgender CGEPP CGES CGESEC CGEPSEC CGETER
adjustsec CGEX CGEX Government
gen CGEXm = CGEX
gen CGEXf = CGEX

capture drop CGE CGEm CGEf
gen CGE = CGEPP + CGES + CGETER + CGEX

gen CGEm = CGEPPm + CGESm + CGETERm + CGEXm
gen CGEf = CGEPPf + CGESf + CGETERf + CGEXf
* browse AGE CGE CGESEC CGEPP CGETER if CNT2=="DE" & YEAR==2023

gensex CG CGE + CGH + CGX

save ENTA_output_data/ENTA_priv_wide, replace


********************************************************************************
* 4. Save data in long format, ENTA by sector
********************************************************************************

use ENTA_output_data/ENTA_priv_wide, clear

************************************************************
* Reshape to long format
************************************************************

* Only published indicators are reshaped.
* [INACTIVE] not reshaped: the helper totals YD0, BSP (internal check),
* BSPPEN, SCX, SCP and the ESA YDC (= SC; the NTA YDC is built in
* compilation2); the LFS series EMPL, EMPLFTACT, WHRUSU, WHRACT and the
* EU-SILC series WHRUSUsilc, EMPLFTsilc - all stay in ENTA_priv_wide.
* local inc "Y YE YM YEM YA YO YP EHI YD YD0 YD1 YD2 YD3" // EMPL EMPLFT
* local ben "BS BSP BSU BSX BSPPEN BSPEN BSFAM TPSOCfc BPSOCfc BP BPB BPPEN BPW TPW"
* local use "CH SH CHE CHH CHR CHX CG CGE CGH CGX SCX SCP"
* local corp "YC TC BPBC BPPC YDC SC"
* local empl "EMPL EMPLFT EMPLFTACT EMPLSTAT WHRUSU WHRUSUT WHRACT WHRACTT WHRUSUsilc EMPLSTATsilc EMPLFTsilc"
local inc "Y YE YM YEM YA YO YP EHI YD YD1 YD2 YD3"
local taxes "T TYEM TYA TX TCON TB TBSPEN TBSN TBPPEN" // T  TCON TPW
local ben "BS BSU BSX BSPEN BSFAM TPSOCfc BPSOCfc BP BPB BPPEN BPW TPW"
local use "CH SH CHE CHH CHR CHX CG CGE CGH CGX"
local corp "YC TC BPBC BPPC SC"
local empl "EMPLFT EMPLSTAT WHRUSUT WHRACTT EMPLSTATsilc"
local vars `inc' `taxes' `ben' `use' `corp' `empl'

foreach var of local vars {

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
foreach var of local vars {
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

* The same file labels the aggregates, so that code, number and label agree.
* Indicators without a label there are not published.
do ENTA_input_data/Prog_ENTA_labels.do esa

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
drop if YEAR<2008   // guard only: 2007 is already dropped in Section 3 (education)
foreach var of varlist _all {
    label var `var' ""
}


do ENTA_input_data/Prog_gen_country_name_from_CNT2.do
sort INDICATOR COUNTRY YEAR SEX AGE

outsheet using ENTA_output_data/ENTA_esa.csv, delim(,) replace
save ENTA_output_data/ENTA_esa, replace

* Compressed copy for Zenodo upload (file size) - .zip, the simplest and
* most common compressed-archive format for external publication.
*
* Built with Stata's zipfile, not 7-Zip via shell: `shell' does nothing in
* /e batch mode (no command, no file, exit code 0), so the archive would
* silently not exist. saving(, replace) overwrites in place, so nothing is
* removed unless a new file takes its place.
*
* Still built from INSIDE ENTA_output_data, because zipfile stores the
* path as given: naming the file with a folder prefix would put that
* folder inside the archive and a Zenodo user unzipping it would get the
* folder instead of a bare CSV.
cd ENTA_output_data
zipfile ENTA_esa.csv, saving(ENTA_esa.zip, replace)
cd $wkdir




********************************************************************************
* 5. NTA and ENTA norms; publish ENTA_units
********************************************************************************
* The norms are averages of the income age profile at ages 30-49, so they are
* built here, after the profiles, and not in ENTA_units.do, which reads only
* aggregates and runs before the profiles. ENTA_aggregates/ENTA_units.dta
* plus the two norms is the published ENTA_units.
*   NORMnta  - average labour income YL = YE + 2/3 YM, weighted by POP
*   NORMenta - average employment income of men YEMm, weighted by POPm
* A year without an income profile (before EU-SILC, 2024, HR 2008) gets a
* missing norm, not 0: a sum over no profile would be 0. The norms before
* 2008 are set to missing as well: the published profiles start in 2008.
* Built for all 26 countries whatever $country says, because the published
* file covers all of them.

use ENTA_input_data/ENTA_input_datasets/population80w, clear
keep if YEAR>=1995
keep if CNT2=="AT" | CNT2=="BE" | CNT2=="BG" | CNT2=="CY" | CNT2=="CZ" | ///
    CNT2=="DE" | CNT2=="DK" | CNT2=="EE" | CNT2=="EL" | CNT2=="ES" | ///
    CNT2=="FI" | CNT2=="FR" | CNT2=="HR" | CNT2=="HU" | CNT2=="IE" | ///
    CNT2=="IT" | CNT2=="LT" | CNT2=="LU" | CNT2=="LV" | CNT2=="NL" | ///
    CNT2=="PL" | CNT2=="PT" | CNT2=="RO" | CNT2=="SE" | CNT2=="SI" | ///
    CNT2=="SK"

* Germany's SILC profile uses the source's age bands: 5-year groups from
* 2022 (16-19, then 20-24, ...) and top-coding at 73 in 2014-2018. Match
* them for the merge, then restore the single years.
gen AGEt = AGE
replace AGE = 5*floor(AGE/5) if AGE>=20 & YEAR>=2022 & CNT2=="DE"
replace AGE = 80 if AGE>=80 & YEAR>=2022 & CNT2=="DE"
replace AGE = 16 if AGE>=16 & AGE<20 & YEAR>=2022 & CNT2=="DE"
replace AGE = 73 if AGE>=73 & YEAR>=2014 & YEAR<=2018 & CNT2=="DE"

foreach x in AT BE BG CY CZ DE DK EE EL ES FI FR HR HU IE IT LT LU LV NL PL PT RO SE SI SK {
    merge m:1 CNT2 YEAR AGE using "ENTA_ageprofiles/ageprofiles/inc_`x'", update
    drop _merge
}
replace AGE = AGEt
drop AGEt

* Labour income, scaled to the aggregates over all ages before the 30-49
* average is taken
adjust YE YM YEM
adjustgender YE YM YEM
gen YL = YE + 2/3*YM

keep if AGE>=30 & AGE<=49
gen YLPOP  = YL*POP
gen YEMPOP = YEMm*POPm
gen byte hasYL  = !missing(YL)
gen byte hasYEM = !missing(YEMm)
collapse (sum) YLPOP POP YEMPOP POPm hasYL hasYEM, by(CNT2 YEAR)

gen NORMnta  = YLPOP/POP   if hasYL>0  & YEAR>=2008
gen NORMenta = YEMPOP/POPm if hasYEM>0 & YEAR>=2008
label variable NORMnta "NTA norm: avg labour income (YL), population-weighted, ages 30-49"
label variable NORMenta "ENTA norm: avg male employment income (YEM), ages 30-49"
keep CNT2 YEAR NORMnta NORMenta
tempfile norms
save `norms'

* Publish
use ENTA_aggregates/ENTA_units, clear
merge 1:1 CNT2 YEAR using `norms', keep(master match) nogen
sort CNT2 YEAR
save ENTA_output_data/ENTA_units, replace
export delimited using ENTA_output_data/ENTA_units.csv, replace
