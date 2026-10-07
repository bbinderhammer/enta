********************************************************************************
* validation_agenta_ya.do
*
* Content:  Decomposes the difference in the age profile of total asset income
*           YA (= YAF + YAG, NTA format) between ENTA 2010 and AGENTA 2010 into
*           the allocation rules in which the two differ. Companion of
*           ENTA_output_control/4a_external_agenta.do.
*
*           ENTA YA = YPr - YPp + YO + YM/3 + YC + YAG (compilation1/2), each
*           scaled to its own ESA aggregate. AGENTA (nta2010AllCountries_*_v3.do)
*           spreads corporate income, interest and other property income by
*           HY090G + HY040G given to the household head (the member with the
*           highest personal income, the oldest on ties), household interest
*           paid by the same shape, imputed rent by HY030G to the head, and
*           the capital share of self-employment income by self-employment
*           income. The rules are switched one at a time from ENTA's to
*           AGENTA's, on unsmoothed EU-SILC 2010 shapes, with every component
*           scaled to ENTA's own 2010 total; YAG is ENTA's in every variant:
*             V0  ENTA rules: YPr = (HY090G + HY040G)/adults + PY080G, YC by
*                 the same without PY080G, YPp = HY100G over the adults
*                 who hold the dwelling, YO = room-based estimate over them
*             V1  V0, private pensions (PY080G) out of YPr
*             V2  V1, property income received and YC to the household head
*             V3  V2, interest paid (YPp) with the shape of property income
*                 received (head), as AGENTA
*             V4  V3, imputed rent HY030G to the head (where HY030G exists)
*             V5  V4 with AGENTA's composition of private asset income (its
*                 aggregates.csv: head-shaped YKFC + YPFX + YMFI - YMFOC -
*                 YMFOHH, imputed rent YKFH, self-employment YKFB), scaled to
*                 ENTA's YAF total, and YAG at AGENTA's ratio YAG/YAF: what is
*                 left is the data (EU-SILC release, ESA vintage) and smoothing
*           Statistic: mean of YA at ages 65-80 over mean labour income
*           (ENTA YL) at 30-49, and the correlation over age with AGENTA.
*           The published ENTA profile (smoothed) is shown beside V0 (raw).
*
* Input:    ENTA_output_data/ENTA_priv_wide.dta, $silcwd/data/silc_*.dta,
*           ENTA_output_control/benchmarks/nta2010_AGENTA_long_Euro.csv,
*           ENTA_output_control/benchmarks/nta2010_AGENTA_aggregates.csv
*           (AGENTA's aggregates by country, one file)
* Output:   ENTA_microdata_checks/results/agenta_ya_decomp.csv. No log is
*           written.
* Run:      after ENTA_setup_TU.do ($silcwd), from the ENTA root
********************************************************************************

version 19
set more off
local out "ENTA_microdata_checks/results"
capture mkdir "ENTA_microdata_checks/results"
capture mkdir "`out'"
local cnts "AT BE BG CY CZ DE DK EE EL ES FI FR HU IE IT LT LU LV PL PT RO SE SI SK"


********************************************************************************
* 1. AGENTA 2010: YA and YL by age
********************************************************************************

import delimited using "ENTA_output_control/benchmarks/nta2010_AGENTA_long_Euro.csv", ///
    varnames(1) case(preserve) clear
drop if strpos(country, "EU25") | country=="United Kingdom"
keep if sex=="total"
do "ENTA_input_data/Prog_gen_CNT2_from_country_name.do"
keep CNT2 age YA YL
rename (age YA YL) (AGE A_YA A_YL)
tempfile agenta
save `agenta'


* AGENTA's aggregates: composition of private asset income. The file holds
* the aggregates.csv of every country of the AGENTA 2010 results, stacked.
import delimited using "ENTA_output_control/benchmarks/nta2010_AGENTA_aggregates.csv", ///
    varnames(1) case(preserve) stringcols(1 2) clear
keep if inlist(varname, "YKFH", "YKFB", "YKFC", "YPFX", "YMFI", "YMFOC", "YMFOHH", "YAG", "YAF")
reshape wide aggregates, i(CNT2) j(varname) string
rename aggregates* G_*
gen double gH = (G_YKFC + G_YPFX + G_YMFI - G_YMFOC - G_YMFOHH) / G_YAF
gen double gR = G_YKFH / G_YAF
gen double gB = G_YKFB / G_YAF
gen double gG = G_YAG / G_YAF
gen double gchk = gH + gR + gB
summarize gchk
keep CNT2 gH gR gB gG
save `agagg', replace


********************************************************************************
* 2. EU-SILC 2010 shapes by age, per country
********************************************************************************

tempfile shapes
local first 1
foreach x of local cnts {
    use CNT2 YEAR HHID AGE WEIGHTa ADULT NADULT ACCOMODATION YEM YM BSPPEN ///
        PY080G PY090G PY100G HY030G HY040G HY090G HY100G YOest ///
        using "$silcwd/data/silc_`x'" if YEAR==2010, clear
    foreach v in YEM YM BSPPEN PY080G PY090G PY100G HY030G HY040G HY090G HY100G YOest {
        replace `v' = 0 if missing(`v')
    }
    * Head as in AGENTA: highest personal income (earnings, self-employment,
    * unemployment and old-age benefits), the oldest on ties, at least 16
    gen double inc = YEM + PY090G + BSPPEN
    bysort HHID: egen double _mx = max(inc)
    gen byte head = inc==_mx & AGE>=16
    bysort HHID: egen byte _nh = total(head)
    bysort HHID: egen _amx = max(cond(head, AGE, .))
    replace head = 0 if _nh>1 & AGE!=_amx
    bysort HHID (head AGE): replace head = 0 if head==1 & head[_N]==1 & _n<_N
    bysort HHID: egen byte _nh2 = total(head)
    bysort HHID: egen _aold = max(AGE)
    replace head = 1 if _nh2==0 & AGE==_aold
    bysort HHID (head AGE): replace head = 0 if head==1 & _n<_N
    drop _mx _nh _amx _nh2 _aold

    gen double HP = HY090G + HY040G                      // household property income received
    bysort HHID: egen double _nacc = total(ACCOMODATION==1)
    gen double s_adult = cond(ADULT==1, HP/NADULT, 0)
    gen double s_pen   = PY080G
    gen double s_head  = cond(head==1, HP, 0)
    gen double s_mort  = cond(ACCOMODATION==1 & _nacc>0, HY100G/_nacc, 0)
    gen double s_ir    = YOest
    gen double s_irh   = cond(head==1, HY030G, 0)
    gen double s_ym    = YM
    replace AGE = min(AGE, 80)
    collapse (mean) s_* [pw=WEIGHTa], by(CNT2 AGE)
    if `first' {
        save `shapes'
        local first 0
    }
    else {
        append using `shapes'
        save `shapes', replace
    }
}


********************************************************************************
* 3. ENTA 2010 components and the variants
********************************************************************************

use CNT2 YEAR AGE POP YPr YPp YO YM YE YC YAG using "ENTA_output_data/ENTA_priv_wide" ///
    if YEAR==2010, clear
merge 1:1 CNT2 AGE using `shapes', keep(match) nogen
merge 1:1 CNT2 AGE using `agenta', keep(match) nogen
gen double YL = YE + 2/3*YM

* Scale a shape to the ENTA total of component k: gen p = shape * T_k / sum(shape*POP)
capture program drop scaleto
program define scaleto
    args newvar shape comp
    tempvar a b
    bysort CNT2: egen double `a' = total(`comp'*POP)
    bysort CNT2: egen double `b' = total(`shape'*POP)
    gen double `newvar' = cond(`b'!=0, `shape' * `a' / `b', 0)
end

gen double s_pr0 = s_adult + s_pen
scaleto pr0  s_pr0   YPr
scaleto pr1  s_adult YPr
scaleto prh  s_head  YPr
scaleto c0   s_adult YC
scaleto ch   s_head  YC
scaleto pp0  s_mort  YPp
scaleto pph  s_head  YPp
scaleto yo0  s_ir    YO
scaleto yoh  s_irh   YO
scaleto ym   s_ym    YM
* where HY030G is not delivered (DE), keep the room-based imputed rent
bysort CNT2: egen double _irh = total(s_irh)
replace yoh = yo0 if _irh==0

gen double E_pub = YPr - YPp + YO + YM/3 + YC + YAG
gen double V0 = pr0 - pp0  + yo0 + ym/3 + c0 + YAG
gen double V1 = pr1 - pp0  + yo0 + ym/3 + c0 + YAG
gen double V2 = prh - pp0  + yo0 + ym/3 + ch + YAG
gen double V3 = prh - pph  + yo0 + ym/3 + ch + YAG
gen double V4 = prh - pph  + yoh + ym/3 + ch + YAG

* V5: AGENTA's composition, scaled to ENTA's YAF total
merge m:1 CNT2 using `agagg', keep(master match) nogen
gen double _yaf = YPr - YPp + YO + YM/3 + YC
bysort CNT2: egen double TYAF = total(_yaf*POP)
foreach p in H R B {
    local s = cond("`p'"=="H", "s_head", cond("`p'"=="R", "s_irh", "s_ym"))
    bysort CNT2: egen double _b`p' = total(`s'*POP)
    gen double a`p' = cond(_b`p'!=0, `s' * g`p' * TYAF / _b`p', 0)
}
* no HY030G (DE): the room-based shape carries AGENTA's imputed rent
bysort CNT2: egen double _bR2 = total(s_ir*POP)
replace aR = s_ir * gR * TYAF / _bR2 if _bR==0
bysort CNT2: egen double _tyag = total(YAG*POP)
gen double yag5 = YAG * (gG*TYAF) / _tyag
gen double V5 = aH + aR + aB + yag5
* composition of private asset income, ENTA and AGENTA
bysort CNT2: egen double _tr = total(YO*POP)
bysort CNT2: egen double _tm = total(YM/3*POP)
gen double eR = _tr / TYAF
gen double eB = _tm / TYAF
gen double eG = _tyag / TYAF


********************************************************************************
* 4. Old-age level and correlation with AGENTA
********************************************************************************

bysort CNT2: egen double nE = mean(cond(inrange(AGE,30,49), YL, .))
bysort CNT2: egen double nA = mean(cond(inrange(AGE,30,49), A_YL, .))
tempname h
tempfile res
postfile `h' str2 CNT2 double(oldA oldPub oldV0 oldV1 oldV2 oldV3 oldV4 oldV5 ///
    rPub rV0 rV1 rV2 rV3 rV4 rV5 eR gR eB gB eG gG) using `res'
quietly levelsof CNT2, local(done) clean
foreach c of local done {
    quietly {
        preserve
        keep if CNT2=="`c'"
        summarize A_YA if AGE>=65, meanonly
        local oA = r(mean)/nA[1]
        foreach v in E_pub V0 V1 V2 V3 V4 V5 {
            summarize `v' if AGE>=65, meanonly
            local o`v' = r(mean)/nE[1]
            corr `v' A_YA
            local r`v' = r(rho)
        }
        post `h' ("`c'") (`oA') (`oE_pub') (`oV0') (`oV1') (`oV2') (`oV3') (`oV4') (`oV5') ///
            (`rE_pub') (`rV0') (`rV1') (`rV2') (`rV3') (`rV4') (`rV5') ///
            (eR[1]) (gR[1]) (eB[1]) (gB[1]) (eG[1]) (gG[1])
        restore
    }
}
postclose `h'
use `res', clear
format old* r* %6.3f
export delimited using "`out'/agenta_ya_decomp.csv", replace
display _n "YA at 65-80 over YL at 30-49: AGENTA, ENTA published, and ENTA with the rules"
display "switched one at a time (V0 ENTA rules raw ... V4 all AGENTA rules)"
list CNT2 oldA oldPub oldV0 oldV1 oldV2 oldV3 oldV4 oldV5, noobs clean
display _n "Correlation over age with AGENTA"
list CNT2 rPub rV0 rV1 rV2 rV3 rV4 rV5, noobs clean
display _n "Shares in private asset income YAF, ENTA (e) and AGENTA (g): imputed rent R,"
display "capital share of self-employment income B, government asset income over YAF G"
list CNT2 eR gR eB gB eG gG, noobs clean
collapse (median) old* r*
display _n "Medians over countries"
list, noobs clean
