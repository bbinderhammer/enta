# ENTA - Extended National Transfer Accounts

ENTA is a Stata pipeline that builds Extended National Transfer Accounts
for 26 EU countries. It combines household microdata (EU-SILC, HBS,
EUROMOD, LFS) with Eurostat ESA2010 aggregates to produce per-capita,
per-age, per-sex profiles of income, consumption, taxes, and public and
private transfers.

National Transfer Accounts take the aggregate totals of the national
accounts and distribute them by age and sex, so that the economy can be
read as a set of age profiles: who earns, who consumes, who pays taxes,
who receives transfers, and how the gap between what an age group
consumes and what it earns is financed. ENTA is the European
implementation, built on Eurostat sources and reconciled to ESA2010
throughout.

## What the data covers

- **26 countries.** Austria, Belgium, Bulgaria, Croatia, Cyprus, Czechia,
  Denmark, Estonia, Finland, France, Germany, Greece, Hungary, Ireland,
  Italy, Latvia, Lithuania, Luxembourg, Netherlands, Poland, Portugal,
  Romania, Slovakia, Slovenia, Spain and Sweden.
- **Age profiles** cover the income reference years 2008-2023, by single
  year of age from 0 to 80 - where 80 is the open-ended top group - and by
  sex, as men, women and total. Croatia starts in 2009 and Bulgaria ends
  in 2022.
- **Aggregates** cover 1995-2024, Bulgaria to 2022.
- **Two formats.** The ESA format keeps the terminology and sector
  structure of the European System of Accounts and centres on the
  household sector. The NTA format combines the private sectors, adds the
  government sector and uses the concepts of the global NTA project, so
  results are comparable with NTA data from outside Europe. The same
  underlying estimates are published in both.

The age profiles are published as nominal euro per capita and the
aggregates as nominal totals in million euro. Real, PPS and normalised
units are derived on demand from the published conversion factors rather
than stored - the manual gives every formula.

## The data, and the documentation

This repository holds the **code** and the input data needed to rebuild
ENTA, apart from the licensed microdata. The results are published
separately:

| What | Where |
| --- | --- |
| ENTA data, for download | Zenodo: https://doi.org/10.5281/zenodo.20360412 |
| Interactive data explorer | https://ntaeurope.eu/entadata |
| Manual - methodology, codebook, country notes | [`2026_ENTA_Manual_V_2_0_0/Manual.pdf`](2026_ENTA_Manual_V_2_0_0/Manual.pdf) (ENTA Manual V.2.0.0) |

The [manual](2026_ENTA_Manual_V_2_0_0/Manual.pdf) is the real
documentation: it describes the NTA/ESA methodology, every variable, the
limitations and country-specific treatments, and the function of each file
in this repository. This README is only an orientation page.

## What is in this repository, and what is not

**Included**

- All code: the setup file, the input-data preparation
  (`ENTA_input_data/*.do`), the age profiles, the aggregates, the two
  compilation files and the diagnostic scan.
- The input files that cannot be downloaded from Eurostat, in
  `ENTA_input_data/`:
  - `Original_input_data/CPI_world_bank.xls` - consumer prices, World Bank.
  - `Original_input_data/taxud_tax_ec_func_en.csv` - tax revenue by
    economic function, European Commission, DG TAXUD.
  - `Original_input_data/population_UN.dta` - population by age, UN World
    Population Prospects (the UN data portal needs a personal API token).
  - `ENTA_input_datasets/CGH_AWG.dta` - the public health expenditure
    profile from the 2018 Ageing Report. The code that builds it is not
    published.
  - `ENTA_input_datasets/taxr.dta` and `inctax_nonempl_decomp.dta` - tax
    shares by country and year derived from EUROMOD. They are aggregates
    and contain no microdata.
- The manual, as PDF.

**Not included**

- **Microdata** - EU-SILC, HBS and LFS scientific-use files, obtained from
  Eurostat under contract; EUROMOD output; and the Austrian consumption
  survey (Konsumerhebung 2010 and 2015), provided by Statistics Austria.
  The versions used are listed under Requirements below.
- **Eurostat tables.** The `Suppl_*.do` files and `Aggr_ESA2010.do`
  download them with the `eurostatuse` package when the switch
  `global download` in `ENTA_setup.do` is set to 1. Eurostat revises its
  data, so a new download will not reproduce the published results
  exactly; the manual gives the download date of each table used.
- **Output.** The age profiles (`ENTA_ageprofiles/ageprofiles/`), the
  aggregates (`ENTA_aggregates/*.dta`) and the final data
  (`ENTA_output_data/`) are rebuilt by the code. The published version is
  on Zenodo.

## Requirements

**Software**

- Stata. ENTA V.2.0.0 was produced with Stata 19 SE.
- Stata packages from SSC: `eurostatuse` (Eurostat downloads), `sumdist`
  and `supsmooth` - install with `ssc install <name>`.
- R with the `data.table` package, for the diagnostic scan only. ENTA
  V.2.0.0 was checked with R 4.6.1.

**Microdata** (request from Eurostat, the EUROMOD team and Statistics
Austria; versions used for ENTA V.2.0.0)

| Source | Version used |
| --- | --- |
| EU-SILC cross-sectional UDB, survey years 2008-2024 | 2025 release |
| EU-LFS yearly files | 2024 release |
| HBS | Waves 2010 and 2015 |
| EUROMOD | J2.0+, with input data from 2024 |
| Konsumerhebung (Austria only), Statistics Austria | 2010 and 2015 |

## Setup

`ENTA_setup.do` defines the directory globals and the `adjustaggr`,
`adjust`, `adjustgender`, `adjustsec`, `control` and `controlcorp`
programs that nearly every other file calls. Section 1 lists, in a table, every path you must enter (the marked
`<<SET ...>>` lines - only for the steps you run) and which file needs it;
the working directory defaults to the folder Stata is started in. The same
section holds the download switch, `global download` (0 = use the stored
Eurostat tables, 1 = download them again).
**Enter your paths and run it first** - the programs live only in the current
Stata session's memory, so it has to be re-run in each new session, and a
`clear all` in mid-run drops them.

## Repository layout

| Path | Contents |
| --- | --- |
| `ENTA_setup.do` | Path globals, the download switch and the shared adjustment programs - run first |
| `ENTA_input_data/` | Microdata prep (`Micro_*.do`), supplementary aggregate builders (`Suppl_*.do`), ESA2010 sector accounts (`Aggr_ESA2010*.do`), two country-code helpers, and the input files listed above |
| `ENTA_ageprofiles/` | The five do-files that build the age profiles; they write the per-country results to `ageprofiles/` |
| `ENTA_aggregates/` | `ENTA_aggregates_compilation.do` (the ESA2010 totals everything reconciles against), `ENTA_units.do` (unit conversion factors), and `ENTA_generate_manual_tables.do` (a documentation utility); they write `ENTA_aggregates.dta` and `ENTA_units.dta` |
| `ENTA_compilation1_esa.do` | Combines the age profiles into the full account, ESA concepts |
| `ENTA_compilation2_nta.do` | Final compilation under NTA concepts |
| `ENTA_diagnostic/` | Re-runnable checks on the published output, and the triage ledger - see its own README |
| `2026_ENTA_Manual_V_2_0_0/Manual.pdf` | The manual |

## Run order

On a build from scratch the order is:

1. `ENTA_setup.do`.
2. `ENTA_input_data/`, in any order except:
   - `Micro_HBS_Austria.do` before `Micro_HBS.do`.
   - `Suppl_consumption_hh_coicop.do` after `Aggr_ESA2010.do`.
   - `Micro_impute_cons_into_SILC.do` is the exception - it belongs at
     step 5.
   - `Micro_SILC.do` and `Micro_HBS.do` call `adjustaggr`, which reads
     `ENTA_aggregates.dta`, and `Micro_HBS.do` also reads `ENTA_units.dta`;
     on a build from scratch run them after step 3.
   - `Micro_EUROMOD.do` and `Suppl_population_UN.do` can be skipped: their
     outputs (`taxr.dta`, `inctax_nonempl_decomp.dta`, `population_UN.dta`)
     are in the repository.
3. `ENTA_aggregates/ENTA_aggregates_compilation.do`, then
   `ENTA_aggregates/ENTA_units.do` (unit conversion factors, from the
   aggregates and the supplementary data). Everything downstream reconciles
   against the totals these write.
4. `ENTA_ageprofiles/`: `ENTA_income.do`, `ENTA_taxes.do`,
   `ENTA_benefits.do`, `ENTA_employment.do`. These scale to the
   aggregates, so they come after step 3.
5. `ENTA_input_data/Micro_impute_cons_into_SILC.do`. It reads
   `ENTA_units.dta` from step 3, which is why it runs here rather than with
   the rest of its own folder. Steps 5-6 read none of the step-4 profiles,
   so the two groups can run in either order.
6. `ENTA_ageprofiles/ENTA_consumption_intrahousehold_transfers.do`, which
   needs the imputed consumption from step 5.
7. `ENTA_compilation1_esa.do`, then `ENTA_compilation2_nta.do`, **in the
   same Stata session**: compilation2 uses a program that only
   compilation1 defines. Compilation1 also computes the NTA and ENTA norms
   from the income profile and publishes `ENTA_units`.
8. `ENTA_diagnostic/diagnostic_scan.R` (R, run from the project root).

Steps 3 to 8 take roughly three quarters of an hour together. Step 2 is
much longer and is only needed when rebuilding from the microdata.

## Checking the output

`ENTA_diagnostic/diagnostic_scan.R` reads the four published CSV files and
rebuilds nothing. Each check is one row of `checks.csv`. Invariants are
defects when they fail: every profile must reconcile with its aggregate,
the accounting identities must hold, men and women must add up to the
total, and quantities floored at zero must not be negative. The other
checks look for missing or zero-filled data, level and shape breaks,
changes in the share of men, and unusual spikes in an age profile; these
are judgements rather than defects - most are real events in the data.
`events.csv` and `event_scope.csv` are the ledger of the ones already
examined and explained; the scan reports only what is not in it, so a run
that reports nothing new means the output is in its known state. See
`ENTA_diagnostic/README.md`.

## Funding

This project receives funding from the European Union's Horizon Europe
Research and Innovation Programme under Grant Agreement No. 101095175 and
from the UK Government. It builds on work from the Generational Satellite
Accounts project, financed by the Jubilaeumsfonds of the Austrian
National Bank under Project No. 18465.

The responsibility for all conclusions drawn from the data lies entirely
with the authors.
