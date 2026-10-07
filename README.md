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
| Interactive data explorer | https://www.ntaeurope.eu/dataexplorer |
| Manual - methodology, codebook, limitations, interpretation | [`2026_ENTA_Manual_V_2_0_0/Manual.pdf`](2026_ENTA_Manual_V_2_0_0/Manual.pdf) (ENTA Manual V.2.0.0) |
| Codebook - the units and every indicator, as a document of its own (Appendices A to C of the manual) | [`2026_ENTA_Manual_V_2_0_0/Codebook.pdf`](2026_ENTA_Manual_V_2_0_0/Codebook.pdf) (ENTA Codebook V.2.0.0) |

The [manual](2026_ENTA_Manual_V_2_0_0/Manual.pdf) is the documentation of
the data: it describes the NTA/ESA methodology, every variable, the
limitations and country-specific treatments, and the patterns in the data
that a user must know. This README describes the repository: what is in it,
the order in which the files run, and what each file does.

## What is in this repository, and what is not

**Included**

- All code: the setup file, the input-data preparation
  (`ENTA_input_data/*.do`), the age profiles, the aggregates, the two
  compilation files and the Parquet script, the label file, the output
  control and the checks that read microdata.
- The Eurostat tables as downloaded for this version, in
  `ENTA_input_data/Original_input_data/`, one Stata file per table under its
  Eurostat code (`nasa_10_nf_tr`, `gov_10a_exp`, `nama_10_co3_p3`,
  `demo_pjan`, `educ_enrl1tl`, `educ_uoe_enra02`, `prc_hicp_aind`,
  `prc_ppp_ind`). Eurostat revises its tables, so these copies are what
  makes the published aggregates reproducible; the manual gives the download
  date of each.
- The benchmark data of the external comparisons, in
  `ENTA_output_control/benchmarks/` (AGENTA 2010, the global NTA database,
  the Austrian NTA 2015; sources in the README there).
- The input files that cannot be downloaded from Eurostat, in
  `ENTA_input_data/`:
  - `Original_input_data/CPI_world_bank.xls` - consumer prices, World Bank.
  - `Original_input_data/taxud_tax_ec_func_en.csv` - tax revenue by
    economic function, European Commission, DG TAXUD.
  - `Original_input_data/National_tax_list_2026.xlsx` - national tax lists
    and the split of personal income tax, DG TAXUD (read by
    `Suppl_tax_list.do`).
  - `Original_input_data/population_UN.dta` - population by age, UN World
    Population Prospects (the UN data portal needs a personal API token).
  - `Original_input_data/Health_exp_ageing_report_WebPlotDigitizerDaten.zip`
    - public health expenditure per capita by age and sex, read off the
    charts of the 2018 and 2021 Ageing Reports with WebPlotDigitizer 5.2
    (A. Rohatgi, https://automeris.io); one file per country, edition and
    sex.
  - `Original_input_data/Health_exp_ageing_report_data_cleaning.R` - cleans
    those points (whole ages, gaps interpolated) into
    `Original_input_data/Health_exp_ageing_report.csv`, the rates. Not part
    of the regular run; from the ENTA root:
    `Rscript ENTA_input_data/Original_input_data/Health_exp_ageing_report_data_cleaning.R`.
  - `ENTA_input_datasets/CGH_AWG.dta` - the public health expenditure
    profile built from those rates (2018 edition). The Stata file that builds
    it is not published.
  - `ENTA_input_datasets/taxr.dta` and `inctax_nonempl_decomp.dta` - tax
    shares by country and year derived from EUROMOD. They are aggregates
    and contain no microdata.
- The manual and the codebook, as PDF.

**Not included**

- **Microdata** - EU-SILC, HBS and LFS scientific-use files, obtained from
  Eurostat under contract; EUROMOD output; and the Austrian consumption
  survey (Konsumerhebung 2010 and 2015), provided by Statistics Austria.
  The versions used are listed under Requirements below.
- **Current Eurostat tables.** The stored tables are those of the download
  dates in the manual. The `Suppl_*.do` files and `Aggr_ESA2010.do`
  download current versions with the `eurostatuse` package when the switch
  `global download` in `ENTA_setup.do` is set to 1; a new download will not
  reproduce the published results exactly.
- **Output.** The age profiles (`ENTA_ageprofiles/ageprofiles/`), the
  aggregates (`ENTA_aggregates/*.dta`) and the final data
  (`ENTA_output_data/`) are rebuilt by the code. The published version is
  on Zenodo.

## Requirements

**Software**

- Stata. ENTA V.2.0.0 was produced with Stata 19 SE.
- Stata packages from SSC: `eurostatuse` (Eurostat downloads), `sumdist`
  and `supsmooth` - install with `ssc install <name>`.
- R for `ENTA_compilation3_parquet.R` (packages arrow and data.table) and
  for the scripts of the manual folder: `Manual_quality_tables.R` (base R),
  `Manual_make_figures.R` (arrow, dplyr, ggplot2, ragg),
  `Manual_aggregate_tables.R` (arrow). ENTA V.2.0.0 used R 4.6.1.

**Microdata** (request from Eurostat, the EUROMOD team and Statistics
Austria; versions used for ENTA V.2.0.0)

| Source | Version used |
| --- | --- |
| EU-SILC cross-sectional UDB, survey years 2009-2024 | 2025 release, revision 1 (December 2025; DOI 10.2907/EUSILC2004-2024REV1) |
| EU-LFS yearly files, data up to 2024 | 2025 release (January 2026; DOI 10.2907/LFS1983-2024) |
| HBS | Waves 2010 and 2015 |
| EUROMOD | J2.0+, with input data from 2024 |
| Konsumerhebung (Austria only), Statistics Austria | 2010 and 2015 |

## Setup

`ENTA_setup.do` defines the directory globals and the `adjustaggr`,
`adjust`, `adjustgender`, `adjustsec` and `gensex` programs that nearly
every other file calls. Section 1 lists, in a table, every path you must enter (the marked
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
| `ENTA_setup.do` | Path globals, the download switch and the shared adjustment programs - run first; `ENTA_setup_TU.do` is the same file with the paths of the machine that produced V.2.0.0 and is not published |
| `ENTA_input_data/` | Microdata prep (`Micro_*.do`), supplementary aggregate builders (`Suppl_*.do`), ESA2010 sector accounts (`Aggr_ESA2010*.do`), two country-code helpers, and the input files listed above |
| `ENTA_ageprofiles/` | The five do-files that build the age profiles; they write the per-country results to `ageprofiles/` |
| `ENTA_aggregates/` | `ENTA_aggregates_compilation.do` (the ESA2010 totals everything reconciles against), `ENTA_units.do` (unit conversion factors); they write `ENTA_aggregates.dta` and `ENTA_units.dta` |
| `ENTA_compilation1_esa.do` | Combines the age profiles into the full account, ESA concepts |
| `ENTA_compilation2_nta.do` | Final compilation under NTA concepts |
| `ENTA_compilation3_parquet.R` | Writes the four published CSV files as Parquet files of the same name (R, because Stata cannot write Parquet); the data explorer reads these |
| `ENTA_input_data/Prog_ENTA_labels.do` | Code, number and label of every published indicator; used by both compilations and by the aggregates |
| `ENTA_output_control/` | Checks of the published output and the ledger of explained patterns; needs no microdata - see its own README |
| `ENTA_microdata_checks/` | Quality checks that read the microdata, run by hand - see its own README |
| `2026_ENTA_Manual_V_2_0_0/Manual.pdf`, `Codebook.pdf` | The manual and the codebook |

## Run order

On a build from scratch the order is:

1. `ENTA_setup.do`.
2. `ENTA_input_data/`, in this order (the order in which the manual
   describes them):
   `Suppl_population_UN.do` (only to update `population_UN.dta`),
   `Suppl_population.do`, `Suppl_prices.do`, `Suppl_ppp_exchange_rates.do`,
   `Suppl_tax_structure.do`, `Suppl_tax_list.do`, `Aggr_ESA2010.do`,
   `Suppl_consumption_hh_coicop.do`, `Suppl_gov_expenditure.do`,
   `Suppl_enrollment_educ.do`, `Suppl_consumption_educ_profile.do`,
   `Micro_EUROMOD.do`, `Micro_LFS.do`, then
   after step 3 `Micro_SILC.do` (calls `Micro_SILC_famben.do`),
   `Micro_HBS_Austria.do`, `Micro_HBS.do`. The order follows what each file
   reads:
   - `Suppl_population.do` first: `Suppl_enrollment_educ.do`,
     `Micro_EUROMOD.do`, `Micro_LFS.do`, `Micro_SILC.do`,
     `Micro_HBS_Austria.do`, `Micro_HBS.do` and the public health profile
     read its population files.
   - `Suppl_consumption_educ_profile.do` (age profile of private education
     consumption) after `Suppl_enrollment_educ.do`: it reads
     `enrollment.dta`, the population and the Eurostat table that
     `Suppl_consumption_hh_coicop.do` downloads.
   - `Suppl_tax_structure.do` before `Aggr_ESA2010.do` (reads
     `taxstructure_wide.dta`), and `Aggr_ESA2010.do` before
     `Suppl_consumption_hh_coicop.do` (reads `esa_aggregates.dta`).
   - `Suppl_tax_list.do` (composition of the taxes on benefits from DG
     TAXUD's national tax lists) after `Suppl_ppp_exchange_rates.do`; its
     output `tb_taxlist.dta` is read in step 3.
   - `Micro_HBS_Austria.do` before `Micro_HBS.do`, which appends its files.
   - `Micro_SILC.do` and `Micro_HBS.do` call `adjustaggr`, which reads
     `ENTA_aggregates.dta`, and `Micro_HBS.do` also reads `ENTA_units.dta`;
     on a build from scratch run them after step 3.
   - `Micro_impute_cons_into_SILC.do` is the exception - it belongs at
     step 5.
   - `Micro_EUROMOD.do` and `Suppl_population_UN.do` can be skipped: their
     outputs (`taxr.dta`, `inctax_nonempl_decomp.dta`, `population_UN.dta`)
     are in the repository, as is the public health profile `CGH_AWG.dta`.
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
7. `ENTA_compilation1_esa.do`, then `ENTA_compilation2_nta.do`.
   Compilation1 also computes the NTA and ENTA norms from the income
   profile and publishes `ENTA_units`.
8. `Rscript ENTA_compilation3_parquet.R`, from the ENTA folder: the Parquet
   copies of the four published files (needs the R packages arrow and
   data.table).
9. The checks in `ENTA_output_control/`, in the order of their numbers.

Steps 3 to 9 take roughly three quarters of an hour together. Step 2 is
much longer and is only needed when rebuilding from the microdata.

## The code files

Each do-file starts with a header that states what the file does, what it
reads and what it writes. One line on each:

| File | What it does |
| --- | --- |
| **ENTA root** | |
| `ENTA_setup.do` | Paths, the download switch and the programs `adjustaggr`, `adjust`, `adjustsec` (scale a profile to its aggregate), `gensex` (a new variable with its versions for men and women) and `adjustgender` (make the profiles of men and women consistent with the total) |
| `ENTA_compilation1_esa.do` | Combines the age profiles and the aggregates into ENTA in ESA format; builds the corporate and government profiles and public consumption; writes `ENTA_esa` and `ENTA_units` |
| `ENTA_compilation2_nta.do` | Translates the result into NTA concepts; writes `ENTA_nta` |
| `ENTA_compilation3_parquet.R` | Writes the four published CSV files as Parquet files |
| **ENTA_input_data: aggregates and supplementary data** | |
| `Prog_ENTA_labels.do` | Code, number and label of every published indicator |
| `Prog_gen_CNT2_from_country_name.do`, `Prog_gen_country_name_from_CNT2.do` | Country code from country name, and the reverse |
| `Suppl_population.do` | Population by age and sex |
| `Suppl_population_UN.do` | Imports the UN population; only needed to update `population_UN.dta` |
| `Suppl_prices.do` | Harmonised index of consumer prices |
| `Suppl_ppp_exchange_rates.do` | Exchange rates and purchasing power parities |
| `Suppl_tax_structure.do` | Tax revenue by economic function (DG TAXUD): taxes on employment, self-employment and on the income of the non-employed |
| `Suppl_tax_list.do` | Composition of the taxes on the income of the non-employed, from DG TAXUD's national tax lists |
| `Aggr_ESA2010.do` | ESA sector accounts; calls `Aggr_ESA2010_allocate_transfers_to_sectors.do`, which estimates between which sectors transfers flow |
| `Suppl_consumption_hh_coicop.do` | Household consumption of education, health, imputed rent and other, from consumption by COICOP |
| `Suppl_gov_expenditure.do` | Government expenditure by function (COFOG): social benefits and public consumption by category |
| `Suppl_enrollment_educ.do` | Enrolment in education by level (ISCED 0-1, 2-4, 5-8), single age and sex; the basis of the age profiles of public and private education consumption |
| `Suppl_consumption_educ_profile.do` | Age profile of private education consumption: household spending on education by level (COICOP) distributed with enrolment |
| **ENTA_input_data: microdata** | |
| `Micro_EUROMOD.do` | Tax rates by type of income and age group, and the taxes per euro of each kind of transfer, from EUROMOD |
| `Micro_LFS.do` | Combines the yearly Labour Force Survey files |
| `Micro_SILC.do` | Combines the EU-SILC files of each country and prepares income, benefits, imputed rent and transfers between households; calls `Micro_SILC_famben.do`, which assigns the family benefits of the household to its members |
| `Micro_HBS_Austria.do` | Brings the Austrian Konsumerhebung into HBS format |
| `Micro_HBS.do` | Combines the HBS files of each country and prepares consumption by category |
| `Micro_impute_cons_into_SILC.do` | Imputes other consumption into EU-SILC with a model estimated on the HBS |
| **ENTA_aggregates** | |
| `ENTA_aggregates_compilation.do` | All ENTA aggregates by sector, in million euro; writes `ENTA_aggregates` |
| `ENTA_units.do` | The conversion factors for other units |
| **ENTA_ageprofiles** | |
| `ENTA_income.do` | Profiles of employment income, asset income and equivalised household income |
| `ENTA_taxes.do` | Profiles of taxes, from EU-SILC incomes and the EUROMOD tax rates |
| `ENTA_benefits.do` | Profiles of pensions, family, unemployment and other benefits |
| `ENTA_employment.do` | Employment rates and working hours from the Labour Force Survey |
| `ENTA_consumption_intrahousehold_transfers.do` | Profiles of private consumption and of the transfers within households |

Two files in wide format in `ENTA_output_data`, `ENTA_priv_wide.dta` and
`ENTA_nta_complete_wide.dta`, are intermediate results.

## Checking the output

The checks in `ENTA_output_control/` read the published files and rebuild
nothing; they need no microdata. `1_method_check.do` tests what must hold:
every profile adds up to its aggregate, components add up to their totals,
men and women add up to the total, and quantities that cannot be negative
are not. `2_aggregates_check.do` and `3_profiles_check.do` list the largest
breaks in the aggregates and in the age shapes; these are not errors by
themselves - most are real events in the data. `ledger.csv` holds the
patterns already examined, and each finding is marked with its ledger row
or as new. `4a` to `4c` compare ENTA with other NTA results; the benchmark
data are public and lie in `ENTA_output_control/benchmarks/`, with their
sources named in `ENTA_output_control/README.md`.

## Licence and citation

The code is published under the MIT licence (`LICENSE`). The ENTA data, the
manual and the codebook are published under CC BY 4.0. The input files from
Eurostat, the United Nations, the World Bank, DG TAXUD and the benchmark
data remain under the terms of their sources, named above and in the
manual.

Please cite the data set, not the code (`CITATION.cff` holds the same
citation in machine-readable form):

Hammer, B., Istenič, T., Verbič, M., Sambt, J., & Prskawetz, A. (2026).
European National Transfer Accounts (2.0.0) [Data set]. Zenodo.
https://doi.org/10.5281/zenodo.22550976

The DOI 10.5281/zenodo.20360412 covers all versions and resolves to the
latest one.

## Funding

This project receives funding from the European Union's Horizon Europe
Research and Innovation Programme under Grant Agreement No. 101095175 and
from the UK Government. It builds on work from the Generational Satellite
Accounts project, financed by the Jubilaeumsfonds of the Austrian
National Bank under Project No. 18465.

The responsibility for all conclusions drawn from the data lies entirely
with the authors.
