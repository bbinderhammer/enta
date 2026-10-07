################################################################################
# Parquet copies of the four published files
################################################################################
#
# Reads ENTA_esa.csv, ENTA_nta.csv, ENTA_aggregates.csv and ENTA_units.csv in
# ENTA_output_data and writes each as a Parquet file of the same name, with
# the same columns and rows. Stata cannot write Parquet, so this step is in R.
#
# The Parquet files are published with the CSV files. The ENTA data explorer
# reads them: copy the four files into its folder data/.
#
# Run from the ENTA folder, after ENTA_compilation2_nta.do:
#   Rscript ENTA_compilation3_parquet.R
# Needs the packages arrow and data.table.

library(arrow)

folder <- "ENTA_output_data"

for (name in c("ENTA_esa", "ENTA_nta", "ENTA_aggregates", "ENTA_units")) {
  csv <- file.path(folder, paste0(name, ".csv"))
  if (!file.exists(csv)) stop("Not found: ", csv)
  data <- data.table::fread(csv, data.table = FALSE)
  write_parquet(data, file.path(folder, paste0(name, ".parquet")), compression = "zstd")
  message(name, ".parquet: ", nrow(data), " rows, ",
          round(file.size(file.path(folder, paste0(name, ".parquet"))) / 1e6, 1), " MB")
}
