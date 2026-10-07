********************************************************************************
* Austria: Konsumerhebung 2010 and 2015
********************************************************************************

* Output: $hbswd/HBS_AT_2015.dta and $hbswd/HBS_AT_2010.dta, one row per
* person. Micro_HBS.do Section 2 reads both in place of the Eurostat HBS, which
* for Austria covers only 2020, so this file runs first.
* Input: the Konsumerhebung (Statistics Austria) in $cesin,
* nta2015/data/ces_orig.dta and nta2010/data/ces_orig.dta;
* population_agegr3.dta (Suppl_population.do).
* Requires ENTA_setup.do ($cesin, $hbswd).
* Variables kept: CNT2 YEAR HHID HHTAG HHSIZE SEX AGE AGEGR5 AGEGR15 AGEGR3
* WEIGHTa, and
*   YDCASH  household income x 12 / household size, at survey level here;
*           Micro_HBS.do scales it to the aggregate after the append
*   CH      total consumption
*   CHH     health, COICOP 06
*   CHE     education, COICOP 10
*   CHR     imputed rent, COICOP 04.2
*   CHX     CH - CHH - CHE - CHR

**************************************
* Content

* 0. Age groups and weights (program hbsat_ageweight)

* 1. 2015

* 2. 2010

* Private education expenditure by person [INACTIVE]
* Consumption and save

**************************************


********************************************************************************
* 0. Age groups and weights
********************************************************************************

* AGEGR5 (0, 5, ..., 80 = 80+), AGEGR15 (0, 15, 30, 45, 60 = 60+) and AGEGR3
* (0 = 0-19, 1 = 20-64, 2 = 65+) from AGE, which is never missing in either
* survey. WEIGHTa: the survey weight scaled so that each AGEGR3 group sums to
* the population.

capture program drop hbsat_ageweight
program define hbsat_ageweight
    gen AGEGR5 = min(floor(AGE/5)*5, 80)
    gen AGEGR15 = min(floor(AGE/15)*15, 60)
    gen AGEGR3 = cond(AGE<20, 0, cond(AGE<65, 1, 2))

    bysort CNT2 YEAR AGEGR3: egen double POPCES = total(WEIGHT)
    merge m:1 CNT2 YEAR AGEGR3 using ENTA_input_data/ENTA_input_datasets/population_agegr3, keep(match) nogenerate
    gen ADJPOP = POP / POPCES
    gen WEIGHTa = WEIGHT * ADJPOP
end


********************************************************************************
* 1. 2015
********************************************************************************

use "$cesin/nta2015/data/ces_orig", clear

* gen CON = 1 // not kept; Micro_HBS.do sets CON
gen CNT2 = "AT"
gen YEAR = 2015
gen HHID = ob
egen HHTAG = tag(YEAR HHID)
gen AGE = alt
gen WEIGHT = hgew
gen SEX = geschl
bysort HHID: egen HHSIZE = count(pkz)

hbsat_ageweight

gen YDCASH = hhek_exkl *12 / HHSIZE

replace h_0_0=0 if h_0_0==.
replace h_6_0=0 if h_6_0==.    // Health
replace h_10_0=0 if h_10_0==.  // Education
replace h_4_2=0 if  h_4_2==.   // imputed rents

gen CH = h_0_0
gen CHX = h_0_0 -  h_4_2 - h_10_0  - h_6_0
gen CHH = h_6_0
gen CHE = h_10_0
gen CHR = h_4_2

keep CNT2 HHID HHTAG HHSIZE YEAR YDCASH CH CHX CHH CHE CHR WEIGHTa AGE AGEGR5 AGEGR3 AGEGR15 SEX
save $hbswd/HBS_AT_2015.dta, replace


********************************************************************************
* 2. 2010
********************************************************************************

use "$cesin/nta2010/data/ces_orig", clear

* gen CON = 1 // not kept; Micro_HBS.do sets CON
gen CNT2 = "AT"
gen YEAR = 2010
gen SEX = pr_08
encode ob, gen(HHID)
egen HHTAG = tag(YEAR HHID)
gen AGE = c_alter
gen WEIGHT = hgew
bysort HHID: egen HHSIZE = count(pkz)

hbsat_ageweight

gen YDCASH = c_hhek *12 / HHSIZE


************************************************************
* Private education expenditure by person [INACTIVE]
************************************************************

* INACTIVE: CHEat (private education expenditure assigned to the household
* members in education) is not in the keep list below, so nothing uses
* it; CHE is COICOP 10 at household level, as in 2015.
/*
   gen edu = h_10_0_00_0_0_0 // Total Education-Expenditure
    replace edu=0 if edu==.

  gen edu_prim = h_10_1_01_2_0_0         // Primary-School Expenditure
    replace edu_prim = 0 if edu_prim==.

  gen edu_pre = h_10_1_01_1_0_0         // Pre-School Expenditure
    replace edu_pre = 0 if edu_pre==.

  gen edu_sec =  h_10_2_01_1_0_0         // Lower Secondary-School Expenditure; (Hauptschule, AHS Unterstufe)
    replace edu_sec = 0 if edu_sec==.

  gen edu_up =  h_10_3_01_1_0_0         // Upper Secondary School
    replace edu_up = 0 if edu_up==.

  gen edu_ter =  h_10_4_01_1_0_0         // Tertiary Education Expenditure
    replace edu_ter = 0 if edu_ter==.

  replace h_10_5_01_1_0_0 = 0 if h_10_5_01_1_0_0==.    // unmittelbare Berufsausbildung
  replace h_10_5_01_2_0_0 = 0 if  h_10_5_01_2_0_0 ==.  // Bildungskurse
  gen edu_adult = h_10_5_01_1_0_0 + h_10_5_01_2_0_0    // Adult Education Expenditure

  replace h_10_6_00_0_0_0 = 0 if  h_10_6_00_0_0_0 ==.
  replace h_10_5_01_3_0_0 = 0 if  h_10_5_01_3_0_0 ==.
  gen edu_school = h_10_6_00_0_0_0 + h_10_5_01_3_0_0     // Expenditure for school activities + Nachhilfe (Wandertag, Schikurs,..)

  sum edu*

  gen CHEat = 0  // Private Education Expenditure
  gen age = AGE
  gen hhid = HHID

  * We assign each of the above generated expenditure variables to the HH-members in the appropriate
  * age group.

  * Preschool:
    gen preschool = 0   // Indicator if somebody is in pre-school age not enrolled:
      replace preschool = 1 if age<=10 & (pb_09==1 | pb_21==1)
    sort hhid
    by hhid: egen npreschool=sum(age<=10 & (pb_09==1 | pb_21==1))  // variable with the number of preschool children (not enroled) per HH
    replace CHEat = edu_pre/npreschool if preschool==1

   * Primary-School
     gen primschool = 0   // Indicator if somebody is enrolled and in primary-school age:
       replace primschool = 1 if age>=4 & age<=12 & pb_09==2
     sort hhid
     by hhid: egen nprimschool=sum(age>=4 & age<=12 & pb_09==2)  // variable with the number of enrolled children in primary school age per HH
     replace CHEat = CHEat + edu_prim/nprimschool if primschool==1

  * Lower Secondary School // AHS-Unterstufe, Hauptschule
    gen secschool = 0   // Indicator if somebody is enrolled and in secondary-school age:
      replace secschool = 1 if age>=9 & age<=16 & pb_09==3
    sort hhid
    by hhid: egen nsecschool=sum(age>=9 & age<=16 & pb_09==3)  // variable with the number of enrolled children in secondary school age per HH
    replace CHEat = CHEat + edu_sec/nsecschool if secschool==1

  * Upper Secondary School
    gen upschool = 0   // Indicator if somebody is enrolled and in upper-secondary-school age:
    replace upschool = 1 if  pb_09==5 | pb_09==6 | pb_09==7
    sort hhid
    by hhid: egen nupschool=sum(pb_09==5 | pb_09==6 | pb_09==7)  // variable with the number of enrolled children in upper sec school age per HH
    replace CHEat = CHEat + edu_up/nupschool if upschool==1

  * Tertiary Education
    gen tertiary = 0   // Indicator if somebody is enrolled and in tertiary education age:
      replace tertiary = 1 if age>=18 & pb_09==8
    sort hhid
    by hhid: egen ntertiary=sum(age>=18 & pb_09==8)  // variable with the number of enrolled children in tertiary edu age per HH
    replace CHEat = CHEat + edu_ter/ntertiary if tertiary==1

  * General School-Expenditure (Schikurse, Wandertage, Exkursionen...)
    gen school = 0   // Indicator if somebody is enrolled
    replace school = 1 if pb_08==1
    sort hhid
    by hhid: egen nschool=sum(pb_08==1)  // variable with the number of enrolled children per HH
    replace CHEat = CHEat + edu_school/nschool if school==1

  * Adult Eduvcation Expenditure
    gen adultedu = 0   // Indicator if somebody is enrolled
    replace adultedu = 1 if pb_04==1 | pb_06==1
    sort hhid
    by hhid: egen nadultedu=sum(pb_04==1 | pb_06==1)  // variable with the number of enrolled children per HH
    replace CHEat = CHEat + edu_adult/nadultedu if adultedu==1
*/


************************************************************
* Consumption and save
************************************************************

replace h_00_0=0 if h_00_0==.
replace h_06_0=0 if h_06_0==.    // Health
replace h_10_0=0 if h_10_0==.    // Education
replace h_04_2=0 if  h_04_2==.   // imputed rent

gen CH = h_00_0
gen CHH = h_06_0 // Health-Expenditure
gen CHR = h_04_2
gen CHX = h_00_0 - h_06_0 - h_10_0 -  h_04_2
gen CHE = h_10_0

keep CNT2 YEAR HHID HHTAG HHSIZE YDCASH CH CHX CHH CHE CHR WEIGHTa AGE AGEGR5 AGEGR3 AGEGR15 SEX
save $hbswd/HBS_AT_2010.dta, replace
