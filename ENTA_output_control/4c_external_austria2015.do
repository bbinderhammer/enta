********************************************************************************
* 4c_external_austria2015.do
*
* Content:  Compares the published ENTA age profiles for Austria 2015 with the
*           Austrian NTA 2015 (Hammer 2020, "National Transfer Accounts for
*           Austria 2015 (OA edition)", AUSSDA, https://doi.org/10.11587/4EOXZO;
*           results ENTA_output_control/benchmarks/nta_AT_2015_long.dta, method
*           ENTA_output_control/benchmarks/NTA_2015_description.pdf). Age
*           allocation in the Austrian NTA:
*             from ADMINISTRATIVE data (independent of ENTA's sources):
*               employment and self-employment income, taxes on labour and
*               self-employment, cash benefits (integrated wage and income tax
*               statistics, incl. pensions); public health (hospital financing,
*               social insurance data)
*             from other surveys: private asset income and capital taxes
*               (HFCS wave 2, net wealth without main residence and business
*               wealth); consumption taxes and private consumption (consumer
*               expenditure survey 2014/15)
*             with ENTA's own sources or methods (not independent): rental
*               income (EU-SILC, person responsible for housing); private
*               consumption (Konsumerhebung 2014/15, which ENTA uses for AT
*               2015 too, same equivalence scale); intra-household transfers
*               (same method, EU-SILC with imputed consumption); public
*               education (enrolment by level x expenditure by level)
*             by assumption: other social transfers (TGSXIC) equal per person,
*               other public transfers (TGXIC) equal per adult
*
*           Pairs of indicators (Austrian NTA -> ENTA). Benefits follow COFOG
*           in both, but ENTA's pensions BSPEN are old age + survivors +
*           sickness and disability (GF1002 + GF1003 + GF1001, care
*           allowances included), so the Austrian disability and sickness
*           benefits go with the pensions:
*             YL                  -> YE     income of employees
*             YS                  -> YM     income from self-employment
*             YL + YS             -> YEM    employment income
*             YAF                 -> YAF    private asset income (NTA file)
*             YR                  -> YO     rental income / operating surplus
*                                           of households
*             TGYL + TGYS         -> TYEM   taxes and contributions on labour
*             TGYA                -> TYA    capital taxes (Austrian series incl.
*                                           those of corporations)
*             TGC                 -> TCON   taxes on consumption
*             TGSOAIC + TGSDIC    -> BSPEN - TB  pensions, disability and
*                                           sickness; the Austrian NTA subtract
*                                           ALL taxes on benefits from the
*                                           old-age benefits
*             TGSUIC              -> BSU    unemployment
*             TGSFIC              -> BSFAM  family (and education grants)
*             TGSUIC + TGSFIC     -> BSU + BSFAM (BUF)  the two together: other
*                                           labour-market benefits of women at
*                                           25-35 (TGSUICoth) against EU-SILC
*                                           family benefits
*             TGSXIC + TGXIC      -> BSX    other benefits (Austrian: by
*                                           assumption, see above)
*             TGIC                -> BS - TB  cash benefits, net of taxes
*             CGE, CGH, CG        -> CGE, CGH, CG
*             CF                  -> CF     private consumption (NTA file)
*             TFWI, TFWO          -> BPW, TPW  intra-household transfers
*           Both sources are euro per person in 2015, scaled to national
*           accounts, so levels are compared too. Ages 0-79 and 80+ (the
*           Austrian 80-90 as a population-weighted mean).
*           Statistics per indicator, for both sexes together:
*             r        correlation over ages 0-80
*             mad      mean absolute difference, each profile divided by its
*                      own mean employment income (YEM; YL + YS) at 30-49
*             lvl      ENTA total / Austrian NTA total (per capita x each
*                      source's own population)
*             peakE/A, chE/A (0-19), oldE/A (65-80) as in 4b_external_nta.do
*             mshE/A   male share of the total (men and women)
*             rM, rF   correlation over age for men and for women
*
* Input:    ENTA_output_data/ENTA_esa.dta, ENTA_output_data/ENTA_nta.dta,
*           ENTA_output_control/benchmarks/nta_AT_2015_long.dta
* Output:   ENTA_output_control/results/external/at2015_stats.csv, at2015_*.png,
*           and the log
* Run:      from the ENTA root, standalone: do ENTA_output_control/4c_external_austria2015.do
********************************************************************************

version 19
clear
set more off
local out "ENTA_output_control/results/external"
capture mkdir "ENTA_output_control/results"
capture mkdir "`out'"
local atfile "ENTA_output_control/benchmarks/nta_AT_2015_long.dta"
local codes "YE YM YEM YAF YO TYEM TYA TCON PEN BSU BSFAM BUF BSX BSN CGE CGH CG CF BPW TPW"


********************************************************************************
* 1. Austrian NTA 2015 (administrative)
********************************************************************************

use "`atfile'", clear
keep age SEX POP YL YS YAF YR TGYL TGYS TGYA TGC TGSOAIC TGSUIC TGSFIC TGSDIC ///
    TGSXIC TGXIC TGIC CGE CGH CG CF TFWI TFWO
gen double A_YE    = YL
gen double A_YM    = YS
gen double A_YEM   = YL + YS
gen double A_YAF   = YAF
gen double A_YO    = YR
gen double A_TYEM  = TGYL + TGYS
gen double A_TYA   = TGYA
gen double A_TCON  = TGC
gen double A_PEN   = TGSOAIC + TGSDIC
gen double A_BSU   = TGSUIC
gen double A_BSFAM = TGSFIC
gen double A_BUF   = TGSUIC + TGSFIC
gen double A_BSX   = TGSXIC + TGXIC
gen double A_BSN   = TGIC
gen double A_CGE   = CGE
gen double A_CGH   = CGH
gen double A_CG    = CG
gen double A_CF    = CF
gen double A_BPW   = TFWI
gen double A_TPW   = TFWO
gen str5 SEXs = cond(SEX==0, "Total", cond(SEX==1, "Men", "Women"))
rename (age POP) (AGE A_POP)
* 80+ as one group, population-weighted
gen AGE80 = min(AGE, 80)
foreach v of local codes {
    replace A_`v' = A_`v' * A_POP
}
collapse (sum) A_*, by(SEXs AGE80)
foreach v of local codes {
    replace A_`v' = A_`v' / A_POP
}
rename (AGE80 SEXs) (AGE SEX)
tempfile at
save `at'


********************************************************************************
* 2. ENTA Austria 2015
********************************************************************************

use CNT2 YEAR AGE VALUE IND SEX using "ENTA_output_data/ENTA_esa.dta" ///
    if CNT2=="AT" & YEAR==2015, clear
keep if inlist(IND, "POP", "YE", "YM", "YEM", "YO", "TYEM", "TYA", "TCON", "TB") ///
    | inlist(IND, "BS", "BSPEN", "BSU", "BSFAM", "BSX", "CGE", "CGH", "CG") ///
    | inlist(IND, "BPW", "TPW")
tempfile esa
save `esa'
use CNT2 YEAR AGE VALUE IND SEX using "ENTA_output_data/ENTA_nta.dta" ///
    if CNT2=="AT" & YEAR==2015 & inlist(IND, "YAF", "CF"), clear
append using `esa'
drop CNT2 YEAR
reshape wide VALUE, i(SEX AGE) j(IND) string
rename VALUE* *
gen double PEN = BSPEN - TB
gen double BSN = BS - TB
gen double BUF = BSU + BSFAM
foreach v of local codes {
    rename `v' E_`v'
}
rename POP E_POP
merge 1:1 SEX AGE using `at', keep(match) nogen
sort SEX AGE
tempfile both
save `both'


********************************************************************************
* 3. Statistics
********************************************************************************

* male shares and sex-specific correlations
tempfile sexst
preserve
keep if SEX!="Total"
foreach v of local codes {
    gen double eT_`v' = E_`v' * E_POP
    gen double aT_`v' = A_`v' * A_POP
}
collapse (sum) eT_* aT_*, by(SEX)
tempname hs
postfile `hs' str5 IND double(mshE mshA) using `sexst'
foreach v of local codes {
    local me = eT_`v'[1] / (eT_`v'[1] + eT_`v'[2])
    local ma = aT_`v'[1] / (aT_`v'[1] + aT_`v'[2])
    post `hs' ("`v'") (`me') (`ma')
}
postclose `hs'
restore

foreach s in E A {
    bysort SEX: egen double _n`s' = mean(cond(inrange(AGE,30,49), `s'_YEM, .))
}
tempname h
tempfile stats
postfile `h' str5 IND double(r rM rF mad lvl peakE peakA chE chA oldE oldA) using `stats'
foreach v of local codes {
    quietly {
        corr E_`v' A_`v' if SEX=="Total"
        local r = r(rho)
        corr E_`v' A_`v' if SEX=="Men"
        local rM = r(rho)
        corr E_`v' A_`v' if SEX=="Women"
        local rF = r(rho)
        preserve
        keep if SEX=="Total"
        gen double _e = E_`v' / _nE
        gen double _a = A_`v' / _nA
        gen double _ad = abs(_e - _a)
        summarize _ad, meanonly
        local mad = r(mean)
        gen double _te = E_`v' * E_POP
        gen double _ta = A_`v' * A_POP
        summarize _te, meanonly
        local te = r(sum)
        summarize _ta, meanonly
        local ta = r(sum)
        local lvl = cond(`ta'!=0, `te'/`ta', .)
        egen double _mxe = max(E_`v')
        egen double _mxa = max(A_`v')
        summarize AGE if E_`v'==_mxe, meanonly
        local pe = r(min)
        summarize AGE if A_`v'==_mxa, meanonly
        local pa = r(min)
        foreach q in e a {
            summarize _`q' if AGE<20, meanonly
            local ch`q' = r(mean)
            summarize _`q' if AGE>=65, meanonly
            local ol`q' = r(mean)
        }
        post `h' ("`v'") (`r') (`rM') (`rF') (`mad') (`lvl') (`pe') (`pa') ///
            (`che') (`cha') (`ole') (`ola')
        restore
    }
}
postclose `h'
use `stats', clear
merge 1:1 IND using `sexst', nogen
gen int ord = .
local i = 0
foreach v of local codes {
    local ++i
    replace ord = `i' if IND=="`v'"
}
sort ord
drop ord
format r rM rF mad lvl chE chA oldE oldA mshE mshA %6.3f
format peakE peakA %3.0f
export delimited using "`out'/at2015_stats.csv", replace
display _n "ENTA against the Austrian NTA 2015 (administrative sources)"
list IND r rM rF mad lvl peakE peakA chE chA oldE oldA mshE mshA, noobs clean


********************************************************************************
* 4. Figures, both sexes, normalised by employment income at 30-49
********************************************************************************

use `both', clear
keep if SEX=="Total"
foreach s in E A {
    egen double _n`s' = mean(cond(inrange(AGE,30,49), `s'_YEM, .))
}
foreach set in 1 2 {
    local vs = cond(`set'==1, "YE YM YAF YO TYEM TCON", "PEN BSU BSFAM BSX CGH CF")
    local gl ""
    foreach v of local vs {
        gen double e_`v' = E_`v' / _nE
        gen double a_`v' = A_`v' / _nA
        quietly twoway (line e_`v' AGE, lcolor(navy)) ///
            (line a_`v' AGE, lcolor(maroon) lpattern(dash)), ///
            title("`v'", size(medium)) xtitle("") ytitle("") legend(off) ///
            name(g_`v', replace) nodraw
        local gl "`gl' g_`v'"
    }
    quietly graph combine `gl', rows(2) cols(3) ///
        title("AT 2015: ENTA (solid) and Austrian NTA, administrative sources (dashed)", size(medium)) ///
        note("Per capita, divided by mean employment income at ages 30-49 of the same source") ///
        name(comb, replace)
    quietly graph export "`out'/at2015_`set'.png", name(comb) replace width(1800)
    graph drop _all
}
