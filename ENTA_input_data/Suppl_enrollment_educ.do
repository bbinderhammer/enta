********************************************************************************
* Enrollment in education by age, sex and ISCED level
********************************************************************************

* Output: ENTA_input_data/ENTA_input_datasets/enrollment.dta (read by
* ENTA_compilation1_esa.do, Section 3 Education). Number of students
* CGEPRE, CGEPRI, CGEPP, CGESEC, CGEPSEC, CGETER, total CGE and enrollment
* rate ENRR, by CNT2 YEAR AGE, total and men (m) / women (f), 2008+.
* Men + women = total for all numbers of students.
* CGEPP, CGESEC, CGEPSEC and CGETER are scaled to the smoothed ENRR
* (Section 7); CGEPRE and CGEPRI are the unsmoothed split of ISCED 0 and 1
* and need not add up to CGEPP (compilation1 reads neither).
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
* Downloads two Eurostat tables if the global $download is set to "1":
*   educ_enrl1tl    - ISCED 1997 enrollment (used up to 2012)
*   educ_uoe_enra02 - ISCED 2011 enrollment (used from 2013)

if "$download"=="1" {
    * In Stata's temp folder, outside Dropbox: eurostatuse erases its working
    * file at the end, which fails while Dropbox holds it
    * Until 2012
    cd "`c(tmpdir)'"
    eurostatuse educ_enrl1tl, noflags clear
    cd "$wkdir"
    save ENTA_input_data/Original_input_data/educ_enrl1tl, replace

    * From 2013
    cd "`c(tmpdir)'"
    eurostatuse educ_uoe_enra02, noflags clear
    cd "$wkdir"
    save ENTA_input_data/Original_input_data/educ_uoe_enra02, replace
}


********************************************************************************
* 1. Source data
********************************************************************************
* Loads ISCED 1997 (2008-2012) and ISCED 2011 (2013-latest) enrollment data,
* appends them, harmonises variable names (N = students, isced = level code,
* src = ISCED vintage), creates education-level groups (PRE, PRI, PP, SEC,
* PSEC, TER), and parses age codes into numeric bounds (alo, ahi).

local fyear = 2008 // first year
local lyear = 2024 // latest year

************************************************************
* ISCED 1997 (educ_enrl1tl), until 2012
************************************************************

* Reshape from wide (one column per year) to long; keep 2008-2012
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

* Same reshape for the ISCED 2011 table; append the 1997 data
use ENTA_input_data/Original_input_data/educ_uoe_enra02, clear
keep geo sex age isced11 educ_uoe_enra022013-educ_uoe_enra02`lyear'
reshape long educ_uoe_enra02, i(geo sex age isced11) j(YEAR)
rename (educ_uoe_enra02 isced11) (N isced)
gen src = 2011
append using `i97'

* Drop country-source-years with no data at all
bysort src geo YEAR: egen nyear = count(N)
drop if nyear == 0
drop nyear

* Country code, numeric sex (0=total, 1=male, 2=female)
rename geo CNT2
gen SEX = 0 if sex=="T"
replace SEX = 1 if sex=="M"
replace SEX = 2 if sex=="F"
drop sex

************************************************************
* Education levels
************************************************************

* Map ISCED codes to six level groups used downstream:
*   PRE  = ISCED 0 (pre-primary)
*   PRI  = ISCED 1 (primary)
*   PP   = ISCED 0+1 (pre-primary + primary, created by duplicating PRE/PRI)
*   SEC  = ISCED 2+3 (secondary)
*   PSEC = ISCED 4 (post-secondary non-tertiary)
*   TER  = ISCED 5-8 (2011) or 5-6 (1997) (tertiary)
gen lev = ""
replace lev = "PRE"  if isced=="ED0"
replace lev = "PRI"  if isced=="ED1"
replace lev = "SEC"  if inlist(isced, "ED2", "ED3")
replace lev = "PSEC" if isced=="ED4"
replace lev = "TER"  if (src==2011 & inlist(isced, "ED5", "ED6", "ED7", "ED8")) | (src==1997 & isced=="ED5_6")
keep if lev!=""
* PRE and PRI rows are duplicated; the copy becomes PP (ISCED 0+1)
expand 2 if inlist(lev, "PRE", "PRI"), gen(dup)
replace lev = "PP" if dup
drop dup

* Collapse ISCED sub-levels within each group (e.g. ED2+ED3 -> SEC)
* All-missing groups stay missing (not zero)
collapse (sum) N (count) nN=N, by(src CNT2 YEAR SEX lev age)
replace N = . if nN == 0
drop nN

* Fix: France 2010-2011 age 29 wrongly assigned (use 25-29 group instead)
replace N = . if CNT2=="FR" & inlist(YEAR, 2010, 2011) & age=="Y29" & inlist(lev, "SEC", "PSEC", "TER")

************************************************************
* Age groups
************************************************************

* Parse Eurostat age codes into numeric lower (alo) and upper (ahi) bounds.
*   "Y25"       -> alo=25, ahi=25  (single year)
*   "Y20-24"    -> alo=20, ahi=24  (5-year band)
*   "Y_LT2"     -> alo=0,  ahi=1   (under 2)
*   "Y_LT3"     -> alo=0,  ahi=2   (under 3)
*   "Y_GE65"    -> alo=65, ahi=80  (open-ended, capped at 80)
*   "TOTAL","UNK"-> alo=.,  ahi=.   (left missing)
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
* Ensures every cell has consistent total, male and female counts.
* Fallback hierarchy for the male share:
*   1. own cell (N1 and N2 both reported)
*   2. nearest year with a sex split (same country, level, age)
*   3. population sex composition of the same age range
* After imputation, sexes are rescaled so N1 + N2 = N0 exactly.

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

* Build population sex shares by age range (fallback source)
* Load single-year population by sex, reshape wide (POP1=male, POP2=female)
preserve
use ENTA_input_data/ENTA_input_datasets/population80 if SEX>0, clear
reshape wide POP, i(CNT2 YEAR AGE) j(SEX)
tempfile pop12
save `pop12'
restore

* For TOTAL/UNK ages (alo/ahi missing), default to full 0-80 range
gen plo = cond(alo<., alo, 0)
gen phi = cond(ahi<., ahi, 80)

* Expand each age band to single years, merge population, collapse back
* to get male+female population totals within each age range
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

* Reshape main data wide by sex: N0=total, N1=male, N2=female
reshape wide N, i(src CNT2 YEAR lev age) j(SEX)
merge m:1 CNT2 YEAR plo phi using `rangepop', keep(master match) nogen

* Step 1: one sex missing -> set to 0
replace N1 = 0 if N1==. & N2<.
replace N2 = 0 if N2==. & N1<.

* Step 2: total missing -> men + women (flag: ctot)
gen byte ctot = N0==. & N1<. & N1 + N2 > 0
replace N0 = N1 + N2 if ctot

* Step 3: male share from own cell
gen double shm = N1 / (N1 + N2) if N1 + N2 > 0 & N1<.

* Step 4: nearest-year share (forward and backward fill)
* Forward fill (earlier years)
gen double shp = shm
gen yp = YEAR if shm<.
bysort CNT2 lev age (YEAR): replace shp = shp[_n-1] if shp==.
by CNT2 lev age: replace yp = yp[_n-1] if yp==.
* Backward fill (later years)
gen double shn = shm
gen yn = YEAR if shm<.
gen negYEAR = -YEAR
bysort CNT2 lev age (negYEAR): replace shn = shn[_n-1] if shn==.
by CNT2 lev age: replace yn = yn[_n-1] if yn==.

* Step 5: pick best available share (flags: csplit, cpop)
gen double sh = shm
gen byte csplit = sh==. & N0>0 & N0<.
* Only forward or only backward available
replace sh = shp if csplit & shp<. & shn==.
replace sh = shn if csplit & shn<. & shp==.
* Both available: pick closer year; average if equidistant
replace sh = cond(YEAR-yp < yn-YEAR, shp, cond(YEAR-yp > yn-YEAR, shn, (shp + shn)/2)) if csplit & shp<. & shn<.
* Last resort: population sex share
gen byte cpop = csplit & sh==.
replace sh = POP1 / (POP1 + POP2) if cpop & POP1 + POP2 > 0

* Step 6: rescale sexes to match total
* Applied to all cells with a total and a share, not only to the imputed
* ones, so that men + women = total holds exactly everywhere
gen byte cscale = !csplit & N0<. & N1<. & abs(N1 + N2 - N0) > 2
replace N1 = N0 * sh if N0<. & sh<.
replace N2 = N0 * (1 - sh) if N0<. & sh<.

* Diagnostics (the 26 ENTA countries only)
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

* Clean up and reshape back to long (one row per sex)
keep src CNT2 YEAR lev age alo ahi single band5 eu N0 N1 N2
reshape long N, i(src CNT2 YEAR lev age) j(SEX)


********************************************************************************
* 3. Single years of age
********************************************************************************
* Distributes multi-year age groups to single years of age using a reference
* age profile (enrollment rate x population). Handles open-ended groups,
* evenly-spread data artefacts, unknown-age students and year jumps.

************************************************************
* Population
************************************************************

* Load single-year population for later use as weights
preserve
use ENTA_input_data/ENTA_input_datasets/population80, clear
tempfile pop
save `pop'
restore

************************************************************
* Choice of age groups
************************************************************

* Decide which source rows to use (use=1) and how far each row's students
* are spread (blo-bhi). Decisions based on total (SEX==0), applied to both
* sexes.
* - single years, Y_LT2, Y_LT3, open groups: always used
* - 5-year groups overlapping single years (ISCED 1997 ages 15-34, ISCED
*   2011 ages 20-49): prefer single years if all five reported, else use
*   the 5-year group
* - if both reported and differ by > max(10, 1%): scale singles to the
*   5-year total (e.g. HR 2010 tertiary 25-29)
* - Slovenia ISCED 1997 ISCED 1-4 ages 20-29: always use the 5-year group
*   (single years hold the whole group at one age)
gen r5 = .
replace r5 = floor(alo/5)*5 if (single | band5) & src==1997 & inrange(alo, 15, 34)
replace r5 = floor(alo/5)*5 if (single | band5) & src==2011 & inrange(alo, 20, 49)

* Count and sum single-year cells within each 5-year group (SEX==0 only)
bysort CNT2 YEAR lev r5: egen nS = count(cond(SEX==0 & single & r5<., N, .))
by CNT2 YEAR lev r5: egen double sumS = total(cond(SEX==0 & single & r5<., N, .))
by CNT2 YEAR lev r5: egen posS = total(SEX==0 & single & r5<. & N>0 & N<.)
by CNT2 YEAR lev r5: egen firstpos = max(SEX==0 & single & alo==r5 & r5<. & N>0 & N<.)
by CNT2 YEAR lev r5: egen double B = max(cond(SEX==0 & band5 & r5<., N, .))

* Default: use single years, LT and GE groups
gen byte use = single | inlist(age, "Y_LT2", "Y_LT3") | substr(age, 1, 4)=="Y_GE"
replace use = 1 if band5 & r5==.
gen blo = alo
gen bhi = ahi

* Switch to the 5-year group if not all five singles are reported, or for
* Slovenia exception
gen byte full = nS==5
gen byte si5 = src==1997 & CNT2=="SI" & inlist(lev, "PRI", "SEC", "PSEC") & inlist(r5, 20, 25) & B<.
replace use = 0 if single & r5<. & ((!full & B<.) | si5)
replace use = 1 if band5 & r5<. & ((!full & B<.) | si5)
* Scale: singles sum differs from 5-year group by > max(10, 1%)
gen byte scale = full & !si5 & B>0 & B<. & abs(B - sumS) > max(10, 0.01*B) & r5<.

* Lumps: all students of a 5-year group at its first age, the other four
* ages 0 or missing (IT 2013 ISCED 1-3, RO 2013-2021 at ages 30, 35, 40,
* ...): widen the first single year to cover the full 5-year band
gen byte lump = src==2011 & posS==1 & firstpos & sumS>=100 & (B==. | B==0 | abs(B - sumS)<=1) & r5<.
replace scale = 0 if lump
replace use = 1 if single & lump & alo==r5
replace use = 0 if band5 & lump
replace bhi = alo + 4 if single & lump & alo==r5

* France 2020 ISCED 2-3: single age 30 actually holds 30+
replace bhi = 80 if CNT2=="FR" & YEAR==2020 & lev=="SEC" & age=="Y30"

************************************************************
* Open and evenly spread age groups
************************************************************

* Open-ended groups in ISCED 1997
* A 5-year group is treated as open-ended (bhi=80) when no older group
* exists. Detected where TOTAL minus parts about  0.
bysort CNT2 YEAR lev: egen double B30 = max(cond(SEX==0 & age=="Y30-34", N, .))
by CNT2 YEAR lev: egen double B35 = max(cond(SEX==0 & age=="Y35-39", N, .))
by CNT2 YEAR lev: egen double G40 = max(cond(SEX==0 & age=="Y_GE40", N, .))
gen byte open = 0
replace open = 35 if src==1997 & age=="Y35-39" & B35>0 & B35<. & G40==.
replace open = 30 if src==1997 & age=="Y30-34" & use & B30>0 & B30<. & B35==. & G40==.

* Croatia tertiary ISCED 1997: Y35-39 + Y_GE40 combined = 35+
bysort CNT2 YEAR lev SEX: egen double g40s = max(cond(age=="Y_GE40", N, .))
gen byte hr35 = src==1997 & CNT2=="HR" & lev=="TER"
replace N = cond(N<., N, 0) + g40s if hr35 & age=="Y35-39" & g40s<.
replace use = 0 if hr35 & age=="Y_GE40"
replace open = 35 if hr35 & age=="Y35-39"
drop g40s hr35

* Romania ISCED 2-4 special cases
* ISCED 1997: single age 21 holds 21+ (ages 22+ unreported)
* 2013: single age 24 holds 24+
bysort CNT2 YEAR lev: egen n2224 = count(cond(SEX==0 & inlist(age, "Y22", "Y23", "Y24"), N, .))
gen byte ro21 = src==1997 & CNT2=="RO" & inlist(lev, "SEC", "PSEC") & n2224==0
replace use = 1 if ro21 & inlist(age, "Y20", "Y21") & N<.
replace use = 0 if ro21 & age=="Y20-24"
replace open = 21 if ro21 & age=="Y21"
replace open = 24 if CNT2=="RO" & YEAR==2013 & inlist(lev, "SEC", "PSEC") & age=="Y24"
drop n2224 ro21
replace bhi = 80 if open

* Greece tertiary 2010-2013: single age 29 holds 29+
replace open = 29 if CNT2=="EL" & lev=="TER" & inrange(YEAR, 2010, 2013) & age=="Y29"
replace bhi = 80 if open==29

* Evenly spread age groups in ISCED 2011
* Some countries' source data spreads students equally across ages within
* a segment (FR, PL, EL, IE, HU, SI 2013+). Detected as identical values
* (min==max, >=20) across all ages in a segment. Consecutive flagged
* segments are merged and redistributed with the reference profile.
foreach s in 30 35 40 {
    local e = cond(`s'==40, 49, `s' + 4)
    local n = `e' - `s' + 1
    bysort CNT2 YEAR lev: egen double mn = min(cond(SEX==0 & single & inrange(alo, `s', `e'), N, .))
    by CNT2 YEAR lev: egen double mx = max(cond(SEX==0 & single & inrange(alo, `s', `e'), N, .))
    by CNT2 YEAR lev: egen ct = count(cond(SEX==0 & single & inrange(alo, `s', `e'), N, .))
    gen byte f`s' = src==2011 & ct==`n' & mn==mx & mn>=20
    drop mn mx ct
}
* 40-44 = 45-49 also counts as evenly spread
bysort CNT2 YEAR lev: egen double b40 = max(cond(SEX==0 & age=="Y40-44", N, .))
by CNT2 YEAR lev: egen double b45 = max(cond(SEX==0 & age=="Y45-49", N, .))
replace f40 = 1 if src==2011 & b40==b45 & b40>=20 & b40<.
* 5-year bands 50-54 = 55-59 = 60-64
by CNT2 YEAR lev: egen double mn = min(cond(SEX==0 & inlist(age, "Y50-54", "Y55-59", "Y60-64"), N, .))
by CNT2 YEAR lev: egen double mx = max(cond(SEX==0 & inlist(age, "Y50-54", "Y55-59", "Y60-64"), N, .))
by CNT2 YEAR lev: egen ct = count(cond(SEX==0 & inlist(age, "Y50-54", "Y55-59", "Y60-64"), N, .))
gen byte f50 = src==2011 & ct==3 & mn==mx & mn>=20
drop mn mx ct b40 b45

* Merge consecutive flagged segments: compute start (blo) and end (bhi) of
* the combined evenly-spread block
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

* Students of unknown age (UNK) that are known to be adults are
* redistributed over the indicated age range using the reference profile.
* Otherwise UNK students are implicitly spread like the known-age students.
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

* Flag country-year-level combinations where the age distribution is
* unreliable (jfrom = first age to replace from neighbouring years).
* Criteria:
*   - age groups sum to < 50% of TOTAL (>=1,000)
*   - students 55+ (or 50+) below 10% of nearest clean year
*   - country-specific known issues (IE 2018, BE 2015, NL, EL, BG, IT)
bysort CNT2 YEAR lev: egen double tot = max(cond(SEX==0 & age=="TOTAL", N, .))
by CNT2 YEAR lev: egen double sumuse = total(cond(SEX==0 & use, N, .))
by CNT2 YEAR lev: egen double o55 = total(cond(SEX==0 & inlist(age, "Y55-59", "Y60-64", "Y_GE65"), N, .))
by CNT2 YEAR lev: egen double o50 = total(cond(SEX==0 & age=="Y50-54", N, .))
egen byte tagy = tag(CNT2 YEAR lev)

* Nearest earlier and later year with 55+ >= 500
gen double op = o55 if tagy & src==2011 & o55>=500
gen double on = op
bysort CNT2 lev tagy (YEAR): replace op = op[_n-1] if op==.
gen negYEAR = -YEAR
bysort CNT2 lev tagy (negYEAR): replace on = on[_n-1] if on==.
* Current 55+ < 10% of min(earlier, later) -> jump
gen byte z55 = tagy & src==2011 & !(CNT2=="RO" & inlist(lev, "SEC", "PSEC") & inrange(YEAR, 2013, 2021)) & ///
    ((op<. & on<. & o55 < 0.1*min(op, on)) | (op<. & on==. & o55 < 0.1*op) | (op==. & on<. & o55 < 0.1*on))
bysort CNT2 YEAR lev: egen byte zz55 = max(z55)

gen jfrom = .
replace jfrom = 0 if sumuse < 0.5*tot & tot>=1000 & tot<.
replace jfrom = min(jfrom, cond(o50==0, 50, 55)) if zz55 & !(CNT2=="FR" & YEAR==2020 & lev=="SEC")
drop op on negYEAR z55 zz55
* Country-specific overrides
replace jfrom = min(jfrom, 20) if CNT2=="IE" & YEAR==2018 & lev=="SEC"
replace jfrom = min(jfrom, 65) if CNT2=="BE" & YEAR==2015 & lev=="SEC"
replace jfrom = min(jfrom, 25) if CNT2=="NL" & lev=="TER" & (inrange(YEAR, 2008, 2010) | inrange(YEAR, 2013, 2014))
replace jfrom = min(jfrom, 20) if CNT2=="EL" & YEAR==2014 & lev=="TER"
replace jfrom = min(jfrom, 50) if CNT2=="BG" & inrange(YEAR, 2013, 2014)
* Italy 2013-2015 tertiary: almost no students aged 18 and 19, more at ages
* 22-29 and more of unknown age than in the years before and after
replace jfrom = min(jfrom, 18) if CNT2=="IT" & inrange(YEAR, 2013, 2015) & lev=="TER"


************************************************************
* Reference age profile 2015-2017
************************************************************

* Build a reference enrollment rate by country x level x sex x age,
* averaged over (up to) three clean ISCED 2011 years near 2015-2017.
* Years with evenly-spread groups, lumps or year jumps are excluded;
* nearest clean years substituted (at most 3).
gen dref = abs(YEAR - 2016)*10 - (YEAR > 2016) if tagy & src==2011 & !even & !anylump & jfrom==. & ///
    !(CNT2=="RO" & inlist(lev, "SEC", "PSEC") & inrange(YEAR, 2013, 2021))
bysort CNT2 lev tagy (dref): gen rk = _n if dref<.
bysort CNT2 YEAR lev: egen byte refyear = max(rk<=3 & rk<.)
drop dref rk

* Diagnostic: list EU countries whose reference years differ from 2015-2017
preserve
keep if tagy & refyear & eu
bysort CNT2 lev (YEAR): gen str20 ry = string(YEAR) if _n==1
by CNT2 lev: replace ry = ry[_n-1] + " " + string(YEAR) if _n>1
by CNT2 lev: keep if _n==_N
di as text _n "Reference years other than 2015-2017 (EU):"
list CNT2 lev ry if ry!="2015 2016 2017", noobs clean
restore

* Compute the reference: expand used rows to single years, merge
* population to get students per person, average across reference years
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
* EU average as fallback where a country has no clean reference
keep if eu
collapse (mean) rateEU=rate, by(lev SEX AGE)
tempfile refeu
save `refeu'
restore

* Diagnostic: list EU cases with even spreads, lumps, open groups or jumps
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

* Each used row is spread over blo-bhi in proportion to
*   reference rate x population
* Fallback 1: EU-average reference if country reference is 0 over the range
* Fallback 2: population alone if EU average is also 0

* Scale single years to their 5-year group total where flagged
bysort CNT2 YEAR SEX lev r5: egen double sS = total(cond(single, N, .)) if r5<.
by CNT2 YEAR SEX lev r5: egen double bS = max(cond(band5, N, .)) if r5<.
bysort CNT2 YEAR lev r5: egen byte scaleg = max(scale)
replace N = N * bS / sS if scaleg & single & sS>0 & bS<.

* Save year-jump flags for later
preserve
keep if tagy
keep CNT2 YEAR lev jfrom
tempfile jumps
save `jumps'
restore

* Expand each used row to single years, merge reference rate and population,
* distribute students proportionally
keep if use & SEX>0 & N<.
keep CNT2 YEAR SEX lev age blo bhi N eu
gen long id = _n
expand bhi - blo + 1
bysort id: gen AGE = blo + _n - 1
merge m:1 CNT2 YEAR SEX AGE using `pop', keep(match) nogen
merge m:1 CNT2 lev SEX AGE using `ref', keep(master match) nogen keepusing(rate)
merge m:1 lev SEX AGE using `refeu', keep(master match) nogen
* Weight = rate x population; fallbacks if sum of weights is 0
gen double w = rate * POP
replace w = 0 if w==.
gen double w2 = rateEU * POP
replace w2 = 0 if w2==.
bysort id: egen double W = total(w)
by id: egen double W2 = total(w2)
by id: egen double WP = total(POP)
gen double Na = cond(W>0, N * w / W, cond(W2>0, N * w2 / W2, N * POP / WP))

* Diagnostic: list groups that fell back to EU average or population
preserve
keep if W==0 & bhi>blo & N>0 & eu
gen byte poponly = W2==0
collapse (sum) N=Na (max) poponly, by(CNT2 YEAR lev age blo bhi)
di as text _n "Age groups without a country reference (EU average profile; poponly = population), EU, 2+ ages, SEX 1+2:"
list CNT2 YEAR lev age blo bhi N, noobs clean sepby(CNT2)
restore

* Collapse back to single-year level
collapse (sum) N=Na (mean) POP, by(CNT2 YEAR SEX lev AGE)

************************************************************
* Replace year jumps with values from neighbouring years
************************************************************

* For ages flagged by jfrom, replace students per person with the mean of
* the nearest earlier and later non-jump year (same country, level, sex,
* age). Two passes:
*   Pass 1: the systematic jumps identified above
*   Pass 2: isolated one-year spikes/dips left after pass 1 (students per
*           person at ages 30-49 or 50+ more than 2x or less than 0.5x both
*           neighbours, with >=500 students)

* Add rows for jump-year ages that were missing entirely
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
        * Pass 2: detect isolated spikes/dips in broad age groups
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
        gen double rel_before = r / rm
        gen double rel_after = r / rf
        di as text _n "Pass 2, isolated one-year spikes and dips (EU):"
        list CNT2 YEAR lev g G rel_before rel_after if eu, noobs clean
        * Handle empty result (no spikes found)
        if _N>0 {
            collapse (min) jfrom=g, by(CNT2 YEAR lev)
        }
        else {
            keep CNT2 YEAR lev g
            rename g jfrom
        }
        tempfile spikes
        save `spikes'
        restore
        merge m:1 CNT2 YEAR lev using `spikes', keep(master match) nogen
    }

    * Replace jump ages with interpolated rates from neighbours
    gen byte jump = AGE>=jfrom & jfrom<.
    gen double rate = N / POP
    * Forward fill (nearest earlier clean year)
    gen double rp = rate if !jump
    bysort CNT2 lev SEX AGE (YEAR): replace rp = rp[_n-1] if jump
    * Backward fill (nearest later clean year)
    gen double rn = rate if !jump
    gen negYEAR = -YEAR
    bysort CNT2 lev SEX AGE (negYEAR): replace rn = rn[_n-1] if jump
    * Mean of both; one if only one available
    gen double rj = (rp + rn)/2
    replace rj = rp if rj==.
    replace rj = rn if rj==.
    replace N = rj * POP if jump & rj<.
    * Diagnostic: list jump cells with no neighbour at all
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

* Reshape so each level becomes a column (CGEPRE, CGEPRI, CGEPP, etc.)
keep CNT2 YEAR SEX AGE lev N
replace lev = "CGE" + lev
reshape wide N, i(CNT2 YEAR SEX AGE) j(lev) string
rename N* *

* Ensure all ages 0-80 exist for every country-year in the data span
* (EL 2009 has no source data and is imputed below)
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

* Set remaining missing values to 0; ages below 3 are not pre-primary
* under the ISCED 1997 expenditure classification (COFOG)
foreach var in CGEPRE CGEPRI CGESEC CGEPSEC CGETER CGEPP {
    replace `var' = 0 if `var' == .
    replace `var' = 0 if AGE<3
}

************************************************************
* Greece 2009: impute from 2008 and 2010
************************************************************

* Eurostat has no data at all for EL 2009. Impute as mean of 2008 and
* 2010 enrollment rates x 2009 population.
foreach var in CGEPRE CGEPRI CGEPP CGESEC CGEPSEC CGETER {
    bys CNT2 SEX AGE: egen `var'EL09 = mean(cond(inlist(YEAR, 2008, 2010), `var'/POP, .)) if CNT2=="EL"
    replace `var' = `var'EL09*POP if CNT2=="EL" & YEAR==2009
    drop `var'EL09
}

************************************************************
* Replace missing or implausible values with values from other years
************************************************************

* For specific country-year-age problems, store a reference enrollment
* rate from a clean year, then apply it to the affected years.

* Variables to hold reference enrollment rates
gen CGEPPi = .
gen CGETERi = .
gen CGESECi = .

* Pre-primary and primary
* Denmark 2008-2009: some age-5 students missing
replace CGEPPi = CGEPP/POP if YEAR==2011 & CNT2=="DK"
* Greece 2018 and 2020+: pre-primary missing
replace CGEPPi = CGEPP/POP if YEAR==2019 & CNT2=="EL"
* Hungary 2013: pre-primary missing
replace CGEPPi = CGEPP/POP if YEAR==2014 & CNT2=="HU"

* Poland 2020+: primary/secondary boundary shift
replace CGEPPi = CGEPP/POP if YEAR==2018 & CNT2=="PL"
replace CGESECi = CGESEC/POP if YEAR==2018 & CNT2=="PL"

* Ireland post-secondary: kept as reported (ISCED 4->3 shift in 2017-2018
* cancels in CGES = CGESEC + CGEPSEC; imputing ISCED 4 caused a level shift)

* Ireland 2011 ages 12-13: no secondary students; use 2012 rates
replace CGEPPi = CGEPP/POP if YEAR==2012 & CNT2=="IE"
replace CGESECi = CGESEC/POP if YEAR==2012 & CNT2=="IE"

* Tertiary
* Luxembourg before 2011: no tertiary education reported
replace CGETERi = CGETER/POP if YEAR==2011 & CNT2=="LU"

* Collapse to country x sex x age averages (the reference rates)
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

* Apply reference rates to affected country-years
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

* Create SEX==0 (total) as the sum of male and female
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

* Total enrollment rate = all levels / population
gen ENRR = (CGEPP + CGESEC + CGEPSEC + CGETER)/POP

* Cap at 1; force to 1 for compulsory-school ages in selected countries
replace ENRR = 1 if ENRR>1
replace ENRR = 1 if AGE >= 6 & AGE < 17 & ///
    (inlist(CNT2, "FR", "HR", "IE", "SK", "BE", "BG", "CZ") | ///
    inlist(CNT2, "DK", "EE", "LV", "SI", "PL"))

************************************************************
* Into wide format by sex
************************************************************

* Reshape to one row per CNT2 x YEAR x AGE with suffixes m/f and no
* suffix for total.
local vars "ENRR CGEPRE CGEPRI CGEPP CGESEC CGEPSEC CGETER POP"

* Total (SEX==0)
preserve
keep if SEX == 0
keep `vars' CNT2 YEAR AGE
sort CNT2 YEAR AGE
tempfile tot
save `tot', replace
restore

* Men (SEX==1)
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

* Women (SEX==2)
keep if SEX == 2
keep `vars' CNT2 YEAR AGE
foreach var of local vars {
    rename `var' `var'f
}

sort CNT2 YEAR AGE
merge 1:1 CNT2 YEAR AGE using `tot', nogenerate

sort CNT2 YEAR AGE
merge 1:1 CNT2 YEAR AGE using `men', nogenerate

* line ENRR AGE if YEAR==2013 & CNT2=="PL"


********************************************************************************
* 6. Smooth the enrollment rate
********************************************************************************
* Applies the user-written supsmooth (Friedman's super smoother, bandwidth
* chosen by cross-validation) to ENRR by age, separately for total, male
* and female, for each country and year. Three country groups with different
* age ranges to smooth over:
*   Age 20+: AT BE DE SK EL IE IT LV NL PL RO SI
*   Age 25+: DK FI SE (higher adult enrollment, smoother already at 20-24)
*   Age 6-17: EE SK HU RO (noisy compulsory-school-age enrollment)

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
* Scale CGEPP, CGESEC, CGEPSEC, CGETER so their sum matches the smoothed ENRR
* x population. Split each level to male/female using pre-smoothing sex shares
* (population shares as fallback when both sexes are 0). This guarantees
* men + women = total for every level.

* Total students implied by the smoothed ENRR
gen CGEsm = ENRR*POP
* Total students before smoothing
gen CGEest = CGEPP + CGESEC + CGEPSEC + CGETER

* Scale each level proportionally; split to sexes
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

* Verification: recompute ENRR from scaled levels (should equal smoothed)
gen ENRRc = (CGEPP + CGESEC + CGEPSEC + CGETER) / POP
* browse ENRR ENRRc

* Make male and female enrollment rates consistent with the total
* (adjustgender defined in ENTA_setup.do)
adjustgender ENRR

* Compute total CGE by sex
gen CGE = CGEPP + CGESEC + CGEPSEC + CGETER
gen CGEm = CGEPPm + CGESECm + CGEPSECm + CGETERm
gen CGEf = CGEPPf + CGESECf + CGEPSECf + CGETERf

* line CGE CGEPP CGESEC CGEPSEC CGETER AGE if CNT2=="IE" & YEAR==2013
* line CGEf CGEPPf CGESECf CGEPSECf CGETERf AGE if CNT2=="PL" & YEAR==2012

* Save final dataset
sort CNT2 YEAR AGE
save ENTA_input_data/ENTA_input_datasets/enrollment, replace


/*
********************************************************************************
* 8. Plot the data [INACTIVE]
********************************************************************************
* Diagnostic line plots of any variable by age, one line per year (2008-2023),
* colour-coded from yellow (early) to blue (late). Adjust `var' and `cnt'.

  use ENTA_input_data/ENTA_input_datasets/enrollment, clear

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
