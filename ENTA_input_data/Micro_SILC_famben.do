  *****************************
  * 3.0 Individualize family and child benefits
    * (goes to parents of children in education)
  ****************************

  * Called via `do Micro_SILC_famben.do` from Micro_SILC.do (Section 3) -
  * NOT a standalone file. Runs in the same session on the dataset
  * already in memory, and depends on it containing:
  *   ACTIVITY, AGE, RB220, RB230, HHID, YEAR, PID   (education/parent-ID
  *                                                    lookup)
  *   COUPLEID, ADULT, NADULT                        (benefit distribution)
  *   HY050G, HY050N                                 (family benefit
  *                                                    amounts to individualize)
  *   PY010G PY020G PY050G PY080G PY090G PY100G PY110G PY120G PY130G
  *   PY140G                                         (-> PYG, income share)
  * If any of these is dropped earlier in Micro_SILC.do before this call,
  * the run halts here.

    gen PYG = PY010G + PY020G + PY050G + PY080G + PY090G + PY100G + PY110G + PY120G + PY130G + PY140G
	
    tempfile data
    save `data', replace

    * Lookup of every real household member (YEAR HHID PID), used below to
    * verify that RB220/RB230 (father/mother ID) point to someone actually
    * co-resident. EU-SILC can leave these IDs populated (well, one case in Austria) even when the
    * parent or the child has left the household, so a missing-value check alone is not
    * sufficient - the ID may still point to (or collide with) an
    * unrelated person's real PID at merge time.
      preserve
        keep YEAR HHID PID
        tempfile hhmembers
        save `hhmembers'
      restore

    * Information on the children of fathers (RB220): number and education status ****************
  	  // generate the desired information for children, save data, and merge it with the data of the father
	
	  * Education status
	    gen EDUC = 0
	      replace EDUC = 1 if ACTIVITY==1 & AGE<35
	      label var EDUC "in education and younger than 35"

	  * Verify the father (RB220) actually lives in this household: his ID
	  * must match a real person's PID within the same HHID and YEAR.
	    drop PID
	    rename RB220 PID
	    merge m:1 YEAR HHID PID using `hhmembers', keep(master match)
	    rename PID RB220
	    replace RB220 = . if _merge!=3  // not co-resident (or was missing)
	    drop _merge

	  * Keep the information for children whose father is identified in the survey
	    keep EDUC RB220 HHID YEAR
	    drop if RB220==.  // drop if father is not living in the same household
        rename RB220 PID // father ID becomes ID - for merging
 
      * Identify siblings (children of a certain person)
        egen SIBLING = group(YEAR HHID PID)  // group all children of a person who live in the HH
        sort SIBLING
		
      * Number of children in education
	    by SIBLING: egen EDUCHILD=total(EDUC==1) 
	      label var EDUCHILD "number of children in education"
		
      * Number of children 
	    bysort YEAR HHID SIBLING: egen NCHILD=count(PID) 
	      label var NCHILD "number of children"
		
	  * Select "representative" sibling
        egen SIBLINGTAG = tag(SIBLING)     
        keep if SIBLINGTAG==1 

	  * Save child dataset
	    sort YEAR PID
        tempfile fatherdata
	    save `fatherdata'
	  
    * Information on children of mothers (RB230) ****************
  
	  use `data', clear
	
	  * Education status
	    gen EDUC = 0
	      replace EDUC = 1 if ACTIVITY==1 & AGE<35
	      label var EDUC "in education an younger than 35"

	  * Verify the mother (RB230) actually lives in this household: her ID
	  * must match a real person's PID within the same HHID and YEAR.
	    drop PID
	    rename RB230 PID
	    merge m:1 YEAR HHID PID using `hhmembers', keep(master match)
	    rename PID RB230
	    replace RB230 = . if _merge!=3  // not co-resident (or was missing)
	    drop _merge

	  * Keep data for those persons whose mother is in the survey
	    keep EDUC RB230 HHID YEAR
	    drop if RB230==.  // drop if mother is not living in the same household
        rename RB230 PID // mothers ID becomes ID - for merging
 
      * Identify siblings (children of a certain person)
        egen SIBLING = group(YEAR HHID PID)  // group all children of a person who live in the HH
        sort SIBLING
		
      * Number of children in education
	    by SIBLING: egen EDUCHILD=total(EDUC==1) 
	      label var EDUCHILD "number of children in education"
		
      * Number of children 
	    bysort YEAR HHID SIBLING: egen NCHILD=count(PID) 
	      label var NCHILD "number of children"
		
	  * Select "representative"
        egen SIBLINGTAG = tag(SIBLING)     
        keep if SIBLINGTAG==1 

	  * Save child dataset
	    sort YEAR PID
        tempfile motherdata
	    save `motherdata'
	  
    * Merge datasets *****************************
	
      use `data', clear
	  
	  sort YEAR PID
	  merge 1:1 YEAR PID using `fatherdata', update
	  
	  drop _merge
	  
	  sort YEAR PID
	  merge 1:1 YEAR PID using `motherdata', update
	  
	  drop _merge
	  
    * Distribute family benefits *****************
      // Family benefits are distributed to parents with children in education
	  // inverse to their income share; otherwise to all adults of the
	  // household, also inverse to their income share

	  * Share of primary income within couples, bounded to [0,1]. Unbounded, a
	  * partner with negative PYG would push the share outside [0,1], so one
	  * partner would get negative family benefits and the other more than the
	  * household received. Couple income not positive: no share, equal split.
	      bysort YEAR HHID COUPLEID: egen inc_couple = sum(PYG) if COUPLEID!=.
	      gen incshare_couple = min(max(PYG/inc_couple, 0), 1) if inc_couple>0 & inc_couple<.
		  //browse PYG inc_couple COUPLEID incshare_couple
		  // Family benefits should be assigned to the person who carries out most of the childcare

	  * Number of children in education is the maximum within couples, assuming that couples care together for children
	    * even if one of the partners is not father/mother
	      bysort YEAR HHID COUPLEID: egen NEDUCHILD = max(EDUCHILD) if COUPLEID!=.
	      replace NEDUCHILD = EDUCHILD if COUPLEID==.
		  
	  * Children are distributed within couples according to inverse of income share
	    // the indicator serves as weight to distribute family benefits
		  replace NEDUCHILD = NEDUCHILD*(1-incshare_couple) if incshare_couple!=.
		  
	  * Generation of weights summing up to 1 within the household
	      bysort YEAR HHID: egen NEDUCHILDHH = sum(NEDUCHILD)
		  replace NEDUCHILD = NEDUCHILD/NEDUCHILDHH
		  
	  * If children cannot be identified the family transfers are assigned to
	  * all adults, inversely to their share of the adults' primary income
	  * (bounded to [0,1], renormalised within the household). We do not know
	  * which couple, if any, receives them. Equal shares where that income is
	  * not positive or there is only one adult.
	      drop NEDUCHILDHH
	      bysort YEAR HHID: egen NEDUCHILDHH = sum(NEDUCHILD)
	      bysort YEAR HHID: egen famb_inc = sum(PYG*(ADULT==1))
	      gen famb_w = 1 - min(max(PYG/famb_inc, 0), 1) if ADULT==1 & famb_inc>0 & famb_inc<.
	      bysort YEAR HHID: egen famb_sw = sum(famb_w)
		  replace NEDUCHILD = famb_w/famb_sw if ADULT==1 & NEDUCHILDHH==0 & famb_sw>0
		  replace NEDUCHILD = 1/NADULT if ADULT==1 & NEDUCHILDHH==0 & !(famb_sw>0)
	      drop famb_inc famb_w famb_sw
		
 	  gen HY050Gp = HY050G*NEDUCHILD
	    replace HY050Gp = 0 if HY050Gp==.
		label var HY050Gp "Individualized family benefits, gross"

		
 	  * Net income variable commented out - not used downstream (Micro_
	  * SILC.do's own BSPN, the one consumer, is itself commented out
	  * there with the same "not used" note), gross (HY050Gp) used
	  * throughout - matching the convention already established for
	  * every other net-income variable in Micro_SILC.do.
	  //gen HY050Np = HY050N*NEDUCHILD
	  //replace HY050Np = 0 if HY050Np==.
 	  // gen HY050Np = 0 // alternative assignment to all households
	  //replace HY050Np = HY050N/NADULT if ADULT==1
	  //label var HY050Np "Individualized family benefits, net"

	  * Control if values add up
	    //bysort YEAR HHID: egen cHY050Gp = sum(HY050Gp)
	    //bysort YEAR HHID: egen cHY050Np = sum(HY050Np)
	    //browse YEAR HHID AGE SEX HY050N HY050Gp cHY050Np cHY050Gp HY050Np HY050N HY050G

		//sum HY050N cHY050Np