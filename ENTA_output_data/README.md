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
| `ENTA_esa.parquet`, `ENTA_nta.parquet`, `ENTA_aggregates.parquet`, `ENTA_units.parquet` | The four CSV files in Parquet format, same columns and rows; read by the ENTA data explorer | `ENTA_compilation3_parquet.R` |
| `ENTA_priv_wide.dta` | ESA format, wide (intermediate; read by `ENTA_compilation2_nta.do`). The per-country files `ENTA_priv_wide_<CC>.dta` exist only during the run and are erased after the append | `ENTA_compilation1_esa.do` |
| `ENTA_nta_complete_wide.dta` | NTA format, wide (intermediate) | `ENTA_compilation2_nta.do` |

The four CSV files are the published data; each `.zip` holds the CSV of the
same name. Other units (real, PPS, normalised) are calculated from
`ENTA_units` - the manual gives the formulas.

The checks in `ENTA_output_control/` control these files; see the README
there.
