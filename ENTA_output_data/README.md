# ENTA_output_data

The final ENTA datasets are written here. The folder is empty in the
repository: the code fills it. The published version of these files is on
Zenodo: https://doi.org/10.5281/zenodo.20360412

| File | Contents | Written by |
| --- | --- | --- |
| `ENTA_esa.dta`, `.csv`, `.zip` | Age profiles in ESA format, long, nominal euro per capita | `ENTA_compilation1_esa.do` |
| `ENTA_nta.dta`, `.csv`, `.zip` | Age profiles in NTA format, long, nominal euro per capita | `ENTA_compilation2_nta.do` |
| `ENTA_aggregates.dta`, `.csv` | Aggregates, long, nominal totals in million euro | `ENTA_aggregates/ENTA_aggregates_compilation.do` |
| `ENTA_units.dta`, `.csv` | Unit conversion factors, including the NTA and ENTA norms | `ENTA_compilation1_esa.do` |
| `ENTA_priv_wide.dta`, `ENTA_priv_wide_<CC>.dta` | ESA format, wide (intermediate; read by `ENTA_compilation2_nta.do`) | `ENTA_compilation1_esa.do` |
| `ENTA_nta_complete_wide.dta` | NTA format, wide (intermediate) | `ENTA_compilation2_nta.do` |

The four CSV files are the published data; each `.zip` holds the CSV of the
same name. Other units (real, PPS, normalised) are calculated from
`ENTA_units` - the manual gives the formulas.

`ENTA_diagnostic/diagnostic_scan.R` checks the four CSV files; see the README
in `ENTA_diagnostic/`.
