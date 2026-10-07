********************************************************************************
* ENTA output control: link the findings of a check to the ledger
********************************************************************************
*
* Defines the program ledger_match. The checks call this file once and then
* use the program on their list of findings.
*
* The data in memory need the variables CNT2, YEAR and IND. The program adds
* the variable LEDGER: the ID of every ledger row that covers the finding, or
* "new" if there is none.
*
* A ledger row covers a finding if the country is the same, the year lies
* between YEAR_FROM and YEAR_TO, and the indicator is one of the codes in
* INDICATORS (codes separated by blanks). A ledger row with CNT2 = ALL covers
* every country, one with INDICATORS = ALL every indicator.

*
* The program is called with the kind of finding: national_income, level,
* components, shape, men or spikes. A ledger row covers only the kinds listed
* in its column FINDINGS (separated by blanks; ALL covers every kind).

capture program drop ledger_match
program define ledger_match
    args kind
    capture drop LEDGER
    gen long FINDING = _n
    tempfile findings ledger hits
    save `findings'

    import delimited using ENTA_output_control/ledger.csv, varnames(1) stringcols(_all) case(upper) clear
    if _N > 0 {
        destring YEAR_FROM YEAR_TO, replace
        keep if strpos(" " + FINDINGS + " ", " `kind' ")>0 | FINDINGS=="ALL"
        keep ID CNT2 YEAR_FROM YEAR_TO INDICATORS
        save `ledger', emptyok

        * rows for ALL countries: one copy for each country in the findings
        use `findings', clear
        keep CNT2
        duplicates drop
        rename CNT2 COUNTRY_OF_FINDING
        tempfile countries
        save `countries'
        use `ledger', clear
        keep if CNT2=="ALL"
        if _N > 0 {
            cross using `countries'
            replace CNT2 = COUNTRY_OF_FINDING
            drop COUNTRY_OF_FINDING
            append using `ledger'
            drop if CNT2=="ALL"
            save `ledger', replace
        }

        use `findings', clear
        keep FINDING CNT2 YEAR IND
        joinby CNT2 using `ledger'
        keep if YEAR>=YEAR_FROM & YEAR<=YEAR_TO & (strpos(" " + INDICATORS + " ", " " + IND + " ")>0 | INDICATORS=="ALL")
        if _N > 0 {
            sort FINDING ID
            by FINDING: gen strL LEDGER = ID if _n==1
            by FINDING: replace LEDGER = LEDGER[_n-1] + " " + ID if _n>1
            by FINDING: keep if _n==_N
            keep FINDING LEDGER
            save `hits'
            use `findings', clear
            merge 1:1 FINDING using `hits', nogen
        }
        else {
            use `findings', clear
            gen strL LEDGER = ""
        }
    }
    else {
        use `findings', clear
        gen strL LEDGER = ""
    }
    replace LEDGER = "new" if LEDGER==""
    drop FINDING
end
