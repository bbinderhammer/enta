********************************************************************************
* EU-SILC microdata for ENTA
********************************************************************************
*
* Reads the EU-SILC cross-sectional UDB files (csv) of every country and year,
* builds person-level demographic, income and benefit variables and saves one
* file per country: $silcwd/data/silc_XX.dta. Read by ENTA_income.do,
* ENTA_taxes.do, ENTA_benefits.do, ENTA_consumption_intrahousehold_transfers.do
* and Micro_impute_cons_into_SILC.do.
*
* Requires ENTA_setup.do (paths $silcin/$silcwd, program adjustaggr),
* population_agegr3.dta (Suppl_population.do), Micro_SILC_famben.do (called in
* Section 3) and the user-written command sumdist.
*
* YEAR is the income reference year (survey year - 1).
*
* Run time: Section 0 (csv import) and the percentiles in Section 5.2 take
* most of the time. Both are commented out (INACTIVE) and only need to run
* when the import changes or when YDCASH/EHI change; Sections 1-6 start from
* $silcwd/data/silcXX0_1.dta and load the saved perc_XX.dta.
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
*    1.6 Partners, couples and persons responsible for accommodation
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

* INACTIVE: the csv import is time consuming and only needs to run when
* something changes in how the files are imported (new SILC delivery, other
* variables in the keep list of 0.3). Sections 1-6 start from the saved
* $silcwd/data/silcXX0_1.dta. To import again, remove the
* comment markers around this section.

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

    // The original personal data file for Italy 2020 or 2009 needs to be renamed

    * Household register file
      clear
      cap noi import delimited using "$silcin\`x'\20`y'\UDB_c`x'`y'D.csv", varnames(1) case(preserve) delimiter(",") clear
      cap noi clonevar HHID = DB030
      gen YEAR = 1999 + `y' // YEAR refers to income reference period
      cap noi sort HHID
      cap noi save "$silcwd/UDB_c`x'`y'D", replace

    * Personal register
      clear
      cap noi import delimited using "$silcin\`x'\20`y'\UDB_c`x'`y'R.csv", varnames(1) case(preserve) delimiter(",") clear
      cap noi clonevar PID = RB030    // personal ID
      cap noi clonevar HHID = RX030
      cap noi sort HHID PID
      cap noi save "$silcwd/UDB_c`x'`y'R", replace

    * Household data
      clear
      cap noi import delimited using "$silcin\`x'\20`y'\UDB_c`x'`y'H.csv", varnames(1) case(preserve) delimiter(",") clear
      cap noi clonevar HHID = HB030
      cap noi sort HHID
      cap noi save "$silcwd/UDB_c`x'`y'H", replace

    * Personal data
      clear
      cap noi import delimited using "$silcin\`x'\20`y'\UDB_c`x'`y'P.csv", varnames(1) case(preserve) delimiter(",") clear
      cap noi destring PB120, ignore ("**")replace // in Poland there is ** instead of number
      cap noi clonevar PID = PB030
      cap noi clonevar HHID = PX030
    * Alternative if PX030 missing (the household ID is PID without its last
    * two digits; double, a float is rounded for 10+ digit PIDs)
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
      capture confirm file $silcwd/silc`x'`y'.dta // is there a data set for the year and country
      if (_rc==0 & `firstyear'==0) {      // first year with data: load it
        use $silcwd/silc`x'`y'.dta, clear
        *erase silc`x'`y'.dta
        local firstyear = `y'             // local with the first year
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
      PB030 PB120 PB140 PB210 PE010 PL03*  PL060 PL073 PL074 PL075 PL076 PL100 PX030 PY010G PY010N PY020G PY020N PY021G PY021N PY030G PY035G PY035N PY050G PY050N PY080G PY080N PY090G PY090N PY100G PY100N PY110G PY110N PY120G PY120N PY130G PY130N PY140G PY140N // Personal data (P)

    save $silcwd/data/silc`x'0_1, replace
    display "`x'"
    display "`y'"

}  // close foreach x
*/

global country "AT BE BG CY CZ DE DK EE EL ES FI FR HR HU IE IT LT LU LV NL PL PT RO SE SI SK" //  AT
//global country "AT"

* Sections 1-6 run for each country inside this loop (not indented)
foreach x in $country {
  use $silcwd/data/silc`x'0_1, clear

  * Country
    gen CNT2 = "`x'"


********************************************************************************
* 1. Non-income variables
********************************************************************************

  * Identify duplicates
  * Count observations per key
    /*
    bysort CNT2 YEAR HHID PID: gen n = _N
    tab n
    */
    //duplicates drop CNT2 YEAR HHID PID, force

  ************************************************************
  * 1.1 Demographic characteristics
  ************************************************************

  * Sector
  * Not used later in the project (adjustaggr/adjust regenerate their own
  * SECTOR="Households" on the fly if missing) - commented out
    //gen SECTOR = "Households"

  * Age at end of income reference period
    gen AGE = RX020
    label var AGE "Age at end of inc reference period"
    replace AGE = 80 if AGE>=80 & AGE!=.
    //browse YEAR AGE RX020 RB010 RB080 PB140 //if AGE<0
    drop if AGE<0

  * Alternative measure of age if RX020 missing
    gen AGEalt = RB010 - RB080 - 1
    replace AGEalt = 0 if AGEalt==-1
    //browse AGE AGEalt
    replace AGE = AGEalt if AGE==. & AGEalt>=0 & AGEalt<=80

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

  * Country of birth
  * Not used later in the project - commented out
    //gen MIGR = 0
    //capture replace MIGR = 1 if (RB280=="OTH" | RB280=="EU") & YEAR>=2020
    //replace MIGR = 1 if (PB210=="OTH" | PB210=="EU") & YEAR<2020
    //replace MIGR = . if PB210=="" & YEAR<2020

  ************************************************************
  * 1.2 Weights
  ************************************************************

  * Personal weight
    gen WEIGHT = RB050 // personal cross-sectional weight
    drop if WEIGHT==0 | WEIGHT==.
    gen ONE = 1

  * Weight that adjusts to total population (WEIGHTa)
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
    merge m:1 CNT2 YEAR AGEGR3 using ENTA_input_data\ENTA_input_datasets/population_agegr3
    keep if _merge==3
    drop _merge

  * Adjusted WEIGHT that sums up to total population
    gen ADJPOP = POP / POPSILC
    gen WEIGHTa = WEIGHT * ADJPOP
    drop POP

  * Missing values in WEIGHTa: mean of the household (IE, 200-300 persons a
  * year without weight while other household members have one)
    bysort YEAR HHID: egen WEIGHTi = mean(WEIGHTa)
    replace WEIGHTa = WEIGHTi if WEIGHTa==.

  * POPSILC, ADJPOP, WEIGHTi only needed to build WEIGHTa above - not used later
    drop POPSILC ADJPOP WEIGHTi

  ************************************************************
  * 1.3 Household size and within-household ID
  ************************************************************

  * Household size
    bysort YEAR HHID: egen HHSIZE = count(PID)
    label var HHSIZE "no. of hh members"

  * Within-household ID
  * Rank of the person within the household (1 to HHSIZE), used to number
  * couples in 1.6. Not taken from the last two digits of PID: PID/100 as
  * float is rounded once HHID exceeds 16,777,216 (CZ from 2018, HR/PL/DK/HU/
  * NL/EE/LV from 2021 - no couple was found), and in split panel households
  * persons from different origin households can share the last two digits.
    bysort YEAR HHID (PID): gen PIDHH = _n
    label var PIDHH "ID of HH-member within household"

  ************************************************************
  * 1.4 Activity status
  ************************************************************

    gen ACTIVITY = .

  * Value labels for activity variable
    label define ACTIVITY 0 "missing" 1 "education" 2 "parttime" 3 "fulltime" ///
                          4 "unemployed" 5 "domestic work and care" 6 "retired" ///
                          7 "inactive, other"
    label values ACTIVITY ACTIVITY

  * PL032, self-defined economic status from 2020 onwards (collection 2021)
    cap replace ACTIVITY = 1 if PL032==5 | PL032==7 | AGE<=15 // education and unpaid work experience, military service
    cap replace ACTIVITY = 3 if PL032==1 // employed
    cap replace ACTIVITY = 4 if PL032==2 // unemployed
    cap replace ACTIVITY = 5 if PL032==6 // domestic work
    cap replace ACTIVITY = 6 if PL032==3 | PL032==4  // retired or disabled
    cap replace ACTIVITY = 7 if PL032==8 // inactive other

  * PL031, self-defined economic status from 2008
    cap replace ACTIVITY = 1 if PL031==6 | PL031==9 | AGE<=15 // education and unpaid work experience, military service
    cap replace ACTIVITY = 2 if PL031==2 | PL031==4 // employed and self-employed part time
    cap replace ACTIVITY = 3 if PL031==1 | PL031==3 // employed and self-employed fulltime; compulsory military and civil service
    cap replace ACTIVITY = 4 if PL031==5 // unemployed
    cap replace ACTIVITY = 5 if PL031==10 // domestic work
    cap replace ACTIVITY = 6 if PL031==7 | PL031==8  // retired or disabled
    cap replace ACTIVITY = 7 if PL031==11 // inactive other

  * PL030, self-defined economic status until 2007
    capture replace ACTIVITY = 1 if PL030==4 | PL030==7 | AGE<=15 // education and unpaid work experience, military service
    capture replace ACTIVITY = 2 if PL030==2 // working part time
    capture replace ACTIVITY = 3 if PL030==1  // working fulltime; compulsory military and civil service
    capture replace ACTIVITY = 4 if PL030==3 // unemployed
    capture replace ACTIVITY = 5 if PL030==8 // domestic work
    capture replace ACTIVITY = 6 if PL030==5 | PL030==6  // retired or disabled
    capture replace ACTIVITY = 7 if PL030==9 // inactive other

  * Missing values: current education activity (PE010)
    replace ACTIVITY = 1 if PE010==1 & ACTIVITY==. // in education
  * Missing values: basic activity status (RB210, until 2019: 1 at work,
  * 2 unemployed, 3 retired, 4 other inactive)
    replace ACTIVITY = 3 if RB210==1 & ACTIVITY==. // at work (no info about full-time and part-time)
    replace ACTIVITY = 4 if RB210==2 & ACTIVITY==.  // unemployed
    replace ACTIVITY = 6 if RB210==3 & ACTIVITY==.  // retired
    replace ACTIVITY = 7 if RB210==4 & ACTIVITY==.  // inactive, other

  * Missing values: self-defined main activity status (RB211, from 2020;
  * same codes as PL032, not the RB210 codes, which would leave students and
  * persons in domestic work missing)
    replace ACTIVITY = 3 if RB211==1 & ACTIVITY==. // employed (no info about full-time and part-time)
    replace ACTIVITY = 4 if RB211==2 & ACTIVITY==.  // unemployed
    replace ACTIVITY = 6 if (RB211==3 | RB211==4) & ACTIVITY==.  // retired or unable to work
    replace ACTIVITY = 1 if (RB211==5 | RB211==7) & ACTIVITY==.  // student, military service
    replace ACTIVITY = 5 if RB211==6 & ACTIVITY==.  // domestic work
    replace ACTIVITY = 7 if RB211==8 & ACTIVITY==.  // inactive, other
    replace ACTIVITY = 6 if ACTIVITY==. & AGE>=60  // retired if age>60 and missing
    replace ACTIVITY = 6 if AGE>=60 & ACTIVITY!=2 & ACTIVITY!=3

  * Missing values: persons with employment or self-employment income are
  * employed, persons with unemployment benefits unemployed (mainly SE, NL:
  * persons in the personal file without PL031/PL032/RB211)
    replace ACTIVITY = 3 if ACTIVITY==. & ((PY010G>0 & PY010G<.) | (PY050G>0 & PY050G<.))
    replace ACTIVITY = 4 if ACTIVITY==. & PY090G>0 & PY090G<.

  * Hours worked and employment status
    gen WHRUSU = PL060 if PL060>1 & PL060<=99
    replace WHRUSU = WHRUSU + PL100 if PL100>1 & PL100<99 // usual number of hours beyond first job
    replace WHRUSU = 0 if WHRUSU==.
    gen EMPLSTAT = 0
    replace EMPLSTAT = 1 if ACTIVITY==2 | ACTIVITY==3

    local variables "PL073 PL074 PL075 PL076"
    foreach var of local variables {
      replace `var' = 0 if `var'==.
    }
    // browse CNT2 YEAR PL073 PL074 PL075 PL076

  * PARTT/FULLT/EMPLFTRY not used by EMPLFT below or anywhere later - commented out
    //gen PARTT = PL074 + PL076
    //gen FULLT = PL073 + PL075
    //gen EMPLFTRY = 0
    //replace EMPLFTRY = 0.25 if (PARTT + FULLT) > 2
    //replace EMPLFTRY = 0.5 if (PARTT + FULLT) > 6
    //replace EMPLFTRY = 1 if FULLT>=10 & (PARTT + FULLT)>6

    gen EMPLFT = 0
    replace EMPLFT = 1 if WHRUSU>35 & EMPLSTAT==1

  ************************************************************
  * 1.5 Adults
  ************************************************************

  * Identifier of adult persons: those most likely to own assets and generate
  * income. Defined on ACTIVITY (1.4), so the same definition holds for all
  * years whichever status variable the survey has (PL030, PL031, PL032):
  * - aged 35+
  * - aged 18-34: employed (full or part time), unemployed or in domestic
  *   work; in education only if no parent lives in the household
  * The PL030, PL031 and PL032 years are treated alike: the unemployed count
  * and persons in education never do.

  * Parent in the household: father (RB220) or mother (RB230) is a member
  * of the same household
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
    //browse YEAR ADULT ACTIVITY AGE PL030 PL031 PL032

  * If there is no working adult, younger non-working persons are adults too
    bysort YEAR HHID: egen NADULT = total(ADULT)
    replace ADULT = 1 if AGE>=16 & NADULT==0

    drop NADULT
    bysort YEAR HHID: egen NADULT = total(ADULT)

    replace ADULT = 1 if AGE>14 & NADULT==0

  * Households without adult persons (15+) are dropped
    drop NADULT
    bysort YEAR HHID: egen NADULT = total(ADULT)
    drop if NADULT==0

  * Person responsible for accommodation: built in 1.6 (needs COUPLEID)
    //gen ACCOMODATION = ADULT
  * Parent of
    //replace ACCOMODATION = 1 if HB080==PID // Person 1
    //replace ACCOMODATION = 1 if HB090==PID // Person 2 responsible for accomodation
    //label var ACCOMODATION "Persons responsible for accomodation"
    //browse YEAR HHID PID ACCOMODATION HB080 HB090

  * In each household there has to be at least one person responsible for accommodation
    //  bysort YEAR HHID: egen NACCOMOD = total(ACCOMODATION)
    //  replace ACCOMODATION = 1 if ADULT==1 & NACCOMOD==0
    //  drop NACCOMOD

  ************************************************************
  * 1.6 Partners, couples and persons responsible for accommodation
  ************************************************************

    ****************************************
    * Characteristics of the partner
    ****************************************

    preserve
      drop if RB240==.   // drop if partner is not living in the same household

    * Characteristics of the partner, named [variable]_P
    * ACTIVITY not included - the resulting ACTIVITY_P was never used later
      local partnerchar "AGE PIDHH"
      keep `partnerchar' RB030 RB240 YEAR HHID
      rename RB240 PID // for merging with main data partner-ID is ID, and ID becomes partner-ID
      rename RB030 PID_P

      foreach var of local partnerchar {
        rename `var' `var'_P
      }

    * Save the file with partner-data
      sort YEAR PID
      tempfile partnerdata
      save `partnerdata'
    restore

  * Merge full dataset with the partner dataset
    sort YEAR PID
    merge 1:m YEAR PID using `partnerdata'

  * Duplicates due to wrong assignment of partner ID
    bysort YEAR PID: gen n = _N
    tab n
    //duplicates drop CNT2 YEAR HHID PID, force
    drop if PID_P!=RB240 & PID_P!=. & RB240!=. & n==2 & CNT2=="AT" // drop if wrong partner ID
    drop n

  * In IE some IDs indicated being partner are not in the survey. AT has
  * the same issue on a much smaller scale (HHID 5230001, YEAR 2018 - RB240
  * pointed to PID 523000102, one digit off the real partner 523000103, who has
  * no record at all in that year's register). This is believed isolated to
  * IE/AT and is not extended to other countries.
  * NOTE: must key on the loop variable `x', not the row-level CNT2 -
  * CNT2 only exists on the master side of the merge above, so every
  * _merge==2 (using-only) row has CNT2 blank regardless of which
  * country's iteration produced it. Checking CNT2=="IE"/"AT" here would
  * never match anything.
    drop if _merge==2 & ("`x'"=="IE" | "`x'"=="AT")
    drop _merge

    ****************************************
    * Couple ID
    ****************************************

  * Numbering of couples within the household: each couple gets a number
  * from 1 to the number of couples in the household
    gen COUPLEID = .
    label var COUPLEID "Couple ID within HH"

    sum HHSIZE
    global hhsizemax `r(max)'

  * Each couple first gets the lower within-household ID of the two partners
  * (PIDHH 2 and 4 -> 2)
    forvalues i = 1/$hhsizemax {
      replace COUPLEID = `i' if (PIDHH==`i' | PIDHH_P==`i') & COUPLEID==.
      replace COUPLEID = . if PIDHH_P==.
    }

  * ... then the sequence number of the couple within the household
    egen COUPLETAG = tag(YEAR HHID COUPLEID)
    bysort YEAR HHID: egen COUPLEIDSEQ = seq() if COUPLETAG==1
    rename COUPLEID COUPLEIDtemp
    bysort YEAR HHID COUPLEIDtemp: egen COUPLEID = total(COUPLEIDSEQ)
    replace COUPLEID = . if COUPLEIDtemp==.
    drop COUPLEIDtemp COUPLEIDSEQ COUPLETAG

    ****************************************
    * Persons responsible for accommodation
    ****************************************

    gen ACCOMODATION = ADULT

  * Not responsible if younger than 40 and living with a parent (own parent
  * or parent of the partner)
    gen PARENTS = 1 if (RB220!=. | RB230!=.)
    bysort YEAR HHID COUPLEID: egen PARENTSP = sum(PARENTS)
    replace PARENTSP = 0 if COUPLEID==.
    replace ACCOMODATION = 0 if AGE<40 & (PARENTS==1 | PARENTSP>=1)
  * PARENTS/PARENTSP only needed to build ACCOMODATION above - not used later
    drop PARENTS PARENTSP

  * Parent of
    //replace ACCOMODATION = 1 if HB080==PID // Person 1
    //replace ACCOMODATION = 1 if HB090==PID // Person 2 responsible for accomodation
    label var ACCOMODATION "Persons responsible for accomodation"
    //browse YEAR HHID PID ACCOMODATION HB080 HB090

  * In each household there has to be at least one person responsible for accommodation
    bysort YEAR HHID: egen NACCOMOD = total(ACCOMODATION)
    replace ACCOMODATION = 1 if ADULT==1 & NACCOMOD==0
    drop NACCOMOD


********************************************************************************
* 2. Primary income
********************************************************************************

  * Replace missing values
    local income "PY010G PY020G PY021G PY030G PY050G PY080G PY010N PY020N PY021N PY050N PY080N"
    // PY010 employee cash or near cash income
    // PY020 non-cash employee income; PY021 company car
    // PY030 employers' social contributions (only gross)
    // PY050 self employment income
    // PY080 private pensions
    foreach var of local income {
      replace `var' = 0 if `var'==.
    }

    local income "HY030G HY040G HY090G HY100G HY110G HY170G HY030N HY040N HY090N HY100N HY110N HY170N"
    foreach var of local income {
      replace `var' = 0 if `var'==.
    }
    // HY030 Imputed rent
    // HY040 Income from rental of property or land
    // HY090 Income from capital investments
    // HY100 Interest payments on mortgages
    // HY110 Income received by persons below 16
    // HY170G Value of goods produced for own consumption

  ************************************************************
  * 2.1 Income of persons below age 16
  ************************************************************

  * Number of children in older child ages (most income of children is
  * generated by 15 year olds)
    bysort YEAR HHID: egen NCHILD16 = total(AGE==16)
    bysort YEAR HHID: egen NCHILD15 = total(AGE==15)
    bysort YEAR HHID: egen NCHILD14 = total(AGE<15 & AGE>6)

    gen YCHGp = 0
  * Net income variables commented out - not used downstream, gross values used throughout
    //gen YCHNp = 0

  * If possible income is assigned to 15 year olds (most likely to receive income)
    replace YCHGp = HY110G/NCHILD15 if NCHILD15>=1 & AGE==15
    //replace YCHNp = HY110N/NCHILD15 if NCHILD15>=1 & AGE==15

  * If there is no 15 year old, children aged 7-14 receive the income
    replace YCHGp = HY110G/NCHILD14 if NCHILD15==0 & NCHILD14>=1 & AGE<15 & AGE>6
    //replace YCHNp = HY110N/NCHILD14 if NCHILD15==0 & NCHILD14>=1 & AGE<15 & AGE>6

  * 16 year olds receive child income if no younger children are in the household
    replace YCHGp = HY110G/NCHILD16 if NCHILD15==0 & NCHILD14==0 & NCHILD16>=1  & AGE==16
    //replace YCHNp = HY110N/NCHILD16 if NCHILD15==0 & NCHILD14==0 & NCHILD16>=1  & AGE==16

  * If no children older than 6, the value for child income is assumed to be a
  * mistake and set to zero
    replace YCHGp = 0 if NCHILD15==0 & NCHILD14==0 & NCHILD16==0
    //replace YCHNp = 0 if NCHILD15==0 & NCHILD14==0 & NCHILD16==0

  * Control if it adds up to total
    //bysort YEAR HHID: egen cYCHGp = sum(YCHGp)
    //bysort YEAR HHID: egen cYCHNp = sum(YCHNp)

  ************************************************************
  * 2.2 Imputed rent
  ************************************************************

    //browse CNT2 YEAR HY030N HY030G HY100G HY100N

  * Imputed rent assigned to the persons responsible for accommodation
    //replace ACCOMODATION=1 if ACCOMODATION_P==1
    bysort YEAR HHID: egen NACCOMOD = total(ACCOMODATION==1)

  * Imputed rent
    gen YOG = (HY030G)/NACCOMOD
    label var YOG "Individualized imputed rent"

    //gen YON = (HY030N)/NACCOMOD
    //label var YON "Individualized imputed rent"

  * No negative imputed rents
  // There are even persons not owning the home but paying interest on mortgage
    replace YOG = 0 if YOG<0 | ACCOMODATION==0
    //replace YON = 0 if YON<0 | ACCOMODATION==0

  * Net income variables commented out - not used downstream (YO below uses YOG only)
    //bysort YEAR: egen RNSUM = total(YON)
    //replace YON = YOG if RNSUM==0
    //drop RNSUM

  * Control if it adds up to total
    //bysort YEAR HHID: egen cYON = sum(YON)
    //browse cYON HY030N HY100N

    gen YO = YOG

  * Room-count-based imputed-rent estimate. Not a fallback for missing cases
  * (YOG can never be missing here, HY030G was already zero-filled upstream).
  * ENTA_income.do overwrites YO with this value for every row and
  * ENTA_consumption_intrahousehold_transfers.do uses it for CHR, so it is the
  * imputed-rent figure actually used for the age profiles, not YOG.
  * Rooms (HH030) per person responsible for accommodation; where HH030 is
  * missing for the whole country-year, HH070 instead
    bysort YEAR HHID: egen ACCOhh = sum(ACCOMODATION)
    gen NROOMsh = HH030 / ACCOhh
    bysort CNT2 YEAR: egen NROOMshmiss = sum(NROOMsh)
    replace NROOMsh = HH070 if NROOMshmiss==0
    drop NROOMshmiss
  * Owners and rent-free: full; reduced rent: half; market rent: 0
    gen YOest = 0
    capture replace YOest = NROOMsh if ACCOMODATION==1 & (HH020==1 | HH020==4) // before 2010 survey
    replace YOest = NROOMsh if ACCOMODATION==1 & (HH021==1 | HH021==2 | HH021==5) // from 2010 onwards
    capture replace YOest = 0.5 * NROOMsh if ACCOMODATION==1 & HH020==3
    replace YOest = 0.5 * NROOMsh if ACCOMODATION==1 & HH021==4

  ************************************************************
  * 2.3 Employment income
  ************************************************************

    gen YEEG =  PY010G + PY021G + YCHGp
  * Net income variables commented out - not used downstream, gross values used throughout
    //gen YEEN =  PY010N + PY021N + YCHNp
    gen YMG =  PY050G
    //gen YMN =  PY050N
    replace YEEG =  PY010G + PY020G + YCHGp if YEAR<2006
    //replace YEEN =  PY010N + PY020N + YCHNp if YEAR<2006
    gen YEE = YEEG
    gen YE = YEEG + PY030G
    gen YM = YMG
    gen YEM = YE + YM
    gen YER = PY030G
    // PY010G, PY020G: labour income, cash, in-kind
    // PY030G employers social contributions
    // PY050: income from self-employment

  * Comments:
    // In Austria PY021 (company car) is always 0

  ************************************************************
  * 2.4 Asset income
  ************************************************************

    gen YPG = 0
    replace YPG = (HY090G + HY040G)/NADULT if ADULT==1
    // HY040 Income from rent of property,
    // HY090 from investments in incorporated businesses

  * Approximation of YPG for Denmark, because it includes also negative asset income (interest)
    replace YPG = HY040G/NADULT if ADULT==1 & CNT2=="DK" & YEAR<2019
    replace YPG = YPG + YO if CNT2=="DK" & YEAR<2019

  * Net income variables commented out - not used downstream, gross values used throughout
    //gen YPN = 0
    //replace YPN = (HY090N + HY040N - HY100N - HY120N)/NADULT if ADULT==1
    // HY120 taxes on wealth

  * Property income paid
    gen YPGp = (HY100G)/NACCOMOD  // * Mortgage payments
    replace YPGp = 0 if ACCOMODATION==0
    //gen YPNp = (HY100N)/NACCOMOD  // * Mortgage payments
    //replace YPNp = 0 if ACCOMODATION==0

  * Add private pensions to property income, all years. Eurostat counts
  * PY080 in HY010/HY020 only from survey 2011 (YEAR 2010), so it is added from
  * YEAR 2010 - otherwise YEAR 2010 would lack it
    replace YPG = YPG + PY080G
    //replace YPN = YPN + PY080N if YEAR>=2011

  * Property income received and paid
    gen YPr = YPG
    gen YPp = YPGp
    // PY080: income from private pension plans

  * Total primary income (labour + asset income, no transfers)
    gen YG = YEEG + YMG + YPG
    replace YG = YEEG + YMG + (HY090G + HY040G)/NADULT if ADULT==1 & CNT2=="DK" & YEAR<2019
  * Net income variable commented out - not used downstream, gross values used throughout
    //gen YN = YEEN + YMN + YPN


********************************************************************************
* 3. Public transfers
********************************************************************************

  * Replace missing values with zero
    local income "PY090G PY100G PY110G PY120G PY130G PY140G PY090N PY100N PY110N PY120N PY130N PY140N"
    foreach var of local income {
      replace `var' = 0 if `var'==.
    }
    // PY090 Unemployment benefits
    // PY100 Old age benefits
    // PY110 Survivor benefits
    // PY120 Sickness benefits
    // PY130 Disability benefits
    // PY140 Education related allowances

    local income "HY050G HY060G HY070G HY080G HY050N HY060N HY070N HY080N"
    foreach var of local income {
      replace `var' = 0 if `var'==.
    }
    // HY050 Family and child allowances
    // HY060 Social exclusion n.e.c.
    // HY070 Housing allowances
    // HY080 Inter-household cash transfer received

  ************************************************************
  * 3.1 Family benefits to persons (Micro_SILC_famben.do)
  ************************************************************

    do ENTA_input_data/Micro_SILC_famben.do

  ************************************************************
  * 3.2 Benefits by type
  ************************************************************

    gen BSF = HY050Gp // personalised family benefits
    gen BSU = PY090G  // unemployment
    gen BSOA = PY100G // old age benefits
    gen BSH = PY120G  // sickness
    gen BSE = PY140G  // education
    gen BSD = PY130G // Disability
    gen BSS = PY110G // Survivor
    //gen BS = BSPG - BSH  // BSH is excluded, because most likely PY120 includes benefits not paid by government
    gen BSX = 0
    replace BSX = BSX + (HY060G + HY070G)/NADULT if ADULT==1 // social exclusion n.e.c., housing

  * Combine benefits to make them comparable with aggregate data
    gen BSFAM = BSF + BSE  // Family and education combined
    //gen BPSOCnfc = BS  // benefits of non-financial corporations
    //gen BSPOA = BSOA  // BSPOA includes private and public social benefits in category old age
    gen BSPPEN = BSOA + BSD + BSS // Pension type of transfers combined
    gen BSN = BSFAM + BSU + BSX // Non-Pension benefits
    gen BSP = BSPPEN + BSFAM + BSU + BSX

    gen BSPG = PY090G + PY100G + PY110G + PY120G + PY130G + PY140G + BSX + HY050Gp
    gen BSGc = BSF + BSU + BSOA + BSD + BSE + BSX + BSS + BSH
    gen BSGc1 = BSFAM + BSU + BSPPEN + BSX + BSH
  * Test if components add up, values of BSPG and BSGc should be equal
    //browse BSPG BSGc BSGc1 BSH
    sum BSPG BSGc BSGc1 BSH

  * Net values of social benefits
  * Net income variables commented out - not used downstream, gross values used throughout
    //gen BSXN = 0
    //replace BSXN = (HY060N + HY070N)/NADULT if ADULT==1 // social benefits, other and housing
    //gen BSPN = PY090N + PY100N + PY110N + PY120N + PY130N + PY140N + BSXN + HY050Np
    //browse BSPG BSPN

  * Estimate of transfers paid on public benefits
    //gen TBc = BSPG - BSPN


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
    // PY035 contributions to private pension plan (net values available only for some years)
    // PY080 income from private pension plan (net values available only for some years)

  ************************************************************
  * 4.2 Expenditures
  ************************************************************

    local expenditure "HY100G HY120G HY130G HY140G HY100N HY120N HY130N HY140N HY145N"
    foreach var of local expenditure {
      replace `var' = 0 if `var'==.
    }
    // HY100 Interest repayment on mortgage
    // HY120 Regular taxes on wealth
    // HY130 inter household cash transfer paid
    // HY140 Tax on income and social contributions
    // HY145 Repayments/receipts from tax adjustments (only net)

  ************************************************************
  * 4.3 Private and total transfers
  ************************************************************

    gen BPG = 0
    replace BPG = (HY080G - HY130G)/NADULT if ADULT==1
    // inter-household transfers received less paid

  * Net income variables commented out - not used downstream, gross values used throughout
    //gen BPN = 0
    //replace BPN = (HY080N - HY130N)/NADULT if ADULT==1

  * Total transfers
    gen BG = BSPG + BPG
    //gen BN = BSPN + BPG
    //gen BN = BS + BPN

  ************************************************************
  * 4.4 Total personal income and household cash income
  ************************************************************

  * Disposable income
    replace HY020 = 0 if HY020==.

  * Total individual income (primary income + transfers)
    gen YDG = YG + BG // + YRG

  * Disposable income at household level
    bysort YEAR HHID: egen YDGh = sum(YDG)

  * Household cash income: individual incomes less taxes on income and wealth
  * (equals HY020 from 2010 on - BG 2010 aside; before 2010 HY020 does
  * not include private pensions PY080G)
    gen YDCASHh = YDGh - HY140G - HY120G // + HY110G

    //browse HY020 YDCASHh // HY020 should equal YDh

  ************************************************************
  * 4.5 Equivalised household income
  ************************************************************

  * Modified OECD scale: first person aged 15+ 1, others aged 14+ 0.5, below 14 0.3
    gen ADULT14 = 1 if AGE>14
    egen EQUSCALE = tag(YEAR HHID ADULT14)
    replace EQUSCALE = 0 if ADULT14==0

    replace EQUSCALE = 0.5 if AGE>=14 & EQUSCALE==0
    replace EQUSCALE = 0.3 if AGE<14

  * Number of household members in single household equivalents
    bysort YEAR HHID: egen EQUSCALEhh = total(EQUSCALE)

  * Equivalised disposable household income
    gen EHIhh = HY020
    // browse EHIhh YDGh

    gen EHI = EHIhh / EQUSCALEhh
    drop EHIhh


********************************************************************************
* 5. Other variables
********************************************************************************

  ************************************************************
  * 5.1 Household income per capita (YDCASH)
  ************************************************************

  * Household representative
    egen HHTAG = tag(YEAR HHID)

  * Household income per capita in cash
    gen YDCASH = YDCASHh / HHSIZE
    adjustaggr YDCASH

    bysort YEAR HHID PID: gen n = _N
    tab n
    drop n

  ************************************************************
  * 5.2 Percentiles
  ************************************************************

  * INACTIVE calculation: the percentiles (sumdist, slow) only change when
  * YDCASH, EHI or WEIGHTa change. The merge at the end of this subsection
  * loads the last saved perc_`x' file. To recalculate, remove the
  * comment markers around the block, rerun, then comment it out again.

    /*
  * Percentiles of disposable income per household member
    gen PERC = .
    sum YEAR
    forvalues y = `r(min)'(1)`r(max)' {
      sumdist YDCASH [aw=WEIGHTa] if YEAR==`y' & HHTAG==1, ng(100) qgp(PERC1)
      replace PERC = PERC1 if PERC==. & YEAR==`y' & HHTAG==1
      drop PERC1
    }

  * Percentiles of equivalised income
    gen PERCEHI = .
    sum YEAR
    forvalues y = `r(min)'(1)`r(max)' {
      sumdist EHI [aw=WEIGHTa] if YEAR==`y', ng(100) qgp(PERC1)
      replace PERCEHI = PERC1 if PERCEHI==. & YEAR==`y'
      drop PERC1
    }

  * Save the percentiles, to avoid calculating them in every run
    preserve
      keep CNT2 YEAR HHID PID PERC PERCEHI
      sort CNT2 YEAR HHID PID
      save $silcwd/data/perc_`x', replace
    restore
    */

    sort CNT2 YEAR HHID PID
    //capture drop PERC PERCEHI
    merge 1:1 CNT2 YEAR HHID PID using $silcwd/data/perc_`x', update
    keep if _merge==3
    drop _merge

  * PERC is a household value, but it is computed and saved only for the
  * member tagged by HHTAG. HHTAG follows the sort order, so a change in the
  * code above (e.g. a new bysort) moves it to another member, whose PERC in
  * perc_`x' is missing - and Micro_impute_cons_into_SILC.do, which reads
  * PERC from the HHTAG row, then drops the household (a third of them in
  * the first run). PERC is spread to all members of the
  * household.
    bysort YEAR HHID: egen PERChh = max(PERC)
    replace PERC = PERChh
    drop PERChh


********************************************************************************
* 6. Save
********************************************************************************

    //keep `prim' `ben' `inc' `ovar'
    capture drop *_F  *_IF rl* PH* MI*

    //erase $silcwd/silc`x'0_1.dta
    save $silcwd/data/silc_`x', replace

}  // close foreach x
