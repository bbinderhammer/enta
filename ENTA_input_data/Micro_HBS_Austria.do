
********************************************************************************
* Prepare CES
********************************************************************************

*****************************************
* 2015
*****************************************

  use "$cesin\nta2015\data\ces_orig", clear
  
  gen CON = 1
  gen CNT2 = "AT"
  gen YEAR = 2015
  gen HHID = ob
  egen HHTAG = tag(YEAR HHID) 
  gen AGE = alt
  gen WEIGHT = hgew
  gen SEX = geschl
  bysort HHID: egen HHSIZE = count(pkz)

  gen AGEGR5 = 0 if AGE<5
	    replace AGEGR5 = 5 if AGE>=5 & AGE<10
	    replace AGEGR5 = 10 if AGE>=10 & AGE<15
	    replace AGEGR5 = 15 if AGE>=15 & AGE<20
	    replace AGEGR5 = 20 if AGE>=20 & AGE<25
	    replace AGEGR5 = 25 if AGE>=25 & AGE<30
	    replace AGEGR5 = 30 if AGE>=30 & AGE<35
	    replace AGEGR5 = 35 if AGE>=35 & AGE<40
	    replace AGEGR5 = 40 if AGE>=40 & AGE<45
	    replace AGEGR5 = 45 if AGE>=45 & AGE<50
	    replace AGEGR5 = 50 if AGE>=50 & AGE<55
	    replace AGEGR5 = 55 if AGE>=55 & AGE<60
	    replace AGEGR5 = 60 if AGE>=60 & AGE<65
	    replace AGEGR5 = 65 if AGE>=65 & AGE<70
	    replace AGEGR5 = 70 if AGE>=70 & AGE<75
	    replace AGEGR5 = 75 if AGE>=75 & AGE<80
	    replace AGEGR5 = 80 if AGE>=80
		
  gen AGEGR15 = 0
    replace AGEGR15 = 15 if AGE>=15 & AGE<=29
    replace AGEGR15 = 30 if AGE>=30 & AGE<=44
    replace AGEGR15 = 45 if AGE>=45 & AGE<=69
    replace AGEGR15 = 60 if AGE>=60

  
  * Generate WEIGHT that adjusts to total population (WEIGHTa)
 
	  gen AGEGR3 = 0 if AGE<20
	  replace AGEGR3 = 1 if AGE>=20 & AGE<65
	  replace AGEGR3 = 2 if AGE>=65 
		
	* Total population in three age groups
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

    * Generate adjusted WEIGHT that sums up to total population
      gen ADJPOP = POP / POPSILC
      gen WEIGHTa = WEIGHT * ADJPOP

  gen YDCASH = hhek_exkl *12 / HHSIZE
  
  replace h_0_0=0 if h_0_0==.
  replace h_6_0=0 if h_6_0==.    //Education
  replace h_10_0=0 if h_10_0==.    //Health
  replace h_4_2=0 if  h_4_2==.   // imputed rents
  
  
  gen CH = h_0_0
  gen CHX = h_0_0 -  h_4_2 - h_10_0  - h_6_0 
  gen CHH = h_6_0
  gen CHE = h_10_0
  gen CHR = h_4_2
  
  keep CNT2 HHID HHTAG HHSIZE YEAR YDCASH CH CHX CHH CHE CHR WEIGHTa AGE AGEGR5 AGEGR3 AGEGR15 SEX
  save $hbswd/HBS_AT_2015.dta, replace
 
 
*****************************************
* 2010
*****************************************
  
  use "$cesin\nta2010\data\ces_orig", clear
  
  gen CON = 1
  gen CNT2 = "AT"
  gen YEAR = 2010
  gen SEX = pr_08
  encode ob, gen(HHID)
  egen HHTAG = tag(YEAR HHID)
  gen AGE = c_alter
  gen WEIGHT = hgew
  bysort HHID: egen HHSIZE = count(pkz)
  
  gen AGEGR5 = 0 if AGE<5
	    replace AGEGR5 = 5 if AGE>=5 & AGE<10
	    replace AGEGR5 = 10 if AGE>=10 & AGE<15
	    replace AGEGR5 = 15 if AGE>=15 & AGE<20
	    replace AGEGR5 = 20 if AGE>=20 & AGE<25
	    replace AGEGR5 = 25 if AGE>=25 & AGE<30
	    replace AGEGR5 = 30 if AGE>=30 & AGE<35
	    replace AGEGR5 = 35 if AGE>=35 & AGE<40
	    replace AGEGR5 = 40 if AGE>=40 & AGE<45
	    replace AGEGR5 = 45 if AGE>=45 & AGE<50
	    replace AGEGR5 = 50 if AGE>=50 & AGE<55
	    replace AGEGR5 = 55 if AGE>=55 & AGE<60
	    replace AGEGR5 = 60 if AGE>=60 & AGE<65
	    replace AGEGR5 = 65 if AGE>=65 & AGE<70
	    replace AGEGR5 = 70 if AGE>=70 & AGE<75
	    replace AGEGR5 = 75 if AGE>=75 & AGE<80
	    replace AGEGR5 = 80 if AGE>=80
		
  gen AGEGR15 = 0
    replace AGEGR15 = 15 if AGE>=15 & AGE<=29
    replace AGEGR15 = 30 if AGE>=30 & AGE<=44
    replace AGEGR15 = 45 if AGE>=45 & AGE<=69
    replace AGEGR15 = 60 if AGE>=60
  
 * Generate WEIGHT that adjusts to total population (WEIGHTa)
 
	  gen AGEGR3 = 0 if AGE<20
	  replace AGEGR3 = 1 if AGE>=20 & AGE<65
	  replace AGEGR3 = 2 if AGE>=65 
		
	* Total population in three age groups
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

    * Generate adjusted WEIGHT that sums up to total population
      gen ADJPOP = POP / POPSILC
      gen WEIGHTa = WEIGHT * ADJPOP

  gen YDCASH = c_hhek *12 / HHSIZE

  
  *****************************************
  * Private Education Expenditure
  *****************************************

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


  ************************************
  * Other expenditure
  ************************************

  replace h_00_0=0 if h_00_0==.
  replace h_06_0=0 if h_06_0==.    //Education
  replace h_10_0=0 if h_10_0==.    //Health
  replace h_04_2=0 if  h_04_2==.   // imputed rent
  
  gen CH = h_00_0
  gen CHH = h_06_0 // Health-Expenditure
  gen CHR = h_04_2
  gen CHX = h_00_0 - h_06_0 - h_10_0 -  h_04_2
  gen CHE = h_10_0

  
********************************************************************************
* Append the two datasets and calculate other needed variables
********************************************************************************

  keep CNT2 YEAR HHID HHTAG HHSIZE YDCASH CH CHX CHH CHE CHR WEIGHTa AGE AGEGR5 AGEGR3 AGEGR15 SEX

  save $hbswd/HBS_AT_2010.dta, replace
  