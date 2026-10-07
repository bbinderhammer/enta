********************************************************************************
* EU-SILC microdata for ENTA
********************************************************************************
*
* Reads the EU-SILC cross-sectional UDB files (csv) for all countries and
* years, builds person-level demographic, income and benefit variables, and
* saves one file per country: $silcwd/data/silc_XX.dta. Used by ENTA_income.do,
* ENTA_taxes.do, ENTA_benefits.do, ENTA_consumption_intrahousehold_transfers.do
* and Micro_impute_cons_into_SILC.do.
*
* Needs ENTA_setup.do (paths $silcin/$silcwd, program adjustaggr),
* population_agegr3.dta (Suppl_population.do), Micro_SILC_famben.do (Section 3)
* and the user command sumdist.
*
* YEAR is the income reference year (survey year - 1).
*
* Section 0 (csv import) and the percentiles in 5.2 are the slow parts. Both
* are commented out and only need rerunning when the import changes or when
* YDCASH/EHI change. Sections 1-6 start from $silcwd/data/silcXX0_1.dta and
* load the saved perc_XX.dta.
*
* Content
* 0. Merge and append the original EU-SILC files
*    0.1 Read the csv files and save them as Stata files
*    0.2 Merge the files of a country and year
*    0.3 Append all years of a country
* 1. Non-income variables
*    1.1 Demographic characteristics
*    1.2 Weights
*    1.3 Household size and within-household ID
*    1.4 Activity status
*    1.5 Adults
*    1.6 Partners, couples and the adults who hold the dwelling (ACCOMODATION)
* 2. Primary income
*    2.1 Income of persons below age 16
*    2.2 Imputed rent
*    2.3 Employment income
*    2.4 Asset income
* 3. Public transfers
*    3.1 Family benefits to persons (Micro_SILC_famben.do)
*    3.2 Benefits by type
* 4. Other income components
*    4.1 Private pensions
*    4.2 Expenditures
*    4.3 Private and total transfers
*    4.4 Total personal income and household cash income
*    4.5 Equivalised household income
* 5. Other variables
*    5.1 Household income per capita (YDCASH)
*    5.2 Percentiles
* 6. Save
*
********************************************************************************


********************************************************************************
* 0. Merge and append the original EU-SILC files
********************************************************************************

* INACTIVE. Slow, and only needed when the import changes (new SILC delivery,
* different variables in the keep list in 0.3). Otherwise Sections 1-6 start
* from the saved silcXX0_1.dta. Uncomment this section to import again.

/*
global country "AT BE BG CY CZ DE DK EE EL ES FI FR HR HU IE IT LT LU LV NL PL PT RO SE SI SK" //
//global country "AT"

global year 08 09 10 11 12 13 14 15 16 17 18 19 20 21 22 23 24
//global year 14

foreach x in $country {
 foreach y in $year {

   ************************************************************
   * 0.1 Read the csv files and save them as Stata files
   ************************************************************

   // The Italy 2020 and 2009 personal data files have to be renamed first

   * Household register file
     clear
     cap noi import delimited using "$silcin/`x'/20`y'/UDB_c`x'`y'D.csv", varnames(1) case(preserve) delimiter(",") clear
     cap noi clonevar HHID = DB030
     gen YEAR = 1999 + `y' // income reference year
     cap noi sort HHID
     cap noi save "$silcwd/UDB_c`x'`y'D", replace

   * Personal register
     clear
     cap noi import delimited using "$silcin/`x'/20`y'/UDB_c`x'`y'R.csv", varnames(1) case(preserve) delimiter(",") clear
     cap noi clonevar PID = RB030    // personal ID
     cap noi clonevar HHID = RX030
     cap noi sort HHID PID
     cap noi save "$silcwd/UDB_c`x'`y'R", replace

   * Household data
     clear
     cap noi import delimited using "$silcin/`x'/20`y'/UDB_c`x'`y'H.csv", varnames(1) case(preserve) delimiter(",") clear
     cap noi clonevar HHID = HB030
     cap noi sort HHID
     cap noi save "$silcwd/UDB_c`x'`y'H", replace

   * Personal data
     clear
     cap noi import delimited using "$silcin/`x'/20`y'/UDB_c`x'`y'P.csv", varnames(1) case(preserve) delimiter(",") clear
     cap noi destring PB120, ignore ("**")replace // Poland has ** instead of a number
     cap noi clonevar PID = PB030
     cap noi clonevar HHID = PX030
   * If PX030 is missing, use PID without its last two digits (double, since
   * a float is rounded for 10+ digit PIDs)
     cap noi gen double HHID_1 = PID/100
     cap noi gen HHID1 = floor(HHID_1)
     cap noi replace HHID = HHID1 if HHID==.
     cap noi sort HHID PID
     cap noi save "$silcwd/UDB_c`x'`y'P", replace
     display "`x'"
     display "`y'"

   ************************************************************
   * 0.2 Merge the files of a country and year
   ************************************************************

   * Start with the register data
     clear
     cap noi use "$silcwd/UDB_c`x'`y'R", clear
     cap noi sort HHID PID

   * Merge the personal data
     cap noi merge 1:1 HHID PID using $silcwd/UDB_c`x'`y'P.dta
     cap noi tab _merge // children below 16 are only in the register data
     cap drop _merge

   * Merge the household data
     cap noi sort HHID
     cap noi merge m:1 HHID using $silcwd/UDB_c`x'`y'H.dta
     cap noi tab _merge
     cap drop _merge

   * Merge the household register data
     cap noi sort HHID
     cap noi merge m:1 HHID using $silcwd/UDB_c`x'`y'D.dta
     cap noi tab _merge
     cap drop _merge

   * Save the data by country and year
     cap noi sort HHID PID
     cap noi save $silcwd/silc`x'`y', replace
     display "`x'"
     display "`y'"

   * Erase the single data files
     cap noi erase $silcwd/UDB_c`x'`y'H.dta
     cap noi erase $silcwd/UDB_c`x'`y'P.dta
     cap noi erase $silcwd/UDB_c`x'`y'R.dta
     cap noi erase $silcwd/UDB_c`x'`y'D.dta

 }  // close foreach y

 ************************************************************
 * 0.3 Append all years of a country
 ************************************************************

   local firstyear = "0"

 * Append the yearly data of the country
   foreach y of global year {
     capture confirm file $silcwd/silc`x'`y'.dta // data for this country-year?
     if (_rc==0 & `firstyear'==0) {      // first year with data: load it
       use $silcwd/silc`x'`y'.dta, clear
       *erase silc`x'`y'.dta
       local firstyear = `y'             // remember the first year
     }
     if (_rc==0 & `firstyear'!=`y') {    // append the later years
       append using $silcwd/silc`x'`y'.dta, force
     }
     if (_rc==0) {
       erase $silcwd/silc`x'`y'.dta
     }
   }

 * Keep the variables needed
   keep YEAR HHID PID /// * Identifiers needed throughout the rest of the file
     DB030 /// * Household register file (D)
     RB010 RB030 RB050 RB080 RB090 RB210 RB211 RB220 RB230 RB240 RB280 RX020 RX030 ///  * Personal register (R)
     HB030 HH020 HH021 HH030 HH070 HY020 HY030G HY030N HY040G HY040N HY050G HY050N HY060G HY060N HY070G HY070N HY080G HY080N HY090G HY090N HY100G HY100N HY110G HY110N HY120G HY120N HY130G HY130N HY140G HY140N HY145N HY170G HY170N ///   * Household data (H)
     PB030 PB040 PB120 PB140 PB210 PE010 PL03*  PL060 PL073 PL074 PL075 PL076 PL100 PX030 PY010G PY010N PY020G PY020N PY021G PY021N PY030G PY035G PY035N PY050G PY050N PY080G PY080N PY090G PY090N PY100G PY100N PY110G PY110N PY120G PY120N PY130G PY130N PY140G PY140N // Personal data (P)

   save $silcwd/data/silc`x'0_1, replace
   display "`x'"
   display "`y'"

}  // close foreach x
*/

global country "AT BE BG CY CZ DE DK EE EL ES FI FR HR HU IE IT LT LU LV NL PL PT RO SE SI SK" //  AT
* global country "AT"

* Income percentiles (Section 5.2): 1 = calculate them again and save
* perc_[CC].dta (slow); 0 = load the saved file. They change only when
* YDCASH, EHI or WEIGHTa change.
local run_perc 0

* Sections 1-6 run per country inside this loop
foreach x in $country {
    use $silcwd/data/silc`x'0_1, clear

    * Country
    gen CNT2 = "`x'"


    ********************************************************************************
    * 1. Non-income variables
    ********************************************************************************

    * Check for duplicate person keys
    /*
    bysort CNT2 YEAR HHID PID: gen n = _N
    tab n
    */
    * duplicates drop CNT2 YEAR HHID PID, force

    ************************************************************
    * 1.1 Demographic characteristics
    ************************************************************

    * Sector
    * Not used later (adjustaggr/adjust set SECTOR="Households" themselves)
    * gen SECTOR = "Households"

    * Age at end of income reference period, top-coded at 80
    gen AGE = RX020
    label var AGE "Age at end of inc reference period"
    replace AGE = 80 if AGE>=80 & AGE!=.
    * browse YEAR AGE RX020 RB010 RB080 PB140 //if AGE<0
    drop if AGE<0

    * Fallback age if RX020 is missing, also top-coded at 80. Without it a
    * person over 80 would keep a missing AGE and be dropped at the population
    * merge in 1.2. (No such case in the 2025 release.)
    gen AGEalt = RB010 - RB080 - 1
    replace AGEalt = 0 if AGEalt==-1
    * browse AGE AGEalt
    replace AGE = min(AGEalt, 80) if AGE==. & AGEalt>=0 & AGEalt<.

    * Age groups
    gen AGEGR5  = 5*int(AGE/5)
    replace AGEGR5 = 80 if AGE>=80

    gen AGEGR10 = 10*int(AGE/10)
    replace AGEGR10 = 80 if AGE>=80

    gen AGEGR20 = 20*int(AGE/20)
    replace AGEGR20 = 60 if AGE>=60
    label define AGEGR20 0 "<20" 20 "20-39" 40 "40-59" 60 "60+"
    label val AGEGR20 AGEGR20

    gen AGEGR15 = 0
    replace AGEGR15 = 15 if AGE>=15 & AGE<=29
    replace AGEGR15 = 30 if AGE>=30 & AGE<=44
    replace AGEGR15 = 45 if AGE>=45 & AGE<=59
    replace AGEGR15 = 60 if AGE>=60

    gen AGEGR3 = 0 if AGE<20
    replace AGEGR3 = 1 if AGE>=20 & AGE<65
    replace AGEGR3 = 2 if AGE>=65

    * Sex
    gen SEX = RB090
    label define SEX 0 "Total" 1 "male" 2 "female"
    label val SEX SEX

    * Country of birth - not used later
    * gen MIGR = 0
    * capture replace MIGR = 1 if (RB280=="OTH" | RB280=="EU") & YEAR>=2020
    * replace MIGR = 1 if (PB210=="OTH" | PB210=="EU") & YEAR<2020
    * replace MIGR = . if PB210=="" & YEAR<2020

    ************************************************************
    * 1.2 Weights
    ************************************************************

    * Personal cross-sectional weight
    gen WEIGHT = RB050
    * Some current members have RB050=0 in the register but a positive PB040 in
    * the personal file (2025 release: HR 2013 7 persons, FR 2019 4). Use PB040
    * for them, otherwise their income is lost and their partner's partner ID
    * points to nobody. (The Section 0 import keeps PB040 for this.)
    replace WEIGHT = PB040 if (WEIGHT==0 | WEIGHT==.) & PB040>0 & PB040<.
    drop if WEIGHT==0 | WEIGHT==.
    gen ONE = 1

    * Weight rescaled to total population (WEIGHTa)
    preserve
    collapse (sum) WEIGHT, by(CNT2 YEAR AGEGR3)
    rename WEIGHT POPSILC
    tempfile agepop
    sort CNT2 YEAR AGEGR3
    save `agepop'
    restore

    sort CNT2 YEAR AGEGR3
    merge m:1 CNT2 YEAR AGEGR3 using `agepop'
    drop _merge

    * Add population data
    sort CNT2 YEAR AGEGR3
    merge m:1 CNT2 YEAR AGEGR3 using ENTA_input_data/ENTA_input_datasets/population_agegr3
    keep if _merge==3
    drop _merge

    * Adjusted weight summing to total population
    gen ADJPOP = POP / POPSILC
    gen WEIGHTa = WEIGHT * ADJPOP
    drop POP

    * Missing WEIGHTa: use the household mean (IE, 200-300 persons a year
    * without a weight while others in the household have one)
    bysort YEAR HHID: egen WEIGHTi = mean(WEIGHTa)
    replace WEIGHTa = WEIGHTi if WEIGHTa==.

    * Helpers only needed for WEIGHTa
    drop POPSILC ADJPOP WEIGHTi

    ************************************************************
    * 1.3 Household size and within-household ID
    ************************************************************

    * Household size
    bysort YEAR HHID: egen HHSIZE = count(PID)
    label var HHSIZE "no. of hh members"

    * Rank within the household (1 to HHSIZE), used to number couples in 1.6.
    * Not taken from the last two digits of PID: PID/100 as float is rounded
    * above HHID 16,777,216, and split panel households can reuse the last two
    * digits across origin households.
    bysort YEAR HHID (PID): gen PIDHH = _n
    label var PIDHH "ID of HH-member within household"

    ************************************************************
    * 1.3b Denmark 2010-2018: the green check in unemployment benefits
    ************************************************************

    * Up to income year 2018 Denmark booked the green check (gron check, a small
    * energy-tax compensation paid to almost every adult) in PY090; from 2019 it
    * is a social exclusion benefit (HY060) (Statistics Denmark 2021). The
    * UDB does not separate it, so GCHECK uses the standard amount of the year -
    * the most frequent positive PY090G at age 70+ (162-212 euro) - and assumes
    * every person with PY090G>0 receives it, capped at their PY090G. It is moved
    * from BSU to BSX (3.2), so total benefits are unchanged. 0 elsewhere.
    gen double GCHECK = 0
    if "`x'"=="DK" {
        gen long _gco = _n  // to restore the sort order below
        gen double _gcr = round(PY090G, 0.01) if PY090G>0 & PY090G<. ///
            & AGE>=70 & inrange(YEAR, 2010, 2018)
        bysort YEAR: egen double _gcm = mode(_gcr), maxmode
        * Up to 1.5x the standard amount, treat all of PY090G as green check
        * (child supplements and stored-value rounding push parents above the
        * mode); above that, take out the standard amount only.
        replace GCHECK = cond(PY090G<=1.5*_gcm, PY090G, _gcm) ///
            if PY090G>0 & PY090G<. & _gcm<.
        sort _gco
        drop _gcr _gcm _gco
        tabstat GCHECK if GCHECK>0, by(YEAR) statistics(n mean max)
    }

    ************************************************************
    * 1.4 Activity status
    ************************************************************

    gen ACTIVITY = .

    * Value labels
    label define ACTIVITY 0 "missing" 1 "education" 2 "parttime" 3 "fulltime" ///
        4 "unemployed" 5 "domestic work and care" 6 "retired" ///
        7 "inactive, other"
    label values ACTIVITY ACTIVITY

    * PL032, self-defined economic status from 2020 (collection 2021)
    cap replace ACTIVITY = 1 if PL032==5 | PL032==7 | AGE<=15 // education, work experience, military
    cap replace ACTIVITY = 3 if PL032==1 // employed
    cap replace ACTIVITY = 4 if PL032==2 // unemployed
    cap replace ACTIVITY = 5 if PL032==6 // domestic work
    cap replace ACTIVITY = 6 if PL032==3 | PL032==4  // retired or disabled
    cap replace ACTIVITY = 7 if PL032==8 // inactive other

    * PL031, self-defined economic status from 2008
    cap replace ACTIVITY = 1 if PL031==6 | PL031==9 | AGE<=15 // education, work experience, military
    cap replace ACTIVITY = 2 if PL031==2 | PL031==4 // employed/self-employed part time
    cap replace ACTIVITY = 3 if PL031==1 | PL031==3 // full time; compulsory military/civil service
    cap replace ACTIVITY = 4 if PL031==5 // unemployed
    cap replace ACTIVITY = 5 if PL031==10 // domestic work
    cap replace ACTIVITY = 6 if PL031==7 | PL031==8  // retired or disabled
    cap replace ACTIVITY = 7 if PL031==11 // inactive other

    * PL030, self-defined economic status until 2007
    capture replace ACTIVITY = 1 if PL030==4 | PL030==7 | AGE<=15 // education, work experience, military
    capture replace ACTIVITY = 2 if PL030==2 // part time
    capture replace ACTIVITY = 3 if PL030==1  // full time; compulsory military/civil service
    capture replace ACTIVITY = 4 if PL030==3 // unemployed
    capture replace ACTIVITY = 5 if PL030==8 // domestic work
    capture replace ACTIVITY = 6 if PL030==5 | PL030==6  // retired or disabled
    capture replace ACTIVITY = 7 if PL030==9 // inactive other

    * Fill gaps from current education activity (PE010)
    replace ACTIVITY = 1 if PE010==1 & ACTIVITY==. // in education
    * Fill gaps from basic activity status (RB210, until 2019)
    replace ACTIVITY = 3 if RB210==1 & ACTIVITY==. // at work (no full/part-time split)
    replace ACTIVITY = 4 if RB210==2 & ACTIVITY==.  // unemployed
    replace ACTIVITY = 6 if RB210==3 & ACTIVITY==.  // retired
    replace ACTIVITY = 7 if RB210==4 & ACTIVITY==.  // inactive, other

    * Fill gaps from self-defined main status (RB211, from 2020; uses the PL032
    * codes, not the RB210 ones, which would leave students/domestic work blank)
    replace ACTIVITY = 3 if RB211==1 & ACTIVITY==. // employed (no full/part-time split)
    replace ACTIVITY = 4 if RB211==2 & ACTIVITY==.  // unemployed
    replace ACTIVITY = 6 if (RB211==3 | RB211==4) & ACTIVITY==.  // retired or unable to work
    replace ACTIVITY = 1 if (RB211==5 | RB211==7) & ACTIVITY==.  // student, military service
    replace ACTIVITY = 5 if RB211==6 & ACTIVITY==.  // domestic work
    replace ACTIVITY = 7 if RB211==8 & ACTIVITY==.  // inactive, other
    replace ACTIVITY = 6 if ACTIVITY==. & AGE>=60  // 60+ and still missing: retired
    replace ACTIVITY = 6 if AGE>=60 & ACTIVITY!=2 & ACTIVITY!=3

    * Remaining gaps from income: employment/self-employment income -> employed,
    * unemployment benefits -> unemployed (mainly SE, NL: personal-file persons
    * without PL031/PL032/RB211)
    replace ACTIVITY = 3 if ACTIVITY==. & ((PY010G>0 & PY010G<.) | (PY050G>0 & PY050G<.))
    replace ACTIVITY = 4 if ACTIVITY==. & PY090G - GCHECK>0 & PY090G<.

    * Hours worked and employment status
    gen WHRUSU = PL060 if PL060>1 & PL060<=99
    replace WHRUSU = WHRUSU + PL100 if PL100>1 & PL100<99 // hours in further jobs
    replace WHRUSU = 0 if WHRUSU==.
    gen EMPLSTAT = 0
    replace EMPLSTAT = 1 if ACTIVITY==2 | ACTIVITY==3

    local variables "PL073 PL074 PL075 PL076"
    foreach var of local variables {
        replace `var' = 0 if `var'==.
    }
    * browse CNT2 YEAR PL073 PL074 PL075 PL076

    * PARTT/FULLT/EMPLFTRY not used - commented out
    * gen PARTT = PL074 + PL076
    * gen FULLT = PL073 + PL075
    * gen EMPLFTRY = 0
    * replace EMPLFTRY = 0.25 if (PARTT + FULLT) > 2
    * replace EMPLFTRY = 0.5 if (PARTT + FULLT) > 6
    * replace EMPLFTRY = 1 if FULLT>=10 & (PARTT + FULLT)>6

    gen EMPLFT = 0
    replace EMPLFT = 1 if WHRUSU>35 & EMPLSTAT==1

    ************************************************************
    * 1.5 Adults
    ************************************************************

    * Adults are the persons most likely to own assets and earn income. Defined
    * on ACTIVITY so the rule is the same across all years (PL030/PL031/PL032):
    * - aged 35+
    * - aged 18-34 if employed, unemployed or in domestic work; in education
    *   only when no parent lives in the household
    * The unemployed always count; persons in education never do.

    * Parent in the household: father (RB220) or mother (RB230) is a member
    preserve
    keep YEAR HHID PID
    rename PID PARID
    gen byte PARHH = 1
    tempfile hhmembers
    save `hhmembers'
    restore
    gen byte PARENTHH = 0
    foreach p in RB220 RB230 {
        gen double PARID = `p'
        merge m:1 YEAR HHID PARID using `hhmembers', keep(master match) nogen
        replace PARENTHH = 1 if PARHH==1
        drop PARID PARHH
    }

    gen ADULT = 0
    replace ADULT = 1 if AGE>=35 & AGE<.
    replace ADULT = 1 if AGE>=18 & AGE<. & inlist(ACTIVITY, 2, 3, 4, 5)
    replace ADULT = 1 if AGE>=18 & AGE<. & ACTIVITY==1 & PARENTHH==0
    drop PARENTHH
    * browse YEAR ADULT ACTIVITY AGE PL030 PL031 PL032

    * If no working adult, younger non-working persons count as adults too
    bysort YEAR HHID: egen NADULT = total(ADULT)
    replace ADULT = 1 if AGE>=16 & NADULT==0

    drop NADULT
    bysort YEAR HHID: egen NADULT = total(ADULT)

    replace ADULT = 1 if AGE>14 & NADULT==0

    * Drop households with no adult (15+)
    drop NADULT
    bysort YEAR HHID: egen NADULT = total(ADULT)
    drop if NADULT==0

    * ACCOMODATION is built in 1.6 (it needs COUPLEID). EU-SILC's own persons
    * responsible for the accommodation (HB080, HB090) end with survey 2020 and
    * are not imported, so the same ENTA rule is applied in every year.
    * gen ACCOMODATION = ADULT
    * Parent of
    * replace ACCOMODATION = 1 if HB080==PID // Person 1
    * replace ACCOMODATION = 1 if HB090==PID // Person 2 responsible for accomodation
    * label var ACCOMODATION "Persons responsible for accomodation"
    * browse YEAR HHID PID ACCOMODATION HB080 HB090

    * At least one person per household must be responsible for accommodation
    *  bysort YEAR HHID: egen NACCOMOD = total(ACCOMODATION)
    *  replace ACCOMODATION = 1 if ADULT==1 & NACCOMOD==0
    *  drop NACCOMOD

    ************************************************************
    * 1.6 Partners, couples and the adults who hold the dwelling (ACCOMODATION)
    ************************************************************

    ****************************************
    * Characteristics of the partner
    ****************************************

    preserve
    drop if RB240==.   // partner not in the same household

    * Partner characteristics, suffixed _P. ACTIVITY left out (ACTIVITY_P
    * was never used).
    local partnerchar "AGE PIDHH"
    keep `partnerchar' RB030 RB240 YEAR HHID
    rename RB240 PID // partner ID becomes the merge key; own ID becomes PID_P
    rename RB030 PID_P

    foreach var of local partnerchar {
        rename `var' `var'_P
    }

    * Save the partner data
    sort YEAR PID
    tempfile partnerdata
    save `partnerdata'
    restore

    * Merge the partner data back in
    sort YEAR PID
    merge 1:m YEAR PID using `partnerdata'

    * Duplicates from a wrong partner ID
    bysort YEAR PID: gen n = _N
    tab n
    * duplicates drop CNT2 YEAR HHID PID, force
    drop if PID_P!=RB240 & PID_P!=. & RB240!=. & n==2 & CNT2=="AT" // wrong partner ID
    drop n

    * Partner IDs pointing to nobody: a using-only row (_merge==2) is the partner
    * record of a person whose RB240 names a PID not in the data. It has no AGE,
    * weight or income and is not a real person, so it is dropped. Checked in the
    * raw UDB (2025 release): 31 such IDs missing from both files
    * (e.g. AT 2018 HHID 5230001, RB240 523000102, one digit off 523000103), plus
    * 7 (HR 2013) from the RB050=0 partners dropped in 1.2. The person whose
    * RB240 points to nobody stays, without a partner or COUPLEID.
    drop if _merge==2
    drop _merge

    ****************************************
    * Couple ID
    ****************************************

    * Number the couples within each household, 1 to the number of couples
    gen COUPLEID = .
    label var COUPLEID "Couple ID within HH"

    sum HHSIZE
    global hhsizemax `r(max)'

    * First give each couple the lower within-household ID of its two partners
    * (PIDHH 2 and 4 -> 2)
    forvalues i = 1/$hhsizemax {
        replace COUPLEID = `i' if (PIDHH==`i' | PIDHH_P==`i') & COUPLEID==.
        replace COUPLEID = . if PIDHH_P==.
    }

    * Then renumber them 1, 2, ... within the household
    egen COUPLETAG = tag(YEAR HHID COUPLEID)
    bysort YEAR HHID: egen COUPLEIDSEQ = seq() if COUPLETAG==1
    rename COUPLEID COUPLEIDtemp
    bysort YEAR HHID COUPLEIDtemp: egen COUPLEID = total(COUPLEIDSEQ)
    replace COUPLEID = . if COUPLEIDtemp==.
    drop COUPLEIDtemp COUPLEIDSEQ COUPLETAG

    ****************************************
    * Adults who hold the dwelling
    ****************************************
    * ACCOMODATION marks the adults who get the dwelling's imputed rent (YOG,
    * YOest) and mortgage interest (YPGp), split equally: all adults except those
    * under 40 living with a parent (own or partner's). An ENTA rule, not
    * EU-SILC's HB080/HB090 (which end with survey 2020 and are unused).
    gen ACCOMODATION = ADULT

    * Not responsible if under 40 and living with a parent (own or partner's)
    gen PARENTS = 1 if (RB220!=. | RB230!=.)
    bysort YEAR HHID COUPLEID: egen PARENTSP = sum(PARENTS)
    replace PARENTSP = 0 if COUPLEID==.
    replace ACCOMODATION = 0 if AGE<40 & (PARENTS==1 | PARENTSP>=1)
    * Helpers only needed for ACCOMODATION
    drop PARENTS PARENTSP

    * Parent of
    * replace ACCOMODATION = 1 if HB080==PID // Person 1
    * replace ACCOMODATION = 1 if HB090==PID // Person 2 responsible for accomodation
    label var ACCOMODATION "Adult holding the dwelling (imputed rent, mortgage interest)"
    * browse YEAR HHID PID ACCOMODATION HB080 HB090

    * Where the rule leaves none, make all adults responsible
    bysort YEAR HHID: egen NACCOMOD = total(ACCOMODATION)
    replace ACCOMODATION = 1 if ADULT==1 & NACCOMOD==0
    drop NACCOMOD


    ********************************************************************************
    * 2. Primary income
    ********************************************************************************

    * Missing values to zero
    local income "PY010G PY020G PY021G PY030G PY050G PY080G PY010N PY020N PY021N PY050N PY080N"
    * PY010 employee cash or near-cash income
    * PY020 non-cash employee income; PY021 company car
    * PY030 employers' social contributions (gross only)
    * PY050 self-employment income
    * PY080 private pensions
    foreach var of local income {
        replace `var' = 0 if `var'==.
    }

    local income "HY030G HY040G HY090G HY100G HY110G HY170G HY030N HY040N HY090N HY100N HY110N HY170N"
    foreach var of local income {
        replace `var' = 0 if `var'==.
    }
    * HY030 Imputed rent
    * HY040 Income from rental of property or land
    * HY090 Income from capital investments
    * HY100 Interest payments on mortgages
    * HY110 Income received by persons below 16
    * HY170 Value of goods produced for own consumption

    ************************************************************
    * 2.1 Income of persons below age 16
    ************************************************************

    * Count children in the older child ages (child income is mostly from 15s)
    bysort YEAR HHID: egen NCHILD16 = total(AGE==16)
    bysort YEAR HHID: egen NCHILD15 = total(AGE==15)
    bysort YEAR HHID: egen NCHILD14 = total(AGE<15 & AGE>6)

    gen YCHGp = 0
    * Net version not used downstream
    * gen YCHNp = 0

    * Assign child income to 15 year olds where possible
    replace YCHGp = HY110G/NCHILD15 if NCHILD15>=1 & AGE==15
    * replace YCHNp = HY110N/NCHILD15 if NCHILD15>=1 & AGE==15

    * If no 15 year old, to children aged 7-14
    replace YCHGp = HY110G/NCHILD14 if NCHILD15==0 & NCHILD14>=1 & AGE<15 & AGE>6
    * replace YCHNp = HY110N/NCHILD14 if NCHILD15==0 & NCHILD14>=1 & AGE<15 & AGE>6

    * If no younger children, to 16 year olds
    replace YCHGp = HY110G/NCHILD16 if NCHILD15==0 & NCHILD14==0 & NCHILD16>=1  & AGE==16
    * replace YCHNp = HY110N/NCHILD16 if NCHILD15==0 & NCHILD14==0 & NCHILD16>=1  & AGE==16

    * No child over 6: treat the value as an error and set it to zero
    replace YCHGp = 0 if NCHILD15==0 & NCHILD14==0 & NCHILD16==0
    * replace YCHNp = 0 if NCHILD15==0 & NCHILD14==0 & NCHILD16==0

    * Check it sums to the total
    * bysort YEAR HHID: egen cYCHGp = sum(YCHGp)
    * bysort YEAR HHID: egen cYCHNp = sum(YCHNp)

    ************************************************************
    * 2.2 Imputed rent
    ************************************************************

    * browse CNT2 YEAR HY030N HY030G HY100G HY100N

    * Imputed rent split equally among the accommodation holders (1.6)
    * replace ACCOMODATION=1 if ACCOMODATION_P==1
    bysort YEAR HHID: egen NACCOMOD = total(ACCOMODATION==1)

    * Imputed rent
    gen YOG = (HY030G)/NACCOMOD
    label var YOG "Individualized imputed rent"

    * gen YON = (HY030N)/NACCOMOD
    * label var YON "Individualized imputed rent"

    * No negative imputed rent
    * Some persons pay mortgage interest without owning the home
    replace YOG = 0 if YOG<0 | ACCOMODATION==0
    * replace YON = 0 if YON<0 | ACCOMODATION==0

    * Net version not used downstream (YO uses YOG only)
    * bysort YEAR: egen RNSUM = total(YON)
    * replace YON = YOG if RNSUM==0
    * drop RNSUM

    * Check it sums to the total
    * bysort YEAR HHID: egen cYON = sum(YON)
    * browse cYON HY030N HY100N

    gen YO = YOG

    * Room-based imputed-rent estimate. Not a fallback (YOG is never missing
    * here). ENTA_income.do overwrites YO with this for every row and
    * ENTA_consumption_intrahousehold_transfers.do uses it for CHR, so this -
    * not YOG - is the imputed rent that feeds the age profiles. Rooms (HH030)
    * per accommodation holder, or HH070 where HH030 is missing for the whole
    * country-year.
    bysort YEAR HHID: egen ACCOhh = sum(ACCOMODATION)
    gen NROOMsh = HH030 / ACCOhh
    bysort CNT2 YEAR: egen NROOMshmiss = sum(NROOMsh)
    replace NROOMsh = HH070 if NROOMshmiss==0
    drop NROOMshmiss
    * Owners and rent-free: full; reduced rent: half; market rent: 0
    gen YOest = 0
    capture replace YOest = NROOMsh if ACCOMODATION==1 & (HH020==1 | HH020==4) // before survey 2010
    replace YOest = NROOMsh if ACCOMODATION==1 & (HH021==1 | HH021==2 | HH021==5) // from 2010
    capture replace YOest = 0.5 * NROOMsh if ACCOMODATION==1 & HH020==3
    replace YOest = 0.5 * NROOMsh if ACCOMODATION==1 & HH021==4

    ************************************************************
    * 2.3 Employment income
    ************************************************************

    gen YEEG =  PY010G + PY021G + YCHGp
    * Net version not used downstream
    * gen YEEN =  PY010N + PY021N + YCHNp
    gen YMG =  PY050G
    * gen YMN =  PY050N
    replace YEEG =  PY010G + PY020G + YCHGp if YEAR<2006
    * replace YEEN =  PY010N + PY020N + YCHNp if YEAR<2006
    gen YEE = YEEG
    gen YE = YEEG + PY030G
    gen YM = YMG
    gen YEM = YE + YM
    gen YER = PY030G
    * PY010G, PY020G: labour income, cash, in-kind
    * PY030G employers' social contributions
    * PY050: self-employment income

    * In Austria PY021 (company car) is always 0

    ************************************************************
    * 2.4 Asset income
    ************************************************************

    gen YPG = 0
    replace YPG = (HY090G + HY040G)/NADULT if ADULT==1
    * HY040 rental of property/land
    * HY090 investments in incorporated businesses

    * Denmark: HY090 also holds negative asset income (interest), so use HY040
    * only and add imputed rent instead
    replace YPG = HY040G/NADULT if ADULT==1 & CNT2=="DK" & YEAR<2019
    replace YPG = YPG + YO if CNT2=="DK" & YEAR<2019

    * Net version not used downstream
    * gen YPN = 0
    * replace YPN = (HY090N + HY040N - HY100N - HY120N)/NADULT if ADULT==1
    * HY120 taxes on wealth

    * Property income paid (mortgage interest)
    gen YPGp = (HY100G)/NACCOMOD
    replace YPGp = 0 if ACCOMODATION==0
    * gen YPNp = (HY100N)/NACCOMOD
    * replace YPNp = 0 if ACCOMODATION==0

    * Add private pensions (PY080G) to property income, all years.
    * Eurostat includes PY080 in HY010/HY020 only from survey 2011 (YEAR 2010),
    * but it is collected earlier too, so add it everywhere for comparability.
    replace YPG = YPG + PY080G
    * replace YPN = YPN + PY080N if YEAR>=2011

    * Property income received and paid
    gen YPr = YPG
    gen YPp = YPGp
    * PY080: income from private pension plans

    * Total primary income (labour + asset, no transfers)
    gen YG = YEEG + YMG + YPG
    replace YG = YEEG + YMG + (HY090G + HY040G)/NADULT if ADULT==1 & CNT2=="DK" & YEAR<2019
    * Net version not used downstream
    * gen YN = YEEN + YMN + YPN


    ********************************************************************************
    * 3. Public transfers
    ********************************************************************************

    * Missing values to zero
    local income "PY090G PY100G PY110G PY120G PY130G PY140G PY090N PY100N PY110N PY120N PY130N PY140N"
    foreach var of local income {
        replace `var' = 0 if `var'==.
    }
    * PY090 Unemployment
    * PY100 Old age
    * PY110 Survivor
    * PY120 Sickness
    * PY130 Disability
    * PY140 Education allowances

    local income "HY050G HY060G HY070G HY080G HY050N HY060N HY070N HY080N"
    foreach var of local income {
        replace `var' = 0 if `var'==.
    }
    * HY050 Family and child allowances
    * HY060 Social exclusion n.e.c.
    * HY070 Housing allowances
    * HY080 Inter-household cash transfer received

    ************************************************************
    * 3.1 Family benefits to persons (Micro_SILC_famben.do)
    ************************************************************

    do ENTA_input_data/Micro_SILC_famben.do

    ************************************************************
    * 3.2 Benefits by type
    ************************************************************

    gen BSF = HY050Gp // personalised family benefits
    gen BSU = PY090G - GCHECK  // unemployment (DK 2010-2018 excludes the green check, 1.3b)
    gen BSOA = PY100G // old age
    gen BSH = PY120G  // sickness
    gen BSE = PY140G  // education
    gen BSD = PY130G // disability
    gen BSS = PY110G // survivor
    * BSH (PY120G) enters no profile: compared with the aggregates, the
    * survey's sickness benefits are mainly sick pay from employers, not a
    * government benefit. Government sick pay is part of the pension
    * aggregate (COFOG sickness and disability) and follows BSPPEN.
    gen BSX = 0
    replace BSX = BSX + (HY060G + HY070G)/NADULT if ADULT==1 // social exclusion, housing
    replace BSX = BSX + GCHECK  // DK 2010-2018 green check, treated as HY060 (1.3b)

    * Combine to match the aggregate data
    gen BSFAM = BSF + BSE  // family + education
    * gen BPSOCnfc = BS  // benefits of non-financial corporations
    * gen BSPOA = BSOA  // includes private and public old-age benefits
    gen BSPPEN = BSOA + BSD + BSS // pension-type transfers
    gen BSN = BSFAM + BSU + BSX // non-pension benefits
    gen BSP = BSPPEN + BSFAM + BSU + BSX

    gen BSPG = PY090G - GCHECK + PY100G + PY110G + PY120G + PY130G + PY140G + BSX + HY050Gp
    gen BSGc = BSF + BSU + BSOA + BSD + BSE + BSX + BSS + BSH
    gen BSGc1 = BSFAM + BSU + BSPPEN + BSX + BSH
    * Check: BSPG and BSGc should match
    * browse BSPG BSGc BSGc1 BSH
    sum BSPG BSGc BSGc1 BSH

    * Net benefits - not used downstream
    * gen BSXN = 0
    * replace BSXN = (HY060N + HY070N)/NADULT if ADULT==1 // social exclusion, housing
    * gen BSPN = PY090N + PY100N + PY110N + PY120N + PY130N + PY140N + BSXN + HY050Np
    * browse BSPG BSPN

    * Estimated transfers paid on public benefits
    * gen TBc = BSPG - BSPN


    ********************************************************************************
    * 4. Other income components
    ********************************************************************************

    ************************************************************
    * 4.1 Private pensions
    ************************************************************

    local income "PY035G PY080G PY035N PY080N"
    foreach var of local income {
        replace `var' = 0 if `var'==.
    }
    * PY035 private pension contributions (net only in some years)
    * PY080 private pension income (net only in some years)

    ************************************************************
    * 4.2 Expenditures
    ************************************************************

    local expenditure "HY100G HY120G HY130G HY140G HY100N HY120N HY130N HY140N HY145N"
    foreach var of local expenditure {
        replace `var' = 0 if `var'==.
    }
    * HY100 Mortgage interest paid
    * HY120 Regular taxes on wealth
    * HY130 Inter-household cash transfer paid
    * HY140 Tax on income and social contributions
    * HY145 Tax adjustment repayments/receipts (net only)

    ************************************************************
    * 4.3 Private and total transfers
    ************************************************************

    gen BPG = 0
    replace BPG = (HY080G - HY130G)/NADULT if ADULT==1
    * inter-household transfers received less paid

    * Net version not used downstream
    * gen BPN = 0
    * replace BPN = (HY080N - HY130N)/NADULT if ADULT==1

    * Total transfers
    gen BG = BSPG + BPG
    * gen BN = BSPN + BPG
    * gen BN = BS + BPN

    ************************************************************
    * 4.4 Total personal income and household cash income
    ************************************************************

    * Disposable income
    replace HY020 = 0 if HY020==.

    * Total individual income (primary + transfers)
    gen YDG = YG + BG // + YRG

    * Household disposable income
    bysort YEAR HHID: egen YDGh = sum(YDG)

    * Household cash income: individual incomes less income and wealth taxes
    * (equals HY020 from 2010 on, bar BG 2010; before 2010 HY020 excludes PY080G)
    gen YDCASHh = YDGh - HY140G - HY120G // + HY110G

    * browse HY020 YDCASHh // HY020 should equal YDh

    ************************************************************
    * 4.5 Equivalised household income
    ************************************************************

    * Modified OECD scale: first 15+ member 1, other 14+ members 0.5, under 14 0.3
    gen ADULT14 = 1 if AGE>14
    egen EQUSCALE = tag(YEAR HHID ADULT14)
    replace EQUSCALE = 0 if ADULT14==0

    replace EQUSCALE = 0.5 if AGE>=14 & EQUSCALE==0
    replace EQUSCALE = 0.3 if AGE<14

    * Household size in equivalent members
    bysort YEAR HHID: egen EQUSCALEhh = total(EQUSCALE)

    * Equivalised household disposable income
    gen EHIhh = HY020
    * browse EHIhh YDGh

    gen EHI = EHIhh / EQUSCALEhh
    drop EHIhh


    ********************************************************************************
    * 5. Other variables
    ********************************************************************************

    ************************************************************
    * 5.1 Household income per capita (YDCASH)
    ************************************************************

    * One row per household
    egen HHTAG = tag(YEAR HHID)

    * Household cash income per capita
    gen YDCASH = YDCASHh / HHSIZE
    adjustaggr YDCASH

    bysort YEAR HHID PID: gen n = _N
    tab n
    drop n

    ************************************************************
    * 5.2 Percentiles
    ************************************************************

    * Calculated only if run_perc (top of the file) is 1; otherwise the saved
    * perc_`x' is merged below.

    if `run_perc' {
        * Percentiles of household cash income per capita.
        * Weighted with the household mean of WEIGHTa: WEIGHTa varies by
        * member (ADJPOP by age group) and the HHTAG member depends on the sort
        * order, which Stata breaks randomly, so using the tagged member's own weight
        * would make the percentiles change between runs.
        bysort YEAR HHID: egen double WEIGHTh = mean(WEIGHTa)
        gen PERC = .
        sum YEAR
        forvalues y = `r(min)'(1)`r(max)' {
            sumdist YDCASH [aw=WEIGHTh] if YEAR==`y' & HHTAG==1, ng(100) qgp(PERC1)
            replace PERC = PERC1 if PERC==. & YEAR==`y' & HHTAG==1
            drop PERC1
        }
        drop WEIGHTh

        * Percentiles of equivalised income
        gen PERCEHI = .
        sum YEAR
        forvalues y = `r(min)'(1)`r(max)' {
            sumdist EHI [aw=WEIGHTa] if YEAR==`y', ng(100) qgp(PERC1)
            replace PERCEHI = PERC1 if PERCEHI==. & YEAR==`y'
            drop PERC1
        }

        * Save, so they need not be recomputed every run
        preserve
        keep CNT2 YEAR HHID PID PERC PERCEHI
        sort CNT2 YEAR HHID PID
        save $silcwd/data/perc_`x', replace
        restore
    }

    sort CNT2 YEAR HHID PID
    * capture drop PERC PERCEHI
    merge 1:1 CNT2 YEAR HHID PID using $silcwd/data/perc_`x', update

    * Every current person must be in perc_`x'. A missing or conflicting person
    * means the sample changed since the percentiles were saved, so they are out
    * of date - stop rather than drop silently (rebuild via 5.2). Persons only in
    * perc_`x' (_merge==2) are dropped below.
    quietly count if !inlist(_merge, 2, 3)
    if r(N)>0 {
        display as error "Micro_SILC.do: `r(N)' persons of `x' are not in perc_`x'.dta or conflict with it - the percentiles are out of date. Recalculate them (Section 5.2)."
        exit 459
    }
    keep if _merge==3
    drop _merge

    * PERC is a household value but is saved only for the HHTAG member. HHTAG
    * follows the sort order, so a code change can move it to a member whose PERC
    * is missing, and Micro_impute_cons_into_SILC.do (which reads PERC from the
    * HHTAG row) would then drop the household. Spread PERC to all members.
    bysort YEAR HHID: egen PERChh = max(PERC)
    replace PERC = PERChh
    drop PERChh


    ********************************************************************************
    * 6. Save
    ********************************************************************************

    * keep `prim' `ben' `inc' `ovar'
    capture drop *_F  *_IF rl* PH* MI*

    * erase $silcwd/silc`x'0_1.dta
    save $silcwd/data/silc_`x', replace

}  // close foreach x
