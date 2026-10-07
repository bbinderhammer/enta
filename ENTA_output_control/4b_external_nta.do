********************************************************************************
* 4b_external_nta.do
*
* Content:  Compares the published ENTA age profiles (NTA format, both sexes)
*           with the results of national NTA teams from the global NTA
*           database (ENTA_output_control/benchmarks/NTA_EU_countries.csv: AT, DE, FI,
*           FR, HU, IT, SI, SE, ES; single years of age, nominal, national
*           currency). Unlike AGENTA, these are independent estimates: other
*           teams, other sources and methods, often another release of the
*           national accounts.
*
*           Pairs compared. Same year: AT 2010, AT 2015, DE 2008, FR 2011,
*           IT 2008, SI 2010. Nearest ENTA year (2008) for results within
*           three years of it: FI 2006, HU 2005, SE 2006 (group "near"). ES
*           (2000) and earlier years are left out.
*
*           Indicators (NTA codes, as in the global NTA database): YL, YA, C,
*           TG, TF, T (= TG + TF), S, RA (= YA - S), LCD (= C - YL). ENTA's
*           YA is YAF + YAG, TG = TGI - TGO. Not every pair has every
*           indicator (the national files differ).
*
*           Levels differ by construction and currency, so the comparison is
*           about age shapes, at ages 0-79 (the top groups differ: 80+, 90+,
*           100+). Per pair and indicator:
*             r        correlation of the two profiles over ages 0-79
*             mad      mean absolute difference of the profiles, each divided
*                      by its own mean labour income at ages 30-49
*             peakE/X  age of the maximum (ENTA, external)
*             chE/X    mean at 0-19 over mean labour income at 30-49
*             oldE/X   mean at 65-79 over mean labour income at 30-49
*           and per pair the ages at which the life-cycle deficit turns into a
*           surplus and back.
*
* Input:    ENTA_output_data/ENTA_nta.dta (published), and
*           ENTA_output_control/benchmarks/NTA_EU_countries.csv
* Output:   ENTA_output_control/results/external/ (not kept):
*             nta_stats.csv    one row per pair and indicator
*             nta_summary.csv  one row per indicator and group (medians)
*             nta_lcd.csv      life-cycle deficit crossing ages per pair
*             nta_<CNT2>_<YEAR>.png  normalised profiles, six indicators
*           and a summary in the log.
* Run:      from the ENTA root, standalone (no setup file needed):
*           do ENTA_output_control/4b_external_nta.do
********************************************************************************

version 19
clear
set more off
local out "ENTA_output_control/results/external"
capture mkdir "ENTA_output_control/results"
capture mkdir "`out'"
local codes "YL YA C TG TF T S RA LCD"


********************************************************************************
* 1. National NTA results: per capita profiles, ages 0-79
********************************************************************************

import delimited using "ENTA_output_control/benchmarks/NTA_EU_countries.csv", ///
    varnames(1) case(preserve) clear
rename Country country
do "ENTA_input_data/Prog_gen_CNT2_from_country_name.do"
gen int XYEAR = Year
* the pairs: external year -> ENTA year
gen int YEAR = .
replace YEAR = XYEAR if inlist(CNT2 + string(XYEAR), "AT2010", "AT2015", "DE2008", ///
    "FR2011", "IT2008", "SI2010")
replace YEAR = 2008 if inlist(CNT2 + string(XYEAR), "FI2006", "HU2005", "SE2006")
keep if YEAR<.
gen str5 GROUP = cond(YEAR==XYEAR, "same", "near")

* per capita rows (Units, units, Unit; Thousands = per capita in thousands);
* the Millions/Billions rows are totals and are not used
keep if inlist(Unit, "Units", "units", "Unit", "Thousands") & VarName!="DN"
gen double f = cond(Unit=="Thousands", 1000, 1)
keep CNT2 YEAR XYEAR GROUP VarName f Age0-Age79
duplicates drop CNT2 YEAR VarName, force
reshape long Age, i(CNT2 YEAR VarName) j(AGE)
gen double X = Age * f
drop Age f
reshape wide X, i(CNT2 YEAR XYEAR GROUP AGE) j(VarName) string
foreach v of local codes {
    capture confirm variable X`v'
    if _rc gen double X_`v' = .
    else rename X`v' X_`v'
}
keep CNT2 YEAR XYEAR GROUP AGE X_YL X_YA X_C X_TG X_TF X_T X_S X_RA X_LCD
tempfile ext
save `ext'


********************************************************************************
* 2. ENTA, both sexes together
********************************************************************************

use CNT2 YEAR AGE VALUE IND SEX using "ENTA_output_data/ENTA_nta.dta" ///
    if SEX=="Total" & inlist(CNT2, "AT", "DE", "FI", "FR", "HU", "IT", "SI", "SE") ///
    & inlist(YEAR, 2008, 2010, 2011, 2015), clear
keep if inlist(IND, "YL", "YA", "YAF", "YAG", "C", "TG", "TF", "S")
drop SEX
reshape wide VALUE, i(CNT2 YEAR AGE) j(IND) string
rename VALUE* *
gen double _d = abs(YA - (YAF + YAG))
quietly summarize _d
display "ENTA: max |YA - (YAF + YAG)| = " %12.4f r(max)
drop _d YAF YAG
gen double T   = TG + TF
gen double RA  = YA - S
gen double LCD = C - YL
foreach v of local codes {
    rename `v' E_`v'
}
merge 1:1 CNT2 YEAR AGE using `ext', keep(match) nogen
sort CNT2 YEAR AGE
tempfile both
save `both'


********************************************************************************
* 3. Statistics per pair and indicator
********************************************************************************

foreach s in E X {
    bysort CNT2 YEAR: egen double _n`s' = mean(cond(inrange(AGE,30,49), `s'_YL, .))
}
egen pair = group(CNT2 YEAR)
quietly summarize pair
local np = r(max)

tempname h
tempfile stats
postfile `h' str2 CNT2 int(YEAR XYEAR) str5 GROUP str4 IND ///
    double(r mad peakE peakX chE chX oldE oldX) using `stats'
forvalues p = 1/`np' {
    foreach v of local codes {
        quietly {
            preserve
            keep if pair==`p'
            local c = CNT2[1]
            local y = YEAR[1]
            local xy = XYEAR[1]
            local g = GROUP[1]
            count if X_`v'<.
            if r(N)>1 {
                corr E_`v' X_`v'
                local r = r(rho)
                gen double _e = E_`v' / _nE
                gen double _x = X_`v' / _nX
                gen double _ad = abs(_e - _x)
                summarize _ad, meanonly
                local mad = r(mean)
                egen double _mxe = max(E_`v')
                egen double _mxx = max(X_`v')
                summarize AGE if E_`v'==_mxe, meanonly
                local pe = r(min)
                summarize AGE if X_`v'==_mxx, meanonly
                local px = r(min)
                foreach q in e x {
                    summarize _`q' if AGE<20, meanonly
                    local ch`q' = r(mean)
                    summarize _`q' if AGE>=65, meanonly
                    local ol`q' = r(mean)
                }
                post `h' ("`c'") (`y') (`xy') ("`g'") ("`v'") (`r') (`mad') (`pe') (`px') ///
                    (`che') (`chx') (`ole') (`olx')
            }
            restore
        }
    }
}
postclose `h'

use `stats', clear
format r mad chE chX oldE oldX %7.3f
format peakE peakX %3.0f
export delimited using "`out'/nta_stats.csv", replace
display _n "Per pair and indicator"
list CNT2 YEAR XYEAR IND r mad peakE peakX chE chX oldE oldX, noobs clean sepby(CNT2 YEAR)
tempfile st
save `st'

* Summary per indicator: all pairs, and the same-year pairs alone
tempfile s1
gen double dpeak = abs(peakE - peakX)
gen byte r_lt90 = r < 0.9
preserve
collapse (median) r_med=r mad_med=mad dpeak_med=dpeak (min) r_min=r ///
    (max) mad_max=mad (sum) r_lt90 (count) n=r, by(IND)
gen str5 GROUP = "all"
save `s1'
restore
keep if GROUP=="same"
collapse (median) r_med=r mad_med=mad dpeak_med=dpeak (min) r_min=r ///
    (max) mad_max=mad (sum) r_lt90 (count) n=r, by(IND)
gen str5 GROUP = "same"
append using `s1'
gen int ord = .
local i = 0
foreach v of local codes {
    local ++i
    replace ord = `i' if IND=="`v'"
}
sort GROUP ord
drop ord
format r_med r_min mad_med mad_max %7.3f
export delimited using "`out'/nta_summary.csv", replace
display _n "Summary per indicator (medians over pairs; r_lt90 = pairs with r < 0.9)"
list GROUP IND n r_med r_min mad_med mad_max dpeak_med r_lt90, noobs clean sepby(GROUP)


********************************************************************************
* 4. Life-cycle deficit: ages where the surplus starts and ends
********************************************************************************

use `both', clear
sort CNT2 YEAR AGE
foreach s in E X {
    by CNT2 YEAR: egen int `s'_start = min(cond(AGE>=15 & `s'_LCD<0, AGE, .))
    by CNT2 YEAR: egen int `s'_end = min(cond(AGE>`s'_start & `s'_LCD>0, AGE, .))
}
by CNT2 YEAR: keep if _n==1
keep CNT2 YEAR XYEAR GROUP E_start X_start E_end X_end
export delimited using "`out'/nta_lcd.csv", replace
display _n "Life-cycle deficit: first age of surplus (start) and first age of deficit again (end)"
list, noobs clean


********************************************************************************
* 5. Figures: normalised profiles, six indicators per pair
********************************************************************************

use `both', clear
foreach s in E X {
    bysort CNT2 YEAR: egen double _n`s' = mean(cond(inrange(AGE,30,49), `s'_YL, .))
}
foreach v in YL C TG TF YA LCD {
    gen double e_`v' = E_`v' / _nE
    gen double x_`v' = X_`v' / _nX
}
egen pair = group(CNT2 YEAR)
quietly summarize pair
forvalues p = 1/`r(max)' {
    quietly levelsof CNT2 if pair==`p', local(c) clean
    quietly levelsof YEAR if pair==`p', local(y) clean
    quietly levelsof XYEAR if pair==`p', local(xy) clean
    local gl ""
    foreach v in YL C TG TF YA LCD {
        quietly count if pair==`p' & x_`v'<.
        if r(N)>0 {
            quietly twoway (line e_`v' AGE if pair==`p', lcolor(navy)) ///
                (line x_`v' AGE if pair==`p', lcolor(maroon) lpattern(dash)), ///
                title("`v'", size(medium)) xtitle("") ytitle("") legend(off) ///
                name(g_`v', replace) nodraw
            local gl "`gl' g_`v'"
        }
    }
    quietly graph combine `gl', rows(2) cols(3) ///
        title("`c': ENTA `y' (solid) and national NTA `xy' (dashed)", size(medium)) ///
        note("Per capita, divided by mean labour income at ages 30-49 of the same source") ///
        name(comb, replace)
    quietly graph export "`out'/nta_`c'_`y'.png", name(comb) replace width(1800)
    graph drop _all
}
