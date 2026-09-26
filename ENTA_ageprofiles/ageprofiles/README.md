# ENTA_ageprofiles/ageprofiles

The per-country age profiles are written here, one file per profile type and
country (`<CC>` = two-letter country code). The folder is empty in the
repository: the do-files in `ENTA_ageprofiles/` build the profiles from the
EU-SILC, HBS and LFS microdata, which are not public.

| File | Contents | Written by |
| --- | --- | --- |
| `inc_<CC>.dta` | Income: employment, mixed and property income | `ENTA_income.do` |
| `tax_<CC>.dta` | Taxes and social contributions by type of income | `ENTA_taxes.do` |
| `ben_<CC>.dta` | Public cash benefits: pensions, unemployment, family and other | `ENTA_benefits.do` |
| `lfs_<CC>.dta` | Employment rates and working hours | `ENTA_employment.do` |
| `ctpriv_<CC>.dta` | Private consumption and intrahousehold transfers | `ENTA_consumption_intrahousehold_transfers.do` |
| `cfe_cfh_1015_<CC>.dta` | Intermediate: HBS age and sex pattern of education and health consumption, read again by the same file | `ENTA_consumption_intrahousehold_transfers.do` |

Each profile is by year, single year of age (0-80, where 80 is 80 and over)
and sex. `ENTA_compilation1_esa.do` merges them, scales them to the
aggregates and writes the final data to `ENTA_output_data/`. Public
consumption profiles (education, health) are built inside the compilation and
are not saved here. The run order is in the README at the project root.
