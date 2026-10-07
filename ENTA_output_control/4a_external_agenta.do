********************************************************************************
* 4a_external_agenta.do
*
* Content:  Compares the published ENTA age profiles (NTA format) for 2010 with
*           the AGENTA results for 2010 (ENTA_output_control/benchmarks/
*           nta2010_AGENTA_long_Euro.csv): 25 EU countries, both sexes together,
*           ages 0-80, euro per capita.
*           AGENTA is ENTA's predecessor (same team, similar sources), so this
*           is a consistency check, not an independent benchmark.
*
*           Levels differ by definition (ENTA is scaled to the ESA2010
*           aggregates of the current Eurostat release), so the comparison is
*           mainly about age shapes. Per country and indicator:
*             r        correlation of the two profiles over ages 0-80
*             mad      mean absolute difference of the two profiles, each
*                      divided by its own mean labour income at ages 30-49
*                      (the NTA normalisation), in units of that mean
*             lvl      ENTA total / AGENTA total (per capita values times each
*                      source's own population), a level ratio; not
*                      meaningful for net series close to zero in total
*                      (TFB, TFW, TG, S, SF, SG, YAG, RA)
*             peakE/A  age of the maximum (ENTA, AGENTA)
*             chE/A    mean at 0-19 over mean labour income at 30-49
*             oldE/A   mean at 65-80 over mean labour income at 30-49
*           and per country the ages at which the life-cycle deficit (LCD =
*           C - YL) turns negative (surplus starts) and positive again.
*
* Input:    ENTA_output_data/ENTA_nta.dta (published), and
*           ENTA_output_control/benchmarks/nta2010_AGENTA_long_Euro.csv
* Output:   ENTA_output_control/results/external/ (not kept):
*             agenta_stats.csv    one row per country and indicator
*             agenta_summary.csv  one row per indicator (medians, counts)
*             agenta_lcd.csv      LCD crossing ages per country
*             agenta_<CNT2>.png   normalised profiles, six indicators
*             agenta_mean_profiles.csv  mean of the normalised profiles over
*                                 the countries, six indicators
*             agenta_2010.png     the figure of the manual (mean profiles);
*                                 Manual_make_figures.R copies it into the
*                                 manual folder
*           and a summary in the log.
*
* Run:      from the ENTA root, standalone (no setup file needed):
*           do ENTA_output_control/4a_external_agenta.do
********************************************************************************

version 19
clear
set more off
local out "ENTA_output_control/results/external"
capture mkdir "ENTA_output_control/results"
capture mkdir "`out'"
local graphs 1      // 1 = one figure per country

* Indicators compared under the same code. CFX is compared as ENTA CFX + CFR
* (AGENTA's CFX holds housing; CF = CFE + CFH + CFX there). LCD = C - YL,
* T = TG + TF and RA = YA - S are built for ENTA the way AGENTA defines them.
local codes "YL YA YAF YAG C CF CFE CFH CFX CG CGE CGH CGX TF TFB TFW TG TGI TGO S SF SG LCD T RA"


********************************************************************************
* 1. AGENTA 2010
********************************************************************************

import delimited using "ENTA_output_control/benchmarks/nta2010_AGENTA_long_Euro.csv", ///
    varnames(1) case(preserve) clear
capture drop v1
drop if strpos(country, "EU25") | country=="United Kingdom"
keep if sex=="total"
do "ENTA_input_data/Prog_gen_CNT2_from_country_name.do"
assert CNT2 != ""
rename DN POP
keep CNT2 age POP YL YA YAF YAG C CF CFE CFH CFX CG CGE CGH CGX TF TFB TFW TG TGI TGO S SF SG LCD T RA
rename age AGE
foreach v of local codes {
    rename `v' A_`v'
}
rename POP A_POP
tempfile agenta
save `agenta'


********************************************************************************
* 2. ENTA 2010, both sexes together
********************************************************************************

use CNT2 YEAR AGE VALUE IND SEX using "ENTA_output_data/ENTA_nta.dta" ///
    if YEAR==2010 & SEX=="Total", clear
keep if inlist(IND, "POP", "YL", "YA", "YAF", "YAG", "C", "CF", "CFE", "CFH") ///
    | inlist(IND, "CFX", "CFR", "CG", "CGE", "CGH", "CGX", "TF", "TFB", "TFW") ///
    | inlist(IND, "TG", "TGI", "TGO", "S", "SF", "SG")
drop YEAR SEX
reshape wide VALUE, i(CNT2 AGE) j(IND) string
rename VALUE* *

* Definitions: check that ENTA's TG is TGI - TGO and C is CF + CG, as in
* AGENTA; the comparison relies on it
gen double _d1 = abs(TG - (TGI - TGO))
gen double _d2 = abs(C - (CF + CG))
quietly summarize _d1
display "ENTA 2010: max |TG - (TGI - TGO)| = " %12.4f r(max)
quietly summarize _d2
display "ENTA 2010: max |C - (CF + CG)|    = " %12.4f r(max)
drop _d1 _d2

* ENTA's NTA YA is the total YAF + YAG, as AGENTA's; check it
gen double _d3 = abs(YA - (YAF + YAG))
quietly summarize _d3
display "ENTA 2010: max |YA - (YAF + YAG)| = " %12.4f r(max)
drop _d3
replace CFX = CFX + CFR
drop CFR
gen double LCD = C - YL
gen double T   = TG + TF
gen double RA  = YA - S
foreach v of local codes {
    rename `v' E_`v'
}
rename POP E_POP

merge 1:1 CNT2 AGE using `agenta'
quietly levelsof CNT2 if _merge==2, local(onlyA) clean
quietly levelsof CNT2 if _merge==1, local(onlyE) clean
display "Only in AGENTA: `onlyA'"
display "Only in ENTA:   `onlyE'"
keep if _merge==3
drop _merge
quietly levelsof CNT2, local(cnts) clean
display "Compared: `cnts'"
tempfile both
save `both'


********************************************************************************
* 3. Statistics per country and indicator
********************************************************************************

* Mean labour income at ages 30-49, per source and country (normalisation)
foreach s in E A {
    bysort CNT2: egen double _n`s' = mean(cond(inrange(AGE,30,49), `s'_YL, .))
}

tempname h
tempfile stats
postfile `h' str2 CNT2 str4 IND double(r mad lvl peakE peakA chE chA oldE oldA) ///
    using `stats'
foreach c of local cnts {
    foreach v of local codes {
        quietly {
            preserve
            keep if CNT2=="`c'"
            sort AGE
            * correlation over age
            capture corr E_`v' A_`v'
            local r = cond(_rc | r(N)<2, ., r(rho))
            * normalised profiles and their mean absolute difference
            gen double _e = E_`v' / _nE
            gen double _a = A_`v' / _nA
            gen double _ad = abs(_e - _a)
            summarize _ad, meanonly
            local mad = r(mean)
            * level ratio of the population-weighted totals
            gen double _te = E_`v' * E_POP
            gen double _ta = A_`v' * A_POP
            summarize _te, meanonly
            local te = r(sum)
            summarize _ta, meanonly
            local ta = r(sum)
            local lvl = cond(`ta'!=0, `te'/`ta', .)
            * age of the maximum
            egen double _mxe = max(E_`v')
            egen double _mxa = max(A_`v')
            summarize AGE if E_`v'==_mxe, meanonly
            local pe = r(min)
            summarize AGE if A_`v'==_mxa, meanonly
            local pa = r(min)
            * child and old-age levels relative to prime-age labour income
            summarize _e if AGE<20, meanonly
            local che = r(mean)
            summarize _a if AGE<20, meanonly
            local cha = r(mean)
            summarize _e if AGE>=65, meanonly
            local ole = r(mean)
            summarize _a if AGE>=65, meanonly
            local ola = r(mean)
            post `h' ("`c'") ("`v'") (`r') (`mad') (`lvl') (`pe') (`pa') ///
                (`che') (`cha') (`ole') (`ola')
            restore
        }
    }
}
postclose `h'

use `stats', clear
format r mad lvl chE chA oldE oldA %7.3f
format peakE peakA %3.0f
export delimited using "`out'/agenta_stats.csv", replace
tempfile st
save `st'

* Summary per indicator
gen byte r_lt90 = r < 0.9 if r<.
gen byte mad_gt10 = mad > 0.10 if mad<.
gen double dpeak = abs(peakE - peakA)
collapse (median) r_med=r mad_med=mad lvl_med=lvl dpeak_med=dpeak ///
    (min) r_min=r (max) mad_max=mad (sum) r_lt90 mad_gt10 (count) n=r, by(IND)
gen int ord = .
local i = 0
foreach v of local codes {
    local ++i
    replace ord = `i' if IND=="`v'"
}
sort ord
drop ord
format r_med r_min mad_med mad_max lvl_med %7.3f
export delimited using "`out'/agenta_summary.csv", replace
display _n "Summary per indicator (medians over countries; r_lt90 = countries with r < 0.9;"
display "mad_gt10 = countries with a mean shape difference above 10% of prime-age YL)"
list, noobs clean abbrev(9)

* The largest shape differences
use `st', clear
gsort -mad
display _n "The 25 largest shape differences (mad):"
list CNT2 IND r mad lvl peakE peakA chE chA oldE oldA in 1/25, noobs clean


********************************************************************************
* 4. Life-cycle deficit: ages where the surplus starts and ends
********************************************************************************

use `both', clear
sort CNT2 AGE
foreach s in E A {
    * first age from 15 on with LCD < 0, and first age after that with LCD > 0
    by CNT2: egen int `s'_start = min(cond(AGE>=15 & `s'_LCD<0, AGE, .))
    by CNT2: egen int `s'_end = min(cond(AGE>`s'_start & `s'_LCD>0, AGE, .))
}
by CNT2: keep if _n==1
keep CNT2 E_start A_start E_end A_end
order CNT2 E_start A_start E_end A_end
export delimited using "`out'/agenta_lcd.csv", replace
display _n "Life-cycle deficit: first age of surplus (start) and first age of deficit again (end)"
list, noobs clean


********************************************************************************
* 5. Figures: normalised profiles, six indicators per country
********************************************************************************

if `graphs' {
    use `both', clear
    foreach s in E A {
        bysort CNT2: egen double _n`s' = mean(cond(inrange(AGE,30,49), `s'_YL, .))
    }
    foreach v in YL CF CG TG TF LCD {
        gen double e_`v' = E_`v' / _nE
        gen double a_`v' = A_`v' / _nA
    }
    foreach c of local cnts {
        local gl ""
        foreach v in YL CF CG TG TF LCD {
            quietly twoway (line e_`v' AGE if CNT2=="`c'", lcolor(navy)) ///
                (line a_`v' AGE if CNT2=="`c'", lcolor(maroon) lpattern(dash)), ///
                title("`v'", size(medium)) xtitle("") ytitle("") ///
                legend(off) ///
                name(g_`v', replace) nodraw
            local gl "`gl' g_`v'"
        }
        quietly graph combine `gl', rows(2) cols(3) ///
            title("`c' 2010: ENTA (solid) and AGENTA (dashed)", size(medium)) ///
            note("Per capita, divided by mean labour income at ages 30-49 of the same source") ///
            name(comb, replace)
        quietly graph export "`out'/agenta_`c'.png", name(comb) replace width(1800)
        graph drop _all
    }
}


********************************************************************************
* 6. Figure for the manual: mean of the normalised profiles over the countries
********************************************************************************

use `both', clear
foreach s in E A {
    bysort CNT2: egen double _n`s' = mean(cond(inrange(AGE,30,49), `s'_YL, .))
}
local figvars "YL YA CF CG TGI TGO"
foreach v of local figvars {
    gen double e_`v' = E_`v' / _nE
    gen double a_`v' = A_`v' / _nA
}
collapse (mean) e_* a_*, by(AGE)
export delimited using "`out'/agenta_mean_profiles.csv", replace

local t_YL  "Labour income (YL)"
local t_YA  "Asset income (YA)"
local t_CF  "Private consumption (CF)"
local t_CG  "Public consumption (CG)"
local t_TGI "Public transfers received (TGI)"
local t_TGO "Public transfers paid (TGO)"
local gl ""
foreach v of local figvars {
    * the legend is shown in the first panel only
    local leg "legend(off)"
    if "`v'"=="YL" local leg `"legend(order(1 "ENTA" 2 "AGENTA") ring(0) position(6) cols(1) size(small))"'
    quietly twoway (line e_`v' AGE, lcolor(navy)) ///
        (line a_`v' AGE, lcolor(maroon) lpattern(dash)), ///
        title("`t_`v''", size(medium)) xtitle("Age") ytitle("") `leg' ///
        name(m_`v', replace) nodraw
    local gl "`gl' m_`v'"
}
quietly graph combine `gl', rows(2) cols(3) name(comb, replace)
quietly graph export "`out'/agenta_2010.png", name(comb) replace width(1800)
graph drop _all
