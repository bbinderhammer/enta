* Population by country, year, age and sex
*
* Source: Eurostat table demo_pjan (population on 1 January by age and sex).
* ENTA uses the average population of a year: the mean of 1 January of that
* year and 1 January of the next.
*
* The UN population data (population_UN.dta, stored in the repository and
* built by Suppl_population_UN.do) are used in two cases:
*   - Eurostat reports the oldest ages only as one group (for example 85 and
*     older). The group is distributed over single ages with the UN age
*     distribution. The Eurostat total is kept.
*   - Eurostat has no population by age at all (Croatia before 2001). The UN
*     population is used.
*
* Output (in ENTA_input_data/ENTA_input_datasets):
*   population100, population100w   single ages 0-99 and 100+, long and wide
*   population80,  population80w    single ages 0-79 and 80+, long and wide
*   population0, population0t       total population, by sex and overall
*   population_agegr15, _agegr3     broad age groups, used to adjust the
*                                   survey weights to the population

***********************************
* Content
* 1. Population by age and sex, 1995 onward
***********************************

if "$download"=="1" {
    * Download the population data from Eurostat. The download runs in Stata's
    * temp folder: eurostatuse erases its working file at the end, which fails
    * in a folder that is synchronised (e.g. Dropbox).
    cd "`c(tmpdir)'"
    clear
    eurostatuse demo_pjan, noflags clear
    cd "$wkdir"
    save ENTA_input_data/Original_input_data/demo_pjan, replace
}

********************************************************************************
* 1. Population by age and sex, 1995 onward
********************************************************************************

use ENTA_input_data/Original_input_data/demo_pjan, clear


keep age sex geo demo_pjan*

* Years in the download, from the variable names demo_pjan1960, ... - so a
* new download with another last year needs no edit here
unab pjanvars : demo_pjan*
local fyear = .
local vyear = .
foreach v of local pjanvars {
    local fyear = min(`fyear', real(substr("`v'", 10, .)))
    local vyear = max(`vyear', real(substr("`v'", 10, .)))
}

tempfile data
save `data'
forvalues y=`fyear'/`vyear' {
    use `data', clear
    keep age sex geo demo_pjan`y'
    rename demo_pjan`y' NA
    gen year = `y'
    tempfile na`y'
    save `na`y''
}
use `na`fyear'', clear
local fyear1 = `fyear' + 1
forvalues y=`fyear1'/`vyear' {
    append using `na`y''
}

sort sex geo year

* Keep only years with at least some information
bysort year geo: egen yearmiss = count(NA) // number of non-missing values in variable NA
drop if yearmiss==0 | yearmiss==1
drop yearmiss

* Relabel age variable
forvalues i=1/99 {
    replace age = "`i'" if age=="Y`i'"
}
replace age = "0" if age=="Y_LT1"
replace age = "100" if age=="Y_OPEN"

drop if age=="TOTAL"
drop if age=="UNK"

* Make age as numeric variable
rename age age_str
destring age_str, gen(AGE)
drop age_str

gen SEX=0 if sex=="T"
replace SEX=1 if sex=="M"
replace SEX=2 if sex=="F"

rename geo CNT2

rename NA POP
* gen YEAR = year-1 // EU-SILC refers to end of income reference period, demo_pjan to beginning of year
gen YEAR = year
sort CNT2 YEAR SEX AGE

******************************************************
* Oldest ages reported as one group: distribute over single ages
******************************************************

* In some countries and years Eurostat's open age group starts below 100,
* for example at 85 (Cyprus 1995-1999). The single ages inside the group
* are missing, and the value of the group is stored at AGE 100.
* The group is distributed over its single ages and 100+ in proportion to
* the UN population at these ages. The Eurostat total does not change.

* Romania, 1 January 1995 to 2001: Eurostat reports 4,597 persons aged
* 100 and older in 2000, against 443 in 2002. Ages 90 and older are put
* into one group, which is distributed in the same way.
gen ro90 = CNT2=="RO" & inrange(YEAR,1995,2001) & AGE>=90
bysort CNT2 YEAR SEX: egen sum90 = total(POP*ro90)
replace POP = sum90 if ro90 & AGE==100
replace POP = .     if ro90 & AGE<100
drop ro90 sum90

merge 1:1 CNT2 YEAR SEX AGE using ENTA_input_data/Original_input_data/population_UN, keep(master match) nogen

* Ages inside the open group: the missing ages and the open group itself
bysort CNT2 YEAR SEX: egen nmissage = total(POP==.)
gen inopen = nmissage>0 & (POP==. | AGE==100)

* Value of the open group, and UN population at the ages inside it
bysort CNT2 YEAR SEX: egen openval = max(cond(AGE==100, POP, .))
bysort CNT2 YEAR SEX: egen unsum = total(POPun*inopen)

replace POP = openval*POPun/unsum if inopen & openval<. & unsum>0 & unsum<.
drop POPun nmissage inopen openval unsum
sort CNT2 YEAR SEX AGE

******************************************************
* Average population of the year
******************************************************

* Mean of 1 January of the year and 1 January of the next year.
* The last year of a country has no next year and keeps the figure of
* 1 January.
bysort CNT2: egen lastyear = max(YEAR)
preserve
replace YEAR = YEAR-1
rename POP POP1
sort CNT2 YEAR SEX AGE
tempfile pop
save `pop'
restore
sort CNT2 YEAR SEX AGE
merge 1:1 CNT2 YEAR SEX AGE using `pop', keepusing(POP1)

replace POP = (POP + POP1) / 2 if YEAR<lastyear
drop POP1 _merge lastyear

******************************************************
* No population by age in Eurostat: use the UN population
******************************************************

drop if YEAR<1995

sort CNT2 YEAR SEX AGE
merge 1:1 CNT2 YEAR SEX AGE using ENTA_input_data/Original_input_data/population_UN

* A country and year in which Eurostat still has a missing age (Croatia
* 1995-2000, where Eurostat reports only the total) takes the UN
* population at all ages and for both sexes.
bysort CNT2 YEAR: egen nmiss = sum(POP==.)

replace POP = POPun if nmiss!=0

drop nmiss _merge POPun sex year


******************************************************
* Save the data
******************************************************

* Age, sex, 100 age groups, long format
sort CNT2 YEAR SEX AGE
save ENTA_input_data/ENTA_input_datasets/population100, replace

* Age, sex, 100 age groups, wide format
preserve
reshape wide POP, i(CNT2 YEAR AGE) j(SEX)
rename POP0 POP
rename POP1 POPm
rename POP2 POPf
sort CNT2 YEAR AGE
save ENTA_input_data/ENTA_input_datasets/population100w, replace
restore

* Age sex, 80 age groups, long format
replace AGE = 80 if AGE>=80
collapse (rawsum) POP, by(CNT2 YEAR SEX AGE)
sort CNT2 YEAR SEX AGE
save ENTA_input_data/ENTA_input_datasets/population80, replace

* 15-year age groups, for use in HBS
preserve
keep if SEX==0
gen AGEGR15 = 0 if AGE<15
replace AGEGR15 = 15 if AGE>=15 & AGE<=29
replace AGEGR15 = 30 if AGE>=30 & AGE<=44
replace AGEGR15 = 45 if AGE>=45 & AGE<=59
replace AGEGR15 = 60 if AGE>=60
collapse (sum) POP, by(CNT2 YEAR AGEGR15)
sort CNT2 YEAR AGEGR15
save ENTA_input_data/ENTA_input_datasets/population_agegr15, replace
restore

* Age sex, 80 age groups, wide format
preserve
reshape wide POP, i(CNT2 YEAR AGE) j(SEX)
rename POP0 POP
rename POP1 POPm
rename POP2 POPf
sort CNT2 YEAR AGE
save ENTA_input_data/ENTA_input_datasets/population80w, replace
restore

* total, age ,sex, long format
collapse (rawsum) POP, by(CNT2 YEAR SEX)
gen AGE = 999
sort CNT2 YEAR SEX AGE
save ENTA_input_data/ENTA_input_datasets/population0, replace

* Total
keep if SEX==0
collapse (rawsum) POP, by(CNT2 YEAR)
gen AGE = 999
sort CNT2 YEAR
save ENTA_input_data/ENTA_input_datasets/population0t, replace

* Three age groups, long format (for adjusting survey data to total population)
use ENTA_input_data/ENTA_input_datasets/population80, clear
keep if SEX==0
gen AGEGR3 = 0 if AGE<20
replace AGEGR3= 1 if AGE>=20 & AGE<65
replace AGEGR3 = 2 if AGE>=65

collapse (sum) POP, by(CNT2 YEAR AGEGR3)
sort CNT2 YEAR AGEGR3
save ENTA_input_data/ENTA_input_datasets/population_agegr3, replace
