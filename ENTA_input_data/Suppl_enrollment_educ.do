********************************************************************************
* Enrollment in education by age, sex and ISCED level
********************************************************************************

* Output: ENTA_input_data/ENTA_input_datasets/enrollment.dta (read by
* ENTA_compilation1_esa.do, Section 3 Education). Number of students
* CGEPRE, CGEPRI, CGEPP, CGESEC, CGEPSEC, CGETER, total CGE and enrollment
* rate ENRR, by CNT2 YEAR AGE, total and men (m) / women (f), 2008+.
* Men + women = total for all numbers of students.
* Requires ENTA_setup.do (adjustgender), population80.dta
* (Suppl_population.do) and the user-written command supsmooth.

**************************************
* Content

* 0. Data sources

* 1. Source data

  * ISCED 1997 (educ_enrl1tl), until 2012
  * ISCED 2011 (educ_uoe_enra02), 2013+
  * Education levels
  * Age groups

* 2. Men and women add up to the total

* 3. Single years of age

  * Population
  * Choice of age groups
  * Open and evenly spread age groups
  * Unknown age
  * Year jumps
  * Reference age profile 2015-2017
  * Distribute age groups to single years of age
  * Replace year jumps with values from neighbouring years
  * Into wide format by education level

* 4. Clean the data

  * Missing to zero, below age 3 to zero
  * Greece 2009: impute from 2008 and 2010
  * Replace missing or implausible values with values from other years
  * Total = men + women

* 5. Enrollment rate

  * Enrollment rate ENRR
  * Into wide format by sex

* 6. Smooth the enrollment rate

  * Age 20+
  * Age 25+
  * Age 6-17

* 7. Adjust education levels to the smoothed enrollment rate and save

* 8. Plot the data [INACTIVE]

**************************************


********************************************************************************
* 0. Data sources
********************************************************************************

  if "$download"=="1" {
  * Until 2012
    cd ENTA_input_data\Original_input_data
	
    eurostatuse educ_enrl1tl, noflags clear
    save educ_enrl1tl, replace

  * From 2013
    eurostatuse educ_uoe_enra02, noflags clear
    save educ_uoe_enra02, replace
	
	cd "$wkdir"
  }


********************************************************************************
* 1. Source data
********************************************************************************

  local fyear = 2008 // first year
  local lyear = 2024 // latest year

  ************************************************************
  * ISCED 1997 (educ_enrl1tl), until 2012
  ************************************************************

    use ENTA_input_data/Original_input_data/educ_enrl1tl, clear
    keep geo sex age isced97 educ_enrl1tl`fyear'-educ_enrl1tl2012
    reshape long educ_enrl1tl, i(geo sex age isced97) j(YEAR)
    rename (educ_enrl1tl isced97) (N isced)
    gen src = 1997
    tempfile i97
    save `i97'

  ************************************************************
  * ISCED 2011 (educ_uoe_enra02), 2013+
  ************************************************************

    use ENTA_input_data/Original_input_data/educ_uoe_enra02, clear
    keep geo sex age isced11 educ_uoe_enra022013-educ_uoe_enra02`lyear'
    reshape long educ_uoe_enra02, i(geo sex age isced11) j(YEAR)
    rename (educ_uoe_enra02 isced11) (N isced)
    gen src = 2011
    append using `i97'

  * Keep only years with at least some information
    bysort src geo YEAR: egen nyear = count(N)
    drop if nyear == 0
    drop nyear

  * Country, sex
    rename geo CNT2
    gen SEX = 0 if sex=="T"
    replace SEX = 1 if sex=="M"
    replace SEX = 2 if sex=="F"
    drop sex

  ************************************************************
  * Education levels
  ************************************************************

  * PRE = CGEPRE (ISCED 0), PRI = CGEPRI (1), PP = CGEPP (0-1), SEC =
  * CGESEC (2-3), PSEC = CGEPSEC (4), TER = CGETER (ISCED 2011 5-8,
  * ISCED 1997 5-6)
    gen lev = ""
    replace lev = "PRE"  if isced=="ED0"
    replace lev = "PRI"  if isced=="ED1"
    replace lev = "SEC"  if inlist(isced, "ED2", "ED3")
    replace lev = "PSEC" if isced=="ED4"
    replace lev = "TER"  if (src==2011 & inlist(isced, "ED5", "ED6", "ED7", "ED8")) | (src==1997 & isced=="ED5_6")
    keep if lev!=""
    expand 2 if inlist(lev, "PRE", "PRI"), gen(dup)
    replace lev = "PP" if dup
    drop dup

  * Sum over ISCED levels (all missing stays missing, not 0)
    collapse (sum) N (count) nN=N, by(src CNT2 YEAR SEX lev age)
    replace N = . if nN == 0
    drop nN

  * France 2010 and 2011 wrong assignment to age 29 (the 25-29 group is
  * used instead)
    replace N = . if CNT2=="FR" & inlist(YEAR, 2010, 2011) & age=="Y29" & inlist(lev, "SEC", "PSEC", "TER")

  ************************************************************
  * Age groups
  ************************************************************

  * alo-ahi: ages covered by the age code; open groups end at 80
  * (population80: 80 = 80+); TOTAL and UNK stay missing
    gen alo = .
    gen ahi = .
    replace alo = real(substr(age, 2, .)) if regexm(age, "^Y[0-9]+$")
    replace ahi = alo if regexm(age, "^Y[0-9]+$")
    replace alo = real(substr(age, 2, 2)) if regexm(age, "^Y[0-9][0-9]-[0-9][0-9]$")
    replace ahi = real(substr(age, 5, 2)) if regexm(age, "^Y[0-9][0-9]-[0-9][0-9]$")
    replace alo = 0 if inlist(age, "Y_LT2", "Y_LT3")
    replace ahi = 1 if age=="Y_LT2"
    replace ahi = 2 if age=="Y_LT3"
    replace alo = real(substr(age, 5, .)) if substr(age, 1, 4)=="Y_GE"
    replace ahi = 80 if substr(age, 1, 4)=="Y_GE"
    gen byte single = alo==ahi & alo<.
    gen byte band5 = ahi==alo+4 & alo<.


********************************************************************************
* 2. Men and women add up to the total
********************************************************************************

  * Rules, for every level and age group:
  * - one sex missing while the other is reported: the missing sex is 0 (in
  *   all such source cells the total equals the reported sex)
  * - total missing, sexes reported: total = men + women (RO 2017-2018 ISCED 3)
  * - total without a sex split (BE 2017-2019, EL 2013-2017, PT 2017-2018
  *   pre-primary; EL 2014 ages 6-7 both sexes 0): sex shares of the nearest
  *   year with a split (same country, level, age group; mean of both if two
  *   years are equally near), population shares if there is none
  * - otherwise the sexes are scaled to the total (rounding; EL 2013 age 5
  *   -9, DE 2014 ISCED 6 -5 to +8)

  * Population by sex of the ages of each age code (fallback shares)
    preserve
      use ENTA_input_data\ENTA_input_datasets/population80 if SEX>0, clear
      reshape wide POP, i(CNT2 YEAR AGE) j(SEX)
      tempfile pop12
      save `pop12'
    restore
    gen plo = cond(alo<., alo, 0)
    gen phi = cond(ahi<., ahi, 80)
    preserve
      keep CNT2 YEAR plo phi
      duplicates drop
      expand phi - plo + 1
      bysort CNT2 YEAR plo phi: gen AGE = plo + _n - 1
      joinby CNT2 YEAR AGE using `pop12'
      collapse (sum) POP1 POP2, by(CNT2 YEAR plo phi)
      tempfile rangepop
      save `rangepop'
    restore

    reshape wide N, i(src CNT2 YEAR lev age) j(SEX)
    merge m:1 CNT2 YEAR plo phi using `rangepop', keep(master match) nogen

  * One sex missing: 0
    replace N1 = 0 if N1==. & N2<.
    replace N2 = 0 if N2==. & N1<.

  * Total missing: men + women
    gen byte ctot = N0==. & N1<. & N1 + N2 > 0
    replace N0 = N1 + N2 if ctot

  * Sex shares of the cell itself
    gen double shm = N1 / (N1 + N2) if N1 + N2 > 0 & N1<.

  * Nearest year with sex shares
    gen double shp = shm
    gen yp = YEAR if shm<.
    bysort CNT2 lev age (YEAR): replace shp = shp[_n-1] if shp==.
    by CNT2 lev age: replace yp = yp[_n-1] if yp==.
    gen double shn = shm
    gen yn = YEAR if shm<.
    gen negYEAR = -YEAR
    bysort CNT2 lev age (negYEAR): replace shn = shn[_n-1] if shn==.
    by CNT2 lev age: replace yn = yn[_n-1] if yn==.

    gen double sh = shm
    gen byte csplit = sh==. & N0>0 & N0<.
    replace sh = shp if csplit & shp<. & shn==.
    replace sh = shn if csplit & shn<. & shp==.
    replace sh = cond(YEAR-yp < yn-YEAR, shp, cond(YEAR-yp > yn-YEAR, shn, (shp + shn)/2)) if csplit & shp<. & shn<.
    gen byte cpop = csplit & sh==.
    replace sh = POP1 / (POP1 + POP2) if cpop & POP1 + POP2 > 0

  * Sexes scaled to the total
    gen byte cscale = !csplit & N0<. & N1<. & abs(N1 + N2 - N0) > 2
    replace N1 = N0 * sh if N0<. & sh<.
    replace N2 = N0 * (1 - sh) if N0<. & sh<.

    gen byte eu = inlist(CNT2, "AT", "BE", "BG", "CY", "CZ", "DE", "DK", "EE", "EL") | ///
      inlist(CNT2, "ES", "FI", "FR", "HU", "HR", "IE", "IT", "LT", "LU") | ///
      inlist(CNT2, "LV", "NL", "PL", "PT", "RO", "SE", "SI", "SK")
    di as text _n "Men + women = total, EU cells changed (level PP counts ISCED 0-1 again):"
    di "  total from men + women: " _c
    count if ctot & eu
    di "  sex split from nearest year: " _c
    count if csplit & !cpop & eu
    di "  sex split from population: " _c
    count if cpop & eu
    di "  sexes scaled to total (|difference| > 2): " _c
    count if cscale & eu
    list CNT2 YEAR lev age N0 if (ctot | csplit | cscale) & eu & lev!="PP" & N0>=10, noobs clean sepby(CNT2 YEAR lev)

    keep src CNT2 YEAR lev age alo ahi single band5 eu N0 N1 N2
    reshape long N, i(src CNT2 YEAR lev age) j(SEX)


********************************************************************************
* 3. Single years of age
********************************************************************************

  ************************************************************
  * Population
  ************************************************************

    preserve
      use ENTA_input_data\ENTA_input_datasets/population80, clear
      tempfile pop
      save `pop'
    restore

  ************************************************************
  * Choice of age groups
  ************************************************************

  * Rows used (use), and the ages each row is distributed to (blo-bhi).
  * Decisions are taken on the total (SEX 0) and hold for men and women.
  * - single years, Y_LT2, Y_LT3 and open groups: used
  * - 5-year groups next to single years (ISCED 1997 15-34, ISCED 2011
  *   20-49): single years if all five are reported, else the 5-year group
  * - both reported and different by more than max(10, 1%): single years
  *   scaled to the 5-year group (HR 2010 tertiary 25-29)
  * - Slovenia ISCED 1997 ISCED 1-4, 20-29: always the 5-year group (single
  *   years hold the whole group at one age)
    gen r5 = .
    replace r5 = floor(alo/5)*5 if (single | band5) & src==1997 & inrange(alo, 15, 34)
    replace r5 = floor(alo/5)*5 if (single | band5) & src==2011 & inrange(alo, 20, 49)

    bysort CNT2 YEAR lev r5: egen nS = count(cond(SEX==0 & single & r5<., N, .))
    by CNT2 YEAR lev r5: egen double sumS = total(cond(SEX==0 & single & r5<., N, .))
    by CNT2 YEAR lev r5: egen posS = total(SEX==0 & single & r5<. & N>0 & N<.)
    by CNT2 YEAR lev r5: egen firstpos = max(SEX==0 & single & alo==r5 & r5<. & N>0 & N<.)
    by CNT2 YEAR lev r5: egen double B = max(cond(SEX==0 & band5 & r5<., N, .))

    gen byte use = single | inlist(age, "Y_LT2", "Y_LT3") | substr(age, 1, 4)=="Y_GE"
    replace use = 1 if band5 & r5==.
    gen blo = alo
    gen bhi = ahi

    gen byte full = nS==5
    gen byte si5 = src==1997 & CNT2=="SI" & inlist(lev, "PRI", "SEC", "PSEC") & inlist(r5, 20, 25) & B<.
    replace use = 0 if single & r5<. & ((!full & B<.) | si5)
    replace use = 1 if band5 & r5<. & ((!full & B<.) | si5)
    gen byte scale = full & !si5 & B>0 & B<. & abs(B - sumS) > max(10, 0.01*B) & r5<.

  * Lumps: all students of a 5-year group at its first age, the other four
  * ages 0 or missing (IT 2013 ISCED 1-3, RO 2013-2021 at ages 30, 35, 40,
  * ...): spread over the group
    gen byte lump = src==2011 & posS==1 & firstpos & sumS>=100 & (B==. | B==0 | abs(B - sumS)<=1) & r5<.
    replace scale = 0 if lump
    replace use = 1 if single & lump & alo==r5
    replace use = 0 if band5 & lump
    replace bhi = alo + 4 if single & lump & alo==r5

  * France 2020 ISCED 2-3: single age 30 holds 30+ (26,636; 2019 30+:
  * 26,540)
    replace bhi = 80 if CNT2=="FR" & YEAR==2020 & lev=="SEC" & age=="Y30"

  ************************************************************
  * Open and evenly spread age groups
  ************************************************************

  * ISCED 1997: a 5-year group is open ended where no older group is
  * reported - TOTAL minus the parts is 0 there: Y35-39 = 35+ (IT
  * tertiary 2008-2012, RO tertiary except 2011, DE ISCED 3 2009-2012),
  * Y30-34 = 30+ (FR, PL tertiary, IE 2008-2009, EL 2008-2011)
    bysort CNT2 YEAR lev: egen double B30 = max(cond(SEX==0 & age=="Y30-34", N, .))
    by CNT2 YEAR lev: egen double B35 = max(cond(SEX==0 & age=="Y35-39", N, .))
    by CNT2 YEAR lev: egen double G40 = max(cond(SEX==0 & age=="Y_GE40", N, .))
    gen byte open = 0
    replace open = 35 if src==1997 & age=="Y35-39" & B35>0 & B35<. & G40==.
    replace open = 30 if src==1997 & age=="Y30-34" & use & B30>0 & B30<. & B35==. & G40==.

  * Croatia tertiary ISCED 1997: Y35-39 holds most of 35+ (Y_GE40 413-748
  * next to Y35-39 about equal to Y30-34; 35+ 7,616 in 2012 and 7,813 in
  * 2013): Y35-39 + Y_GE40 = 35+
    bysort CNT2 YEAR lev SEX: egen double g40s = max(cond(age=="Y_GE40", N, .))
    gen byte hr35 = src==1997 & CNT2=="HR" & lev=="TER"
    replace N = cond(N<., N, 0) + g40s if hr35 & age=="Y35-39" & g40s<.
    replace use = 0 if hr35 & age=="Y_GE40"
    replace open = 35 if hr35 & age=="Y35-39"
    drop g40s hr35

  * Romania ISCED 2-4
  * - ISCED 1997: single age 21 holds 21+ (104,200-193,103; ages 22-24 and
  *   all older groups not reported): single ages 20 and 21 instead of
  *   the 20-24 group, age 21 = 21+
  * - 2013: single age 24 holds 24+ (ISCED 3 72,540, ISCED 4 45,504; ages
  *   22-23 about 7,000 each; 25+ reported as 0)
    bysort CNT2 YEAR lev: egen n2224 = count(cond(SEX==0 & inlist(age, "Y22", "Y23", "Y24"), N, .))
    gen byte ro21 = src==1997 & CNT2=="RO" & inlist(lev, "SEC", "PSEC") & n2224==0
    replace use = 1 if ro21 & inlist(age, "Y20", "Y21") & N<.
    replace use = 0 if ro21 & age=="Y20-24"
    replace open = 21 if ro21 & age=="Y21"
    replace open = 24 if CNT2=="RO" & YEAR==2013 & inlist(lev, "SEC", "PSEC") & age=="Y24"
    drop n2224 ro21
    replace bhi = 80 if open

  * Greece tertiary 2010-2013: single age 29 holds 29+ (age 29 173,391 in
  * 2012, 30,193 in 2008)
    replace open = 29 if CNT2=="EL" & lev=="TER" & inrange(YEAR, 2010, 2013) & age=="Y29"
    replace bhi = 80 if open==29

  * ISCED 2011: equal values (at least 20) in consecutive age groups were
  * spread evenly by the source (FR, PL, EL, IE, HU, SI 2013-).
  * Segments: single years 30-34, 35-39, 40-49 (or 40-44 = 45-49), groups
  * 50-54 = 55-59 = 60-64 (with 65+); consecutive flagged segments are one
  * group, spread with the reference age profile
    foreach s in 30 35 40 {
      local e = cond(`s'==40, 49, `s' + 4)
      local n = `e' - `s' + 1
      bysort CNT2 YEAR lev: egen double mn = min(cond(SEX==0 & single & inrange(alo, `s', `e'), N, .))
      by CNT2 YEAR lev: egen double mx = max(cond(SEX==0 & single & inrange(alo, `s', `e'), N, .))
      by CNT2 YEAR lev: egen ct = count(cond(SEX==0 & single & inrange(alo, `s', `e'), N, .))
      gen byte f`s' = src==2011 & ct==`n' & mn==mx & mn>=20
      drop mn mx ct
    }
    bysort CNT2 YEAR lev: egen double b40 = max(cond(SEX==0 & age=="Y40-44", N, .))
    by CNT2 YEAR lev: egen double b45 = max(cond(SEX==0 & age=="Y45-49", N, .))
    replace f40 = 1 if src==2011 & b40==b45 & b40>=20 & b40<.
    by CNT2 YEAR lev: egen double mn = min(cond(SEX==0 & inlist(age, "Y50-54", "Y55-59", "Y60-64"), N, .))
    by CNT2 YEAR lev: egen double mx = max(cond(SEX==0 & inlist(age, "Y50-54", "Y55-59", "Y60-64"), N, .))
    by CNT2 YEAR lev: egen ct = count(cond(SEX==0 & inlist(age, "Y50-54", "Y55-59", "Y60-64"), N, .))
    gen byte f50 = src==2011 & ct==3 & mn==mx & mn>=20
    drop mn mx ct b40 b45

    gen s35 = cond(f30, 30, 35)
    gen s40 = cond(f35, s35, 40)
    gen s50 = cond(f40, s40, 50)
    gen e40 = cond(f50, 80, 49)
    gen e35 = cond(f40, e40, 39)
    gen e30 = cond(f35, e35, 34)
    replace blo = 30  if use & f30 & inrange(alo, 30, 34)
    replace bhi = e30 if use & f30 & inrange(alo, 30, 34)
    replace blo = s35 if use & f35 & inrange(alo, 35, 39)
    replace bhi = e35 if use & f35 & inrange(alo, 35, 39)
    replace blo = s40 if use & f40 & inrange(alo, 40, 49)
    replace bhi = e40 if use & f40 & inrange(alo, 40, 49)
    replace blo = s50 if use & f50 & alo>=50 & alo<.
    replace bhi = 80  if use & f50 & alo>=50 & alo<.
    drop s35 s40 s50 e30 e35 e40

    bysort CNT2 YEAR lev: egen byte anylump = max(lump)
    gen byte even = f30 | f35 | f40 | f50

  ************************************************************
  * Unknown age
  ************************************************************

  * Students of unknown age (UNK) are otherwise left out, which spreads
  * them like the students of known age. Where they are adults they
  * are spread with the reference age profile over
  * - 25+: PL tertiary 2008-2012 (known 25+ and UNK 642,619 in 2012, 25+
  *   605,878 in 2013 with UNK 4,077); RO ISCED 2-4 2015-2021 (UNK 0 in
  *   2022: -68,904, students 20+ +77,702)
  * - 24+: RO ISCED 2-4 2014 (age 24 and older not reported)
  * - 20+: BE ISCED 2-3 and tertiary 2014+ (UNK +129,253 / +33,919 in 2014,
  *   80% of the fall in known ages at 25+)
    gen byte unk = age=="UNK" & N<. & ( ///
      (CNT2=="PL" & lev=="TER" & inrange(YEAR, 2008, 2012)) | ///
      (CNT2=="RO" & inlist(lev, "SEC", "PSEC") & inrange(YEAR, 2014, 2021)) | ///
      (CNT2=="BE" & inlist(lev, "SEC", "TER") & YEAR>=2014))
    replace use = 1 if unk
    replace blo = cond(CNT2=="BE", 20, cond(CNT2=="RO" & YEAR==2014, 24, 25)) if unk
    replace bhi = 80 if unk

  ************************************************************
  * Year jumps
  ************************************************************

  * jfrom: first age replaced with values from neighbouring years
  * - no age information: the age groups sum to less than half of TOTAL
  *   (TOTAL at least 1,000; CZ ISCED 4 2013-2022)
  * - students aged 55+ (0 if not reported) below 10% of the nearest earlier
  *   and later ISCED 2011 year with 500 or more (the smaller of the two, or
  *   the one there is): RO tertiary 2013-2021, LV tertiary 2014-2015, IT
  *   ISCED 1 2016, IE tertiary 2013 ...; from 50 if 50-54 is 0 as well.
  *   Not for RO ISCED 2-4 2013-2021 (open age 24 and UNK above)
  * - IE 2018 ISCED 2-3 ages 20+ (65+ 12,748; 2017 77, 2019 2,268)
  * - BE 2015 ISCED 2-3 ages 65+ (39,711; 2014 19,718, 2016 19,411)
  * - NL tertiary 2008-2010 and 2013-2014 ages 25+ (30-49 about half of the
  *   years before and after)
  * - EL 2014 tertiary ages 20+ (27% of students of unknown age; age 29
  *   7,505, 2013 131,316, 2015 33,054)
  * - BG 2013-2014 all levels ages 50+ (per 1000 aged 50+: 8.3 and 7.2;
  *   2015 4.1, 2016 3.8)
    bysort CNT2 YEAR lev: egen double tot = max(cond(SEX==0 & age=="TOTAL", N, .))
    by CNT2 YEAR lev: egen double sumuse = total(cond(SEX==0 & use, N, .))
    by CNT2 YEAR lev: egen double o55 = total(cond(SEX==0 & inlist(age, "Y55-59", "Y60-64", "Y_GE65"), N, .))
    by CNT2 YEAR lev: egen double o50 = total(cond(SEX==0 & age=="Y50-54", N, .))
    egen byte tagy = tag(CNT2 YEAR lev)
    gen double op = o55 if tagy & src==2011 & o55>=500
    gen double on = op
    bysort CNT2 lev tagy (YEAR): replace op = op[_n-1] if op==.
    gen negYEAR = -YEAR
    bysort CNT2 lev tagy (negYEAR): replace on = on[_n-1] if on==.
    gen byte z55 = tagy & src==2011 & !(CNT2=="RO" & inlist(lev, "SEC", "PSEC") & inrange(YEAR, 2013, 2021)) & ///
      ((op<. & on<. & o55 < 0.1*min(op, on)) | (op<. & on==. & o55 < 0.1*op) | (op==. & on<. & o55 < 0.1*on))
    bysort CNT2 YEAR lev: egen byte zz55 = max(z55)

    gen jfrom = .
    replace jfrom = 0 if sumuse < 0.5*tot & tot>=1000 & tot<.
    replace jfrom = min(jfrom, cond(o50==0, 50, 55)) if zz55 & !(CNT2=="FR" & YEAR==2020 & lev=="SEC")
    drop op on negYEAR z55 zz55
    replace jfrom = min(jfrom, 20) if CNT2=="IE" & YEAR==2018 & lev=="SEC"
    replace jfrom = min(jfrom, 65) if CNT2=="BE" & YEAR==2015 & lev=="SEC"
    replace jfrom = min(jfrom, 25) if CNT2=="NL" & lev=="TER" & (inrange(YEAR, 2008, 2010) | inrange(YEAR, 2013, 2014))
    replace jfrom = min(jfrom, 20) if CNT2=="EL" & YEAR==2014 & lev=="TER"
    replace jfrom = min(jfrom, 50) if CNT2=="BG" & inrange(YEAR, 2013, 2014)


  ************************************************************
  * Reference age profile 2015-2017
  ************************************************************

  * Students per person by country, level, sex and single year of age,
  * mean of 2015-2017 (ISCED 2011; 50-64 flat within 5-year groups, 65+
  * flat). Years with evenly spread groups, lumps or year jumps at that
  * level are left out and replaced by the nearest clean years (at most
  * three; FR, RO, ...). RO ISCED 2-4 2013-2021 are left out as well: the
  * adults are in the open age 24 or in UNK there.
    gen dref = abs(YEAR - 2016)*10 - (YEAR > 2016) if tagy & src==2011 & !even & !anylump & jfrom==. & ///
      !(CNT2=="RO" & inlist(lev, "SEC", "PSEC") & inrange(YEAR, 2013, 2021))
    bysort CNT2 lev tagy (dref): gen rk = _n if dref<.
    bysort CNT2 YEAR lev: egen byte refyear = max(rk<=3 & rk<.)
    drop dref rk

    preserve
      keep if tagy & refyear & eu
      bysort CNT2 lev (YEAR): gen str20 ry = string(YEAR) if _n==1
      by CNT2 lev: replace ry = ry[_n-1] + " " + string(YEAR) if _n>1
      by CNT2 lev: keep if _n==_N
      di as text _n "Reference years other than 2015-2017 (EU):"
      list CNT2 lev ry if ry!="2015 2016 2017", noobs clean
    restore

    preserve
      keep if refyear & use & !unk & SEX>0 & N<.
      gen long id = _n
      expand ahi - alo + 1
      bysort id: gen AGE = alo + _n - 1
      merge m:1 CNT2 YEAR SEX AGE using `pop', keep(match) nogen
      bysort id: egen double W = total(POP)
      gen double Na = N * POP / W
      collapse (sum) Na (mean) POP (max) eu, by(CNT2 YEAR lev SEX AGE)
      gen double rate = Na / POP
      collapse (mean) rate (max) eu, by(CNT2 lev SEX AGE)
      tempfile ref
      save `ref'
    * EU average (fallback where a country has no reference)
      keep if eu
      collapse (mean) rateEU=rate, by(lev SEX AGE)
      tempfile refeu
      save `refeu'
    restore

    preserve
      keep if tagy & eu & (even | anylump | open | jfrom<.)
      di as text _n "Evenly spread (even), lumps, open groups and year jumps (EU):"
      list CNT2 YEAR lev f30 f35 f40 f50 anylump jfrom, noobs clean sepby(CNT2)
    restore
    preserve
      keep if SEX==0 & eu & open>0
      list CNT2 YEAR lev age open N, noobs clean sepby(CNT2)
    restore

  ************************************************************
  * Distribute age groups to single years of age
  ************************************************************

  * Each used row is spread over blo-bhi in proportion to reference rate x
  * population; with the EU average reference where the country reference
  * is 0 over the whole range (no clean reference year: FR ISCED 2-3, ...),
  * population alone if that is 0 too
    bysort CNT2 YEAR SEX lev r5: egen double sS = total(cond(single, N, .)) if r5<.
    by CNT2 YEAR SEX lev r5: egen double bS = max(cond(band5, N, .)) if r5<.
    bysort CNT2 YEAR lev r5: egen byte scaleg = max(scale)
    replace N = N * bS / sS if scaleg & single & sS>0 & bS<.

    preserve
      keep if tagy
      keep CNT2 YEAR lev jfrom
      tempfile jumps
      save `jumps'
    restore

    keep if use & SEX>0 & N<.
    keep CNT2 YEAR SEX lev age blo bhi N eu
    gen long id = _n
    expand bhi - blo + 1
    bysort id: gen AGE = blo + _n - 1
    merge m:1 CNT2 YEAR SEX AGE using `pop', keep(match) nogen
    merge m:1 CNT2 lev SEX AGE using `ref', keep(master match) nogen keepusing(rate)
    merge m:1 lev SEX AGE using `refeu', keep(master match) nogen
    gen double w = rate * POP
    replace w = 0 if w==.
    gen double w2 = rateEU * POP
    replace w2 = 0 if w2==.
    bysort id: egen double W = total(w)
    by id: egen double W2 = total(w2)
    by id: egen double WP = total(POP)
    gen double Na = cond(W>0, N * w / W, cond(W2>0, N * w2 / W2, N * POP / WP))

    preserve
      keep if W==0 & bhi>blo & N>0 & eu
      gen byte poponly = W2==0
      collapse (sum) N=Na (max) poponly, by(CNT2 YEAR lev age blo bhi)
      di as text _n "Age groups without a country reference (EU average profile; poponly = population), EU, 2+ ages, SEX 1+2:"
      list CNT2 YEAR lev age blo bhi N, noobs clean sepby(CNT2)
    restore

    collapse (sum) N=Na (mean) POP, by(CNT2 YEAR SEX lev AGE)

  ************************************************************
  * Replace year jumps with values from neighbouring years
  ************************************************************

  * Students per person of the nearest year before and after without a
  * jump (same country, level, sex, age); mean of both, or the one there is.
  * Pass 1: the year jumps above; ages the source does not report at all in
  * a jump year are added first.
  * Pass 2: isolated one-year spikes and dips left after pass 1 - students
  * per person aged 30-49 or 50+ more than twice the larger or less than half
  * the smaller of the year before and the year after (at least 500
  * students; years at the end of a series and level shifts are not
  * touched).
    preserve
      use `jumps' if jfrom<., clear
      expand 2
      bysort CNT2 YEAR lev: gen SEX = _n
      expand 81
      bysort CNT2 YEAR lev SEX: gen AGE = _n - 1
      keep if AGE>=jfrom
      keep CNT2 YEAR lev SEX AGE
      tempfile jgrid
      save `jgrid'
    restore
    merge 1:1 CNT2 YEAR SEX lev AGE using `jgrid', nogen
    replace N = 0 if N==.
    merge m:1 CNT2 YEAR SEX AGE using `pop', keep(1 3 4 5) nogen update
    merge m:1 CNT2 YEAR lev using `jumps', keep(master match) nogen
    gen byte eu = inlist(CNT2, "AT", "BE", "BG", "CY", "CZ", "DE", "DK", "EE", "EL") | ///
      inlist(CNT2, "ES", "FI", "FR", "HU", "HR", "IE", "IT", "LT", "LU") | ///
      inlist(CNT2, "LV", "NL", "PL", "PT", "RO", "SE", "SI", "SK")

    forvalues pass = 1/2 {

      if `pass'==2 {
        drop jfrom
        preserve
          gen g = cond(AGE>=50, 50, cond(AGE>=30, 30, .))
          drop if g==.
          collapse (sum) G=N P=POP (max) eu, by(CNT2 YEAR lev g)
          gen double r = G / P
          egen long grp = group(CNT2 lev g)
          tsset grp YEAR
          gen double rm = L.r
          gen double rf = F.r
          gen double Gn = min(L.G, F.G)
          gen byte spike = rm<. & rf<. & ((r > 2*max(rm, rf) & G>=500) | (r < 0.5*min(rm, rf) & Gn>=500))
          keep if spike
          if _N==0 set obs 0
          gen double rel_before = r / rm
          gen double rel_after = r / rf
          di as text _n "Pass 2, isolated one-year spikes and dips (EU):"
          list CNT2 YEAR lev g G rel_before rel_after if eu, noobs clean
          collapse (min) jfrom=g, by(CNT2 YEAR lev)
          tempfile spikes
          save `spikes'
        restore
        merge m:1 CNT2 YEAR lev using `spikes', keep(master match) nogen
      }

      gen byte jump = AGE>=jfrom & jfrom<.
      gen double rate = N / POP
      gen double rp = rate if !jump
      bysort CNT2 lev SEX AGE (YEAR): replace rp = rp[_n-1] if jump
      gen double rn = rate if !jump
      gen negYEAR = -YEAR
      bysort CNT2 lev SEX AGE (negYEAR): replace rn = rn[_n-1] if jump
      gen double rj = (rp + rn)/2
      replace rj = rp if rj==.
      replace rj = rn if rj==.
      replace N = rj * POP if jump & rj<.
      preserve
        keep if jump & rj==. & eu
        di as text _n "Pass `pass': year jumps without a neighbouring year (kept as reported, EU):"
        if _N>0 {
          gen n = 1
          collapse (sum) n (min) amin=AGE (max) amax=AGE, by(CNT2 YEAR lev)
          list, noobs clean
        }
      restore
      drop jump rate rp rn negYEAR rj
    }
    drop jfrom

  ************************************************************
  * Into wide format by education level
  ************************************************************

    keep CNT2 YEAR SEX AGE lev N
    replace lev = "CGE" + lev
    reshape wide N, i(CNT2 YEAR SEX AGE) j(lev) string
    rename N* *

  * All ages 0-80 of every country-year from the first to the last year
  * with data of that country (EL 2009 has none and is imputed below)
    bysort CNT2: egen ymin = min(YEAR)
    by CNT2: egen ymax = max(YEAR)
    preserve
      keep CNT2 ymin ymax
      duplicates drop
      tempfile span
      save `span'
    restore
    drop ymin ymax
    merge 1:1 CNT2 YEAR SEX AGE using `pop', nogen
    merge m:1 CNT2 using `span', keep(match) nogen
    keep if SEX>0 & inrange(YEAR, ymin, ymax)
    drop ymin ymax


********************************************************************************
* 4. Clean the data
********************************************************************************

  ************************************************************
  * Missing to zero, below age 3 to zero
  ************************************************************

  * Below age 3 set to zero (expenditure by COFOG uses the ISCED 1997
  * classification, below 3 is not pre-primary)
    foreach var in CGEPRE CGEPRI CGESEC CGEPSEC CGETER CGEPP {
      replace `var' = 0 if `var' == .
      replace `var' = 0 if AGE<3
    }

  ************************************************************
  * Greece 2009: impute from 2008 and 2010
  ************************************************************

  * Eurostat educ_enrl1tl has no value at all for EL 2009. Students per
  * person by level, sex and age = mean of 2008 and 2010, times the 2009
  * population.
    foreach var in CGEPRE CGEPRI CGEPP CGESEC CGEPSEC CGETER {
      bys CNT2 SEX AGE: egen `var'EL09 = mean(cond(inlist(YEAR, 2008, 2010), `var'/POP, .)) if CNT2=="EL"
      replace `var' = `var'EL09*POP if CNT2=="EL" & YEAR==2009
      drop `var'EL09
    }

  ************************************************************
  * Replace missing or implausible values with values from other years
  ************************************************************

  * Variables that will contain enrollment rates from reference year
    gen CGEPPi = .
    gen CGETERi = .
    gen CGESECi = .

  * Pre-primary and primary
  * In Denmark 2008 and 2009 some students at age five missing
    replace CGEPPi = CGEPP/POP if YEAR==2011 & CNT2=="DK"
  * In Greece 2018 and 2020+ are missing for pre-primary
    replace CGEPPi = CGEPP/POP if YEAR==2019 & CNT2=="EL"
  * Hungary 2013 missing for pre-primary
    replace CGEPPi = CGEPP/POP if YEAR==2014 & CNT2=="HU"

  * Poland: change of enrollment assignment between primary and secondary
  * in 2020
    replace CGEPPi = CGEPP/POP if YEAR==2018 & CNT2=="PL"
    replace CGESECi = CGESEC/POP if YEAR==2018 & CNT2=="PL"

  * Ireland post-secondary is kept as reported: students move from ISCED 4
  * to ISCED 3 in 2017-2018, which cancels in CGES = CGESEC + CGEPSEC
  * (compilation1); replacing ISCED 4 with its 2019 rate made a level shift
  * in CGES

  * Ireland 2011 age 12: no secondary students (all in primary), age 13
  * shifted as well; use 2012
    replace CGEPPi = CGEPP/POP if YEAR==2012 & CNT2=="IE"
    replace CGESECi = CGESEC/POP if YEAR==2012 & CNT2=="IE"

  * Tertiary
  * Luxembourg before 2011 no tertiary education
    replace CGETERi = CGETER/POP if YEAR==2011 & CNT2=="LU"

  * Reference rates by country, sex and age
    preserve
      collapse (mean) CGEPPi CGESECi CGETERi, by(CNT2 SEX AGE)
      sort CNT2 SEX AGE
      tempfile imp
      save `imp'
    restore

    drop CGEPPi CGETERi CGESECi
    sort CNT2 SEX AGE
    merge m:1 CNT2 SEX AGE using `imp'
    drop _merge

  * Replace
    replace CGEPP = CGEPPi*POP if CNT2=="DK" & (YEAR==2008 | YEAR==2009) & AGE==5
    replace CGEPP = CGEPPi*POP if CNT2=="EL" & (YEAR==2018 | YEAR>=2020)
    replace CGEPP = CGEPPi*POP if CNT2=="HU" & (YEAR==2013)

    replace CGEPP = CGEPPi*POP if CNT2=="PL" & YEAR>=2020
    replace CGESEC = CGESECi*POP if CNT2=="PL" & YEAR>=2020
    replace CGEPP = CGEPPi*POP if CNT2=="IE" & (YEAR==2011) & (AGE==12 | AGE==13)
    replace CGESEC = CGESECi*POP if CNT2=="IE" & (YEAR==2011) & (AGE==12 | AGE==13)

    replace CGETER = CGETERi*POP if CNT2=="LU" & (YEAR<=2010)
    drop CGEPPi CGETERi CGESECi

  ************************************************************
  * Total = men + women
  ************************************************************

    preserve
      collapse (sum) CGEPRE CGEPRI CGEPP CGESEC CGEPSEC CGETER, by(CNT2 YEAR AGE)
      gen SEX = 0
      merge 1:1 CNT2 YEAR SEX AGE using `pop', keep(match) nogen
      tempfile tot0
      save `tot0'
    restore
    append using `tot0'
    sort CNT2 YEAR SEX AGE


********************************************************************************
* 5. Enrollment rate
********************************************************************************

  ************************************************************
  * Enrollment rate ENRR
  ************************************************************

    gen ENRR = (CGEPP + CGESEC + CGEPSEC + CGETER)/POP

  * Set ENRR to 1 if almost all enrolled
    replace ENRR = 1 if ENRR>1
    replace ENRR = 1 if AGE >= 6 & AGE < 17 & ///
      (inlist(CNT2, "FR", "HR", "IE", "SK", "BE", "BG", "CZ") | ///
       inlist(CNT2, "DK", "EE", "LV", "SI", "PL"))

  ************************************************************
  * Into wide format by sex
  ************************************************************

    local vars "ENRR CGEPRE CGEPRI CGEPP CGESEC CGEPSEC CGETER POP"

  * Total
    preserve
      keep if SEX == 0
      keep `vars' CNT2 YEAR AGE
      sort CNT2 YEAR AGE
      tempfile tot
      save `tot', replace
    restore

  * Men
    preserve
      keep if SEX == 1
      keep `vars' CNT2 YEAR AGE
      foreach var of local vars {
        rename `var' `var'm
      }
      sort CNT2 YEAR AGE
      tempfile men
      save `men', replace
    restore

  * Women
    keep if SEX == 2
    keep `vars' CNT2 YEAR AGE
    foreach var of local vars {
      rename `var' `var'f
    }

    sort CNT2 YEAR AGE
    merge 1:1 CNT2 YEAR AGE using `tot', nogenerate

    sort CNT2 YEAR AGE
    merge 1:1 CNT2 YEAR AGE using `men', nogenerate

    // line ENRR AGE if YEAR==2013 & CNT2=="PL"


********************************************************************************
* 6. Smooth the enrollment rate
********************************************************************************

  ************************************************************
  * Age 20+
  ************************************************************

    local countries "AT BE DE SK EL IE IT LV NL PL RO SI"

    sum YEAR
    local min = r(min)
    local max = r(max)

    foreach cnt of local countries {

      local vars "ENRR"
      foreach var of local vars {

        capture drop s`var' s`var'm s`var'f
        gen s`var' = `var'
        gen s`var'm = `var'm
        gen s`var'f = `var'f

        forvalues yr = `min'/`max' {
          supsmooth `var' AGE if YEAR==`yr' & AGE>=20 & CNT2=="`cnt'", gen(s`var'1) bwcv
          replace s`var' = s`var'1 if s`var'1!=.
          supsmooth `var'm AGE if YEAR==`yr' & AGE>=20 & CNT2=="`cnt'", gen(s`var'm1) bwcv
          replace s`var'm = s`var'm1 if s`var'm1!=.
          supsmooth `var'f AGE if YEAR==`yr' & AGE>=20 & CNT2=="`cnt'", gen(s`var'f1) bwcv
          replace s`var'f = s`var'f1 if s`var'f1!=.
          drop s`var'1 s`var'm1 s`var'f1
        }  // close forvalues yr

        sort CNT2 YEAR AGE
        replace `var' = s`var' if CNT2=="`cnt'"
        replace `var'f = s`var'f if CNT2=="`cnt'"
        replace `var'm = s`var'm if CNT2=="`cnt'"
        drop s`var' s`var'm s`var'f

      }  // close foreach var
    }  // close foreach cnt

  ************************************************************
  * Age 25+
  ************************************************************

    local countries "DK FI SE"

    sum YEAR
    local min = r(min)
    local max = r(max)

    foreach cnt of local countries {

      local vars "ENRR"
      foreach var of local vars {

        capture drop s`var' s`var'm s`var'f
        gen s`var' = `var'
        gen s`var'm = `var'm
        gen s`var'f = `var'f

        forvalues yr = `min'/`max' {
          supsmooth `var' AGE if YEAR==`yr' & AGE>=25 & CNT2=="`cnt'", gen(s`var'1) bwcv
          replace s`var' = s`var'1 if s`var'1!=.
          supsmooth `var'm AGE if YEAR==`yr' & AGE>=25 & CNT2=="`cnt'", gen(s`var'm1) bwcv
          replace s`var'm = s`var'm1 if s`var'm1!=.
          supsmooth `var'f AGE if YEAR==`yr' & AGE>=25 & CNT2=="`cnt'", gen(s`var'f1) bwcv
          replace s`var'f = s`var'f1 if s`var'f1!=.
          drop s`var'1 s`var'm1 s`var'f1
        }  // close forvalues yr

        sort CNT2 YEAR AGE
        replace `var' = s`var' if CNT2=="`cnt'"
        replace `var'f = s`var'f if CNT2=="`cnt'"
        replace `var'm = s`var'm if CNT2=="`cnt'"
        drop s`var' s`var'm s`var'f

      }  // close foreach var
    }  // close foreach cnt

  ************************************************************
  * Age 6-17
  ************************************************************

    local countries "EE SK HU RO"

    sum YEAR
    local min = r(min)
    local max = r(max)

    foreach cnt of local countries {

      local vars "ENRR"
      foreach var of local vars {

        capture drop s`var' s`var'm s`var'f
        gen s`var' = `var'
        gen s`var'm = `var'm
        gen s`var'f = `var'f

        forvalues yr = `min'/`max' {
          supsmooth `var' AGE if YEAR==`yr' & AGE>=6 & AGE<18 & CNT2=="`cnt'", gen(s`var'1) bwcv
          replace s`var' = s`var'1 if s`var'1!=.
          supsmooth `var'm AGE if YEAR==`yr' & AGE>=6 & AGE<18 & CNT2=="`cnt'", gen(s`var'm1) bwcv
          replace s`var'm = s`var'm1 if s`var'm1!=.
          supsmooth `var'f AGE if YEAR==`yr' & AGE>=6 & AGE<18 & CNT2=="`cnt'", gen(s`var'f1) bwcv
          replace s`var'f = s`var'f1 if s`var'f1!=.
          drop s`var'1 s`var'm1 s`var'f1
        }  // close forvalues yr

        sort CNT2 YEAR AGE
        replace `var' = s`var' if CNT2=="`cnt'"
        replace `var'f = s`var'f if CNT2=="`cnt'"
        replace `var'm = s`var'm if CNT2=="`cnt'"
        drop s`var' s`var'm s`var'f

      }  // close foreach var
    }  // close foreach cnt


********************************************************************************
* 7. Adjust education levels to the smoothed enrollment rate and save
********************************************************************************

  * Total: levels scaled to the smoothed enrollment rate. Men and women:
  * the total split with each sex's share of the students before smoothing
  * (population shares where both are 0), so men + women = total.
    gen CGEsm = ENRR*POP
    gen CGEest = CGEPP + CGESEC + CGEPSEC + CGETER

    local vars "CGEPP CGESEC CGEPSEC CGETER"
    foreach var of local vars {
      replace `var' = `var' * CGEsm / CGEest
      replace `var'=0 if `var'==.
      replace `var'm=0 if `var'm==.
      replace `var'f=0 if `var'f==.
      gen double sh = `var'm / (`var'm + `var'f)
      replace sh = POPm / (POPm + POPf) if sh==.
      replace `var'm = `var' * sh
      replace `var'f = `var' * (1 - sh)
      drop sh
    }

    gen ENRRc = (CGEPP + CGESEC + CGEPSEC + CGETER) / POP
    // browse ENRR ENRRc

  * Enrollment rates of men and women consistent with the total
    adjustgender ENRR

    gen CGE = CGEPP + CGESEC + CGEPSEC + CGETER
    gen CGEm = CGEPPm + CGESECm + CGEPSECm + CGETERm
    gen CGEf = CGEPPf + CGESECf + CGEPSECf + CGETERf

    // line CGE CGEPP CGESEC CGEPSEC CGETER AGE if CNT2=="IE" & YEAR==2013
    // line CGEf CGEPPf CGESECf CGEPSECf CGETERf AGE if CNT2=="PL" & YEAR==2012

    sort CNT2 YEAR AGE
    save ENTA_input_data\ENTA_input_datasets/enrollment, replace


/*
********************************************************************************
* 8. Plot the data [INACTIVE]
********************************************************************************

  use ENTA_input_data\ENTA_input_datasets/enrollment, clear

  sort CNT2 YEAR AGE
  local var "CGEPSEC"
  local cnt "IE"

    local yr5 = 2005
    local yr6 = 2006
    local yr7 = 2007
    local yr8 = 2008
    local yr9 = 2009
    local yr10 = 2010
    local yr11 = 2011
    local yr12 = 2012
    local yr13 = 2013
    local yr14 = 2014
    local yr15 = 2015
    local yr16 = 2016
    local yr17 = 2017
    local yr18 = 2018
    local yr19 = 2019
    local yr20 = 2020
    local yr21 = 2021
    local yr22 = 2022
    local yr23 = 2023

    graph twoway line `var' AGE if YEAR==`yr8' & CNT2=="`cnt'", lcol("230 210 80") ///
    || line `var' AGE if YEAR==`yr9' & CNT2=="`cnt'", lcol("200 210 85") ///
    || line `var' AGE if YEAR==`yr10' & CNT2=="`cnt'", lcol("165 205 90") ///
    || line `var' AGE if YEAR==`yr11' & CNT2=="`cnt'", lcol("125 200 95") ///
    || line `var' AGE if YEAR==`yr12' & CNT2=="`cnt'", lcol("90 200 100") ///
    || line `var' AGE if YEAR==`yr13' & CNT2=="`cnt'", lcol("75 190 110") ///
    || line `var' AGE if YEAR==`yr14' & CNT2=="`cnt'", lcol("60 180 120") ///
    || line `var' AGE if YEAR==`yr15' & CNT2=="`cnt'", lcol("30 165 140") ///
    || line `var' AGE if YEAR==`yr16' & CNT2=="`cnt'", lcol("0 150 160") ///
    || line `var' AGE if YEAR==`yr17' & CNT2=="`cnt'", lcol("0 125 150") ///
    || line `var' AGE if YEAR==`yr18' & CNT2=="`cnt'", lcol("0 110 140") ///
    || line `var' AGE if YEAR==`yr19' & CNT2=="`cnt'", lcol("0 80 130") ///
    || line `var' AGE if YEAR==`yr20' & CNT2=="`cnt'", lcol("20 65 115") ///
    || line `var' AGE if YEAR==`yr21' & CNT2=="`cnt'", lcol("45 45 100") ///
    || line `var' AGE if YEAR==`yr22' & CNT2=="`cnt'", lcol("60 30 95") ///
    || line `var' AGE if YEAR==`yr23' & CNT2=="`cnt'", lcol("75 20 85") ///
      graphregion(margin(l-3 r t+0 b-3) color(white)) ///
      plotregion(margin(tiny)) ///
      title("`cnt'", size(large) margin(tiny)) ///
      ytitle("ENR", size(med)) ///
      xtitle("Age", margin(0 0 0 2) size(medlarge)) ///
      xlabel(0(10)80, labs(med)) ylabel(, labs(small)) ///
      legend(cols(5) lab(1 "2008") lab(2 "2009") lab(3 "2010") lab(4 "2011") lab(5 "2012") lab(6 "2013") ///
      lab(7 "2014") lab(8 "2015") lab(9 "2016") lab(10 "2017") lab(11 "2018") lab(12 "2019") lab(13 "2020") lab(14 "2021") lab(15 "2022") lab(16 "2023") ///
      bmargin(small) size(vsmall) ring(0) position(1) symx(*0.5))
    graph display, xsize(9) ysize(5)
*/
