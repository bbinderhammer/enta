********************************************************************************
* Labels of all published ENTA indicators
********************************************************************************
*
* One place for the code, number and label of every indicator, so that an
* indicator has the same label in the age profiles and in the aggregates.
*
* HOW IT IS USED
*   do ENTA_input_data/Prog_ENTA_labels.do esa    ESA format: age profiles (ENTA_esa) and the sectors
*                            Households, Corporations, Government and Total
*                            economy of ENTA_aggregates
*   do ENTA_input_data/Prog_ENTA_labels.do nta    NTA format: age profiles (ENTA_nta) and the sector
*                            "NTA Aggregates" of ENTA_aggregates
*   Called by ENTA_compilation1_esa.do, ENTA_compilation2_nta.do and
*   ENTA_aggregates/ENTA_aggregates_compilation.do.
*
* Needs the variable IND (indicator code). Creates the variable INDICATOR.
* An indicator without a label here is not published.
*
* NUMBERS
*   0 production and population, 1 primary income, 2 taxes, 3 social benefits,
*   4 funded pensions, 5 private transfers, 6 disposable income, 7 public
*   consumption, 8 private consumption, 9 saving, 10 totals.
*   ESA format: indicators of the corporations end with C and are numbered
*   C.1 to C.9, in the same order.

args format
if !inlist("`format'", "esa", "nta") {
    display as error "Prog_ENTA_labels.do: say which format, esa or nta"
    exit 198
}

gen INDICATOR = ""

********************************************************************************
* ESA format
********************************************************************************

if "`format'"=="esa" {

    * 0 Production and population
    replace INDICATOR = "0 Population (POP)" if IND=="POP"
    replace INDICATOR = "0 Gross domestic product (GDP)" if IND=="GDP"
    replace INDICATOR = "0.1 Taxes less subsidies on products (TPSp)" if IND=="TPSp"
    replace INDICATOR = "0.2 Consumption of fixed capital (CFC)" if IND=="CFC"
    replace INDICATOR = "0.3 Net labour income received from ROW (YEROW)" if IND=="YEROW"
    replace INDICATOR = "0.4 Net property income received from ROW (YPROW)" if IND=="YPROW"

    * 1 Primary income
    replace INDICATOR = "1 Primary income (Y)" if IND=="Y"
    replace INDICATOR = "1.1 Employment income (YEM)" if IND=="YEM"
    replace INDICATOR = "1.1.1 Compensation of employees (YE)" if IND=="YE"
    replace INDICATOR = "1.1.2 Mixed income (YM)" if IND=="YM"
    replace INDICATOR = "1.2 Asset income (YA)" if IND=="YA"
    replace INDICATOR = "1.2.1 Property income (YP)" if IND=="YP"
    replace INDICATOR = "1.2.2 Operating surplus (YO)" if IND=="YO"
    replace INDICATOR = "1.3 Equivalised household income (EHI)" if IND=="EHI"
    * Employment (age profiles only)
    replace INDICATOR = "1.E.1 Employment status (EMPLSTAT)" if IND=="EMPLSTAT"
    replace INDICATOR = "1.E.2 Employment status, EU-SILC based (EMPLSTATsilc)" if IND=="EMPLSTATsilc"
    replace INDICATOR = "1.E.3 Usual working hours (WHRUSUT)" if IND=="WHRUSUT"
    replace INDICATOR = "1.E.4 Actual working hours (WHRACTT)" if IND=="WHRACTT"
    replace INDICATOR = "1.E.5 Employment, ft-equivalents (EMPLFT)" if IND=="EMPLFT"

    * 2 Taxes and social contributions
    replace INDICATOR = "2 Taxes (T)" if IND=="T"
    replace INDICATOR = "2.1 Taxes on employment income (TYEM)" if IND=="TYEM"
    replace INDICATOR = "2.2 Taxes on assets and asset income (TYA)" if IND=="TYA"
    replace INDICATOR = "2.3 Taxes on income of non-employed (TB)" if IND=="TB"
    replace INDICATOR = "2.3.1 Taxes on pay-as-you-go pensions (TBSPEN)" if IND=="TBSPEN"
    replace INDICATOR = "2.3.2 Taxes on non-pension social benefits (TBSN)" if IND=="TBSN"
    replace INDICATOR = "2.3.3 Taxes on funded pensions (TBPPEN)" if IND=="TBPPEN"
    replace INDICATOR = "2.4 Taxes on consumption (TCON)" if IND=="TCON"
    replace INDICATOR = "2.5 Other current transfers (TX)" if IND=="TX"
    replace INDICATOR = "2.5.1 Other current transfers, households (TXH)" if IND=="TXH"
    replace INDICATOR = "2.5.2 Other current transfers, NPISH (TXNPISH)" if IND=="TXNPISH"
    replace INDICATOR = "2.6 Net transfers from ROW, government (TROW)" if IND=="TROW"

    * 3 Social benefits in cash
    replace INDICATOR = "3 Social benefits in cash (BS)" if IND=="BS"
    replace INDICATOR = "3.1 Social benefits, pensions (BSPEN)" if IND=="BSPEN"
    replace INDICATOR = "3.2 Social benefits, family (BSFAM)" if IND=="BSFAM"
    replace INDICATOR = "3.3 Social benefits, unemployment (BSU)" if IND=="BSU"
    replace INDICATOR = "3.4 Social benefits, other (BSX)" if IND=="BSX"

    * 4 Funded pensions
    replace INDICATOR = "4 Funded pensions, benefits less contributions (BPPEN)" if IND=="BPPEN"
    replace INDICATOR = "4.1 Funded pensions, contributions (TPSOCfc)" if IND=="TPSOCfc"
    replace INDICATOR = "4.2 Funded pensions, benefits (BPSOCfc)" if IND=="BPSOCfc"

    * 5 Private transfers
    replace INDICATOR = "5 Private transfers (BP)" if IND=="BP"
    replace INDICATOR = "5.1 Private transfers, net received (BPB)" if IND=="BPB"
    replace INDICATOR = "5.2 Transfers within households, received (BPW)" if IND=="BPW"
    replace INDICATOR = "5.3 Transfers within households, paid (TPW)" if IND=="TPW"
    replace INDICATOR = "5.4 Net transfers from ROW (BROW)" if IND=="BROW"

    * 6 Disposable income
    replace INDICATOR = "6 Disposable income (YD)" if IND=="YD"
    replace INDICATOR = "6.1 Disp. income, employment and public transfers (YD1)" if IND=="YD1"
    replace INDICATOR = "6.2 Disp. income, YD1 plus transfers within households (YD2)" if IND=="YD2"
    replace INDICATOR = "6.3 Disp. income, YD2 plus operating surplus (YD3)" if IND=="YD3"

    * 7 Public consumption
    replace INDICATOR = "7 Public consumption (CG)" if IND=="CG"
    replace INDICATOR = "7.1 Public consumption, education (CGE)" if IND=="CGE"
    replace INDICATOR = "7.2 Public consumption, health (CGH)" if IND=="CGH"
    replace INDICATOR = "7.3 Public consumption, other (CGX)" if IND=="CGX"

    * 8 Private consumption
    replace INDICATOR = "8 Private consumption (CH)" if IND=="CH"
    replace INDICATOR = "8.1 Private consumption, education (CHE)" if IND=="CHE"
    replace INDICATOR = "8.2 Private consumption, health (CHH)" if IND=="CHH"
    replace INDICATOR = "8.3 Private consumption, imputed rent (CHR)" if IND=="CHR"
    replace INDICATOR = "8.4 Private consumption, other (CHX)" if IND=="CHX"

    * 9 Saving
    replace INDICATOR = "9 Saving (S)" if IND=="S"
    replace INDICATOR = "9 Saving, households (SH)" if IND=="SH"

    * 10 Totals
    replace INDICATOR = "10 Total consumption (C)" if IND=="C"

    * Corporations
    replace INDICATOR = "C.1 Primary income, corporations (YC)" if IND=="YC"
    replace INDICATOR = "C.2 Taxes, corporations (TC)" if IND=="TC"
    replace INDICATOR = "C.4 Funded pensions, corporations (BPPC)" if IND=="BPPC"
    replace INDICATOR = "C.4.1 Funded pensions, contributions, corporations (TPSOCfcC)" if IND=="TPSOCfcC"
    replace INDICATOR = "C.4.2 Funded pensions, benefits, corporations (BPSOCfcC)" if IND=="BPSOCfcC"
    replace INDICATOR = "C.5 Private transfers, corporations (BPBC)" if IND=="BPBC"
    replace INDICATOR = "C.6 Disposable income, corporations (YDC)" if IND=="YDC"
    replace INDICATOR = "C.9 Saving, corporations (SC)" if IND=="SC"
}

********************************************************************************
* NTA format
********************************************************************************
* Not in the aggregates: population (POP) and the transfers within households
* (TFW, TFWI, TFWO), which have no national total.
* Only in the aggregates: total disposable income (YD) and the two parts of
* funded pensions (TFPO, TFPI).

if "`format'"=="nta" {

    replace INDICATOR = "0 Population (POP)" if IND=="POP"

    replace INDICATOR = "1 Primary income (Y)" if IND=="Y"
    replace INDICATOR = "1.1 Labour inc (YL)" if IND=="YL"
    replace INDICATOR = "1.2 Asset inc, private (YAF)" if IND=="YAF"
    replace INDICATOR = "1.2.1 Asset inc, households (YAH)" if IND=="YAH"
    replace INDICATOR = "1.2.2 Asset inc, corporations (YAC)" if IND=="YAC"
    replace INDICATOR = "1.3 Asset inc, government (YAG)" if IND=="YAG"
    replace INDICATOR = "1.4 Asset inc, total (YA)" if IND=="YA"

    replace INDICATOR = "2 Public transfers, outflows (TGOT)" if IND=="TGOT"
    replace INDICATOR = "2.1 Public transfers, out, househ (TGOTH)" if IND=="TGOTH"
    replace INDICATOR = "2.2 Public transfers, out, corp (TGOTC)" if IND=="TGOTC"
    replace INDICATOR = "2.3 Public trans, net from ROW (TGNF)" if IND=="TGNF"

    replace INDICATOR = "3 Public transfers, inflows in cash (TGIC)" if IND=="TGIC"
    replace INDICATOR = "3.1 Public trans, pensions (TGICPEN)" if IND=="TGICPEN"
    replace INDICATOR = "3.2 Public trans, family (TGICF)" if IND=="TGICF"
    replace INDICATOR = "3.3 Public trans, unempl (TGICU)" if IND=="TGICU"
    replace INDICATOR = "3.4 Public trans, other (TGICX)" if IND=="TGICX"

    replace INDICATOR = "4 Funded pensions, benefits less contr (TPEN)" if IND=="TPEN"
    replace INDICATOR = "4.1 Funded pensions, contributions (TFPO)" if IND=="TFPO"
    replace INDICATOR = "4.2 Funded pensions, benefits (TFPI)" if IND=="TFPI"

    replace INDICATOR = "5 Transfers private (TF)" if IND=="TF"
    replace INDICATOR = "5.1 Trans priv between HH, net received (TFB)" if IND=="TFB"
    replace INDICATOR = "5.2 Trans priv within HH, net received (TFW)" if IND=="TFW"
    replace INDICATOR = "5.2.1 Trans priv within HH, received (TFWI)" if IND=="TFWI"
    replace INDICATOR = "5.2.2 Trans priv within HH, paid (TFWO)" if IND=="TFWO"

    replace INDICATOR = "6 Disposable income, total (YD)" if IND=="YD"
    replace INDICATOR = "6.0 Disposable income, NTA (YDF)" if IND=="YDF"
    replace INDICATOR = "6.0.1 Disposable income, NTA, househ (YDH)" if IND=="YDH"
    replace INDICATOR = "6.0.2 Disposable income, NTA, corp (YDC)" if IND=="YDC"

    replace INDICATOR = "7 Public consumption (CG)" if IND=="CG"
    replace INDICATOR = "7.1 Public cons, education (CGE)" if IND=="CGE"
    replace INDICATOR = "7.2 Public cons, health (CGH)" if IND=="CGH"
    replace INDICATOR = "7.3 Public cons, other (CGX)" if IND=="CGX"
    replace INDICATOR = "7.4 Adjusted disp inc (incl. pub cons, YDHA)" if IND=="YDHA"

    replace INDICATOR = "8 Private consumption (CF)" if IND=="CF"
    replace INDICATOR = "8.1 Private cons, education (CFE)" if IND=="CFE"
    replace INDICATOR = "8.2 Private cons, health (CFH)" if IND=="CFH"
    replace INDICATOR = "8.3 Private cons, imp rent (CFR)" if IND=="CFR"
    replace INDICATOR = "8.4 Private cons, other (CFX)" if IND=="CFX"

    replace INDICATOR = "9 Saving, total (S)" if IND=="S"
    replace INDICATOR = "9.1 Saving, private (SF)" if IND=="SF"
    replace INDICATOR = "9.1.1 Saving, househ (SH)" if IND=="SH"
    replace INDICATOR = "9.1.2 Saving, corp (SC)" if IND=="SC"
    replace INDICATOR = "9.2 Saving, public (SG)" if IND=="SG"

    replace INDICATOR = "10.1 Total government transfers, net (TG)" if IND=="TG"
    replace INDICATOR = "10.2 Total government transfers, inflows (TGI)" if IND=="TGI"
    replace INDICATOR = "10.3 Public age reallocations, outflows (TGO)" if IND=="TGO"
    replace INDICATOR = "10.3.1 Public age realloc, outflows, asset-based (TGOABR)" if IND=="TGOABR"
    replace INDICATOR = "10.4 Total consumption (C)" if IND=="C"
}
