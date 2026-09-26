********************************************************************************
* Sectorize social contributions and other transfers

  * Transfers are classified according to which sector they are directed to
  * and from which sector they are received (Households + NPISH, corporations, governemnt
  
  * this code is called from inside Aggr_ESA2010.do
  
********************************************************************************
  
***************************************
* Content
  * One block per ESA transaction, in the order they appear below. Each block
  * opens with a banner and a single `local var "..."` that the whole block uses.
  * TPS: Taxes less subsidies on products
  * Taxes less subsidies on production (TPN = D29 - D39)
    * D29: Other taxes on production
    * D39: Other subsidies on production
  * D51: Taxes on income
  * D59: Other current taxes
  * D61: Social contributions
  * D62: Social benefits
  * D71: Net non-life insurance premiums
  * D72: Non-life insurance claims
  * D74: Current international cooperation
  * D75: Miscellaneous current transfers
  * D76: VAT and GNI-based EU own resources
***************************************

    * Legend - TWO different naming patterns, separated only by an underscore.
    * They mean different things; do not confuse them.
    *
    *   [var]p<sec> / [var]r<sec>   NO underscore - economy-wide totals,
    *   the same value on every observation of a country-year:
    *     [var]pg  total PAID BY government      [var]rg  total RECEIVED BY government
    *     [var]ph  total PAID BY households      [var]rh  total RECEIVED BY households
    *     [var]pc  total PAID BY corporations    [var]rc  total RECEIVED BY corporations
    *     [var]pr  total PAID BY ROW             [var]rr  total RECEIVED BY ROW
    *
    *   [var]p_<sec> / [var]r_<sec>  WITH underscore - directed flows, read on
    *   the row of the sector at the other end of the flow:
    *     [var]p_g  paid TO government           [var]r_g  received FROM government
    *     [var]p_h  paid TO households           [var]r_h  received FROM households
    *     [var]p_c  paid TO corporations         [var]r_c  received FROM corporations
    *     [var]p_r  paid TO ROW                  [var]r_r  received FROM ROW
    *
    * sec: h = households + NPISH (S14_S15)   c = corporations (S11, S12)
    *      g = government (S13)               r = rest of world (S2)
    *      t = total economy (S1)
	
  * Working names for the mirror-flow idiom below ("what sector A pays to B is
  * what B receives from A"). They were the ordinary variables `temp'/`temp1'
  * before, which could collide with anything of that name in memory; as
  * tempvars they get unique names. Each block still drops them, so nothing
  * is left behind.
    tempvar mt mt1

  gen sec = ""
  replace sec = "h" if sector=="S14_S15" // & ((CNT2=="DE" & YEAR<=2011) | (CNT2=="IE" & YEAR<=2009))
  replace sec = "c" if sector=="S11" | sector=="S12"  
  replace sec = "g" if sector=="S13"  
  replace sec = "r" if sector=="S2"  
  replace sec = "t" if sector=="S1"  
	
  ************************************************************
  * TPS: Taxes less subsidies on products
  ************************************************************

    local var "TPS"
                               
   * paid: total by sector
    gen `var'_h1 = `var'p if sec=="h"
    gen `var'_c1 = `var'p if sec=="c"
    gen `var'_g1 = `var'p if sec=="g"
    gen `var'_r1 = `var'p if sec=="r"
    bysort geo YEAR: egen `var'pg = total(`var'_g1)
    bysort geo YEAR: egen `var'pc = total(`var'_c1)
    bysort geo YEAR: egen `var'ph = total(`var'_h1)
    bysort geo YEAR: egen `var'pr = total(`var'_r1)
    drop `var'_g* `var'_c* `var'_r* `var'_h1
			  
  * received: total by sector
    gen `var'_h1 = `var'r if sec=="h"  
    gen `var'_c1 = `var'r if sec=="c"  
    gen `var'_g1 = `var'r if sec=="g" 
    gen `var'_r1 = `var'r if sec=="r"
    bysort geo YEAR: egen `var'rh = total(`var'_h1)
    bysort geo YEAR: egen `var'rc = total(`var'_c1)
    bysort geo YEAR: egen `var'rg = total(`var'_g1)
    bysort geo YEAR: egen `var'rr = total(`var'_r1)
    drop `var'_h*  `var'_c* `var'_g* `var'_r* 
	 
	//browse geo YEAR sector `var'p* `var'r*
	
	// only h and g pay taxes on products, only g and r receive taxes

	
	gen `var'p_g = 0
	gen `var'p_r = 0	
	gen `var'r_h = 0
	gen `var'r_g = 0
	
    * g pays only to g
      replace `var'p_g = `var'pg  if sec=="g"
      replace `var'r_g = `var'pg  if sec=="g"
	  
    * Sector h pays the rest 
	  replace `var'p_g = `var'rg - `var'pg if sec=="h"
	  replace `var'r_h = `var'rg - `var'pg if sec=="g"
	  replace `var'p_r = `var'rr if sec=="h"	  
	  
	 * Test
	 /*
	 gen `var'pc1 = `var'p_g + `var'p_r
	 gen `var'p_diff = `var'pc1 - `var'p

	 gen `var'rc1 = `var'r_h + `var'r_g
	 gen `var'r_diff = `var'rc1 - `var'r

	 //browse YEAR geo sec `var'* `var'p_diff `var'r_diff if sec=="h" | sec=="g" | sec=="c"
	 drop `var'rc1 `var'pc1 `var'p_diff `var'r_diff
	 */
	 
	 
	 
********************************************************************************
* Taxes less subsidies on production (TPN = D29 - D39)
********************************************************************************
  
    * Taxes less subsidies on production
    gen TPNr = D29r - D39p
    gen TPNp = D29p - D39r
	// gen TPN = TPNp - TPNr
	
	
  ************************************************************
  * D29: Other taxes on production
  ************************************************************

    local var "D29"
                               
   * paid: total by sector
    gen `var'_h1 = `var'p if sec=="h"
    gen `var'_c1 = `var'p if sec=="c"
    gen `var'_g1 = `var'p if sec=="g"
    gen `var'_r1 = `var'p if sec=="r"
    bysort geo YEAR: egen `var'pg = total(`var'_g1)
    bysort geo YEAR: egen `var'pc = total(`var'_c1)
    bysort geo YEAR: egen `var'ph = total(`var'_h1)
    bysort geo YEAR: egen `var'pr = total(`var'_r1)
    drop `var'_g* `var'_c* `var'_r* `var'_h1
			  
  * received: total by sector
    gen `var'_h1 = `var'r if sec=="h"  
    gen `var'_c1 = `var'r if sec=="c"  
    gen `var'_g1 = `var'r if sec=="g" 
    gen `var'_r1 = `var'r if sec=="r"
    bysort geo YEAR: egen `var'rh = total(`var'_h1)
    bysort geo YEAR: egen `var'rc = total(`var'_c1)
    bysort geo YEAR: egen `var'rg = total(`var'_g1)
    bysort geo YEAR: egen `var'rr = total(`var'_r1)
    drop `var'_h*  `var'_c* `var'_g* `var'_r* 
	 
	//browse geo YEAR sector `var'p* `var'r*
	
	gen `var'p_g = 0	
	gen `var'p_r = 0	
	gen `var'r_h = 0
	gen `var'r_g = 0
	gen `var'r_c = 0
	gen `var'r_r = 0	
	
	replace `var'p_g = `var'p if sec=="g" | sec=="h" | sec=="c"
	replace `var'p_r = `var'rr if sec=="g"
	replace `var'r_g = `var'pg if sec=="g"
	replace `var'r_h = `var'ph if sec=="g"
	replace `var'r_c = `var'pc if sec=="g"	
	
	
  ************************************************************
  * D39: Other subsidies on production
  ************************************************************

    local var "D39"
                               
   * paid: total by sector
    gen `var'_h1 = `var'p if sec=="h"
    gen `var'_c1 = `var'p if sec=="c"
    gen `var'_g1 = `var'p if sec=="g"
    gen `var'_r1 = `var'p if sec=="r"
    bysort geo YEAR: egen `var'pg = total(`var'_g1)
    bysort geo YEAR: egen `var'pc = total(`var'_c1)
    bysort geo YEAR: egen `var'ph = total(`var'_h1)
    bysort geo YEAR: egen `var'pr = total(`var'_r1)
    drop `var'_g* `var'_c* `var'_r* `var'_h1
			  
  * received: total by sector
    gen `var'_h1 = `var'r if sec=="h"  
    gen `var'_c1 = `var'r if sec=="c"  
    gen `var'_g1 = `var'r if sec=="g" 
    gen `var'_r1 = `var'r if sec=="r"
    bysort geo YEAR: egen `var'rh = total(`var'_h1)
    bysort geo YEAR: egen `var'rc = total(`var'_c1)
    bysort geo YEAR: egen `var'rg = total(`var'_g1)
    bysort geo YEAR: egen `var'rr = total(`var'_r1)
    drop `var'_h*  `var'_c* `var'_g* `var'_r* 
	 
	//browse geo YEAR sector `var'p* `var'r*
	
	// paid by g and r
	// received by c, h and g
	
	gen `var'p_c = 0
	gen `var'p_h = 0
	gen `var'p_g = 0
	gen `var'r_g = 0
	gen `var'r_r = 0	
	
    * Sector r and g pay to c, h and g according to shares
	// replace `var'r_r = `var'pr * `var'rc / (`var'rh + `var'rc + `var'rg) if sec=="c"
	replace `var'r_r = `var'pr * `var'rh / (`var'rh + `var'rc + `var'rg) if sec=="h"
	replace `var'r_r = `var'pr * `var'rg / (`var'rh + `var'rc + `var'rg) if sec=="g"	
	
	replace `var'p_c = `var'pr * `var'rc / (`var'rh + `var'rc + `var'rg) if sec=="r"
	replace `var'p_h = `var'pr * `var'rh / (`var'rh + `var'rc + `var'rg) if sec=="r"
	replace `var'p_g = `var'pr * `var'rg / (`var'rh + `var'rc + `var'rg) if sec=="r"
	
	replace `var'r_g = `var'pg * `var'rc / (`var'rh + `var'rc + `var'rg) if sec=="c"
	corpdist `var'r_g `var'r
	replace `var'r_r = `var'r - `var'r_g if sec=="c"
	replace `var'r_g = `var'pg * `var'rh / (`var'rh + `var'rc + `var'rg) if sec=="h"
	replace `var'r_g = `var'pg * `var'rg / (`var'rh + `var'rc + `var'rg) if sec=="g"
	
	replace `var'p_c = `var'pg * `var'rc / (`var'rh + `var'rc + `var'rg) if sec=="g"
	replace `var'p_h = `var'pg * `var'rh / (`var'rh + `var'rc + `var'rg) if sec=="g"
	replace `var'p_g = `var'pg * `var'rg / (`var'rh + `var'rc + `var'rg) if sec=="g"

	* Where nothing is received at all (h + c + g receipts = 0) every share
	* above is 0/0 and the piece becomes missing, which made TPN, T and YD
	* missing for all CY sectors 1995-2003 (D39 not reported there and set to
	* 0 in Aggr_ESA2010.do B.3). With no receipts there is nothing to allocate,
	* so those pieces are 0 - as already done for D59 below.
	foreach p in p_c p_h p_g r_g r_r {
	  replace `var'`p' = 0 if missing(`var'`p') & (`var'rh + `var'rc + `var'rg)==0
	}
	
    * Test
      /*
	  gen `var'pc1 = `var'p_g + `var'p_h + `var'p_c
	  gen `var'p_diff = `var'pc1 - `var'p

	  gen `var'rc1 = `var'r_g + `var'r_r
	  gen `var'r_diff = `var'rc1 - `var'r

	  //browse geo YEAR sector `var'r_diff `var'p_diff if sec=="h" | sec=="c" | sec=="g" | sec=="t"

      drop `var'pc1 `var'rc1 `var'r_diff `var'p_diff
      */
	  
    gen TPNp_g = D29p_g - D39r_g
    gen TPNp_r = -D39r_r
	
    gen TPNr_h = D29r_h - D39p_h
    gen TPNr_g = D29r_g - D39p_g
	gen TPNr_c = D29r_c - D39p_c

  ************************************************************
  * D51: Taxes on income
  ************************************************************

    local var "D51"
	// Paid only to g and r
                               
   * paid: total by sector
    gen `var'_h1 = `var'p if sec=="h"
    gen `var'_c1 = `var'p if sec=="c"
    gen `var'_g1 = `var'p if sec=="g"
    gen `var'_r1 = `var'p if sec=="r"
    bysort geo YEAR: egen `var'pg = total(`var'_g1)
    bysort geo YEAR: egen `var'pc = total(`var'_c1)
    bysort geo YEAR: egen `var'ph = total(`var'_h1)
    bysort geo YEAR: egen `var'pr = total(`var'_r1)
    drop `var'_g* `var'_c* `var'_r* `var'_h1
			  
  * received: total by sector
    gen `var'_h1 = `var'r if sec=="h"  
    gen `var'_c1 = `var'r if sec=="c"  
    gen `var'_g1 = `var'r if sec=="g" 
    gen `var'_r1 = `var'r if sec=="r"
    bysort geo YEAR: egen `var'rh = total(`var'_h1)
    bysort geo YEAR: egen `var'rc = total(`var'_c1)
    bysort geo YEAR: egen `var'rg = total(`var'_g1)
    bysort geo YEAR: egen `var'rr = total(`var'_r1)
    drop `var'_h*  `var'_c* `var'_g* `var'_r* 
	 
	//browse geo YEAR sector D51p* D51r*

	
	* No taxes to h and c
	  gen `var'p_h = 0
	  gen `var'p_c = 0
	  
    * ROW and g pay only to government
      gen `var'p_g = 0
	  replace `var'p_g = `var'pr  if sec=="r"
      replace `var'p_g = `var'pg  if sec=="g"
	 
    * Sector h and c pay to g and r according to shares
	  replace `var'p_g = (`var'rg - `var'pr - `var'pg)  * `var'p / ((`var'rg - `var'pr - `var'pg) + `var'rr) if sector=="S11" | sector=="S12"	| sector=="S14_S15"
	  gen `var'p_r = 0
	  replace `var'p_r = (`var'rr)  * `var'p / ((`var'rg - `var'pr - `var'pg) + `var'rr) if sector=="S11" | sector=="S12"	| sector=="S14_S15"
	 
     
	 * We know all payments, so we know all receipts
	 gen `var'r_h = 0
	 gen `var'r_g = 0
	 gen `var'r_r = 0
	 gen `var'r_c = 0
	 
    * Received by g
      local psec "h" // received by c from h
      local rsec "g"
        gen `mt1' = `var'p_`rsec' if sec=="`psec'"
        bysort geo YEAR: egen `mt' = total(`mt1')
        replace `var'r_`psec' = `mt' if sec=="`rsec'"
		drop `mt' `mt1'
		
      local psec "g" 
      local rsec "g"
        gen `mt1' = `var'p_`rsec' if sec=="`psec'"
        bysort geo YEAR: egen `mt' = total(`mt1')
        replace `var'r_`psec' = `mt' if sec=="`rsec'"
		drop `mt' `mt1'
		
      local psec "c" 
      local rsec "g"
        gen `mt1' = `var'p_`rsec' if sec=="`psec'"
        bysort geo YEAR: egen `mt' = total(`mt1')
        replace `var'r_`psec' = `mt' if sec=="`rsec'"
		drop `mt' `mt1'
		
      local psec "r" 
      local rsec "g"
        gen `mt1' = `var'p_`rsec' if sec=="`psec'"
        bysort geo YEAR: egen `mt' = total(`mt1')
        replace `var'r_`psec' = `mt' if sec=="`rsec'"
		drop `mt' `mt1'
		
    * received by r
      local psec "c" 
      local rsec "r"
        gen `mt1' = `var'p_`rsec' if sec=="`psec'"
        bysort geo YEAR: egen `mt' = total(`mt1')
        replace `var'r_`psec' = `mt' if sec=="`rsec'"
		drop `mt' `mt1'
		
      local psec "h" 
      local rsec "r"
        gen `mt1' = `var'p_`rsec' if sec=="`psec'"
        bysort geo YEAR: egen `mt' = total(`mt1')
        replace `var'r_`psec' = `mt' if sec=="`rsec'"
		drop `mt' `mt1'
		
    * Test
      /*
	  gen `var'pc1 = `var'p_g + `var'p_h + `var'p_c + `var'p_r
	  gen `var'p_diff = `var'pc1 - `var'p

	  gen `var'rc1 = `var'r_g + `var'r_h + `var'r_c + `var'r_r
	  gen `var'r_diff = `var'rc1 - `var'r
	  //browse geo YEAR sector `var'r_diff `var'p_diff if sec=="h" | sec=="c" | sec=="g" | sec=="t"

      drop `var'pc1 `var'rc1 `var'r_diff `var'p_diff
      */
	  
  ************************************************************
  * D59: Other current taxes
  ************************************************************

    local var "D59"
                               
   * paid: total by sector
    gen `var'_h1 = `var'p if sec=="h"
    gen `var'_c1 = `var'p if sec=="c"
    gen `var'_g1 = `var'p if sec=="g"
    gen `var'_r1 = `var'p if sec=="r"
    bysort geo YEAR: egen `var'pg = total(`var'_g1)
    bysort geo YEAR: egen `var'pc = total(`var'_c1)
    bysort geo YEAR: egen `var'ph = total(`var'_h1)
    bysort geo YEAR: egen `var'pr = total(`var'_r1)
    drop `var'_g* `var'_c* `var'_r* `var'_h1
			  
  * received: total by sector
    gen `var'_h1 = `var'r if sec=="h"  
    gen `var'_c1 = `var'r if sec=="c"  
    gen `var'_g1 = `var'r if sec=="g" 
    gen `var'_r1 = `var'r if sec=="r"
    bysort geo YEAR: egen `var'rh = total(`var'_h1)
    bysort geo YEAR: egen `var'rc = total(`var'_c1)
    bysort geo YEAR: egen `var'rg = total(`var'_g1)
    bysort geo YEAR: egen `var'rr = total(`var'_r1)
    drop `var'_h*  `var'_c* `var'_g* `var'_r* 
	 
	//browse geo YEAR sector `var'p* `var'r*

	
	* No taxes to h and c
	  gen `var'p_h = 0
	  gen `var'p_c = 0
	  
    * ROW and g pay only to governemnt
      gen `var'p_g = 0
	  replace `var'p_g = `var'pr  if sec=="r"
      replace `var'p_g = `var'pg  if sec=="g"
	 
    * Sector h and c pay to g and r according to shares
	  replace `var'p_g = (`var'rg - `var'pr - `var'pg)  * `var'p / ((`var'rg - `var'pr - `var'pg) + `var'rr) if sector=="S11" | sector=="S12"	| sector=="S14_S15"
	  gen `var'p_r = 0
	  replace `var'p_r = (`var'rr)  * `var'p / ((`var'rg - `var'pr - `var'pg) + `var'rr) if sector=="S11" | sector=="S12"	| sector=="S14_S15"
	  replace `var'p_r = 0 if `var'p_r==.
	  replace `var'p_g = 0 if `var'p_g==.	 
     
	 * We know all payments, so we know all receipts	
	 gen `var'r_h = 0
	 gen `var'r_g = 0
	 gen `var'r_r = 0
	 gen `var'r_c = 0
	 
    * Received by g	
      local psec "h" // received by c from h
      local rsec "g"
        gen `mt1' = `var'p_`rsec' if sec=="`psec'"
        bysort geo YEAR: egen `mt' = total(`mt1')
        replace `var'r_`psec' = `mt' if sec=="`rsec'"
		drop `mt' `mt1'
			
      local psec "g" 
      local rsec "g"
        gen `mt1' = `var'p_`rsec' if sec=="`psec'"
        bysort geo YEAR: egen `mt' = total(`mt1')
        replace `var'r_`psec' = `mt' if sec=="`rsec'"
		drop `mt' `mt1'
			
      local psec "c" 
      local rsec "g"
        gen `mt1' = `var'p_`rsec' if sec=="`psec'"
        bysort geo YEAR: egen `mt' = total(`mt1')
        replace `var'r_`psec' = `mt' if sec=="`rsec'"
		drop `mt' `mt1'
			
      local psec "r" 
      local rsec "g"
        gen `mt1' = `var'p_`rsec' if sec=="`psec'"
        bysort geo YEAR: egen `mt' = total(`mt1')
        replace `var'r_`psec' = `mt' if sec=="`rsec'"
		drop `mt' `mt1'
		
    * received by r
      local psec "c" 
      local rsec "r"
        gen `mt1' = `var'p_`rsec' if sec=="`psec'"
        bysort geo YEAR: egen `mt' = total(`mt1')
        replace `var'r_`psec' = `mt' if sec=="`rsec'"
		drop `mt' `mt1'
		
      local psec "h" 
      local rsec "r"
        gen `mt1' = `var'p_`rsec' if sec=="`psec'"
        bysort geo YEAR: egen `mt' = total(`mt1')
        replace `var'r_`psec' = `mt' if sec=="`rsec'"
		drop `mt' `mt1'
		
    * Test
	  /*
	  gen `var'rc1 = `var'r_g + `var'r_h + `var'r_c + `var'r_r
	  gen `var'r_diff = `var'rc1 - `var'r

	  gen `var'pc1 = `var'p_g + `var'p_h + `var'p_c + `var'p_r
	  gen `var'p_diff = `var'pc1 - `var'p

	  //browse geo YEAR sector `var'r_diff `var'p_diff D59* if sec=="h" | sec=="c" | sec=="g" | sec=="t"

      drop `var'pc1 `var'rc1 `var'r_diff `var'p_diff
      */

  ************************************************************
  * D61: Social contributions
  ************************************************************
  
  * Received by gov, corporations, households and ROW; paid only by households and ROW
  * Received by households and ROW is assumed to be paid by households

  local var "D61"
                               
  * paid: total by sector
    gen `var'_h1 = `var'p if sec=="h"
    gen `var'_c1 = `var'p if sec=="c"
    gen `var'_g1 = `var'p if sec=="g"
    gen `var'_r1 = `var'p if sec=="r"
    bysort geo YEAR: egen `var'pg = total(`var'_g1)
    bysort geo YEAR: egen `var'pc = total(`var'_c1)
    bysort geo YEAR: egen `var'ph = total(`var'_h1)
    bysort geo YEAR: egen `var'pr = total(`var'_r1)
    drop `var'_g* `var'_c* `var'_r* `var'_h1
			  
  * received: total by sector
    gen `var'_h1 = `var'r if sec=="h"  
    gen `var'_c1 = `var'r if sec=="c"  
    gen `var'_g1 = `var'r if sec=="g" 
    gen `var'_r1 = `var'r if sec=="r"
    bysort geo YEAR: egen `var'rh = total(`var'_h1)
    bysort geo YEAR: egen `var'rc = total(`var'_c1)
    bysort geo YEAR: egen `var'rg = total(`var'_g1)
    bysort geo YEAR: egen `var'rr = total(`var'_r1)
    drop `var'_h*  `var'_c* `var'_g* `var'_r* 
	 
	
	* received by households is assumed to be paid by households (not r)
	gen `var'r_h = `var'rh if sec=="h" 
	gen `var'p_h = `var'rh if sec=="h"	
	replace `var'p_h = 0 if sec!="h"
	
    * received by ROW is for sure paid by households
	replace `var'r_h = `var'rr if sec=="r"
	gen `var'p_r = `var'rr if sec=="h"	
	replace `var'p_r = 0 if sec!="h"
	
	* received by g is distributed to paying sectors r and h according to their shares
    gen `var'r_r = `var'r * `var'pr / (`var'pr + (`var'ph - `var'rh - `var'rr)) if sec=="g" | sec=="c"	
    replace `var'r_h = `var'r - `var'r_r if sec=="g" | sec=="c"	
    replace `var'r_r = 0 if sec=="r" | sec=="h"

	//browse geo YEAR sector D61p D61r D61r_r D61r_h
	
  * paid: only by hh and row
    gen `var'p_g = 0
	gen `var'p_c = 0
	 
     * we know what is received by g and c from h => it is clear what households pay to g and c
     local psec	"h"
     local rsec "g"
     gen `var'_`rsec'_`psec'1 = `var'r_`psec' if sec=="`rsec'"
     bysort geo YEAR: egen `var'_`rsec'_`psec' = total(`var'_`rsec'_`psec'1 )
     replace `var'p_`rsec' = `var'_`rsec'_`psec' if sec=="`psec'"
     drop `var'_`rsec'_`psec'1
	 
     local psec	"h"
     local rsec "c"
        gen `var'_`rsec'_`psec'1 = `var'r_`psec' if sec=="`rsec'"
        bysort geo YEAR: egen `var'_`rsec'_`psec' = total(`var'_`rsec'_`psec'1 )
        replace `var'p_`rsec' = `var'_`rsec'_`psec' if sec=="`psec'"
		drop `var'_`rsec'_`psec'1

	
  * Control if values add up
	/*
	gen D61rc1 = D61r_h + D61r_r
	gen D61pc1 = D61p_g + D61p_c + D61p_r + D61p_h

	gen D61p_diff = D61pc1 - D61p
	gen D61r_diff = D61rc1 - D61r

	//browse geo YEAR sector D61p D61pc1 D61r D61rc1 D61r_r D61r_h D61p_g D61p_c D61r_diff D61p_diff if sec=="h" | sec=="c" | sec=="g"

    drop `var'pc1 `var'rc1 `var'r_diff `var'p_diff
    */

	
  ************************************************************
  * D62: Social benefits
  ************************************************************
  
    local var "D62"
	* No social benefits received by governments and corporations
                               
  * paid: total by sector
    gen `var'_h1 = `var'p if sec=="h"
    gen `var'_c1 = `var'p if sec=="c"
    gen `var'_g1 = `var'p if sec=="g"
    gen `var'_r1 = `var'p if sec=="r"
    bysort geo YEAR: egen `var'pg = total(`var'_g1)
    bysort geo YEAR: egen `var'pc = total(`var'_c1)
    bysort geo YEAR: egen `var'ph = total(`var'_h1)
    bysort geo YEAR: egen `var'pr = total(`var'_r1)
    drop `var'_g* `var'_c* `var'_r* `var'_h1
			  
  * received: total by sector
    gen `var'_h1 = `var'r if sec=="h"  
    gen `var'_c1 = `var'r if sec=="c"  
    gen `var'_g1 = `var'r if sec=="g" 
    gen `var'_r1 = `var'r if sec=="r"
    bysort geo YEAR: egen `var'rh = total(`var'_h1)
    bysort geo YEAR: egen `var'rc = total(`var'_c1)
    bysort geo YEAR: egen `var'rg = total(`var'_g1)
    bysort geo YEAR: egen `var'rr = total(`var'_r1)
    drop `var'_h*  `var'_c* `var'_g* `var'_r* 
 
	
	* Paid by ROW is received by households
	gen `var'r_r = 0
	replace `var'r_r = `var'pr if sec=="h"
	gen `var'p_h = `var'pr if sec=="r"
	
	* Paid by h is received by h
	gen `var'r_h = 0
	replace `var'r_h = `var'ph if sec=="h"
	replace `var'p_h = `var'ph if sec=="h"
	
	* paid by c and g is distributed to receiving sectors r and h according to their shares
    gen `var'p_r = `var'p * `var'rr / (`var'rr + (`var'rh - `var'ph - `var'pr)) if sec=="g" | sec=="c"	
    replace `var'p_h = `var'p - `var'p_r if sec=="g" | sec=="c"	
    replace `var'p_r = 0 if sec=="r" | sec=="h"	
	 
    * we know what is paid by g and c to h and r => it is clear what h and r recieve from g and c
    gen `var'r_g = 0
	gen `var'r_c = 0
    
    local psec "g"
    local rsec "h"
    gen `mt1' = `var'p_`rsec' if sec=="`psec'"
    bysort geo YEAR: egen `mt' = total(`mt1')
    replace `var'r_`psec' = `mt' if sec=="`rsec'"
    drop `mt' `mt1'
	
    local psec "c"
    local rsec "h"
    gen `mt1' = `var'p_`rsec' if sec=="`psec'"
    bysort geo YEAR: egen `mt' = total(`mt1')
    replace `var'r_`psec' = `mt' if sec=="`rsec'"
    drop `mt' `mt1'
	
    local psec "g"
    local rsec "r"
    gen `mt1' = `var'p_`rsec' if sec=="`psec'"
    bysort geo YEAR: egen `mt' = total(`mt1')
    replace `var'r_`psec' = `mt' if sec=="`rsec'"
    drop `mt' `mt1'
	
    local psec "c"
    local rsec "r"
    gen `mt1' = `var'p_`rsec' if sec=="`psec'"
    bysort geo YEAR: egen `mt' = total(`mt1')
    replace `var'r_`psec' = `mt' if sec=="`rsec'"
    drop `mt' `mt1'

  * Control if values add up
	/*
	gen D62rc1 = D62r_h + D62r_r + D62r_g + D62r_c
	gen D62pc1 = D62p_h + D62p_r

	gen D62p_diff = D62pc1 - D62p
	gen D62r_diff = D62rc1 - D62r

    drop `var'pc1 `var'rc1 `var'r_diff `var'p_diff
    */
	 	
	
  ************************************************************
  * D71: Net non-life insurance premiums
  ************************************************************
    local var "D71"
                               
   * paid: total by sector
    gen `var'_h1 = `var'p if sec=="h"
    gen `var'_c1 = `var'p if sec=="c"
    gen `var'_g1 = `var'p if sec=="g"
    gen `var'_r1 = `var'p if sec=="r"
    bysort geo YEAR: egen `var'pg = total(`var'_g1)
    bysort geo YEAR: egen `var'pc = total(`var'_c1)
    bysort geo YEAR: egen `var'ph = total(`var'_h1)
    bysort geo YEAR: egen `var'pr = total(`var'_r1)
    drop `var'_g* `var'_c* `var'_r* `var'_h1
			  
  * received: total by sector
    gen `var'_h1 = `var'r if sec=="h"  
    gen `var'_c1 = `var'r if sec=="c"  
    gen `var'_g1 = `var'r if sec=="g" 
    gen `var'_r1 = `var'r if sec=="r"
    bysort geo YEAR: egen `var'rh = total(`var'_h1)
    bysort geo YEAR: egen `var'rc = total(`var'_c1)
    bysort geo YEAR: egen `var'rg = total(`var'_g1)
    bysort geo YEAR: egen `var'rr = total(`var'_r1)
    drop `var'_h*  `var'_c* `var'_g* `var'_r* 
	 
	//browse geo YEAR sector D71p* D71r*

	
	* No premia to h
	  gen `var'p_h = 0
	  
    * Government and ROW pay to corporations
      gen `var'p_c = `var'pg  if sec=="g"
      replace `var'p_c = `var'pr  if sec=="r"
	 
    * Sector h and c pay to g, c and r according to shares
	  replace `var'p_c = (`var'rc - `var'pg - `var'pr)  * `var'p / ((`var'rc - `var'pg - `var'pr) + `var'rg + `var'rr) if sector=="S11" | sector=="S12"	| sector=="S14_S15"
	  gen `var'p_g = `var'rg  * `var'p / ((`var'rc - `var'pg - `var'pr) + `var'rg + `var'rr) if sector=="S11" | sector=="S12"	| sector=="S14_S15"
	  replace `var'p_g = 0 if sec=="g" | sec=="r"
	  gen `var'p_r = 0 
	  replace `var'p_r = `var'rr  * `var'p / ((`var'rc - `var'pg - `var'pr) + `var'rg + `var'rr) if sector=="S11" | sector=="S12"	| sector=="S14_S15"	  

	  
	 * Test
     /*
	 gen `var'pc1 = `var'p_g + `var'p_h + `var'p_c + `var'p_r
	 gen `var'p_diff = `var'pc1 - `var'p
	 */

	 * We know all payments, so we know all receipts
	 gen `var'r_h = 0
	 gen `var'r_g = 0
	 gen `var'r_r = 0
	 gen `var'r_c = 0
	 
    * Received by c
      local psec "h" // received by c from h
      local rsec "c"
        gen `mt1' = `var'p_`rsec' if sec=="`psec'"
        bysort geo YEAR: egen `mt' = total(`mt1')
        replace `var'r_`psec' = `mt' if sec=="`rsec'"
		drop `mt' `mt1'
		
      local psec "g" 
      local rsec "c"
        gen `mt1' = `var'p_`rsec' if sec=="`psec'"
        bysort geo YEAR: egen `mt' = total(`mt1')
        replace `var'r_`psec' = `mt' if sec=="`rsec'"
		drop `mt' `mt1'
		
      local psec "c" 
      local rsec "c"
        gen `mt1' = `var'p_`rsec' if sec=="`psec'"
        bysort geo YEAR: egen `mt' = total(`mt1')
        replace `var'r_`psec' = `mt' if sec=="`rsec'"
		drop `mt' `mt1'
		
      local psec "r" 
      local rsec "c"
        gen `mt1' = `var'p_`rsec' if sec=="`psec'"
        bysort geo YEAR: egen `mt' = total(`mt1')
        replace `var'r_`psec' = `mt' if sec=="`rsec'"
		drop `mt' `mt1'
		
	corpdist D71r_c D71r
	corpdist D71r_h D71r
	corpdist D71r_g D71r
	corpdist D71r_r D71r
		
    * Received by g
	
      local psec "h" // received by c from h
      local rsec "g"
        gen `mt1' = `var'p_`rsec' if sec=="`psec'"
        bysort geo YEAR: egen `mt' = total(`mt1')
        replace `var'r_`psec' = `mt' if sec=="`rsec'"
		drop `mt' `mt1'
		
      local psec "c" 
      local rsec "g"
        gen `mt1' = `var'p_`rsec' if sec=="`psec'"
        bysort geo YEAR: egen `mt' = total(`mt1')
        replace `var'r_`psec' = `mt' if sec=="`rsec'"
		drop `mt' `mt1'
		
    * received by r
      local psec "c" 
      local rsec "r"
        gen `mt1' = `var'p_`rsec' if sec=="`psec'"
        bysort geo YEAR: egen `mt' = total(`mt1')
        replace `var'r_`psec' = `mt' if sec=="`rsec'"
		drop `mt' `mt1'
		
      local psec "h" 
      local rsec "r"
        gen `mt1' = `var'p_`rsec' if sec=="`psec'"
        bysort geo YEAR: egen `mt' = total(`mt1')
        replace `var'r_`psec' = `mt' if sec=="`rsec'"
		drop `mt' `mt1'
		
    * Test
      /*
	  gen `var'rc1 = `var'r_g + `var'r_h + `var'r_c + `var'r_r
	  gen `var'r_diff = `var'rc1 - `var'r
	  //browse geo YEAR sector `var'r_diff `var'p_diff if sec=="h" | sec=="c" | sec=="g" | sec=="t"

      drop `var'pc1 `var'rc1 `var'r_diff `var'p_diff
      */
	  
	 
  ************************************************************
  * D72: Non-life insurance claims
  ************************************************************
    local var "D72"
                               
  * paid: total by sector
    gen `var'_h1 = `var'p if sec=="h"
    gen `var'_c1 = `var'p if sec=="c"
    gen `var'_g1 = `var'p if sec=="g"
    gen `var'_r1 = `var'p if sec=="r"
    bysort geo YEAR: egen `var'pg = total(`var'_g1)
    bysort geo YEAR: egen `var'pc = total(`var'_c1)
    bysort geo YEAR: egen `var'ph = total(`var'_h1)
    bysort geo YEAR: egen `var'pr = total(`var'_r1)
    drop `var'_g* `var'_c* `var'_r* `var'_h1
			  
  * received: total by sector
    gen `var'_h1 = `var'r if sec=="h"  
    gen `var'_c1 = `var'r if sec=="c"  
    gen `var'_g1 = `var'r if sec=="g" 
    gen `var'_r1 = `var'r if sec=="r"
    bysort geo YEAR: egen `var'rh = total(`var'_h1)
    bysort geo YEAR: egen `var'rc = total(`var'_c1)
    bysort geo YEAR: egen `var'rg = total(`var'_g1)
    bysort geo YEAR: egen `var'rr = total(`var'_r1)
    drop `var'_h*  `var'_c* `var'_g* `var'_r* 
	 
	//browse geo YEAR sector D72p* D72r*

	
    * ROW sector: paid to HH and C, received from C
	
     gen `var'r_r = `var'pr * `var'r / (`var'rc + `var'rh) if sector=="S11" | sector=="S12" | sector=="S14_S15"
     replace `var'r_r = 0 if `var'r_r==.
	  	 
     gen `var'r_c = `var'rr if sector=="S2"	 
	 gen `var'p_r = `var'rr * `var'p/`var'pc if sector=="S11" | sector=="S12"
	 replace `var'p_r = 0 if `var'p_r==.
	 
	 * Government sector: received from R, paid to HH
	 
	 replace `var'r_c = `var'r  if sector=="S13"
	 gen `var'p_g = `var'rg * `var'p / `var'pc if sector=="S11" | sector=="S12"
	 replace `var'p_g = 0 if `var'p_g==.
	 
	 gen `var'p_h = `var'pg  if sector=="S13"
	 gen `var'r_g = `var'pg  if sector=="S14_S15"
	 replace `var'r_g = 0 if `var'r_g==.
	 
	 * Households: From corporation to households is the rest of received by households
	 replace `var'r_c = `var'r - `var'r_r - `var'r_g if sector=="S14_S15"
	 // replace `var'r_c = 0 if `var'r_c==.
	 
     local psec	"c" // corporations to households
     local rsec "h"
        gen `var'_`rsec'_`psec'1 = `var'r_`psec' if sec=="`rsec'"
        bysort geo YEAR: egen `var'_`rsec'_`psec' = total(`var'_`rsec'_`psec'1 )
		drop `var'_`rsec'_`psec'1
        replace `var'p_`rsec' = `var'_`rsec'_`psec' if sec=="`psec'"
	replace `var'p_h = 0 if `var'p_h==.
	replace `var'p_h = `var'p_h * `var'p / `var'pc if sec=="c"

	 * Corporations: Not distributed from corporations goes to corporations
	 gen `var'p_c = `var'p - `var'p_h - `var'p_r - `var'p_g if sector=="S12" | sector=="S11"
	 
	 replace `var'p_c = 0 if `var'p_c==.
	 
	 replace `var'r_c = `var'r - `var'r_r if sector=="S12" | sector=="S11"
	 replace `var'r_c = 0 if `var'r_c==.
	 
	 * Test
	 * NOTE: `var'r_h = 0 is NOT purely diagnostic - D72r_h is used downstream
	 * in Aggr_ESA2010.do's TX and TPXr formulas, so this line stays active
	 * even though the rest of this block (the reconciliation check) is
	 * commented out below.
	 gen `var'r_h = 0
	 /*
	 gen `var'rc1 = `var'r_g + `var'r_h + `var'r_c + `var'r_r
	 gen `var'pc1 = `var'p_g + `var'p_h + `var'p_c + `var'p_r

	 gen `var'p_diff = `var'pc1 - `var'p
	 gen `var'r_diff = `var'rc1 - `var'r

	 //browse YEAR geo sector `var'r `var'rc1 `var'p `var'pc1 `var'p_diff  `var'r_diff if sec=="c" | sec=="h" | sec=="g" | sec=="t"

     drop `var'pc1 `var'rc1 `var'r_diff `var'p_diff
     */
	 

	
  ************************************************************
  * D74: Current international cooperation
  ************************************************************
    local var "D74" // only between r and g
	
          
  ************************************************************
  * D75: Miscellaneous current transfers
  ************************************************************
    local var "D75" 
	
   * paid: total by sector
    gen `var'_h1 = `var'p if sec=="h"
    gen `var'_c1 = `var'p if sec=="c"
    gen `var'_g1 = `var'p if sec=="g"
    gen `var'_r1 = `var'p if sec=="r"
    bysort geo YEAR: egen `var'pg = total(`var'_g1)
    bysort geo YEAR: egen `var'pc = total(`var'_c1)
    bysort geo YEAR: egen `var'ph = total(`var'_h1)
    bysort geo YEAR: egen `var'pr = total(`var'_r1)
    drop `var'_g* `var'_c* `var'_r* `var'_h1
			  
  * received: total by sector
    gen `var'_h1 = `var'r if sec=="h"  
    gen `var'_c1 = `var'r if sec=="c"  
    gen `var'_g1 = `var'r if sec=="g" 
    gen `var'_r1 = `var'r if sec=="r"
    bysort geo YEAR: egen `var'rh = total(`var'_h1)
    bysort geo YEAR: egen `var'rc = total(`var'_c1)
    bysort geo YEAR: egen `var'rg = total(`var'_g1)
    bysort geo YEAR: egen `var'rr = total(`var'_r1)
    drop `var'_h*  `var'_c* `var'_g* `var'_r* 
	
	
  * Directed flows from the sector totals, by four rules. Assigning all ROW
  * flows to households would not do: where ROW's D75 came from or went to
  * another sector, households' D75 with corporations would turn negative to
  * balance it (249 of 552 household rows, DE 2009 -10.6 bn).
  *   1. ROW pays to h and c in proportion to what each receives, at most what
  *      the two receive together; any rest goes to g.
  *   2. ROW receives from h and c in proportion to what each pays, at most
  *      what the two pay together; any rest comes from g.
  *   3. g pays to h and c in proportion to what they have left to receive,
  *      at most that amount; any rest stays within g (BG, HR, LT: g pays more
  *      D75 than h and c receive).
  *   4. h and c pay the remaining receipts of h and g in proportion to their
  *      remaining payments; the rest of what they pay goes to c.
  * Flows are non-negative wherever the sector totals are. Each sector's
  * payments add up exactly, as do the receipts of h, g and ROW; an imbalance
  * between total paid and received falls on corporations' receipts.
    tempvar x1 x2 x3 s hR cR gR hP cP gP r2h r2c r2g h2r c2r g2r g2h g2c g2g h2h c2h h2g c2g h2c c2c

  * 1. Paid by ROW
    gen double `x1'  = min(`var'pr, max(`var'rh,0) + max(`var'rc,0))
    gen double `s'   = cond(max(`var'rh,0) + max(`var'rc,0) > 0, max(`var'rh,0) / (max(`var'rh,0) + max(`var'rc,0)), 0)
    gen double `r2h' = `x1' * `s'
    gen double `r2c' = `x1' - `r2h'
    gen double `r2g' = `var'pr - `x1'
    drop `s'

  * 2. Received by ROW
    gen double `x2'  = min(`var'rr, max(`var'ph,0) + max(`var'pc,0))
    gen double `s'   = cond(max(`var'ph,0) + max(`var'pc,0) > 0, max(`var'ph,0) / (max(`var'ph,0) + max(`var'pc,0)), 0)
    gen double `h2r' = `x2' * `s'
    gen double `c2r' = `x2' - `h2r'
    gen double `g2r' = `var'rr - `x2'
    drop `s'

  * What is left after the ROW flows
    gen double `hR' = `var'rh - `r2h'
    gen double `cR' = `var'rc - `r2c'
    gen double `gR' = `var'rg - `r2g'
    gen double `hP' = `var'ph - `h2r'
    gen double `cP' = `var'pc - `c2r'
    gen double `gP' = `var'pg - `g2r'

  * 3. Paid by government
    gen double `x3'  = min(max(`gP',0), max(`hR',0) + max(`cR',0))
    gen double `s'   = cond(max(`hR',0) + max(`cR',0) > 0, max(`hR',0) / (max(`hR',0) + max(`cR',0)), 0)
    gen double `g2h' = `x3' * `s'
    gen double `g2c' = `x3' - `g2h'
    gen double `g2g' = `gP' - `x3'
    drop `s'
    replace `hR' = `hR' - `g2h'
    replace `cR' = `cR' - `g2c'
    replace `gR' = `gR' - `g2g'

  * 4. Paid by households and corporations
    gen double `s'   = cond(max(`hP',0) + max(`cP',0) > 0, max(`hP',0) / (max(`hP',0) + max(`cP',0)), 0)
    gen double `h2h' = `hR' * `s'
    gen double `c2h' = `hR' * (1 - `s')
    gen double `h2g' = `gR' * `s'
    gen double `c2g' = `gR' * (1 - `s')
    gen double `h2c' = `hP' - `h2h' - `h2g'
    gen double `c2c' = `cP' - `c2h' - `c2g'

  * Directed flows on each sector's row (ROW and total economy rows stay 0)
    gen `var'p_h = 0
    gen `var'p_c = 0
    gen `var'p_g = 0
    gen `var'p_r = 0
    gen `var'r_h = 0
    gen `var'r_c = 0
    gen `var'r_g = 0
    gen `var'r_r = 0

    replace `var'p_h = `h2h' if sec=="h"
    replace `var'p_c = `h2c' if sec=="h"
    replace `var'p_g = `h2g' if sec=="h"
    replace `var'p_r = `h2r' if sec=="h"
    replace `var'r_h = `h2h' if sec=="h"
    replace `var'r_c = `c2h' if sec=="h"
    replace `var'r_g = `g2h' if sec=="h"
    replace `var'r_r = `r2h' if sec=="h"

    replace `var'p_h = `g2h' if sec=="g"
    replace `var'p_c = `g2c' if sec=="g"
    replace `var'p_g = `g2g' if sec=="g"
    replace `var'p_r = `g2r' if sec=="g"
    replace `var'r_h = `h2g' if sec=="g"
    replace `var'r_c = `c2g' if sec=="g"
    replace `var'r_g = `g2g' if sec=="g"
    replace `var'r_r = `r2g' if sec=="g"

    replace `var'p_h = `c2h' if sec=="c"
    replace `var'p_c = `c2c' if sec=="c"
    replace `var'p_g = `c2g' if sec=="c"
    replace `var'p_r = `c2r' if sec=="c"
    replace `var'r_h = `h2c' if sec=="c"
    replace `var'r_c = `c2c' if sec=="c"
    replace `var'r_g = `g2c' if sec=="c"
    replace `var'r_r = `r2c' if sec=="c"
    drop `x1' `x2' `x3' `s' `hR' `cR' `gR' `hP' `cP' `gP' `r2h' `r2c' `r2g' `h2r' `c2r' `g2r' `g2h' `g2c' `g2g' `h2h' `c2h' `h2g' `c2g' `h2c' `c2c'
	sort geo YEAR sector

  * S11 and S12 rows: split corporations' flows by each subsector's own
  * payments (p_) and receipts (r_)
    corpdist `var'p_h `var'p
    corpdist `var'p_c `var'p
    corpdist `var'p_g `var'p
    corpdist `var'p_r `var'p
    corpdist `var'r_h `var'r
    corpdist `var'r_c `var'r
    corpdist `var'r_g `var'r
    corpdist `var'r_r `var'r
	
  * Test
	/*
    gen `var'pc1 = `var'p_h + `var'p_c + `var'p_g + `var'p_r
    gen `var'rc1 = `var'r_h + `var'r_c + `var'r_g + `var'r_r

    gen `var'p_diff = `var'pc1 - `var'p
    gen `var'r_diff = `var'rc1 - `var'r

	//browse geo sector YEAR `var'p `var'pc1 `var'r `var'rc1 `var'r_diff `var'p_diff

    drop `var'pc1 `var'rc1 `var'r_diff `var'p_diff
    */

	 * Test if total paid and received by domestic sectors add up
      /*
	  gen dom1 = `var'p_g + `var'p_h + `var'p_c - `var'r_g - `var'r_h - `var'r_c  if sec=="h" | sec=="c" | sec=="g"
	  bysort geo YEAR: egen dom = total(dom1)
	  //browse geo YEAR sector dom
	  drop dom*
	  */
	
  ************************************************************
  * D76: VAT and GNI-based EU own resources
  ************************************************************
    local var "D76" // only from gov to ROW

