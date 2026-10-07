* Generate ENTA aggregate data

* Purpose: Prepares the ESA 2010 non-financial sector accounts for use in ENTA

* Input:
* ENTA_input_data/Original_input_data/nasa_10_nf_tr.dta - Eurostat
*   non-financial sector accounts (ESA 2010), downloaded when global
*   download is 1
* ENTA_input_data/ENTA_input_datasets/taxstructure_wide.dta - tax structure
*   by economic function (Suppl_tax_structure.do, which must run first)
* Calls ENTA_input_data/Aggr_ESA2010_allocate_transfers_to_sectors.do (B.4)
*   and ENTA_input_data/Prog_gen_country_name_from_CNT2.do (D)

* Output
* ENTA_input_data/ENTA_input_datasets/esa_aggregates.dta - aggregate data
*   for each country, year and sector. Read by
*   ENTA_aggregates/ENTA_aggregates_compilation.do and
*   ENTA_input_data/Suppl_consumption_hh_coicop.do (C, which is why that
*   file runs after this one)


********************************************************************************
* Content:

* A. Prepare data
* A.0 Helpful programs and tools
* A.1 Download data
* A.2 Change structure of the data: ESA quantities as variables, different years as observation

* B. Adjustments of data for ENTA
* B.0 Define sectors
* B.1 Replace missing with zero; only if variable is not missing alltogether
* B.2 Assign the taxes on products to households, public sector and NPISH
* B.3 Country-specific patches to the source data (CY, DK)
* B.4 Sectorize transfers (distinguish transfers by paying and receiving sectors)

* C. Prepare ENTA Variables: Sequence of accounts
* C.0 Production
* C.1 Primary distribution of income
* C.2 Taxes and social contributions (Secondary distribution of income)
* Taxes on production
* Payroll taxes paid by employer (TTYER)
* Income taxes D51 and social contributions D61
* Wealth taxes D59
* Other transfers (NL-insurance premia D71, claims D72, miscellaneous D75)
* Indirect taxes
* C.3 Benefits (Secondary distribution of income)
* C.4 Disposable income
* Adjustment of private transfers
* C.5 Use of income

* D. Save the data
********************************************************************************

********************************************************************************
* A. Prepare data
********************************************************************************

************************************************************
* A.0 Helpful programs and tools
************************************************************

* Programme for summing a variable in a country and a given year
capture program drop sumtotal
program define sumtotal
    syntax varlist
    foreach var of local varlist {
        tempvar tmp
        gen `tmp' = `var'
        drop `var'
        bysort geo YEAR: egen `var' = total(`tmp')
    }
end

* Programme for generating total economy values as sum of sector values
capture program drop sumtotalS1
program define sumtotalS1
    syntax varlist
    foreach var of local varlist {
        tempvar tmp tmpt
        gen `tmp' = `var' if inlist(sector, "S11", "S12", "S13", "S14_S15")
        bysort geo YEAR: egen `tmpt' = total(`tmp')
        replace `var'=`tmpt' if sector=="S1" & (`var'==. | `var'==0)
    }
end


* Programme for replacing missing values for subsectors with zero if variable is not missing alltogether
capture program drop replmiss
program define replmiss
    syntax varlist
    foreach var of local varlist {
        tempvar nonmiss
        bysort geo YEAR: egen `nonmiss' = total(`var'), missing
        replace `var' = 0 if `var' == . & `nonmiss' != .
    }
end

* Programme for redistributing quantities for corporations in total to subsectors S11 and S12
capture program drop corpdist
program define corpdist
    args var dvar
    tempvar dS11 dS12 dcor dtotcor dtotS11 dtotS12
    gen `dS11' = `dvar' if sector == "S11"
    gen `dS12' = `dvar' if sector == "S12"
    gen `dcor' = `dvar' if inlist(sector, "S11", "S12")
    bysort geo YEAR: egen `dtotcor' = total(`dcor')
    bysort geo YEAR: egen `dtotS11' = total(`dS11')
    bysort geo YEAR: egen `dtotS12' = total(`dS12')
    replace `var' = `var' * `dtotS11' / `dtotcor' if sector == "S11" & `dtotcor' != 0
    replace `var' = `var' * `dtotS12' / `dtotcor' if sector == "S12" & `dtotcor' != 0
end


************************************************************
* A.1 Download data
************************************************************

* ESA items used. `global indic' is the list the download filters on, A.2
* keeps and the rest of the file loops over, so the codes are named in one
* place only.
*
*   B1G    Value added, gross              B1GQ   Gross domestic product
*   B1N    Value added, net                B1NQ   Net domestic product
*   B2A3G  Operating surplus and mixed income, gross
*   B2A3N  Operating surplus and mixed income, net
*   B2G    Operating surplus, gross        B3G    Mixed income, gross
*   B5G    Balance of primary incomes, gross
*   B5N    Balance of primary incomes, net (national income)
*   B6N    Disposable income, net          B7N    Adjusted disposable income, net
*   B8G    Saving, gross                   B8N    Saving, net
*   B9     Net lending / net borrowing
*   D1     Compensation of employees       D11    Wages and salaries
*   D12    Employers' social contributions
*   D21    Taxes on products               D31    Subsidies on products
*   D29    Other taxes on production       D39    Other subsidies on production
*   D4     Property income                 D5     Current taxes on income and wealth
*   D51    Taxes on income                 D59    Other current taxes
*   D7     Other current transfers         D71    Net non-life insurance premiums
*   D72    Non-life insurance claims       D74    Current international cooperation
*   D75    Miscellaneous current transfers
*   D76    VAT- and GNI-based EU own resources
*   D61    Net social contributions        D611   Employers' actual social contributions
*   D612   Employers' imputed social contributions
*   D613   Households' actual social contributions
*   D614   Households' social contribution supplements
*   D61SC  Social insurance scheme service charges
*   D62    Social benefits other than social transfers in kind
*   D63    Social transfers in kind        D631   ... non-market production
*   D632   ... purchased market production
*   D8     Adjustment for the change in pension entitlements
*   D9     Capital transfers               D91    Capital taxes
*   P1     Total output                    P2     Intermediate consumption
*   P3     Final consumption expenditure   P31    Individual consumption expenditure
*   P32    Collective consumption expenditure
*   P51C   Consumption of fixed capital    P51G   Gross fixed capital formation
*   EMP_HW_DC  Employment, thousand hours worked
*   EMP_PS_DC  Employment, thousand persons

global indic "B1G B1GQ B1NQ B1N B2A3G B2A3N B2G B3G B5N B6N B7N B8N B8G B9 B5G D1 D11 D12 D21 D29 D31 D39 D4 D5 D51 D59 D7 D71 D72 D74 D75 D76 D61 D611 D612 D613 D614 D61SC D62 D63 D631 D632 D8 D9 D91 P1 P2 P3 P32 P31 P51C P51G EMP_HW_DC EMP_PS_DC"

if "$download"=="1" {
    * Download ESA 2010 non-financial sector accounts
    * In Stata's temp folder, outside Dropbox: eurostatuse erases its working
    * file at the end, which fails while Dropbox holds it
    cd "`c(tmpdir)'"
    * Filtered before eurostatuse converts the values: years from 1995, the
    * two units, PAID and RECV, the items in $indic. Same esa_aggregates as
    * the full table, in a fraction of the time
    eurostatuse nasa_10_nf_tr, noflags clear start(1995) keepdim("CP_MEUR CP_MNAC; PAID RECV; $indic")
    cd "$wkdir"
    save ENTA_input_data/Original_input_data/nasa_10_nf_tr, replace
}

use ENTA_input_data/Original_input_data/nasa_10_nf_tr, clear
keep if unit=="CP_MEUR" // CP_MNAC or CP_MEUR
capture drop nasa_10_nf_tr1949 - nasa_10_nf_tr1994 // only in a download without the year filter

************************************************************
* A.2 Change structure of the data: ESA quantities as variables, different years as observation
************************************************************

* Actual structure: long format with years as variables and ESA 2010 components as observation
* Desired structure: ESA 2010 components as variables; years as observation

* Keep only required indicators (global indic, defined in A.1)

gen byte _keep = 0
foreach ind of global indic {
    replace _keep = 1 if na_item=="`ind'"
}
keep if _keep==1
drop _keep

* Reshape from wide (years as variables) to long
rename nasa_10_nf_tr* NA*
reshape long NA, i(unit unit_label direct direct_label na_item na_item_label sector sector_label geo geo_label) j(YEAR)

* Clean string values and destring
capture confirm str variable NA
if !_rc {
    replace NA = "" if inlist(NA, ":", ": ", ": @N", "0 n")
    destring NA, ignore("p" "b" "e") replace force
}


* Keep only years with at least some information
bysort YEAR geo sector: egen yearmiss = count(NA) // number of non-missing values in variable NA
drop if yearmiss==0
drop yearmiss

* From long to wide regarding ESA quantities: ESA indicators from observations
* (identified by na_item and direct) to variables, one row per country, year
* and sector. `D51p' is D51 PAID, `D51r' is D51 RECEIVED.
*
* A single reshape builds the variables for all codes and sectors at once
* (the alternative, merging 2 x 55 tempfiles one by one, is 110 merges); the loop
* afterwards restores the one property the merges had for free - a variable
* exists for every code in `global indic', missing throughout where the
* source reports nothing, because the rest of the file refers to all of them.

keep if inlist(direct, "PAID", "RECV")
gen str16 nadir = na_item + cond(direct=="PAID", "p", "r")
keep unit unit_label sector sector_label geo geo_label YEAR nadir NA
reshape wide NA, i(YEAR geo sector unit unit_label sector_label geo_label) j(nadir) string
rename NA* *

foreach ind of global indic {
    foreach d in p r {
        capture confirm variable `ind'`d'
        if _rc  gen double `ind'`d' = .
    }
}

* Basic variables
gen CNT2 = geo


********************************************************************************
* B. Adjustments of data for ENTA
********************************************************************************

************************************************************
* B.0 Define sectors
************************************************************

keep if inlist(sector, "S1", "S2", "S11", "S12", "S13", "S14", "S15", "S14_S15")


************************************************************
* B.0a Fill a single missing component of other current transfers (D7)
************************************************************

* D7 = D71 + D72 + D74 + D75 + D76. Where Eurostat reports the total and all
* components but one, the missing one is the total less the others. It is
* filled only if that is more than 5 million euro, which is more than the
* rounding of the items; a smaller gap stays missing and becomes 0 in B.1.
* Done before B.1, while a missing value is still missing.
foreach d in p r {
    egen byte _nmiss = rowmiss(D71`d' D72`d' D74`d' D75`d' D76`d')
    egen double _sum = rowtotal(D71`d' D72`d' D74`d' D75`d' D76`d')
    gen double _rest = D7`d' - _sum
    foreach v in D71 D72 D74 D75 D76 {
        gen byte _fill = missing(`v'`d') & _nmiss==1 & abs(_rest)>5 & _rest<.
        replace `v'`d' = _rest if _fill
        list CNT2 YEAR sector `v'`d' if _fill, noobs
        drop _fill
    }
    drop _nmiss _sum _rest
}


************************************************************
* B.1 Replace missing with zero; only if variable is not missing alltogether
************************************************************

foreach var of global indic {
    replmiss `var'p `var'r
}
replace D8r = 0 if D8r==.
replace D8p = 0 if D8p==.


************************************************************
* B.2 Assign the taxes on products to households, public sector and NPISH
************************************************************
/*
Taxes on products are assumed to be paid via consumption; they are shared among sectors according to the consumption share.
This results mainly in a reallocation from the public sector to households: they are not regarded as primary income of S13, but as primary income of S14 which is paid to S13 as transfer
*/

* Taxes on products for total economy
* browse geo YEAR sector D21p D21r D31p D31r
gen D21pt = D21p if sector=="S1"
gen D21rt = D21r if sector=="S1"
gen D31pt = D31p if sector=="S1"
gen D31rt = D31r if sector=="S1"
sumtotal D21pt D21rt D31pt D31rt

gen TPSp = 0
replace TPSp = D21pt - D31rt if sector=="S14_S15" | sector=="S1" // high for households, because they consume the most
gen TPSr = 0
replace TPSr = D21rt - D31pt if sector=="S13" | sector=="S1" // high for public sector, because receiver of these taxes
* ROW: net taxes on products received by ROW (EU customs duties less EU
* product subsidies). Households pay them with the other product taxes;
* government passes them on to ROW (allocation file, TPS; C.4 below).
replace TPSr = D21r - D31p if sector=="S2"
gen TPS = TPSp - TPSr

************************************************************
* B.3 Country-specific patches to the source data
************************************************************

* Everything in this section repairs gaps in the Eurostat data for one
* country. Nothing here is a modelling choice; each patch is inert where the
* source reports the value. Collected in one place so the sequence of
* accounts below reads as one method.

****************************************
* Cyprus: missing D39, D72 and D75
****************************************

replace D39p = 0 if CNT2=="CY" & D39p==.
replace D39r = 0 if CNT2=="CY" & D39r==.

sum D72p if CNT2=="CY" & YEAR==2012 & sector=="S1"
replace D72p = `r(mean)' if CNT2=="CY" & YEAR==2012 & sector=="S12"

sum D72p if CNT2=="CY" & YEAR==2013 & sector=="S1"
replace D72p = `r(mean)' if CNT2=="CY" & YEAR==2013 & sector=="S12"

* CY 2012-2013: missing D75 (and S2 D72) paid.
* Eurostat reports ":" for D75 paid by S12, S13 and S2 and for D72 paid by
* S2 in 2012 and 2013; B.1 has turned them into 0. D75 received then
* exceeds D75 paid by 714 (2012) and 427 (2013), and the D75 allocation
* puts that gap on household payments (household YD and SN too low by the
* same amount). The D7 totals ARE reported for all three sectors, so the
* missing cells follow from D7 = D71 + D72 + D74 + D75 + D76:
*   S13, S12  D75 = D7 - D71 - D72 - D74 - D76
*             (S12 uses the D72p set just above)
*   S2        D75 = total D75 received - D75 paid by the other sectors
*             D72 = D7 - D71 - D74 - D75 - D76
* Result: 2012 S13 362, S12 8, S2 344 (S2 D72 53)
*         2013 S13 223, S12 9, S2 195 (S2 D72 73)
* Each cell is only replaced while it is still 0/missing, so the patch goes
* inert if Eurostat publishes the values.

egen double _D7oth = rowtotal(D71p D72p D74p D76p)
foreach s in S13 S12 {
    replace D75p = D7p - _D7oth if CNT2=="CY" & inlist(YEAR,2012,2013) & sector=="`s'" & (D75p==0 | missing(D75p))
}
drop _D7oth

foreach y in 2012 2013 {
    quietly summarize D75r if CNT2=="CY" & YEAR==`y' & inlist(sector,"S11","S12","S13","S14_S15","S2")
    local recv = r(sum)
    quietly summarize D75p if CNT2=="CY" & YEAR==`y' & inlist(sector,"S11","S12","S13","S14_S15")
    replace D75p = `recv' - r(sum) if CNT2=="CY" & YEAR==`y' & sector=="S2" & (D75p==0 | missing(D75p))
}

egen double _D7oth = rowtotal(D71p D74p D75p D76p)
replace D72p = D7p - _D7oth if CNT2=="CY" & inlist(YEAR,2012,2013) & sector=="S2" & (D72p==0 | missing(D72p))
drop _D7oth

****************************************
* Denmark: missing split of social contributions before 2005
****************************************

* D61 is reported, its components are not, so each component is given the
* share it had in 2005, per sector, for paid and for received.

local sector "S11 S12 S13 S14 S14_S15 S15"
* browse YEAR sector D611p D612p D613p D614p D61SCp if CNT2=="DK"

foreach d in p r {
    local vars "D611`d' D612`d' D613`d' D614`d' D61SC`d'"
    foreach sec of local sector {
        sum D61`d' if YEAR==2005 & sector=="`sec'" & CNT2=="DK"
        local total = `r(sum)'
        foreach var of local vars {
            sum `var' if YEAR==2005 & sector=="`sec'" & CNT2=="DK"
            replace `var' = D61`d' * `r(sum)' / `total' if YEAR<2005 & sector=="`sec'" & CNT2=="DK"
        }
    }
}

* Replace remaining missing social contribution components with zero
foreach var in D611 D612 D613 D614 D61SC {
    replace `var'r = 0 if `var'r == .
    replace `var'p = 0 if `var'p == .
}


************************************************************
* B.4 Sectorize transfers (distinguish transfers by paying and receiving sectors)
************************************************************

do "ENTA_input_data/Aggr_ESA2010_allocate_transfers_to_sectors.do"


********************************************************************************
* C. Prepare ENTA Variables: Sequence of accounts
********************************************************************************

************************************************************
* C.0 Production
************************************************************

* Total output (OUT)
* - Intermediate consumption (variable P2)
* = Value added, gross (VAG)
* + Taxes less subsidies on products
* = GDP
* - Income paid to ROW (YROW; includes compensation of employees and property income, less income received)
* - Consumption of fixed captial (CFC)
* - Taxes less subsidies on products
* = Primary income


* Check the data: value added for total economy is sum of subsectors
foreach var in B1Gp B1Gr B1Np B1Nr {
    tempvar sect sectt
    gen `sect' = `var' if inlist(sector, "S11", "S12", "S14_S15", "S13")
    bysort geo YEAR: egen `sectt' = total(`sect')
    * Brackets matter: & binds before |, so without them every sector with
    * a zero value was overwritten with the sum over sectors, not just S1.
    replace `var' = `sectt' if sector == "S1" & (`var' == . | `var' == 0)
}

* Central variables in the production account

gen OUT = P1p  // Total output incl. intermediate consumption
label var OUT "Output"

gen VAG = P1r - P2p // value added is total output less intermediate consumption (all sectors)
label var VAG "Value added, gross"

* browse CNT2 YEAR sector P1r P2p VAG B1Gr

gen CFC = P51Cp
label var CFC "Consumption of fixed capital"

gen VAN = VAG - P51Cp // net value added is gross value added less CFC
label var VAN "Value added, net"

* GDP by sectors (difference between VAG and GDP (=taxes on products) assigned to households)
gen GDP = VAG
replace GDP = VAG + TPSp if sector=="S14_S15" | sector=="S1"
label var GDP "Gross Domestic Product"


* Control if calculations above equal aggregates from ESA: value added gross, value added net, GDP
tempvar GDPt
gen `GDPt' = GDP if inlist(sector, "S11", "S12", "S14_S15", "S13")
bysort geo YEAR: egen GDPc = total(`GDPt')
* browse geo sector YEAR VAG B1GQp VAN B1Np GDPc GDP B1GQp TPSp
* order geo sector YEAR VAG B1GQp VAN B1Np GDPc GDP B1GQp
* drop GDPc

* Non-income components of GDP: consumption of fixed capital, taxes less subs on products, income to ROW

gen YROW = D1r - D1p + D4r - D4p  // Compensation of employees, property income
label var YROW "Income to ROW"
gen YEROW = D1r - D1p  // Compensation of employees
label var YEROW "Income from ROW"
gen YPROW = D4r - D4p  // Property income
label var YPROW "Property income from ROW"

* Primary income (calculated from production components)
gen Yc_prod = VAG - CFC + YROW
gen Yc1_prod = GDP - CFC + YEROW + YPROW - TPSr - TPS

* Compare primary income (ENTA) and the balance of primary income (ESA)

gen B5Nrc = Yc_prod + TPNr - TPNp if sector=="S14_S15" | sector=="S11" | sector=="S12"
replace B5Nrc = Yc_prod + TPSr + TPNr - TPNp if sector=="S13"
replace B5Nrc = Yc_prod + TPSp - TPS + TPNr - TPNp if sector=="S1"

* browse geo YEAR sector Yc_prod Yc1_prod B5Nr B5Nrc
order geo YEAR sector Yc_prod Yc1_prod B5Nr B5Nrc



************************************************************
* C.1 Primary distribution of income
************************************************************

* Types of income
* YE labour income (compensation of employees)
*   - YER employers social contributions
*   - YEE wages and salaries
* YM mixed income
* YA asset income
*   - YO operating surplus
*   - YP property income
* TPNp taxes on production (paid before primary distribution of income)

* browse geo sector YEAR D1* D11* D12* D29* D39* B2A3* B3* B2* D4* B5N* D8* if CNT2=="CY" & sector=="S12"
* compemsation of employees, other taxes on production, operating surplus (B2), mixed income (B3), property income (D4),
* balance of primary incomes (B5), adjustment for the change in pension entitlements (D8)

* 1. Compensation of employees
gen YEp = D1p
gen YE = D1r
gen YEE = D11r
label var YEE "Wages and salaries"
gen YER = D12r
label var YER "Employers' social contributions and payroll taxes"

* 2. Operating surplus & 3. mixed income

gen YOM = VAN - YEp - TPNp
label var YOM "Operating surplus and mixed income, net"
* browse geo sector YEAR YOM B2A3N*

* Calculate net mixed income and net OS, assuming that CFC are equally distributed across both
* (B2G gross operating surplus, B3G gross mixed income)

gen YO = YOM * B2Gr/(B2Gr + B3Gr) if sector=="S14_S15"
replace YO = YOM if sector=="S11" | sector=="S12" | sector=="S13" | sector=="S15"
gen YM = YOM * B3Gr/(B2Gr + B3Gr) if sector=="S14_S15"
replace YM = 0 if sector=="S11" | sector=="S12" | sector=="S13" | sector=="S15"

* Sum for total economy
sumtotalS1 YO YM


* 4. Property income
gen YP = D4r - D4p
gen YPp = D4p
gen YPr = D4r
label var YP "Property income"

* 5. Controls

* National inocome / balance of primary incomes
gen NNI =  YE + YOM + YP + TPSr + TPNr  // NNI and balance of primary for S13 includes TPSr and TPNr; NTA primary income not
* browse YO YM YOM YE YP TPSr TPNr TPNp B2A3Nr NNI B5Np sector geo YEAR // B2A3Nr = operating surplus + mixed income, B5N balance of primary income
* order sector geo YEAR NNI B5Np  // in Ireland B2A3Nr is not sum of sectors, this is why there is a difference for S1

* 6. NTA Primary income (in contrast to balance of primary incomes: includes taxes less subsidies on products paid to ROW + taxes less subsidies on production)
gen Y = YE + YO + YM + YP + TPNp // TPNp are part of primary income in NTA
label var Y "Primary income"
* browse geo YEAR sector Y Yc_prod // YE YO YM YP TPNp B2Gr B3Gr D29p D29r D39p D39r
* sort geo YEAR sector

* Adjustment for change in pension entitlements (D8)
* D8 imputes a redistribution from corporations to households: positive
* for households, negative for corporations, netting to zero across
* sectors (households +12,575 mio EUR on average, corporations -6,264,
* total economy -32, i.e. rounding plus the rest-of-world leg).
*
* It is not primary income, so it is not added to Y or YP: folding it
* into property income would leave the age profiles unable to reproduce
* YP, since compilation1 rebuilds YP as YPr - YPp.
* It is not disposable income either (ESA B6N excludes it). ENTA ignores
* D8 in all income and saving concepts; it is kept only as the bridge
*   ENTA saving + D8 = ESA net saving B8N
* D8 is very nearly TPSOCfc - BPSOCfc, the net contribution to funded
* pensions, which ENTA already carries gross in BPSOC / TPSOC.
*
* D8 is not part of GDP either (a production measure); adding it would
* make total-economy GDP differ from ESA B1GQ.

* browse YEAR geo sector Y D8r D8p
gen D8 = D8r - D8p
label var D8 "Adjustment for the change in pension entitlements"
label var YP "Property income"

* Control if componets of PI add up to total
gen Yc = YE + YOM + TPNp + YP
* browse geo YEAR sector Y Yc


************************************************************
* C.2 Taxes and social contributions (Secondary distribution of income)
************************************************************

* Types of taxes and transfers to governemnt sector
* TYT income taxes
* TYS Social contributions
*   - TYSER (employer)
*   - TYSHH (households - employees and non-employed)
* TPN taxes on production
* TA Taxes on stock of assets
* TX Other current transfers
* TCON Taxes on products
* TP private transfers
* TROW transfers to rest of the world


gen TYT = 0 // income taxes
gen TYS = 0 // social contributions
gen TYSHH = 0 // social contributions of households
gen TYSER = 0  // social contributions of employer
gen TTYERr = 0 // Total payroll taxes paid by employer (identified using data on tax structure); without social contributions
gen TTYERp = 0
gen TTYER = TTYERp - TTYERr
gen TPX = 0
gen TPXp = 0
gen TPXr = 0
* drop TPN
gen TPN = 0
gen TPSOC = 0
gen TPSOCr = 0
gen TPSOCp = 0
gen TPSOCfc = 0
gen TPSOCnfc = 0
gen TP = 0
gen TPp = 0 // private transfers (not involving g)
gen TPr = 0
gen TA = 0 // wealth taxes (taxes on assets TA)
gen TX = 0 // other current transfers
gen TROWp = 0 // Transfers to ROW
gen TROWr = 0 // Transfers from ROW


****************************************
* Taxes on production
****************************************

replace TPN = TPNp_g - TPNr_g
replace TPN = TPN - TPNr_h - TPNr_c if sec=="g"
replace TROWp = TROWp + TPNp_r

****************************************
* Payroll taxes paid by employer (TTYER)
****************************************

sort CNT2 YEAR
merge m:1 CNT2 YEAR using ENTA_input_data/ENTA_input_datasets/taxstructure_wide
drop if _merge==2
drop _merge

* TTYER is payroll taxes (not social contributions) paid by employer

replace TTYER = TYER - D611r if sector=="S13" // Taxes paid by employers minus employers social contributions
* browse CNT2 YEAR sector TYER D611r TTYER // if sector=="S13"
replace TTYER = 0 if TTYER<0
sumtotal TTYER

* Payroll taxes are distributed to sectors according to share of labour income
gen YERr = YE if sector=="S2"
gen YEHHr = YE if sector=="S14_S15"
sumtotal YERr YEHHr

replace TTYERr = TTYER * YERr / (YERr + YEHHr) if sector == "S2"
tempvar TTYERrow1
gen `TTYERrow1' = TTYERr if sector == "S2"
bysort geo YEAR: egen TTYERrow = total(`TTYERrow1')

replace TTYERr = TTYER * YEHHr / (YERr + YEHHr) if inlist(sector, "S14_S15", "S14")
tempvar TTYERhh1
gen `TTYERhh1' = TTYERr if sector == "S14_S15"
bysort geo YEAR: egen TTYERhh = total(`TTYERhh1')

* DIstribution of payroll taxes to wage earner reduce payments of employer
gen YEGOVp = YEp if sector=="S13"
gen YECORp = YEp if sector=="S11" | sector=="S12"
gen YEHHp = YEp if sector=="S14_S15"
sumtotal YEHHp YEGOVp YECORp

replace TTYERp = TTYER * YECORp / (YECORp + YEGOVp + YEHHp) if sector=="S11" | sector=="S12"
corpdist TTYERp YEp
replace TTYERp = TTYER * YEGOVp / (YECORp + YEGOVp + YEHHp) if sector=="S13"
replace TTYERp = TTYER * YEHHp / (YECORp + YEGOVp + YEHHp) if sector=="S14" | sector=="S14_S15"

* browse CNT2 YEAR sector TTYERr TTYERp TTYER TYER D611r D12r if sector=="S13" | sector=="S14_S15"

gen TTYERrc = TTYERr if sector=="S11" | sector=="S12" | sector=="S13" | sector=="S14_S15" | sector=="S2"
gen TTYERpc = TTYERp if sector=="S11" | sector=="S12" | sector=="S13" | sector=="S14_S15"
sumtotal TTYERpc TTYERrc
drop YERr YEHHr YEHHp YEGOVp YECORp

****************************************
* Income taxes D51 and social contributions D61
****************************************

replace TYT = TYT + D51p_g if sec!="g" // taxes on income and social contributions paid to g
replace TYS = TYS + D61p_g if sec!="g"
replace TYSHH = TYSHH + D613p + D614p if sec!="g"
replace TYSER = TYSER + D611p + D612p if sec!="g"
replace TYT = TYT - D51r_h - D51r_c if sec=="g" // total received by g from g, h and c, social contributions (D61 only paid by h and r)
replace TYS = TYS - D61r_h if sec=="g"

replace TROWp = TROWp + D51p_r + D61p_r
replace TROWr = TROWr + D51r_r + D61r_r
* browse YEAR geo sector TROWr TROWp

* Private transfers in form of social contributions

replace TPSOCp = TPSOCp + D61p_h + D61p_c if sec!="g" //
replace TPSOCr = TPSOCr + D61r_h if sec!="g" //

replace TPSOCnfc = TPSOCp - TPSOCr if sector=="S11" //
replace TPSOCfc = TPSOCp - TPSOCr if sector=="S12" //
bysort CNT2 YEAR: egen TPSOCnfc1 = sum(TPSOCnfc)
bysort CNT2 YEAR: egen TPSOCfc1 = sum(TPSOCfc)
replace TPSOCnfc = -TPSOCnfc1 if sector=="S14_S15"
replace TPSOCfc = -TPSOCfc1 if sector=="S14_S15"

replace TPSOC = TPSOCp - TPSOCr

****************************************
* Wealth taxes D59
****************************************

replace TA = TA + D59p_g if sec!="g"
replace TA = TA -D59r_c - D59r_h if sec=="g"

replace TROWp = TROWp + D59p_r
replace TROWr = TROWr + D59r_r
* browse YEAR CNT2 sector TROW* D59p_r D61p_r if CNT2=="RO"

****************************************
* Other transfers (NL-insurance premia D71, claims D72, miscellaneous D75)
****************************************

replace TX = TX + D71p_g + D72p_g + D75p_g - (D71r_g + D72r_g + D75r_g)
* browse geo YEAR sector TX  D71p_g D72p_g D75p_g D71r_g D72r_g D75r_g  if CNT2=="EL"

replace TX = TX + D71p_h + D71p_c - D71r_h - D71r_c  if sec=="g"
replace TX = TX + D72p_h + D72p_c - D72r_h - D72r_c  if sec=="g"
replace TX = TX + D75p_h + D75p_c - D75r_h - D75r_c  if sec=="g"

replace TPXp = TPp + D71p_h + D71p_c + D72p_h + D72p_c + D75p_h + D75p_c if sec!="g" // TPp +
replace TPXr = TPr + D71r_h + D71r_c + D72r_h + D72r_c + D75r_h + D75r_c if sec!="g" // TPr +
replace TPX = TPXp - TPXr

replace TPp = TPXp + TPSOCp
replace TPr = TPXr + TPSOCr
replace TP = TPp - TPr
* browse geo YEAR sector TP TPp TPXp TPSOCp TPp D71p_h D71p_c D72p_h D72p_c D75p_h D75p_c if CNT2=="CY"

****************************************
* Split TX into households (TXH) and NPISH (TXNPISH)
****************************************

* TX is other current transfers (D71 + D72 + D75) netted against
* government. "Households" here is the S14_S15 sector, so NPISH sit inside
* it - and NPISH are large net receivers of government funding, which is
* what makes TX negative in 392 of 501 country-years. That funding is
* institutional and has no household age pattern, so it does not belong in
* a per-capita household profile.
*
* Eurostat does not publish the D.751 / D.752 / D.759 breakdown of D75 that
* would settle this directly - checked in nasa_10_nf_tr, in gov_10a_exp
* (whose D7_S1311..S1314 are government SUBSECTORS, not transaction
* sub-items) and in the NA_ITEM code list, which carries only D75, D75REC
* and D75PAY. So the split has to be assumed.
*
* ASSUMPTION: government's D75 to S14_S15 divides between the two in
* proportion to what each actually receives, and the flow back to
* government in proportion to what each pays. Both shares come from the
* separately reported S14 and S15 margins, which sum to the S14_S15 margin
* exactly (checked: worst discrepancy 1 million EUR, i.e. rounding).

gen double D75pS14 = D75p if sector=="S14"
gen double D75pS15 = D75p if sector=="S15"
gen double D75rS14 = D75r if sector=="S14"
gen double D75rS15 = D75r if sector=="S15"
sumtotal D75pS14 D75pS15 D75rS14 D75rS15

* NPISH share of what the combined sector pays / receives
gen double shNPp = D75pS15 / (D75pS14 + D75pS15)
gen double shNPr = D75rS15 / (D75rS14 + D75rS15)
replace shNPp = 0 if (D75pS14 + D75pS15) <= 0
replace shNPr = 0 if (D75rS14 + D75rS15) <= 0

gen double TXNPISH = 0
label var TXNPISH "Other current transfers, NPISH part"
* household row: NPISH's share of what h+NPISH pay to, less receive from, government
replace TXNPISH = D75p_g*shNPp - D75r_g*shNPr if sec=="h"
* government row: the mirror, so government's own TX splits consistently
replace TXNPISH = D75p_h*shNPr - D75r_h*shNPp if sec=="g"

gen double TXH = TX - TXNPISH
label var TXH "Other current transfers, households proper (S14)"

drop D75pS14 D75pS15 D75rS14 D75rS15 shNPp shNPr

replace D76p = 0 if D76p==.
replace D76r = 0 if D76r==.
replace TROWp = TROWp + D71p_r  + D72p_r  + D74p + D75p_r + D76p + D29p_r
replace TROWr = TROWr + D71r_r  + D72r_r  + D74r + D75r_r + D76r
* browse CNT2 YEAR sector D71p_r  D72p_r  D74p D75p_r D76p D29p_r D71r_r  D72r_r D74r D75r_r D76r

* Generate values for total economy
* browse geo sector TPX TPXr TPXp TX TROWp TROWr TPSOC TPSOCp TPSOCr
replace TROWr = . if sector=="S1"
replace TROWp = . if sector=="S1"
sumtotalS1 TPX TPXr TPXp TX TROWp TROWr TPSOC TPSOCp TPSOCr


****************************************
* Indirect taxes
****************************************

gen TCON = TPSp_g - TPSr_h - TPSr_g
label var TCON "Consumption taxes"

* Test total taxes + other transfers
/*
gen Tc1 =  TPNp - TPNr + D7p - D7r + D5p - D5r + D61p - D61r
gen Tc2 =  TPN + TPp - TPr + TROWp - TROWr + TX + TYT + TA + TYS

gen Tc_diff = Tc1 - Tc2
browse geo sector YEAR Tc1 Tc2 Tc_diff D61p D61p_g D61p_h D61p_c D61p_r D61r D61r_h D61r_r
order geo sector YEAR Tc1 Tc2 Tc_diff TYT TA TPp TPr TROWp TROWr TX
drop Tc1 Tc2
*/

* Net primary income
gen YN = Y - TPN - TYT - TYS - TA - TX
label var YN "Net primary income"
gen YNb = Y - TPN - TYT - TYS - TA - TX - TCON
label var YNb "Net primary income, basic price"


* Test: Are taxes paid equal to gov received?
preserve
gen Tgov = TPN + TYT + TYS + TA + TX + TCON if sector=="S13"
gen Tpriv = TPN + TYT + TYS + TA + TX + TCON if sector=="S11" | sector=="S12" | sector=="S14_S15"
collapse (sum) Tgov Tpriv, by(geo YEAR)
list
restore

* Generate values for total economy (must be zero)
* browse geo sector YEAR TPN TYT TYS TA TX TCON TP TPr TPp if CNT2=="CY"
sumtotalS1  TPN TYT TYS TA TX TCON TP TPr TPp

************************************************************
* C.3 Benefits (Secondary distribution of income)
************************************************************

gen BS = 0 // Social benefits from g
gen BPSOC = 0
gen BROW = 0

* Social benefits
replace BS = D62r_g if sec=="h" // Social transfers in cash
replace BS = -D62p_h if sec=="g"

replace BPSOC = D62r_c + D62r_h - D62p_h if sec=="h"
replace BPSOC = -D62p_h if sec=="c"

* Distingush social benefits by finacial and other corporations
gen BPSOCfc1 = BPSOC if sector=="S12"
bysort CNT2 YEAR: egen BPSOCfc = sum(BPSOCfc1)
replace BPSOCfc = -BPSOCfc if sec=="h"
replace BPSOCfc = 0 if sector!="S12" & sec!="h"

gen BPSOCnfc1 = BPSOC if sector=="S11"
bysort CNT2 YEAR: egen BPSOCnfc = sum(BPSOCnfc1)
replace BPSOCnfc = -BPSOCnfc if sec=="h"
replace BPSOCnfc = 0 if sector!="S11" & sec!="h"

replace BROW = D62r_r - D62p_r

* Values for total economy
sumtotalS1 BS BPSOC BROW

gen Bc1 = BS + BPSOC + BROW
gen Bc2 = D62r - D62p
* browse geo YEAR sector Bc1 Bc2 BS BPSOC


************************************************************
* C.4 Disposable income
************************************************************

* D8 is NOT part of disposable income, as in ESA (B6N excludes it): funded
* pension contributions and benefits enter gross, through BPSOC and TPSOC.
* D8 only bridges ENTA saving to ESA saving - see S below.
gen YDmp = Y - TYT - TA - TX - TPN - TYS + TPSOCr - TPSOCp + TPXr - TPXp  + TROWr - TROWp + BS + BPSOC + BROW
* browse CNT2 YEAR sector YDmp  Y TYT TA  TX TPN TPr TPp TROWr TROWp BS BPSOC BROW if CNT2=="CY"

gen YDc1 = NNI - TPSr + D5r - D5p + D7r - D7p + D61r - D61p + D62r - D62p
gen YDc2 = B6Nr - TPSr
gen YDc3 = YN + TPr - TPp + TROWr - TROWp + BS + BPSOC + BROW
gen YDc4 = YN - TPSOC - TPX + TROWr - TROWp + BS + BPSOC + BROW

sort geo YEAR sector

* [INACTIVE] data check: YDmp against four derivations
* browse CNT2 YEAR YDmp YDc1 YDc2 YDc3 YDc4
drop YDc*

gen YNc = Y - TYT - TA - TX - TPN - TYS
* browse YN YNc
gen TPc = TPSOCr - TPSOCp + TPXr - TPXp
gen TPc1 = TPr - TPp
* browse TP TPc TPc1

* TPSp_r: product taxes government passes on to ROW (the ROW part of the
* product taxes households pay it, TCON). Not in the market-price YDmp, as in
* ESA B6N; at basic prices government receives them and pays them on.
* YD: disposable income at basic prices, the ENTA concept
gen YD = YDmp + TPSr_h - TPSp_g + TPSr_g - TPSp_r
* browse CNT2 YEAR sector YD YDmp TPSr_h TPSp_g TPSr_g
replace YD=. if sector=="S1"
sumtotalS1 YD


****************************************
* Adjustment of private transfers
****************************************

* The product taxes passed on to ROW are transfers to ROW (government and
* total economy), added after YDmp so that YDmp stays the ESA concept
replace TROWp = TROWp + TPSp_r if sector=="S13"
replace TROWp = TROWp + TPSrr if sector=="S1"
replace BROW = TROWr - TROWp + BROW

* Total benefits
gen B = BS + BPSOC + BROW


************************************************************
* C.5 Use of income
************************************************************

* Cmp: consumption at market prices; C: at basic prices, the ENTA concept
gen Cmp = P3p
label var Cmp "Consumption at market prices"
gen C = P3p - TPSp_g
replace C = . if sector=="S1"
sumtotalS1 C
* gen Ccoll = D63p - TPSp_g - TPSp_r if sector=="S13"
* gen Cind = P32p
* gen Cbc = Ccoll + Cind


gen SN = YD - C
label var SN "Saving"

* ENTA saving excludes D8 like ENTA disposable income, so
*   ENTA saving S + D8 = ESA net saving B8N   (for every sector)
* D8 moves saving from pension funds (S12, negative) to households
* (positive) and nets to about zero for the total economy. SN is kept as
* the control: it should equal S to rounding.
gen S = B8Np - D8
* browse YEAR geo sector SN B8Np S

* Total economy: the sum of the sectors, like YD and C, so that S = YD - C
* there too. Eurostat's total-economy row is not the sum of its sectors in
* Ireland.
replace S = . if sector=="S1"
sumtotalS1 S

gen USEb = C + S
gen USE = Cmp + S
* browse YEAR geo sector USEb YD TCON YDmp USE TPSp_g

gen D_use = YD - USEb
* [INACTIVE] data check: uses against resources, D_use should be 0
* browse CNT2 YEAR sector D_use YD USEb S C YDmp*


********************************************************************************
* D. Save the data
********************************************************************************

do ENTA_input_data/Prog_gen_country_name_from_CNT2.do

drop if YEAR>2024
sort CNT2 YEAR
drop if CNT2=="RS" | CNT2=="CH"

* Drop the control variables.
drop Yc_prod Yc1_prod B5Nrc GDPc Yc Bc1 Bc2 YNc TPc TPc1 USEb USE D_use

* Drop the working variables of the steps above. Each is an intermediate of
* one calculation in this file (the taxes-on-products totals, the corporate
* split of social benefits and contributions, the payroll-tax controls)
drop D21pt D21rt D31pt D31rt TPSOCnfc1 TPSOCfc1 BPSOCfc1 BPSOCnfc1 TTYERrc TTYERpc

* Drop leaked tempvars. `tempvar` inside a do-file (as opposed to inside a
* program) survives until the do-file ends.
capture drop __*

save ENTA_input_data/ENTA_input_datasets/esa_aggregates, replace



