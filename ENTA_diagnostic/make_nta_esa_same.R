# make_nta_esa_same.R
#
# Measures which NTA series are copies of an ESA series (same value in every
# country, year, sex and age, up to the rounding of the published CSV) and
# writes nta_esa_same.csv (columns NTA, ESA). diagnostic_scan.R reads that
# file: check I2 verifies every pair on each run, the other profile checks
# skip the NTA copies, and the ledger treats the two codes as one.
#
# Re-run it when an indicator is added to or renamed in the published files,
# then look at the diff of nta_esa_same.csv before keeping it.
#
# Run from the ENTA project root (~1 minute):
#   "C:\Program Files\R\R-4.6.1\bin\Rscript.exe" ENTA_diagnostic/make_nta_esa_same.R

suppressPackageStartupMessages(library(data.table))
if (!dir.exists("ENTA_output_data")) stop("Run from the ENTA project root.")
TOL <- 1e-6   # relative difference allowed, as i2_copy_rel in diagnostic_scan.R

k <- c("CNT2","YEAR","SEX","AGE")
e <- fread("ENTA_output_data/ENTA_esa.csv", select = c(k, "IND", "VALUE"))
n <- fread("ENTA_output_data/ENTA_nta.csv", select = c(k, "IND", "VALUE"))
we <- dcast(e, CNT2 + YEAR + SEX + AGE ~ IND, value.var = "VALUE")
wn <- dcast(n, CNT2 + YEAR + SEX + AGE ~ IND, value.var = "VALUE")
w  <- merge(wn, we, by = k, suffixes = c(".nta", ".esa"))
nn <- setdiff(names(wn), k); ee <- setdiff(names(we), k)
col <- function(x, s) if (paste0(x, s) %in% names(w)) w[[paste0(x, s)]] else w[[x]]

pairs <- rbindlist(lapply(nn, function(a) {
  va <- col(a, ".nta")
  hit <- ee[vapply(ee, function(b) {
    vb <- col(b, ".esa")
    all(!is.na(va) & !is.na(vb) & abs(va - vb) <= TOL * pmax(1, abs(vb)))
  }, TRUE)]
  if (length(hit)) data.table(NTA = a, ESA = hit[1]) else NULL
}))
fwrite(pairs[order(NTA)], "ENTA_diagnostic/nta_esa_same.csv")
cat(nrow(pairs), "NTA codes are copies of an ESA series:\n")
print(pairs[order(NTA)])
