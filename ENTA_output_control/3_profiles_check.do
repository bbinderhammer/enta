********************************************************************************
* ENTA output control 3: breaks in the age shapes of the profiles
********************************************************************************
*
* Lists the profiles whose age shape, split between men and women, or
* smoothness is unusual, so that a person can look at them. It does not decide
* whether a case is an error.
*
*   1. Shape breaks: the distribution of a profile over ages changes from one
*      year to the next much more than it usually does
*   2. Breaks in the share of men: the share of men in the total of a profile
*      changes much more than it usually does
*   3. Spikes: the value at one age is far from the values at the two
*      neighbouring ages
*
* Which profiles are tested:
*   - profiles in money (not employment rates and hours)
*   - whose total is at least min_size percent of national income
*   - that have one sign: the amounts at all ages add up to at least one_sign
*     of the sum of their absolute values. Saving and net transfers, which are
*     positive at some ages and negative at others, are differences of other
*     profiles and are not tested; their components are.
*   - not saving (S, SH, SC, SF, SG and YDC, which equals SC), for the moment
* The same profile is often published under two codes (CHE in ENTA_esa and
* CFE in ENTA_nta); such cases are shown once, with all their codes.
*
* HOW TO RUN (about 3 minutes; no setup file needed)
*   Open Stata, cd to the ENTA root folder, then:
*       do ENTA_output_control/3_profiles_check.do
*
* INPUT   ENTA_output_data/ENTA_esa.dta, ENTA_nta.dta, ENTA_aggregates.dta
*         ENTA_output_control/ledger.csv
*
* OUTPUT  in ENTA_output_control/results, one row per case, largest first:
*           3_profiles_shape_breaks.csv
*           3_profiles_male_share.csv
*           3_profiles_spikes.csv
*         The number of cases and the largest ones are shown on the screen.
*         The column LEDGER gives the ID of the row in ledger.csv that
*         explains the case, or "new".
*
* THRESHOLDS
local min_size   0.5   // profiles tested: total of at least 0.5 % of national income
local one_sign   0.9   // profiles tested: |sum over ages| is at least 0.9 of the sum of absolute amounts
local min_shift  10    // shape break: at least 10 % of the profile moves to other ages ...
local min_share  7.5   // break in the share of men: at least 7.5 percentage points ...
local times      4     // ... and at least 4 times the usual yearly change of the series
local min_years  8     // series with fewer yearly changes are not tested
local spike      0.25  // spike: distance from the mean of the two neighbours, as a share of the largest value of the profile
local nshow      20    // cases shown on the screen

* Saving by age is not tested for the moment: it is a difference of other
* profiles (income less consumption, or the sum of the corporate profiles)
local saving `""S","SH","SC","SF","SG","YDC""'

* Indicators that are not money amounts (rates, hours)
local notmoney `""EHI","EMPLSTAT","EMPLSTATsilc","EMPLFT","WHRUSUT","WHRACTT""'

********************************************************************************
* 0. Preparation
********************************************************************************

clear
set more off
set linesize 160
capture mkdir ENTA_output_control/results
do ENTA_output_control/0_ledger_match.do     // defines the program ledger_match

* National income of the total economy (mio EUR): measures the size of a profile
use CNT2 YEAR SECTOR IND VALAGGR using ENTA_output_data/ENTA_aggregates, clear
keep if SECTOR=="Total economy" & IND=="Y"
rename VALAGGR YREF
keep CNT2 YEAR YREF
tempfile yref
save `yref'

* once: shows a case that is published under several codes only once.
* Rows of the same country and year with the same value of the variable given
* are one case; ALL_CODES lists their codes. A row with a ledger entry is kept
* in preference to one without.
capture program drop once
program define once
    args keyvar
    gen str24 CODE = FILE + ": " + IND
    gen double KEY = round(`keyvar', 0.0001)
    gen byte ISNEW = LEDGER=="new"
    sort CNT2 YEAR KEY ISNEW CODE
    by CNT2 YEAR KEY: gen strL ALL_CODES = CODE if _n==1
    by CNT2 YEAR KEY: replace ALL_CODES = ALL_CODES[_n-1] + "; " + CODE if _n>1
    by CNT2 YEAR KEY: replace ALL_CODES = ALL_CODES[_N]
    by CNT2 YEAR KEY: keep if _n==1
    drop CODE KEY ISNEW
end

********************************************************************************
* Build, for both files, the yearly measures of every profile
********************************************************************************

foreach f in esa nta {
    use CNT2 YEAR AGE SEX VALUE IND using ENTA_output_data/ENTA_`f', clear
    drop if inlist(IND, `notmoney') | inlist(IND, `saving')

    * Amount at each age in mio EUR: value per person x population
    preserve
    keep if IND=="POP"
    rename VALUE POP
    drop IND
    tempfile pop
    save `pop'
    restore
    drop if IND=="POP"
    merge m:1 CNT2 YEAR AGE SEX using `pop', assert(match) nogen
    gen double M = VALUE*POP/1e6
    gen str3 FILE = "`f'"
    tempfile prof
    save `prof'

    * Share of men in the total of the profile
    collapse (sum) M, by(FILE CNT2 IND YEAR SEX)
    reshape wide M, i(FILE CNT2 IND YEAR) j(SEX) string
    gen double MALE_SHARE = 100*MMen/MTotal
    * no share where men and women have opposite signs
    replace MALE_SHARE = . if MALE_SHARE<0 | MALE_SHARE>100
    keep FILE CNT2 IND YEAR MALE_SHARE
    tempfile sex`f'
    save `sex`f''

    * Age shape: share of each age in the profile, and its change
    use `prof' if SEX=="Total", clear
    bysort CNT2 IND YEAR: egen double MASS  = total(abs(M))
    by     CNT2 IND YEAR: egen double TOTAL = total(M)
    gen double ONE_SIGN = abs(TOTAL)/MASS
    * share of each age in the profile; the sign of the total is left out, so
    * that a total that changes sign does not count as a change of the shape
    gen double P    = M/MASS*sign(TOTAL)
    gen double AGEW = AGE*abs(M)/MASS
    sort CNT2 IND AGE YEAR
    by CNT2 IND AGE: gen double DP = abs(P - P[_n-1]) if YEAR==YEAR[_n-1]+1

    * Spikes: distance of each age from the mean of its two neighbours
    sort CNT2 IND YEAR AGE
    by CNT2 IND YEAR: egen double VMAX = max(abs(VALUE))
    by CNT2 IND YEAR: gen double DEV = abs(VALUE - (VALUE[_n-1] + VALUE[_n+1])/2)/VMAX if AGE>=20 & AGE<=78
    by CNT2 IND YEAR: egen double SPIKE = max(DEV)
    gen SPIKE_AGE = AGE if DEV==SPIKE & DEV<.
    gen byte ISSPIKE = DEV>=`spike' & DEV<.

    collapse (sum) SHIFT=DP MEAN_AGE=AGEW NSPIKES=ISSPIKE (count) NAGES=DP ///
        (first) MASS ONE_SIGN SPIKE (min) SPIKE_AGE, by(FILE CNT2 IND YEAR)
    replace SHIFT = 50*SHIFT          // percent of the profile that moves to other ages
    replace SHIFT = . if NAGES<81     // no year before, or an age missing
    replace MEAN_AGE = . if MASS==0
    merge 1:1 FILE CNT2 IND YEAR using `sex`f'', nogen
    tempfile year`f'
    save `year`f''
}
use `yearesa', clear
append using `yearnta'

* Size of the profile in percent of national income
merge m:1 CNT2 YEAR using `yref', keep(master match) nogen
gen double SIZE = 100*MASS/YREF

* Changes from the year before, and what is usual for the series
sort FILE CNT2 IND YEAR
by FILE CNT2 IND: gen byte PREV = YEAR==YEAR[_n-1]+1
* tested: size, and one sign in this year and the year before
by FILE CNT2 IND: gen byte TESTED = SIZE>=`min_size' & SIZE<. & ONE_SIGN>=`one_sign' & ONE_SIGN<. & ONE_SIGN[_n-1]>=`one_sign' & ONE_SIGN[_n-1]<. & PREV
replace SHIFT = . if !TESTED
by FILE CNT2 IND: gen double MEAN_AGE_BEFORE   = MEAN_AGE[_n-1]   if PREV
by FILE CNT2 IND: gen double MALE_SHARE_BEFORE = MALE_SHARE[_n-1] if PREV
gen double CH_MALE_SHARE = MALE_SHARE - MALE_SHARE_BEFORE if TESTED
gen double ABS_CH_MALE   = abs(CH_MALE_SHARE)
by FILE CNT2 IND: egen double USUAL_SHIFT = median(SHIFT)
by FILE CNT2 IND: egen double USUAL_MALE  = median(ABS_CH_MALE)
by FILE CNT2 IND: egen NSHIFT = count(SHIFT)
by FILE CNT2 IND: egen NMALE  = count(ABS_CH_MALE)
tempfile measures
save `measures'

********************************************************************************
* 1. Shape breaks
********************************************************************************
* SHIFT is the percentage of the profile that sits at other ages than the year
* before (half the sum over ages of the absolute change in the share of each
* age). COUNTRIES tells in how many countries the same indicator has a shape
* break in the same year.

quietly count if SHIFT<. & NSHIFT>=`min_years'
local tested = r(N)
gen double TIMES_USUAL = SHIFT/USUAL_SHIFT
keep if SHIFT>=`min_shift' & SHIFT<. & TIMES_USUAL>=`times' & NSHIFT>=`min_years'
bysort FILE IND YEAR: gen COUNTRIES = _N
ledger_match shape
once SHIFT
gsort -SHIFT

display as text _n "1. SHAPE BREAKS"
display as text "   Yearly changes tested: " as result `tested' as text ";  shape breaks (same profile counted once): " as result _N
quietly count if LEDGER=="new"
display as text "   Of these new (not in the ledger): " as result r(N)
keep CNT2 YEAR LEDGER FILE IND SHIFT USUAL_SHIFT TIMES_USUAL MEAN_AGE_BEFORE MEAN_AGE SIZE COUNTRIES ALL_CODES
order CNT2 YEAR LEDGER FILE IND SHIFT USUAL_SHIFT TIMES_USUAL MEAN_AGE_BEFORE MEAN_AGE SIZE COUNTRIES ALL_CODES
format SHIFT USUAL_SHIFT TIMES_USUAL MEAN_AGE_BEFORE MEAN_AGE SIZE %7.1f
export delimited using ENTA_output_control/results/3_profiles_shape_breaks.csv, replace
display as text "   Largest cases; SHIFT in percent of the profile, SIZE in percent of national income"
if _N>0 {
    list CNT2 YEAR LEDGER FILE IND SHIFT TIMES_USUAL MEAN_AGE_BEFORE MEAN_AGE SIZE COUNTRIES in 1/`=min(_N,`nshow')', noobs separator(0) abbreviate(16)
    display as text _n "   Shape breaks by year"
    tabulate YEAR
}

********************************************************************************
* 2. Breaks in the share of men
********************************************************************************

use `measures', clear
quietly count if ABS_CH_MALE<. & NMALE>=`min_years'
local tested = r(N)
gen double TIMES_USUAL = ABS_CH_MALE/USUAL_MALE
keep if ABS_CH_MALE>=`min_share' & ABS_CH_MALE<. & TIMES_USUAL>=`times' & NMALE>=`min_years'
bysort FILE IND YEAR: gen COUNTRIES = _N
ledger_match men
once ABS_CH_MALE
gsort -ABS_CH_MALE

display as text _n "2. BREAKS IN THE SHARE OF MEN"
display as text "   Yearly changes tested: " as result `tested' as text ";  breaks (same profile counted once): " as result _N
quietly count if LEDGER=="new"
display as text "   Of these new (not in the ledger): " as result r(N)
keep CNT2 YEAR LEDGER FILE IND MALE_SHARE_BEFORE MALE_SHARE CH_MALE_SHARE USUAL_MALE TIMES_USUAL SIZE COUNTRIES ALL_CODES
order CNT2 YEAR LEDGER FILE IND MALE_SHARE_BEFORE MALE_SHARE CH_MALE_SHARE USUAL_MALE TIMES_USUAL SIZE COUNTRIES ALL_CODES
format MALE_SHARE_BEFORE MALE_SHARE CH_MALE_SHARE USUAL_MALE TIMES_USUAL SIZE %7.1f
export delimited using ENTA_output_control/results/3_profiles_male_share.csv, replace
display as text "   Largest cases; share of men in percent of the total of the profile"
if _N>0 {
    list CNT2 YEAR LEDGER FILE IND MALE_SHARE_BEFORE MALE_SHARE CH_MALE_SHARE TIMES_USUAL SIZE COUNTRIES in 1/`=min(_N,`nshow')', noobs separator(0) abbreviate(18)
}

********************************************************************************
* 3. Spikes
********************************************************************************
* A spike is a value at one age (20 to 78) that differs from the mean of the
* two neighbouring ages by at least `spike' times the largest value of the
* profile. One row per country and indicator: the number of years with a
* spike, the first and the last of these years, and the year, age and size of
* the largest one. Profiles in age groups (step functions) show up here.

use `measures', clear
quietly count if SPIKE<. & SIZE>=`min_size' & ONE_SIGN>=`one_sign'
local tested = r(N)
keep if NSPIKES>0 & SIZE>=`min_size' & SIZE<. & ONE_SIGN>=`one_sign' & ONE_SIGN<.
gsort FILE CNT2 IND -SPIKE
by FILE CNT2 IND: gen NYEARS = _N
by FILE CNT2 IND: egen FIRST_YEAR = min(YEAR)
by FILE CNT2 IND: egen LAST_YEAR  = max(YEAR)
by FILE CNT2 IND: keep if _n==1       // the year with the largest spike
ledger_match spikes
once SPIKE
gsort -SPIKE

display as text _n "3. SPIKES"
display as text "   Profiles (country, indicator, year) tested: " as result `tested' as text ";  country-indicators with a spike: " as result _N
quietly count if LEDGER=="new"
display as text "   Of these new (not in the ledger): " as result r(N)
rename SPIKE_AGE AGE
keep CNT2 IND LEDGER FILE NYEARS FIRST_YEAR LAST_YEAR YEAR AGE SPIKE SIZE ALL_CODES
order CNT2 IND LEDGER FILE NYEARS FIRST_YEAR LAST_YEAR YEAR AGE SPIKE SIZE ALL_CODES
format SPIKE %5.2f
format SIZE %7.1f
export delimited using ENTA_output_control/results/3_profiles_spikes.csv, replace
display as text "   Largest cases; YEAR and AGE of the largest spike, SPIKE as a share of the largest value of the profile"
if _N>0 {
    list CNT2 IND LEDGER FILE NYEARS FIRST_YEAR LAST_YEAR YEAR AGE SPIKE SIZE in 1/`=min(_N,`nshow')', noobs separator(0) abbreviate(12)
}
