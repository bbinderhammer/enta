################################################################################
# diagnostic_scan.R - ENTA diagnostic scan                       (2026-09-26)
################################################################################
#
# WHAT IT DOES
#   Reads the four published CSVs in ENTA_output_data (ENTA_esa, ENTA_nta,
#   ENTA_aggregates, ENTA_units) and runs every check listed in checks.csv.
#   Each check returns flags in one common format. Flags of judgement checks
#   are then matched against the event ledger, and everything is written to
#       out/diag_flags.csv   every flag, one row each, with its STATUS
#       out/diag_report.md   READ THIS: summary per check, parameters used,
#                            then only what needs a look
#   STATUS is one of
#       FAIL       a check whose LEDGER is "no" failed - a defect to fix;
#                  no event can explain it away
#       EXPLAINED  matched by an event in the ledger (EVENT names it)
#       EU-WIDE    not in the ledger, but the same indicator moved the same
#                  way in most countries that year (see eu_share); listed,
#                  not counted as new
#       GDP-DRIVEN not in the ledger, a level break (B1) where GDP moved and
#                  the item hardly did (see b1_gdp_move); listed, not new
#       NEW        needs a look
#   Run it after every change to the pipeline (the last step of the pipeline
#   order in CLAUDE.md). A run that reports no FAIL and no NEW means the
#   published output is in its known state.
#
# HOW TO RUN (from the ENTA project root, ~3-5 minutes)
#   "C:\Program Files\R\R-4.6.1\bin\Rscript.exe" ENTA_diagnostic/diagnostic_scan.R
#
# FILES IN THIS FOLDER
#   diagnostic_scan.R  this file: parameters (section 1) and check code
#   checks.csv         the check registry: one row per check - what it tests,
#                      family, whether the ledger may explain it (LEDGER),
#                      and which parameters it uses (PARAMS)
#   identities.csv     the accounting identities check I2 tests
#   nta_esa_same.csv   NTA codes whose series is an exact copy of an ESA series
#                      (e.g. TGICU = BSU). I2 verifies it every run; the other
#                      profile checks skip the copies, and the ledger treats
#                      the two codes as one.
#   events.csv         the ledger, part 1: one row per EVENT - what happened,
#                      written once
#   event_scope.csv    the ledger, part 2: which flags an event explains
#   make_nta_esa_same.R   re-measures nta_esa_same.csv (run after a code change)
#   scan_decisions.md  why each check is built as it is, and what was dropped
#   out/               written by every run; nothing in it is hand-kept
#
# ------------------------------------------------------------------------------
# HOW TO CHANGE OR EXTEND IT
# ------------------------------------------------------------------------------
#   A. Change a threshold
#      Edit the value in the list P in section 1. Every threshold lives there
#      and nowhere else; checks.csv only names the parameters each check uses,
#      and the report prints the value of every parameter used in the run.
#
#   B. Add a check
#      1. Add a row to checks.csv: a new ID, FAMILY, NAME, LEDGER (yes = an
#         event may explain its flags; no = every flag is a FAIL), a short
#         WHAT_IT_TESTS, and the PARAMS it uses.
#      2. Add any new parameters to P (section 1).
#      3. Write a function chk_<ID>() in section 3, next to the others. It
#         returns list(flags = flag(...), tested = <number of units tested>).
#         flag() (section 2) builds the common flag format; fill what applies.
#      The scan runs every ID in checks.csv and stops with a message if a row
#      has no function, a function has no row, or PARAMS names an unknown
#      parameter - so a check cannot silently drop out.
#      To retire a check, delete its row and its function.
#
#   C. Add a family
#      Use a new FAMILY value in checks.csv. A family is only a heading in the
#      report; what matters for each check is its LEDGER column.
#
#   D. Add an identity
#      Add a row to identities.csv: FILE is aggregates, esa or nta; SECTOR is
#      needed for aggregates only; LHS and RHS are codes joined by + and -
#      with spaces around the signs; a break needs |LHS - RHS| > TOL_ABS
#      (mio EUR for aggregates, EUR per person for profiles) and, for
#      aggregates, a relative residual above TOL_REL too.
#
#   E. Explain flags (add an event)
#      1. events.csv: the next free EVENT id (E172 after E171), a short TITLE, the
#         EXPLANATION (what happened and how it was verified) and BUG_REFS.
#      2. event_scope.csv: one row per group of flags it explains. Every
#         column other than EVENT and NOTE is a filter and accepts * for "any":
#            CHECK   a judgement check id (B1, B2, ...) or * for all of them
#            CNT2    country code
#            YEAR    a year, a range such as 1996-1999, or *
#            SECTOR  aggregates sector (B1, S1, S2 only), or *
#            IND     indicator code; an NTA copy and its ESA twin are one code
#         NOTE is optional: what is specific to this row.
#      A flag matched by several events lists them all. An event can never
#      explain a check whose LEDGER is "no". Scope rows that matched nothing
#      in the run are listed at the end of the report, so a stale rule shows.
#
#   F. Change what counts as EU-wide
#      Parameters eu_share and eu_min_n in P. Set eu_share to 2 to switch the
#      automatic tag off.
#
################################################################################

suppressPackageStartupMessages(library(data.table))
if (!dir.exists("ENTA_output_data")) stop("Run from the ENTA project root.")
od  <- "ENTA_output_data"
dd  <- "ENTA_diagnostic"
out <- file.path(dd, "out")
dir.create(out, showWarnings = FALSE)

################################################################################
# 1. Parameters - the only place thresholds are set
################################################################################

P <- list(
  # shared by the judgement checks B1, B3, P1 (B2 scores a distance, see b2_ratio)
  z           = 6,      # robust score above which a change is unusual: |x - median| / median absolute deviation, within the series
  minyears    = 8,      # series with fewer scored years are not scored
  eu_share    = 0.75,   # EU-WIDE: at least this share of countries moved the same direction that year ...
  eu_min_n    = 10,     # ... out of at least this many countries with data
  twin_tol    = 1e-5,   # two profiles are shape twins (scanned once by B2, B3, P1) if their normalised
                        # age shapes differ by less than this at every age, country, year and sex
  # I1 reconciliation
  i1_rel      = 1e-4,   # relative residual counted as a break (0.01%) ...
  i1_abs      = 10,     # ... AND absolute residual above this (mio EUR; ESA values are rounded to the million)
  i1_minagg   = 1,      # aggregates below this (mio EUR) have no relative residual
  i1_systematic = 0.5,  # an indicator breaking in more than this share of country-years is one finding: 'definition differs'
  i1_skip     = c("esa:YD", "nta:C"),  # profiles with no aggregate of their own; a same-named aggregate is another concept
                                       # (YD: Corporations/NTA YD; C: Government C) - comparing them only reports the collision
  # I2 identities (tolerances of the identities themselves are in identities.csv)
  i2_copy_rel = 1e-6,   # NTA copy vs its ESA twin: relative difference allowed (rounding in the CSV)
  # I3 men + women = total
  i3_rel      = 1e-4,   # residual relative to the gross mass sum(|X| x POP)
  i3_pop      = 1,      # POP: persons
  # I4 signs, I3 exclusions: variable lists
  nonneg      = c("CH","CHE","CHH","CHNR","CHR","CHX","BS","BSFAM","BSU","BSX","BSPEN","BSPPEN",
                  "YE","YM","YEM","YO",          # no income component is negative after smoothing (project owner)
                  "BPSOCfc","TBPPEN"),           # funded pensions received, and the tax on them
  nonneg_young = c(),   # indicators that must not be negative below a given age, e.g. c(YP = 20). Empty: the
                        # project owner accepts negative YP at young ages (2026-09-26) - SILC has few observations
                        # there, and scaling YPr and YPp to their aggregates can make YP negative (#278)
  nonneg_except = c("EE:BPSOCfc"),  # source values kept (project owner, 2026-09-25): Eurostat reports negative D62
                                    # paid by EE S12 in 2013-2017 and 2019, the only negative cells in the table (DX-03)
  nonflow     = c("EHI","EMPLSTAT","EMPLSTATsilc","EMPLFT","WHRUSUT","WHRACTT"),  # averages and non-monetary
  # S1 grid
  ages        = 0:80,   # every profile carries exactly these ages
  # S2 zero-filled aggregates
  s2_gdp      = 0.002,  # the series must reach this share of GDP somewhere to count
  # S3 carried forward
  s3_digits   = 8,      # significant digits compared
  # S5 units
  s5_hicp     = 0.5,    # HICP 2020 may differ from 100 by this much
  s5_pop      = 0.001,  # POPtot vs the POP profile: relative difference allowed
  # B1 level breaks
  b1_min      = 0.002,  # the change must also move 0.2% of GDP
  b1_gdp_move = 0.05,   # GDP-DRIVEN: GDP moved at least this much while the item moved less than half as much -
                        # the share broke because of the denominator (IE 2015, HR 2020); listed, not counted as new
  agg_twin_tol = 0.005, # two aggregate series are one (scored once by B1) if their absolute values differ by
                        # less than this share in every country-year where both exceed 1 mio EUR
  # B2 shape breaks
  b2_ratio    = 6,      # the shape must move this many times more than it usually does from one year to the next
  b2_weight   = 0.005,  # indicator must be at least 0.5% of household primary income
  b2_mass     = 0.125,  # at least this share of the profile mass must move to other ages
  # B3 male share
  b3_min      = 0.02,   # male share must move at least 2 percentage points
  b3_cancel   = 0.05,   # skip indicators whose sexes cancel over ages by more than this share
  # P1 spikes and kinks (share of the profile's maximum |value|)
  p1_spike    = 0.20,   # deviation of a spike from what is usual at that age
  p1_kink     = 0.30,   # deviation of a step from what is usual at that age
  p1_skip     = c("BSU"),  # built-in: BSU keeps RAW survey values above its pension-age cliff, whose age moves
                           # with pension reforms - 159 of 336 P1 flags on 2026-09-25
  p1_ages     = c(0:14, 20:79),  # ages scanned (project owner, 2026-09-25): 15-19 have few observations and
                                 # year-to-year jumps are accepted; 80 is the open 80+ group, not smoothed, and its
                                 # step from 79 is expected. A spike needs both neighbours inside this range.
  # P2 plateaus
  p2_len      = 3,      # run of identical non-zero values at least this many ages ...
  p2_nind     = 5,      # ... shared by at least this many indicators in a country-year
  p2_ages     = 18:79   # ages scanned (the 15-17 cap in ENTA_income/ENTA_taxes is by design)
)

################################################################################
# 2. Data and helpers
################################################################################

cat("Reading ...\n")
rd <- function(f, lab) fread(file.path(od, f), select = c("CNT2","YEAR","AGE","VALUE","IND","SEX","INDICATOR"))[, FILE := lab]
esa  <- rd("ENTA_esa.csv", "esa")
nta  <- rd("ENTA_nta.csv", "nta")
agg  <- fread(file.path(od, "ENTA_aggregates.csv"))
uni  <- fread(file.path(od, "ENTA_units.csv"))
copies <- fread(file.path(dd, "nta_esa_same.csv"))         # NTA, ESA (made by make_nta_esa_same.R)
checks <- fread(file.path(dd, "checks.csv"), colClasses = "character")
ids    <- fread(file.path(dd, "identities.csv"), colClasses = "character")

labels <- unique(rbind(esa, nta)[, .(FILE, IND, INDICATOR)])
esa[, INDICATOR := NULL]; nta[, INDICATOR := NULL]
pr <- rbind(esa, nta); rm(esa, nta); invisible(gc())
pop <- pr[FILE == "esa" & IND == "POP", .(CNT2, YEAR, SEX, AGE, POP = VALUE)]
pr  <- pr[IND != "POP"]
# Aliases: NTA copies of an ESA series (nta_esa_same.csv), plus NTA codes that
# an identity in identities.csv sets equal to a single other code (YDC = SC).
# An alias is verified by I2 and skipped by the other profile checks.
al <- ids[FILE == "nta" & !grepl(" ", trimws(RHS)) & !grepl(" ", trimws(LHS)), .(NTA = LHS, ESA = RHS)]
al[, ESA := ifelse(ESA %in% copies$NTA, copies$ESA[match(ESA, copies$NTA)], ESA)]
same <- rbind(copies, al)
pr[, COPY := FILE == "nta" & IND %in% same$NTA]
pr  <- merge(pr, pop, by = c("CNT2","YEAR","SEX","AGE"))
setkey(pr, FILE, CNT2, IND, SEX, YEAR, AGE)

# Shape twins: profiles that are the same age shape, rescaled, in every
# country, year and sex - e.g. YC, TC and BPBC are all the YPr shape scaled to
# their own aggregates, and BPPC = -BPPEN. The level differs, so they are
# separate indicators for I1 and B1, but the shape checks B2, B3 and P1 would
# flag them together every time. Measured on each run; each group is scanned
# once, under its first code, and the report lists the groups.
sg <- pr[COPY == FALSE & !IND %in% P$nonflow, .(AGE, p = VALUE / sum(abs(VALUE)) * sign(sum(VALUE))), by = .(FILE, IND, CNT2, YEAR, SEX)]
sg[, key := paste(FILE, CNT2, YEAR, SEX, AGE)]
sw <- dcast(sg, key ~ paste0(FILE, ":", IND), value.var = "p")
cands <- setdiff(names(sw), "key")
twin_of <- setNames(cands, cands)
for (i in seq_along(cands)[-1]) for (j in seq_len(i - 1)) {
  a <- sw[[cands[i]]]; b <- sw[[cands[j]]]
  if (twin_of[cands[j]] != cands[j]) next                  # compare with group heads only
  if (!identical(is.na(a), is.na(b))) next                 # same coverage
  if (max(abs(a - b), na.rm = TRUE) < P$twin_tol) { twin_of[cands[i]] <- cands[j]; break }
}
twins <- names(twin_of)[twin_of != names(twin_of)]
twingroups <- data.table(member = names(twin_of), head = twin_of)[head %in% twin_of[twins]][
  , .(members = paste(member, collapse = " ")), by = head][, .(members)]
pr[, TWIN := paste0(FILE, ":", IND) %in% twins]
rm(sg, sw)

EU     <- sort(unique(pr$CNT2))                            # countries with profiles
YRS    <- range(pr$YEAR)                                   # profile years
MON    <- function(ind) !ind %in% P$nonflow                # monetary flow profile?
canon  <- function(ind) { i <- match(ind, same$NTA); ifelse(is.na(i), ind, same$ESA[i]) }

# Household primary income (mio EUR), the denominator for household shares
YHH <- agg[SECTOR == "Households" & IND == "Y", .(CNT2, YEAR, YHH = VALAGGR)]
GDP <- agg[SECTOR == "Total economy" & IND == "GDP", .(CNT2, YEAR, GDP = VALAGGR)]

# Robust score within a series: |x - median| / median absolute deviation.
# Falls back to the mean absolute deviation when more than half the values
# are identical; NA when the series does not vary at all.
rscore <- function(x) {
  m <- median(x, na.rm = TRUE); s <- median(abs(x - m), na.rm = TRUE)
  if (!is.finite(s) || s == 0) s <- mean(abs(x - m), na.rm = TRUE)
  if (!is.finite(s) || s == 0) return(rep(NA_real_, length(x)))
  abs(x - m) / s
}

# The common flag format. Every check returns its flags through this.
flag <- function(CHECK, CNT2 = NA_character_, YEAR = NA_integer_, SECTOR = NA_character_,
                 FILE = NA_character_, IND = NA_character_, SEX = NA_character_,
                 VALUE = NA_real_, SCORE = NA_real_, DETAIL = NA_character_, EU = FALSE, AUTO = NA_character_) {
  n <- max(length(CNT2), length(IND), length(DETAIL), length(YEAR))
  if (n == 0 || (length(CNT2) == 0 && length(IND) == 0)) return(NULL)
  data.table(CHECK, CNT2 = as.character(CNT2), YEAR = as.integer(YEAR), SECTOR = as.character(SECTOR),
             FILE = as.character(FILE), IND = as.character(IND), SEX = as.character(SEX),
             VALUE = as.numeric(VALUE), SCORE = round(as.numeric(SCORE), 1),
             DETAIL = as.character(DETAIL), EU = as.logical(EU), AUTO = as.character(AUTO))
}

# EU-wide tag: did the same indicator move the same direction in most
# countries that year? col = the column holding the change, by = the columns that define "the
# same indicator" (e.g. SECTOR, IND). Returns the share moving with this row.
eushare <- function(col, x, by) {
  x <- copy(x); x[, sgn := sign(get(col))]
  x[!is.na(sgn), `:=`(n_up = sum(sgn > 0), n_dn = sum(sgn < 0)), by = c(by, "YEAR")]
  x[, `:=`(nn = n_up + n_dn, with = fifelse(sgn > 0, n_up, n_dn))]
  x[, EU := !is.na(nn) & nn >= P$eu_min_n & with / nn >= P$eu_share]
  x[, c("sgn","n_up","n_dn","nn","with") := NULL][]
}

################################################################################
# 3. Checks - one function per row of checks.csv
################################################################################

# ---- Invariants --------------------------------------------------------------

chk_I1 <- function() {
  pa <- pr[SEX == "Total" & !COPY & !paste0(FILE, ":", IND) %in% P$i1_skip,
           .(PROF = sum(VALUE * POP) / 1e6), by = .(FILE, CNT2, YEAR, IND)]
  x  <- merge(pa, agg[, .(CNT2, YEAR, IND, SECTOR, VALAGGR)], by = c("CNT2","YEAR","IND"), allow.cartesian = TRUE)
  x[, res := PROF - VALAGGR]
  x[, rel := abs(res) / fifelse(abs(VALAGGR) < P$i1_minagg, NA_real_, abs(VALAGGR))]
  x[abs(VALAGGR) < P$i1_minagg & abs(res) < P$i1_minagg, rel := 0]
  x[is.na(rel), rel := Inf]
  x[, nothh := SECTOR != "Households"]
  setorder(x, FILE, CNT2, YEAR, IND, rel, nothh)
  x <- x[, .SD[1], by = .(FILE, CNT2, YEAR, IND)]          # closest sector, Households on a tie
  x[, broken := rel > P$i1_rel & abs(res) > P$i1_abs]
  x[, rate := mean(broken), by = .(FILE, IND)]
  sys <- x[broken & rate > P$i1_systematic,
           .(n = .N, med = median(rel), mx = max(rel), sec = SECTOR[1]), by = .(FILE, IND)]
  spo <- x[broken & rate <= P$i1_systematic]
  list(tested = nrow(x), flags = rbind(
    flag("I1", CNT2 = rep("*", nrow(sys)), FILE = sys$FILE, IND = sys$IND, SECTOR = sys$sec,
         VALUE = sys$med, DETAIL = sprintf("definition differs: breaks in %d country-years, median %.3f%%, max %.3f%%",
                                           sys$n, 100 * sys$med, 100 * sys$mx)),
    flag("I1", spo$CNT2, spo$YEAR, spo$SECTOR, spo$FILE, spo$IND, "Total", spo$rel,
         DETAIL = sprintf("profile %.1f vs aggregate %.1f mio EUR", spo$PROF, spo$VALAGGR))))
}

# evaluate "A + B - C" on the columns of a wide table; NULL if a code is missing
evalx <- function(w, ex) {
  tk <- strsplit(trimws(ex), " +")[[1]]
  sg <- 1; v <- 0
  for (t in tk) {
    if (t == "+") { sg <- 1; next }
    if (t == "-") { sg <- -1; next }
    if (!t %in% names(w)) return(NULL)
    v <- v + sg * w[[t]]
  }
  v
}

chk_I2 <- function() {
  fl <- list(); tested <- 0; untestable <- character()
  for (i in seq_len(nrow(ids))) {
    r <- ids[i]; tol_abs <- as.numeric(r$TOL_ABS); tol_rel <- as.numeric(r$TOL_REL)
    if (r$FILE == "aggregates") {
      w <- dcast(agg[SECTOR == r$SECTOR & CNT2 %in% EU & YEAR >= YRS[1] & YEAR <= YRS[2]],
                 CNT2 + YEAR ~ IND, value.var = "VALAGGR")
      key <- c("CNT2","YEAR")
    } else {
      codes <- setdiff(unlist(strsplit(paste(r$LHS, r$RHS), " +")), c("+","-"))
      w <- dcast(pr[FILE == r$FILE & IND %in% codes], CNT2 + YEAR + SEX + AGE ~ IND, value.var = "VALUE")
      key <- c("CNT2","YEAR","SEX","AGE")
    }
    L <- evalx(w, r$LHS); R <- evalx(w, r$RHS)
    if (is.null(L) || is.null(R)) { untestable <- c(untestable, r$ID); next }
    w[, `:=`(d = L - R, lhs = L)]
    # A missing value makes the identity untestable in that cell, not broken:
    # the gap itself is S1's business (e.g. TXNPISH absent where the source has
    # no household/NPISH split).
    w <- w[!is.na(d)]
    tested <- tested + uniqueN(w[, .(CNT2, YEAR)])
    b <- w[abs(d) > tol_abs & abs(d) > tol_rel * abs(lhs)]
    if (nrow(b)) {
      b <- b[, .(d = max(abs(d)), n = .N), by = .(CNT2, YEAR)]
      fl[[length(fl) + 1]] <- flag("I2", b$CNT2, b$YEAR, if (r$FILE == "aggregates") r$SECTOR else NA,
                                   r$FILE, r$ID, VALUE = b$d,
                                   DETAIL = sprintf("%s = %s: max |residual| %.2f in %d cell(s)", r$LHS, r$RHS, b$d, b$n))
    }
  }
  # every NTA copy in nta_esa_same.csv equals its ESA twin (POP is in pop, not pr)
  for (i in which(copies$NTA != "POP")) {
    a <- pr[FILE == "nta" & IND == copies$NTA[i], .(CNT2, YEAR, SEX, AGE, n = VALUE)]
    e <- pr[FILE == "esa" & IND == copies$ESA[i], .(CNT2, YEAR, SEX, AGE, e = VALUE)]
    m <- merge(a, e, all = TRUE)
    tested <- tested + uniqueN(m[, .(CNT2, YEAR)])
    b <- m[is.na(n) | is.na(e) | abs(n - e) > P$i2_copy_rel * pmax(1, abs(e)), .(n = .N), by = .(CNT2, YEAR)]
    if (nrow(b)) fl[[length(fl) + 1]] <- flag("I2", b$CNT2, b$YEAR, FILE = "esa+nta", IND = copies$NTA[i],
                                             DETAIL = sprintf("NTA %s differs from ESA %s in %d cells", copies$NTA[i], copies$ESA[i], b$n))
  }
  if (length(untestable))
    fl[[length(fl) + 1]] <- flag("I2", CNT2 = "*", IND = untestable,
                                 DETAIL = "identity cannot be tested: a code is not in the published file")
  list(tested = tested, flags = rbindlist(fl))
}

chk_I3 <- function() {
  x <- pr[!COPY & MON(IND), .(M = sum(VALUE * POP), A = sum(abs(VALUE) * POP)), by = .(FILE, CNT2, YEAR, IND, SEX)]
  x <- dcast(x, FILE + CNT2 + YEAR + IND ~ SEX, value.var = c("M","A"))
  x[, rel := (M_Men + M_Women - M_Total) / pmax(A_Total, 1)]
  b <- x[is.na(rel) | abs(rel) > P$i3_rel]
  pw <- dcast(pop, CNT2 + YEAR + AGE ~ SEX, value.var = "POP")
  pb <- pw[is.na(Men + Women - Total) | abs(Men + Women - Total) > P$i3_pop, .(n = .N), by = .(CNT2, YEAR)]
  list(tested = nrow(x) + uniqueN(pw[, .(CNT2, YEAR)]), flags = rbind(
    flag("I3", b$CNT2, b$YEAR, FILE = b$FILE, IND = b$IND, VALUE = b$rel,
         DETAIL = sprintf("men + women - total = %.4f%% of the gross mass", 100 * b$rel)),
    flag("I3", pb$CNT2, pb$YEAR, FILE = "esa", IND = "POP",
         DETAIL = sprintf("POP men + women != total at %d ages", pb$n))))
}

chk_I4 <- function() {
  v <- c(P$nonneg, same[ESA %in% P$nonneg, NTA])
  young <- if (length(P$nonneg_young)) pr[, IND %in% names(P$nonneg_young) & AGE < P$nonneg_young[IND]] else FALSE
  x <- pr[IND %in% v | young]
  x <- x[!paste0(CNT2, ":", canon(IND)) %in% P$nonneg_except]
  # -0.5 EUR: the published CSV rounds, so a true 0 can come back as -0.0001
  b <- x[VALUE < -0.5, .(mn = min(VALUE), n = .N), by = .(FILE, CNT2, YEAR, IND, SEX)]
  list(tested = uniqueN(x[, .(FILE, CNT2, YEAR, IND, SEX)]),
       flags = flag("I4", b$CNT2, b$YEAR, FILE = b$FILE, IND = b$IND, SEX = b$SEX, VALUE = b$mn,
                    DETAIL = sprintf("%d ages below 0, minimum %.2f", b$n, b$mn)))
}

# ---- Structure ---------------------------------------------------------------

chk_S1 <- function() {
  # a country-year missing indicators its file carries elsewhere
  cy   <- unique(pr[, .(FILE, CNT2, YEAR, IND)])
  full <- cy[, CJ(CNT2 = EU, YEAR = YRS[1]:YRS[2], IND = unique(IND)), by = FILE]
  miss <- full[!cy, on = .(FILE, CNT2, YEAR, IND)][, .(n = .N, ex = paste(head(IND, 4), collapse = " ")), by = .(FILE, CNT2, YEAR)]
  # a profile without the full age range
  ag   <- pr[, .(n = .N, ok = setequal(AGE, P$ages)), by = .(FILE, CNT2, YEAR, IND, SEX)][ok == FALSE]
  # an aggregate missing in a country-year of the profile years, although the
  # file carries that sector and indicator for other country-years
  ai   <- agg[CNT2 %in% EU & YEAR >= YRS[1] & YEAR <= YRS[2], .(CNT2, YEAR, SECTOR, IND)]
  ag2  <- unique(ai[, .(SECTOR, IND)])[, CJ(CNT2 = EU, YEAR = YRS[1]:YRS[2]), by = .(SECTOR, IND)]
  ah   <- ag2[!ai, on = .(CNT2, YEAR, SECTOR, IND)]
  ah   <- ah[, .(n = .N, ex = paste(head(IND, 4), collapse = " ")), by = .(CNT2, YEAR, SECTOR)]
  list(tested = nrow(full) + nrow(ag2), flags = rbind(
    flag("S1", miss$CNT2, miss$YEAR, FILE = miss$FILE, IND = "*",
         DETAIL = sprintf("%d indicators missing (%s ...)", miss$n, miss$ex)),
    flag("S1", ag$CNT2, ag$YEAR, FILE = ag$FILE, IND = ag$IND, SEX = ag$SEX,
         DETAIL = sprintf("%d ages instead of %d", ag$n, length(P$ages))),
    flag("S1", ah$CNT2, ah$YEAR, ah$SECTOR, "aggregates", "*",
         DETAIL = sprintf("%d aggregates missing (%s ...)", ah$n, ah$ex))))
}

chk_S2 <- function() {
  z <- pr[SEX == "Total", .(zero = all(VALUE == 0)), by = .(FILE, CNT2, IND, YEAR)]
  z[, live := sum(!zero), by = .(FILE, CNT2, IND)]
  zp <- z[zero & live > 0]
  a <- merge(agg[CNT2 %in% EU & IND != "GDP" & YEAR >= YRS[1] & YEAR <= YRS[2]], GDP, by = c("CNT2","YEAR"))
  setorder(a, CNT2, SECTOR, IND, YEAR)
  a[, `:=`(big = max(abs(VALAGGR / GDP)) >= P$s2_gdp,
           last_nz = if (any(VALAGGR != 0)) max(YEAR[VALAGGR != 0]) else NA_integer_), by = .(CNT2, SECTOR, IND)]
  za <- a[big & VALAGGR == 0 & YEAR < last_nz]
  list(tested = nrow(z) + nrow(unique(a[, .(CNT2, SECTOR, IND)])), flags = rbind(
    flag("S2", zp$CNT2, zp$YEAR, FILE = zp$FILE, IND = zp$IND,
         DETAIL = sprintf("zero at every age; %d other years non-zero", zp$live)),
    flag("S2", za$CNT2, za$YEAR, za$SECTOR, "aggregates", za$IND,
         DETAIL = "aggregate exactly 0 before or inside its non-zero span")))
}

chk_S3 <- function() {
  s <- pr[SEX == "Total", .(h = paste(signif(VALUE, P$s3_digits), collapse = ","), nz = any(VALUE != 0)),
          by = .(FILE, CNT2, IND, YEAR)]
  setorder(s, FILE, CNT2, IND, YEAR)
  s[, same := h == shift(h) & YEAR == shift(YEAR) + 1, by = .(FILE, CNT2, IND)]
  b <- s[same %in% TRUE & nz]
  list(tested = nrow(s), flags = flag("S3", b$CNT2, b$YEAR, FILE = b$FILE, IND = b$IND,
                                      DETAIL = "identical at every age to the previous year"))
}

chk_S4 <- function() {
  l <- copy(labels)
  l[, DESC := sub(" \\([^)]*\\)$", "", sub("^[0-9A-Z.]+ ", "", INDICATOR))]
  n1 <- l[, .N, by = .(FILE, IND)][N > 1]
  d1 <- l[, .(n = uniqueN(IND), inds = paste(unique(IND), collapse = "/")), by = .(FILE, DESC)][n > 1]
  d2 <- l[!mapply(function(i, s) grepl(paste0(i, ")"), s, fixed = TRUE), IND, INDICATOR)]
  list(tested = nrow(unique(l[, .(FILE, IND)])), flags = rbind(
    flag("S4", CNT2 = "*", FILE = n1$FILE, IND = n1$IND, DETAIL = "more than one label"),
    flag("S4", CNT2 = "*", FILE = d1$FILE, IND = d1$inds, DETAIL = paste0("codes share the description '", d1$DESC, "'")),
    flag("S4", CNT2 = "*", FILE = d2$FILE, IND = d2$IND, DETAIL = paste0("label lacks its code: '", d2$INDICATOR, "'"))))
}

chk_S5 <- function() {
  c1 <- melt(uni[, .(CNT2, YEAR, EXR_2020, PPP_EUR_2020)], id.vars = c("CNT2","YEAR"))[, .(n = uniqueN(value)), by = .(CNT2, variable)][n > 1]
  c2 <- uni[YEAR == 2020 & abs(HICP - 100) > P$s5_hicp]
  pt <- merge(uni[, .(CNT2, YEAR, POPtot)], pop[SEX == "Total", .(S = sum(POP)), by = .(CNT2, YEAR)], by = c("CNT2","YEAR"))
  c3 <- pt[abs(S / POPtot - 1) > P$s5_pop]
  list(tested = nrow(uni), flags = rbind(
    flag("S5", c1$CNT2, FILE = "units", IND = as.character(c1$variable), DETAIL = sprintf("%d different values over the years", c1$n)),
    flag("S5", c2$CNT2, 2020L, FILE = "units", IND = "HICP", VALUE = c2$HICP, DETAIL = "HICP 2020 is not 100"),
    flag("S5", c3$CNT2, c3$YEAR, FILE = "units", IND = "POPtot", VALUE = c3$S / c3$POPtot - 1,
         DETAIL = sprintf("POPtot differs from the POP profile by %.3f%%", 100 * (c3$S / c3$POPtot - 1)))))
}

# ---- Breaks ------------------------------------------------------------------

chk_B1 <- function() {
  a <- agg[CNT2 %in% EU & YEAR >= YRS[1] & YEAR <= YRS[2] & IND != "GDP"]
  # One denominator, GDP, for every sector. Household primary income Y was
  # tried and dropped: Y = YEM + YA, so their shares of Y mirror each other and
  # always flagged as a pair.
  a <- merge(a, GDP, by = c("CNT2","YEAR"))
  a[, DEN := GDP]
  a[, share := VALAGGR / DEN]
  # Aggregate twins: the same series published in two sectors, possibly with
  # the sign flipped (Government T = NTA TGOT; Corporations BPSOCfc =
  # -Households BPSOCfc; NTA Y = Total economy Y to rounding). Measured on each
  # run over the whole panel: |values| within agg_twin_tol in every
  # country-year both carry. Each group is scored once, under the first
  # sector in the order below, and the flag names the others.
  a[, sid := paste(SECTOR, IND, sep = ":")]
  a[, ord := match(SECTOR, c("Households","Government","Corporations","Total economy","NTA Aggregates"))]
  w <- dcast(a, CNT2 + YEAR ~ sid, value.var = "VALAGGR")
  ids <- unique(a[, .(sid, ord)])[order(ord, sid), sid]
  head_of <- setNames(ids, ids)
  for (i in seq_along(ids)[-1]) for (j in seq_len(i - 1)) {
    if (head_of[ids[j]] != ids[j]) next
    x1 <- abs(w[[ids[i]]]); x2 <- abs(w[[ids[j]]]); ok <- !is.na(x1) & !is.na(x2) & pmax(x1, x2) > 1
    if (sum(ok) < 0.9 * sum(!is.na(x1)) || !any(ok)) next
    if (max(abs(x1[ok] - x2[ok]) / pmax(x1[ok], x2[ok])) < P$agg_twin_tol) { head_of[ids[i]] <- ids[j]; break }
  }
  twins_of <- data.table(sid = names(head_of), head = head_of)[sid != head, .(twins = paste(sub(":", " ", sid), collapse = ", ")), by = head]
  a <- a[sid %in% head_of[head_of == names(head_of)]]
  a <- merge(a, twins_of, by.x = "sid", by.y = "head", all.x = TRUE)
  setorder(a, CNT2, SECTOR, IND, YEAR)
  a[, `:=`(d = fifelse(YEAR == shift(YEAR) + 1, share - shift(share), NA_real_),
           prev = shift(VALAGGR), gdpprev = shift(GDP)), by = .(CNT2, SECTOR, IND)]
  a[, `:=`(nyr = sum(!is.na(d)), score = rscore(d)), by = .(CNT2, SECTOR, IND)]
  a[, `:=`(dn = shift(d, -1), sn = shift(score, -1)), by = .(CNT2, SECTOR, IND)]
  a <- eushare("d", a, c("SECTOR","IND"))
  b <- a[nyr >= P$minyears & score > P$z & abs(d) >= P$b1_min]
  b[, type := fcase(sign(VALAGGR) != sign(prev) & prev != 0, "sign flip",
                    !is.na(dn) & sn > P$z / 2 & sign(dn) != sign(d) & abs(dn) > 0.5 * abs(d), "one-year spike",
                    default = "step")]
  # The item's own growth next to GDP growth: a share that moves while the
  # item barely does is a denominator effect (IE 2015, DK 2022-23).
  b[, grow := fifelse(prev != 0, 100 * (VALAGGR / prev - 1), NA_real_)]
  b[, ggdp := 100 * (GDP / gdpprev - 1)]
  b[, gdpdriven := !is.na(grow) & abs(ggdp) >= 100 * P$b1_gdp_move & abs(grow) < abs(ggdp) / 2]
  b[, type := paste0(type, fifelse(is.na(twins), "", paste0(" (same series: ", twins, ")")))]
  list(tested = nrow(a[!is.na(d)]),
       flags = flag("B1", b$CNT2, b$YEAR, b$SECTOR, "aggregates", b$IND, VALUE = b$d, SCORE = b$score, EU = b$EU, AUTO = fifelse(b$gdpdriven, "GDP-DRIVEN", NA_character_),
                    DETAIL = sprintf("%s: share of GDP %.4f -> %.4f; level %s, GDP %+.1f%%", b$type, b$share - b$d, b$share,
                                     fifelse(is.na(b$grow) | abs(b$grow) > 999, "n/a", sprintf("%+.1f%%", b$grow)), b$ggdp)))
}

chk_B2 <- function() {
  x <- pr[!COPY & !TWIN & MON(IND)]
  x[, w := VALUE * POP]
  s <- x[, .(tot = sum(w), l1 = sum(abs(w)), n = .N), by = .(FILE, CNT2, IND, SEX, YEAR)]
  x <- merge(x, s[, .(FILE, CNT2, IND, SEX, YEAR, l1)], by = c("FILE","CNT2","IND","SEX","YEAR"))
  x <- x[l1 > 0]
  x[, p := w / l1]
  setkey(x, FILE, CNT2, IND, SEX, AGE, YEAR)
  x[, pp := fifelse(YEAR == shift(YEAR) + 1, shift(p), NA_real_), by = .(FILE, CNT2, IND, SEX, AGE)]
  d <- x[, .(dist = sum(abs(p - pp)), n = sum(!is.na(pp))), by = .(FILE, CNT2, IND, SEX, YEAR)][n == length(P$ages)]
  d <- merge(d, s, by = c("FILE","CNT2","IND","SEX","YEAR"))
  setorder(s, FILE, CNT2, IND, SEX, YEAR)
  s[, totp := fifelse(YEAR == shift(YEAR) + 1, shift(tot), NA_real_), by = .(FILE, CNT2, IND, SEX)]
  d <- merge(d, s[, .(FILE, CNT2, IND, SEX, YEAR, totp)], by = c("FILE","CNT2","IND","SEX","YEAR"))
  d <- merge(d, YHH, by = c("CNT2","YEAR"))
  d[, weight := abs(tot) / 1e6 / YHH]
  # dist is the L1 distance of the normalised profiles: dist / 2 is the share
  # of the profile mass that moved to other ages. A distance is never
  # negative, so it is scored as a ratio to its usual value, not as a z.
  d[, moved := dist / 2]
  d[, `:=`(nyr = .N, usual = median(moved)), by = .(FILE, CNT2, IND, SEX)]
  d[, score := fifelse(usual > 0, moved / usual, NA_real_)]
  d[, dz := moved - usual]                                     # EU-wide tag: moved more than usual
  d <- eushare("dz", d, c("FILE","IND","SEX"))
  # A profile scaled to an aggregate that changed sign simply inverts: arithmetic, not a break.
  b <- d[nyr >= P$minyears & score > P$b2_ratio & weight >= P$b2_weight & moved >= P$b2_mass & !(tot * totp < 0)]
  tb <- b[SEX == "Total", .(FILE, CNT2, IND, YEAR)]
  b <- b[SEX == "Total" | !paste(FILE, CNT2, IND, YEAR) %in% tb[, paste(FILE, CNT2, IND, YEAR)]]
  list(tested = nrow(d),
       flags = flag("B2", b$CNT2, b$YEAR, FILE = b$FILE, IND = b$IND, SEX = b$SEX, VALUE = b$moved, SCORE = b$score, EU = b$EU,
                    DETAIL = sprintf("%.0f%% of the profile mass moved to other ages (usual %.0f%%)%s", 100 * b$moved,
                                     100 * b$usual, fifelse(b$moved > 0.95, "; profile flipped sign", ""))))
}

chk_B3 <- function() {
  x <- pr[!COPY & !TWIN & MON(IND)]
  x[, w := VALUE * POP]
  w <- dcast(x, FILE + CNT2 + IND + YEAR + AGE ~ SEX, value.var = "w")
  s <- w[, .(wm = sum(Men), w = sum(Total), absw = sum(abs(Total)),
             cancel = sum(pmax(abs(Men) + abs(Women) - abs(Total), 0))), by = .(FILE, CNT2, IND, YEAR)]
  s <- merge(s, YHH, by = c("CNT2","YEAR"))
  s[, msh := fifelse(abs(w) / 1e6 >= 1 & cancel / absw < P$b3_cancel & abs(w) / absw > 0.5, wm / w, NA_real_)]
  s[, weight := abs(w) / 1e6 / YHH]
  setorder(s, FILE, CNT2, IND, YEAR)
  s[, d := fifelse(YEAR == shift(YEAR) + 1, msh - shift(msh), NA_real_), by = .(FILE, CNT2, IND)]
  s[, `:=`(nyr = sum(!is.na(d)), score = rscore(d)), by = .(FILE, CNT2, IND)]
  s <- eushare("d", s, c("FILE","IND"))
  b <- s[nyr >= P$minyears & score > P$z & abs(d) >= P$b3_min & weight >= P$b2_weight]
  list(tested = nrow(s[!is.na(d)]),
       flags = flag("B3", b$CNT2, b$YEAR, FILE = b$FILE, IND = b$IND, VALUE = b$d, SCORE = b$score, EU = b$EU,
                    DETAIL = sprintf("male share %.3f -> %.3f", b$msh - b$d, b$msh)))
}

# ---- Profile -----------------------------------------------------------------

chk_P1 <- function() {
  x <- pr[SEX == "Total" & !COPY & !TWIN & MON(IND) & !canon(IND) %in% P$p1_skip, .(FILE, CNT2, IND, YEAR, AGE, VALUE)]
  setkey(x, FILE, CNT2, IND, YEAR, AGE)
  x[, sc := max(abs(VALUE)), by = .(FILE, CNT2, IND, YEAR)]
  x <- x[AGE %in% P$p1_ages]
  # neighbours only where the neighbouring age is itself scanned
  x[, `:=`(vm = fifelse(shift(AGE) == AGE - 1, shift(VALUE), NA_real_),
           vp = fifelse(shift(AGE, -1) == AGE + 1, shift(VALUE, -1), NA_real_)), by = .(FILE, CNT2, IND, YEAR)]
  x <- x[sc > 0]
  x[, `:=`(dev = (VALUE - (vm + vp) / 2) / sc, jmp = (VALUE - vm) / sc)]
  # compare each age with the same age in the same country's other years
  x[, `:=`(nys = sum(!is.na(dev)), zs = rscore(dev), ds = dev - median(dev, na.rm = TRUE),
           nyk = sum(!is.na(jmp)), zk = rscore(jmp), dk = jmp - median(jmp, na.rm = TRUE)), by = .(FILE, CNT2, IND, AGE)]
  sp <- x[nys >= P$minyears & zs > P$z & abs(ds) > P$p1_spike]
  kk <- x[nyk >= P$minyears & zk > P$z & abs(dk) > P$p1_kink]
  kk <- kk[!sp, on = .(FILE, CNT2, IND, YEAR, AGE)]
  a <- rbind(sp[, .(FILE, CNT2, IND, YEAR, AGE, k = "spike", dv = ds, z = zs)],
             kk[, .(FILE, CNT2, IND, YEAR, AGE, k = "kink", dv = dk, z = zk)])
  b <- a[, .(ages = paste0(k, " ", AGE, collapse = ", "), dv = max(abs(dv)), z = max(z)), by = .(FILE, CNT2, IND, YEAR)]
  list(tested = uniqueN(x[, .(FILE, CNT2, IND, YEAR)]),
       flags = flag("P1", b$CNT2, b$YEAR, FILE = b$FILE, IND = b$IND, SEX = "Total", VALUE = b$dv, SCORE = b$z,
                    DETAIL = paste0("unusual for this age: ", b$ages)))
}

chk_P2 <- function() {
  x <- pr[FILE == "esa" & SEX == "Total" & MON(IND) & AGE %in% P$p2_ages, .(CNT2, IND, YEAR, AGE, VALUE)]
  setkey(x, CNT2, IND, YEAR, AGE)
  x[, run := rleid(VALUE), by = .(CNT2, IND, YEAR)]
  r <- x[VALUE != 0, .(a0 = min(AGE), a1 = max(AGE), len = .N), by = .(CNT2, IND, YEAR, run)][len >= P$p2_len]
  r[, band := paste0(a0, "-", a1)]
  b <- r[, .(nind = uniqueN(IND)), by = .(CNT2, YEAR, band)][nind >= P$p2_nind]
  b <- b[, .(bands = paste(band, collapse = " "), nind = max(nind)), by = .(CNT2, YEAR)]
  list(tested = uniqueN(x[, .(CNT2, YEAR)]),
       flags = flag("P2", b$CNT2, b$YEAR, FILE = "esa", IND = "*", SEX = "Total", VALUE = b$nind,
                    DETAIL = sprintf("identical values over ages %s in up to %d indicators", b$bands, b$nind)))
}

################################################################################
# 4. Run every check in checks.csv
################################################################################

fns <- sub("^chk_", "", ls(pattern = "^chk_"))
if (length(setdiff(checks$ID, fns))) stop("checks.csv row without a function: ", paste(setdiff(checks$ID, fns), collapse = " "))
if (length(setdiff(fns, checks$ID))) stop("function without a row in checks.csv: ", paste(setdiff(fns, checks$ID), collapse = " "))
used <- unique(unlist(strsplit(checks$PARAMS, " +")))
used <- used[used != ""]
if (length(setdiff(used, names(P)))) stop("checks.csv PARAMS names an unknown parameter: ", paste(setdiff(used, names(P)), collapse = " "))

res <- list(); tested <- c()
for (id in checks$ID) {
  cat("Check", id, "...\n")
  r <- get(paste0("chk_", id))()
  res[[id]] <- r$flags; tested[id] <- r$tested
}
fl <- rbindlist(res, fill = TRUE)
fl <- merge(fl, checks[, .(CHECK = ID, FAMILY, NAME, LEDGER)], by = "CHECK", sort = FALSE)

################################################################################
# 5. Match the judgement flags against the event ledger
################################################################################

events <- fread(file.path(dd, "events.csv"), colClasses = "character")
scope  <- fread(file.path(dd, "event_scope.csv"), colClasses = "character")
bad <- setdiff(scope$EVENT, events$EVENT)
if (length(bad)) stop("event_scope.csv names events missing from events.csv: ", paste(bad, collapse = " "))

scope[, srow := .I]
scope[, c("Y0","Y1") := {
  y <- ifelse(YEAR == "*", NA, YEAR)
  .(as.integer(sub("-.*", "", y)), as.integer(sub(".*-", "", y)))}]
scope[, INDc := ifelse(IND == "*", "*", canon(IND))]

fl[, fid := .I]
fl[, INDc := canon(IND)]
j <- fl[LEDGER == "yes", .(fid, CHECK, CNT2, YEAR, SECTOR, INDc, k = 1L)]
m <- merge(j, scope[, .(srow, EVENT, sCHECK = CHECK, sCNT2 = CNT2, Y0, Y1, sSECTOR = SECTOR, sIND = INDc, k = 1L)],
           by = "k", allow.cartesian = TRUE)
m <- m[(sCHECK == "*" | sCHECK == CHECK) & (sCNT2 == "*" | sCNT2 == CNT2) &
       (is.na(Y0) | (!is.na(YEAR) & YEAR >= Y0 & YEAR <= Y1)) &
       (sSECTOR == "*" | sSECTOR == SECTOR) & (sIND == "*" | sIND == INDc)]
ev <- m[, .(EVENT = paste(sort(unique(EVENT)), collapse = " ")), by = fid]
fl <- merge(fl, ev, by = "fid", all.x = TRUE)
fl[, STATUS := fcase(LEDGER == "no", "FAIL",
                     !is.na(EVENT), "EXPLAINED",
                     EU %in% TRUE, "EU-WIDE",
                     AUTO %in% "GDP-DRIVEN", "GDP-DRIVEN",
                     default = "NEW")]
unused <- scope[!srow %in% m$srow]

setorder(fl, CHECK, CNT2, YEAR, IND)
fwrite(fl[, .(STATUS, CHECK, NAME, CNT2, YEAR, SECTOR, FILE, IND, SEX, VALUE, SCORE, EU, EVENT, DETAIL)],
       file.path(out, "diag_flags.csv"))

################################################################################
# 6. Report
################################################################################

md <- character()
w  <- function(...) md <<- c(md, paste0(...))
tb <- function(d) {                                    # markdown table
  d <- as.data.table(d)
  w("| ", paste(names(d), collapse = " | "), " |")
  w("|", paste(rep("---", ncol(d)), collapse = "|"), "|")
  for (i in seq_len(nrow(d))) w("| ", paste(unlist(lapply(d[i], as.character)), collapse = " | "), " |")
  w("")
}
fmt <- function(d) d[, .(CNT2, YEAR = ifelse(is.na(YEAR), "", YEAR), SECTOR = ifelse(is.na(SECTOR), "", SECTOR),
                         FILE, IND, SEX = ifelse(is.na(SEX), "", SEX), SCORE = ifelse(is.na(SCORE), "", SCORE), DETAIL)]

w("# ENTA diagnostic scan - report"); w("")
w("Run ", format(Sys.time(), "%Y-%m-%d %H:%M"), " on the published files in `", od, "`:")
for (f in c("ENTA_esa","ENTA_nta","ENTA_aggregates","ENTA_units"))
  w("- `", f, ".csv` ", format(file.mtime(file.path(od, paste0(f, ".csv"))), "%Y-%m-%d %H:%M"))
w(""); w("Countries: ", length(EU), ". Profile years: ", YRS[1], "-", YRS[2], "."); w("")

w("## Summary"); w("")
w("FAIL = a defect (no event can explain it). EU-WIDE = moved the same way in most countries, not counted as new. ",
  "What each check tests: `checks.csv`."); w("")
sm <- checks[, .(ID, FAMILY, NAME)]
cnt <- fl[, .(flags = .N, FAIL = sum(STATUS == "FAIL"), EXPLAINED = sum(STATUS == "EXPLAINED"),
              `EU-WIDE` = sum(STATUS == "EU-WIDE"), `GDP-DRIVEN` = sum(STATUS == "GDP-DRIVEN"), NEW = sum(STATUS == "NEW")), by = .(ID = CHECK)]
sm <- merge(sm, cnt, by = "ID", all.x = TRUE, sort = FALSE)
for (v in c("flags","FAIL","EXPLAINED","EU-WIDE","GDP-DRIVEN","NEW")) set(sm, which(is.na(sm[[v]])), v, 0L)
sm[, tested := tested[ID]]
setcolorder(sm, c("ID","FAMILY","NAME","tested"))
tb(sm)

w("## Parameters used"); w("")
w("Set in section 1 of `diagnostic_scan.R`."); w("")
pu <- checks[, .(p = unlist(strsplit(PARAMS, " +"))), by = ID][p != ""]
pu <- pu[, .(checks = paste(ID, collapse = " ")), by = p]
tb(pu[, .(parameter = p, value = sapply(p, function(k) { v <- P[[k]]
  if (length(v) > 6) paste0(v[1], "..", v[length(v)]) else paste(v, collapse = " ") }), checks)])

w("## Profiles scanned once"); w("")
w("B2, B3 and P1 skip NTA copies of an ESA series (`nta_esa_same.csv`, and YDC = SC) and scan each group of ",
  "shape twins - the same age shape rescaled, in every country, year and sex - once, under its first code:"); w("")
if (nrow(twingroups)) tb(twingroups) else { w("None."); w("") }

w("## FAIL - defects"); w("")
f <- fl[STATUS == "FAIL"]
if (nrow(f)) tb(fmt(f)[, CHECK := f$CHECK][, c("CHECK", names(fmt(f))), with = FALSE]) else { w("None."); w("") }

w("## NEW - needs a look"); w("")
w("Sorted by country and year. NEARBY names the events that explain OTHER flags of the same country-year - ",
  "a neighbouring flag often names the cause. Event texts: `events.csv`."); w("")
n <- fl[STATUS == "NEW"]
if (!nrow(n)) { w("None."); w("") } else {
  nb <- fl[STATUS == "EXPLAINED", .(NEARBY = paste(sort(unique(unlist(strsplit(EVENT, " ")))), collapse = " ")), by = .(CNT2, YEAR)]
  n <- merge(n, nb, by = c("CNT2","YEAR"), all.x = TRUE)
  setorder(n, CNT2, YEAR, CHECK, IND)
  n[duplicated(paste(CNT2, YEAR)), NEARBY := ""]            # name the neighbours once per country-year
  tb(n[, .(CNT2, YEAR = ifelse(is.na(YEAR), "", YEAR), CHECK, SECTOR = ifelse(is.na(SECTOR), "", SECTOR), FILE, IND,
           SEX = ifelse(is.na(SEX), "", SEX), SCORE = ifelse(is.na(SCORE), "", pmin(SCORE, 999)), DETAIL,
           NEARBY = ifelse(is.na(NEARBY), "", NEARBY))])
}

w("## EU-WIDE - same move in most countries"); w("")
e <- fl[STATUS == "EU-WIDE", .(countries = paste(sort(unique(CNT2)), collapse = " "), n = uniqueN(CNT2)),
        by = .(CHECK, YEAR, SECTOR = ifelse(is.na(SECTOR), "", SECTOR), IND)]
if (nrow(e)) tb(e[order(CHECK, YEAR, IND)]) else { w("None."); w("") }

w("## GDP-DRIVEN - the denominator moved"); w("")
e <- fl[STATUS == "GDP-DRIVEN", .(CNT2, YEAR, SECTOR, IND, DETAIL)][order(CNT2, YEAR)]
if (nrow(e)) tb(e) else { w("None."); w("") }

w("## Ledger rules that matched nothing"); w("")
known <- c("*", unique(agg$IND), unique(pr$IND), labels$IND)
unused[, why := fifelse(IND %in% known, "no flag this run", "code not in the published files")]
w(nrow(unused), " of ", nrow(scope), " rows of `event_scope.csv`, by reason:"); w("")
tb(unused[, .N, by = why])
w("A rule on a code that is not published was written for the old Stata scan, which read the internal aggregates file. ",
  "A rule with no flag this run is either stale (the flag has gone) or waiting for a flag that comes and goes with ",
  "the thresholds. Neither costs anything; delete the rows once you are sure. Per event:"); w("")
if (nrow(unused)) tb(unused[, .(rows = .N, codes = paste(head(unique(IND), 8), collapse = " ")), by = .(EVENT, why)][order(EVENT)])

writeLines(md, file.path(out, "diag_report.md"), useBytes = TRUE)
cat("\nDone.\n"); print(sm)
cat("Report: ", file.path(out, "diag_report.md"), "\n")
