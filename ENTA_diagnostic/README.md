# ENTA_diagnostic

Checks on the published ENTA output. Start here.

## Running the scan

From the ENTA project root, after any change to the pipeline (about 3 minutes):

```
"C:\Program Files\R\R-4.6.1\bin\Rscript.exe" ENTA_diagnostic/diagnostic_scan.R
```

It reads only the four published CSVs in `ENTA_output_data` (`ENTA_esa`,
`ENTA_nta`, `ENTA_aggregates`, `ENTA_units`) and writes

- `out/diag_report.md` - **read this**: a summary per check, the parameters
  used, the defects, and the flags not yet explained;
- `out/diag_flags.csv` - every flag with its status.

A run with no FAIL and no NEW means the output is in its known state.

## What it checks

Each check is one row of `checks.csv` (what it tests, which parameters it
uses, whether an event may explain it). Four families:

| Family | Checks | A flag is |
|---|---|---|
| Invariant | I1 reconciliation with the aggregates, I2 identities (`identities.csv`), I3 men + women = total, I4 signs | a defect (FAIL); no event can explain it |
| Structure | S1 missing cells, S2 zero-filled series, S3 profile copied from the previous year, S4 labels, S5 unit constants | explained by an event, or a finding |
| Break | B1 level of each aggregate (share of GDP), B2 age shape of each profile, B3 share of men | explained by an event, or tagged EU-WIDE / GDP-DRIVEN |
| Profile | P1 spikes and kinks unusual for that country, indicator and age; P2 age bands (plateaus) | explained by an event |

NTA series that copy an ESA series (`nta_esa_same.csv`), aggregates published
in two sectors, and profiles with the same age shape are each checked once.

## The ledger

Flags that have been examined are explained by **events**:

- `events.csv` - one row per event: what happened, written once, with the
  evidence and bug-report numbers;
- `event_scope.csv` - which flags each event explains (check, country, year or
  range, sector, indicator; `*` for any), with an optional NOTE per row.

To explain a new flag, add an event and one or more scope rows; the header
of `diagnostic_scan.R` gives the steps, and also how to change a threshold or
add a check, family or identity. The report lists scope rows that matched
nothing, so a stale rule shows.

## Other files

| File | Contents |
|---|---|
| `diagnostic_scan.R` | the scan: parameters (section 1), helpers, one function per check |
| `make_nta_esa_same.R` | re-measures `nta_esa_same.csv`; run it after an indicator is added or renamed |
| `scan_decisions.md` | why each check is built as it is, what was dropped and why |

The events that matter for users of the data are summarised in the manual,
Appendix E (`Interpretation.tex`), and the comparability limits they revealed
in Chapter 5 (`Limitations.tex`).
