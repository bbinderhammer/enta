# ENTA microdata checks

Quality checks that read the microdata (EU-SILC, HBS). They are run by
hand by a person with access to the microdata, after `ENTA_setup.do`, from the
ENTA root folder. They are not part of the output control in
`ENTA_output_control`, and an AI agent does not run them.

Each script writes only aggregated tables into `results/`. `results/` is not
kept under version control and is not published.

## Scripts for the manual chapter "Data quality assessment"

| Script | Question | Output in `results/` | In the manual |
|---|---|---|---|
| `cell_counts.do` | How many observations and receivers are behind each EU-SILC profile, by country, age and sex? | `cell_counts/` | Number of observations; the 20-receiver rule |
| `coverage_silc.do` | How much of each national accounts aggregate does EU-SILC capture? | `coverage/` | Comparing microdata and National Accounts |
| `imputation_check.do` | How well does the imputation of consumption into EU-SILC reproduce the HBS profiles? | `imputation/` | Imputation of consumption |
| `validation_agenta_ya.do` | Which allocation rules explain the difference in the age profile of asset income between ENTA and AGENTA 2010? | `agenta_ya_decomp.csv` | Comparison with AGENTA, asset income |
| `Manual_quality_tables.R` (in the manual folder, run from there) | Writes the three tables and the figure of the chapter from the results above. Reads no microdata. | tables and figure in the manual folder | |

The rest of the comparison with AGENTA and with national NTA results uses
only published data and is in `ENTA_output_control` (`4a` to `4c`).

## Script for the output control

| Script | Question | Output in `results/` |
|---|---|---|
| `survey_breaks.do` | For breaks in the published profiles that the output control could not explain: how many receivers are behind the variable, how is its total distributed over age groups and sexes, and do a few observations decide it? The cases are listed at the top of the script with their ledger rows. | `survey_breaks/` |

## Not in this folder

- The bootstrap of the sampling error and the split-sample test of the
  smoothing are used for the data paper only, not for the manual. Their
  scripts and results are outside the project, in the folder
  `2026_ENTA_data_paper` beside the ENTA folder.

## When to rerun

After a change in the preparation of the microdata (`Micro_*.do`) or in the
age profile files (`ENTA_ageprofiles`), and with a new release of the
microdata. Order: the three Stata scripts of the chapter, then
`Manual_quality_tables.R`. The numbers quoted in the text of the chapter are
not updated by the scripts.

## How the results reach the manual

1. The owner runs the Stata scripts. They write aggregated tables into
   `results/`. They write no log; in batch mode, delete the log Stata leaves
   in the folder it was started from.
2. The owner runs `Manual_quality_tables.R`. It writes the bodies of three
   tables and one figure into the manual folder. These are part of the
   published manual.
3. Numbers in the running text of the subsection "EU-SILC" and of the section
   on coverage are LaTeX macros. `Manual_quality_tables.R` writes them into
   `quality_values.tex` in the manual folder and prints each value beside the
   number of the manual of 2026-10-05, so that a wrong definition shows.
   The macros update the numbers, not the wording around them.
4. All other numbers in the running text that are not in one of the tables
   are read from `results/` by the owner and written into the text by the
   owner, or the owner passes on the conclusion in words.
5. Explanations in the ledger of the output control
   (`ENTA_output_control/ledger.csv`) that rest on `survey_breaks.do` are
   worded by the owner; the ledger is public and holds no figures from
   `results/`.

## Working with an AI agent

The agent may write or change these scripts on request. The project owner
runs them, and also runs `Manual_quality_tables.R`. The agent does not open,
search or list the content of the files in `results/`: it
reads only what is published (the manual with its tables, the published data
files). A search over the project leaves this folder out.
