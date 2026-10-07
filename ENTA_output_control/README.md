# ENTA output control

Everything used to control the published ENTA data. Nothing in this folder
reads microdata: the checks use the published files in `ENTA_output_data`,
the internal aggregates and the Eurostat tables in
`ENTA_input_data/Original_input_data`. Checks that need microdata are in
`ENTA_microdata_checks` and are run by hand.

## Files

| File | What it does |
|---|---|
| `1_method_check.do` | Is the method applied correctly? Profiles add up to the aggregates, components to their totals, men and women to the total; no negative values where none are possible; all ages present. Each test holds or fails. |
| `2_aggregates_check.do` | Lists breaks in the aggregates, in percent of national income: national income itself, level breaks, shifts between components. Also lists country-years in which imputed rent is an unusual share of private consumption (a sign of a wrong unit in the source). |
| `3_profiles_check.do` | Lists breaks in the age shapes of the profiles: shape breaks, breaks in the share of men, spikes at single ages. |
| `4a_external_agenta.do`, `4b_external_nta.do`, `4c_external_austria2015.do` | Compare ENTA with AGENTA 2010, with national NTA results and with the Austrian NTA 2015. |
| `0_ledger_match.do` | Helper used by the checks: links each finding to the ledger. |
| `ledger.csv` | The explained patterns, one row each. |
| `results/` | Written by the checks and rewritten by every run. Never edited by hand. The CSV files (findings of checks 1 to 3 with their ledger IDs; statistics of the external comparisons) are in the repository, the figures are not. `results/external/agenta_2010.png` is the figure of the manual's quality chapter; `Manual_make_figures.R` copies it into the manual folder. |
| `benchmarks/` | The data of the external comparisons, all public: `nta2010_AGENTA_long_Euro.csv` (AGENTA 2010, downloaded from the AGENTA data explorer, https://www.wittgensteincentre.org/ntadata, the whole dataset: all countries and all variables, the non-central variables included), `nta2010_AGENTA_aggregates.csv` (the aggregates of the same AGENTA results by country, in one file; read by `ENTA_microdata_checks/validation_agenta_ya.do`), `NTA_EU_countries.csv` (global NTA database, https://www.ntaccounts.org/web/nta/show/Browse%20database, all EU countries), `nta_AT_2015_long.dta` (Austrian NTA 2015, also published at https://doi.org/10.11587/4EOXZO), with the two method descriptions. The three data files are in the repository, the two PDFs are not. |

## How to run

Open Stata, change to the ENTA root folder, then run the files in the order of
their numbers, for example `do ENTA_output_control/1_method_check.do`. No setup
file is needed. Checks 1 and 2 take about one minute each.

## The routine after a pipeline run

1. Run check 1. It must end with "All checks hold". If not, the failures are
   in `results/1_method_check_violations.csv` and have to be fixed in the code.
2. Run checks 2 and 3. Each finding in `results/` has a column `LEDGER`: the
   ID of the ledger row that explains it, or `new`.
3. Look at the new findings, largest first. Compare with the source: the
   Eurostat table the aggregate is built from, or the neighbouring flags of
   the same country and year.
4. Add a row to `ledger.csv` for each pattern that is understood.
5. Mark the rows a user of the data must know in the column `MANUAL` and
   describe them in the manual.

## The ledger

`ledger.csv` can be edited in a text editor or in Excel (save as CSV, comma
separated).

| Column | Content |
|---|---|
| `ID` | L001, L002, ... |
| `CNT2` | country code, or `ALL` for every country |
| `YEAR_FROM`, `YEAR_TO` | first and last year of the pattern |
| `INDICATORS` | indicator codes, separated by blanks, or `ALL` |
| `FINDINGS` | the kinds of finding the row explains, separated by blanks: `national_income`, `level`, `components` (check 2), `shape`, `men`, `spikes` (check 3), or `ALL` |
| `PATTERN` | what happens in the ENTA data: which indicator moves, in which direction, in million euro and relative to national income (for example: property income falls from 7.5% to 5.0% of national income) |
| `SOURCE_DATA` | the Eurostat (or DG TAXUD) dataset and the variables in it that show the change of the ENTA indicators, with their values and the date of the check |
| `EXPLANATION_AND_EVIDENCE` | what is behind the change: a policy change, a change in the classification of the data, a real economic event, the survey (few observations, or a survey year that differs), or the ENTA method. Empty if we do not know; a restatement of the numbers is not an explanation |
| `REFERENCES` | external literature and documents that support the explanation: institution or author, year, title, full address; empty if there is none |
| `STATUS` | of the explanation: `documented` (a source states it), `verified` (follows from the data themselves), `inferred` (fits the data, no source), `not found` |
| `MANUAL` | section of the manual that describes it, or empty |

`PATTERN` comes from the results of the checks and the published files,
`SOURCE_DATA` from the Eurostat table the indicator is built from, and
`EXPLANATION_AND_EVIDENCE` from documents outside the project or from the
ENTA code. A row can have a full `SOURCE_DATA` cell and an empty explanation:
then the break is in the source and its reason is not known. Nothing is
written into the explanation that is only assumed.

A ledger row covers a finding if the country is the same, the year lies
between `YEAR_FROM` and `YEAR_TO`, the indicator of the finding is one of
`INDICATORS`, and the kind of finding is one of `FINDINGS`. A row on spikes
in German profiles therefore does not cover a level break in Germany.

## What goes into the manual

Only patterns that a user of the data must know: they affect the published
profile years, they are large, and they are not a common economic event that
the reader recognises (2009, 2020).

## Rules for work with an AI agent

- No access to microdata. The agent works only with the files named at the
  top of this page.
- The agent runs the checks, reads `results/` and reports check 1 and the new
  findings.
- The agent proposes ledger rows. A row is added only after the project owner
  has agreed.
- The ledger contains only what was checked. What an AI chatbot or a search
  summary says without a document that was opened is marked as such, and the
  status stays `inferred`.
- Code is changed only after the project owner has agreed.
