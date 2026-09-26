# Diagnostic scan - design decisions

Why diagnostic_scan.R is built as it is. It replaced ENTA_diagnostic_scan.do and
dataexplorer_scan.R on 2026-09-26 (both deleted, and their ledgers with them).

## Decided by the project owner, 2026-09-25

- One scan, in R, reading the published CSVs in ENTA_output_data.
- Level breaks are tested once, on the aggregates only (all sectors). Profile
  levels equal the aggregates by reconciliation, so the profiles carry only
  shape and male-share checks. Replaces Stata Tier 2 and R checks C and D2,
  which flagged 509 / 196 / 299 household breaks with 70-92 in common.
- EU-wide moves are tagged automatically (same direction in >= 20 of 26
  countries), still listed but not counted as new. Replaces most wildcard rules.
- Dropped: Stata 4.3 one sex zero (139 hits, 99 BSU real zeros, never found a
  defect); R E1/E4 unit-factor checks (missing NORM years, exchange-rate and
  HICP moves); R A0 app-copy freshness (belongs to the app's refresh step -
  ENTA_dataexplorer/refresh_data.R already syncs by file time).
- Within-profile spikes/kinks (R B1/B2): useful only if they find anomalies,
  not built-in features (school start, age 18 smoothing, retirement, 80+).
  Design pending, see below.

## Kept (invariants)

Reconciliation (1.1, 5.1); identities (1.2, 5.2, F4, F1 -> one identities
table); men + women = total (4.1, 5.3, F3); signs on floored variables (1.3,
4.2); holes (A2, A4, D4); labels (A1); plateaus (B3); shape breaks (3, 4.5,
5.4 -> one check); male-share breaks (4.4).

## Pending

- A5 carried forward (DECIDED 2026-09-25): flag identical values only (same
  numbers at every age as the previous year). The "same shape, rescaled"
  variant is dropped: several profiles have a constant shape by design (CGX
  flat per capita, ENTA_compilation1_esa.do:696; CGH from the 2018 Ageing
  Report profile, #272), so a copied shape is not an anomaly.
- A6 rare negatives (DECIDED 2026-09-25: dropped): 230 hits, all on series
  that may be negative (YA, YAH, Y, BPSOCfc); the sign check on floored
  variables covers the real case.
- Spikes (DECIDED 2026-09-25: use the redesigned check): scoring each spike against the same country's other years at that
  indicator x age cuts 127k hits to 825 country-year-indicators (Total sex);
  top of the list is BSU at 62+ (raw cells above the 18-61 smoothing range)
  and the DE 2022-23 age bands.
- Event ledger conversion: done 2026-09-25, see below.

## Draft check list (2026-09-25, for review)

checks.csv - the 14 checks of the new scan, one row each, with rule,
threshold, whether the ledger may explain a flag, and which old checks it
replaces. identities.csv - the 19 identities behind I2. nta_esa_same.csv - the
25 NTA codes whose series equal an ESA series exactly (measured on the
published CSVs 2026-09-25); it replaces the 35-entry alias list (codemap) in
dataexplorer_scan.R and defines the "NTA-only concepts" that B2, B3 and P1 scan.
(Re-measured with a 1e-6 tolerance by make_nta_esa_same.R: 26 pairs, YDH = YD
added. YDC = SC holds only to 1 EUR and enters as an alias via identity ID13.)

## Trial implementation (2026-09-25)

diagnostic_scan.R implements checks.csv; its header explains how to change a
parameter, add a check, family, identity or event. The two old ledgers were
converted by a one-off script (since deleted): 835 rules -> 170 events (the 40 rules of
the dropped check 4.3 were not converted). Calibration choices made while
running it on the current output:

- B2 scores the shape distance as a ratio to the series' usual distance
  (b2_ratio 6), as the Stata scan did; a robust z on a distance flagged 167
  instead of 7. b2_mass is now the share of mass moved (0.125 = the old
  L1 distance 0.25).
- P1 thresholds raised to 0.20 / 0.30 and BSU excluded (p1_skip): BSU keeps
  raw survey values above its pension-age cliff by design. 796 -> 177 flags.
- I1 skips esa:YD and nta:C (i1_skip): no aggregate of their own; the
  same-named aggregates (Corporations/NTA YD, Government C) are other concepts.
- B1 merges a series published in two sectors (Government T = NTA TGOT) into
  one flag.
- Aggregate checks (I2, S1, S2, B1) cover the profile years only (2008-2023).
- Event E171 (DE 2022-23 SILC age bands) added as the first new event.
- The published aggregates lack the internal-only codes the old Stata scan
  read (TPN, YPr, YPp, BSP, BSN, TBSPEN, YDCASH ...): 137 old ledger rows can
  no longer match, and identity ID05 (TB = TBSPEN + TBPPEN + TBSN) cannot be
  tested.

## Second pass (2026-09-25, after the project owner's answers)

- ONLY PUBLISHED FILES ARE CHECKED (project owner). ID05 removed; the 137
  ledger rows on unpublished codes removed from event_scope.csv (27 events
  left empty removed).
- TXNPISH missing DE 2008-11, IE 2008-09: source has no household/NPISH split
  (project owner). I2 now treats a missing value as untestable; S1 reports
  every missing aggregate against the full country x year grid; event E172.
- B1 denominator is GDP for every sector (household Y made YEM and YA mirror
  each other).
- Shape twins (twin_tol): profiles with the same normalised age shape are
  scanned once by B2, B3, P1.
- Events E172-E177 added, E171/E026/E027 extended.

## Third pass (2026-09-25, project owner's decisions)

- YM rescaled to its aggregate after the YE/YM split, capped at YEM
  (ENTA_compilation1_esa.do; bug report #278). I1 is clean.
- Sign rules (I4): no income component (YE, YM, YEM, YO) negative; YP not
  negative below 20 (nonneg_young); BPSOCfc and TBPPEN added. FAILs: YP at
  18-19 in 41 country-years (the YPr = YPp rule is not implemented), EE
  BPSOCfc 2013-17 and 2019 (negative in the Eurostat source, DX-03).
- P1 scans ages 0-14 and 20-79 (p1_ages): jumps at 15-19 are accepted (few
  observations), 80 is the open group and not smoothed.
- Enrolment definition change (ISCED 1997 -> 2011) kept as it is: event E178.
