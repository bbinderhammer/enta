********************************************************************************
* Age profile of private education consumption
********************************************************************************

* Household spending on education is split by level of education with the
* national accounts, and each level is given to the persons enrolled at that
* level:
*   pre-primary and primary education (CP101)   -> enrollment ISCED 0-1
*   secondary and post-secondary non-tertiary
*   education (CP102 + CP103)                   -> enrollment ISCED 2-4
*   tertiary education (CP104)                  -> enrollment ISCED 5-8
*   education not definable by level (CP105)    -> all persons aged 20-64,
*                                                  the same amount each
* Within a level every enrolled person has the same amount. Secondary and
* post-secondary education are taken together, as for public education
* consumption (ENTA_compilation1_esa.do, Section 3).
* The shares of the levels are one set per country: the sum over 2008-2022.
* The shares of single years jump in several countries (reclassification).
* Finland and Sweden report no split by level (Finland everything in CP105,
* Sweden everything in CP101): the same amount for every person aged 3-64.
*
* Input:  ENTA_input_data/Original_input_data/nama_10_co3_p3.dta (Eurostat,
*         household consumption by purpose; downloaded by
*         Suppl_consumption_hh_coicop.do)
*         ENTA_input_data/ENTA_input_datasets/enrollment.dta
*         (Suppl_enrollment_educ.do)
*         ENTA_input_data/ENTA_input_datasets/population80w.dta
*         (Suppl_population.do)
* Output: ENTA_input_data/ENTA_input_datasets/consumption_educ_profile.dta,
*         one row per CNT2 YEAR AGE SEX (1 men, 2 women) with CHE, education
*         consumption per person relative to the mean of all persons of the
*         country and year. Only the shape is used: the level is the
*         aggregate CHE. Years 2007 to the last year of enrollment.
* Read by ENTA_ageprofiles/ENTA_consumption_intrahousehold_transfers.do,
*         Section 2b.
* Run after Suppl_population.do and Suppl_enrollment_educ.do. No setup needed.
*
* Content
* 1. Shares of the levels of education
* 2. Profile by age and sex

clear

********************************************************************************
* 1. Shares of the levels of education
********************************************************************************

use ENTA_input_data/Original_input_data/nama_10_co3_p3, clear
keep if unit=="CP_MEUR"
keep if inlist(coicop, "CP10", "CP101", "CP102", "CP103", "CP104", "CP105")
keep geo coicop nama_10_co3_p3*

* Values to numeric if the download left them as text
foreach v of varlist nama_10_co3_p3* {
    capture confirm string variable `v'
    if !_rc {
        destring `v', replace force
    }
}

* One row per country and year, one variable per class
reshape long nama_10_co3_p3, i(geo coicop) j(YEAR)
rename nama_10_co3_p3 V
keep if YEAR>=2008 & YEAR<=2022
reshape wide V, i(geo YEAR) j(coicop) string
rename geo CNT2

* The 26 ENTA countries
keep if inlist(CNT2, "AT", "BE", "BG", "CY", "CZ", "DE", "DK", "EE", "EL") ///
    | inlist(CNT2, "ES", "FI", "FR", "HR", "HU", "IE", "IT", "LT", "LU") ///
    | inlist(CNT2, "LV", "NL", "PL", "PT", "RO", "SE", "SI", "SK")

* A class that is not reported is zero where total education spending is
* reported (France has no post-secondary class). Only years in which the
* classes add up to the total are used.
foreach c in CP101 CP102 CP103 CP104 CP105 {
    replace V`c' = 0 if V`c'==. & VCP10<.
}
gen double VSUM = VCP101 + VCP102 + VCP103 + VCP104 + VCP105
keep if VCP10>0 & VCP10<. & abs(VSUM/VCP10 - 1)<0.01

collapse (sum) VCP101 VCP102 VCP103 VCP104 VCP105 VSUM, by(CNT2)
gen double SHPP  = VCP101 / VSUM
gen double SHSEC = (VCP102 + VCP103) / VSUM
gen double SHTER = VCP104 / VSUM
gen double SHX   = VCP105 / VSUM

* Finland and Sweden: no split by level in the source
gen byte NOSPLIT = inlist(CNT2, "FI", "SE")

keep CNT2 SHPP SHSEC SHTER SHX NOSPLIT
sort CNT2
tempfile shares
save `shares'


********************************************************************************
* 2. Profile by age and sex
********************************************************************************

* Number of students by level, and population, by single year of age
use ENTA_input_data/ENTA_input_datasets/enrollment, clear
keep CNT2 YEAR AGE CGEPP* CGESEC* CGEPSEC* CGETER*
merge 1:1 CNT2 YEAR AGE using ///
    ENTA_input_data/ENTA_input_datasets/population80w, ///
    keep(match) keepusing(POP POPm POPf) nogen
merge m:1 CNT2 using `shares', keep(match) nogen

* Each person's part of the education spending of the country and year
* (E, men Em, women Ef; E summed over all ages is 1): the students of a
* level share the part of that level, the persons aged 20-64 the part that
* is not definable by level.
gen double TPP  = CGEPP
gen double TSEC = CGESEC + CGEPSEC
gen double TTER = CGETER
gen double TAD  = POP if AGE>=20 & AGE<=64
gen double TALL = POP if AGE>=3  & AGE<=64
foreach v in TPP TSEC TTER TAD TALL {
    bysort CNT2 YEAR: egen double S`v' = total(`v')
}
drop TPP TSEC TTER TAD TALL

foreach s in "" m f {
    gen double E`s' = SHPP * CGEPP`s' / STPP ///
        + SHSEC * (CGESEC`s' + CGEPSEC`s') / STSEC ///
        + SHTER * CGETER`s' / STTER ///
        + SHX * POP`s' * (AGE>=20 & AGE<=64) / STAD
    replace E`s' = POP`s' * (AGE>=3 & AGE<=64) / STALL if NOSPLIT==1
}

* Stop if a level has spending but no students in a country and year
count if E==. | Em==. | Ef==.
if r(N) > 0 {
    display as error "Suppl_consumption_educ_profile.do: no profile in these countries and years - a level of education has no students:"
    tabulate CNT2 YEAR if E==. | Em==. | Ef==.
    error 459
}

* Germany: EU-SILC reports age in groups in some years (16-19 and five-year
* groups from 20 in 2022 and later, 73 and older in 2014-2018). The profile
* is merged to EU-SILC by age, so these years get the mean of the group
* under the age code of EU-SILC.
recode AGE (20/24=20) (25/29=25) (30/34=30) (35/39=35) (40/44=40) ///
    (45/49=45) (50/54=50) (55/59=55) (60/64=60) (65/69=65) (70/74=70) ///
    (75/79=75) (80/max=80), gen(AGEGR5)
replace AGE = AGEGR5 if AGE>=20 & YEAR>=2022 & CNT2=="DE"
replace AGE = 16 if AGE>=16 & AGE<20 & YEAR>=2022 & CNT2=="DE"
replace AGE = 73 if AGE>=73 & YEAR>=2014 & YEAR<=2018 & CNT2=="DE"
collapse (sum) E Em Ef POP POPm POPf, by(CNT2 YEAR AGE)

* Per person, relative to the mean of all persons
bysort CNT2 YEAR: egen double POPT = total(POP)
gen double CHE1 = Em / POPm * POPT
gen double CHE2 = Ef / POPf * POPT
keep CNT2 YEAR AGE CHE1 CHE2

* The income year 2007 of EU-SILC has no enrollment data (they start in
* 2008): it takes the profile of 2008. The year is not published.
expand 2 if YEAR==2008, gen(COPY)
replace YEAR = 2007 if COPY==1
drop COPY

reshape long CHE, i(CNT2 YEAR AGE) j(SEX)
label variable CHE "Private education consumption per person, mean of all persons = 1"
sort CNT2 YEAR AGE SEX
save ENTA_input_data/ENTA_input_datasets/consumption_educ_profile, replace
