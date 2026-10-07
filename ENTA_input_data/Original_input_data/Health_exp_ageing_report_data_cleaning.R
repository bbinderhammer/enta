# Health_exp_ageing_report_data_cleaning.R - health expenditure age profiles
# of the Ageing Report
#
# Builds ENTA_input_data/Original_input_data/Health_exp_ageing_report.csv,
# which ENTA_CGH.do (not published) reads
# to make the public health profile CGH_AWG. Not part of the regular pipeline:
# run it only to rebuild the csv, e.g. after digitising a new Ageing Report.
#
# Input: the age profiles of public health expenditure per capita, by sex,
# from the 2018 and 2021 Ageing Reports, read off the published charts with
# WebPlotDigitizer 5.2 (A. Rohatgi, https://automeris.io) - one csv per country (";"-separated, decimal comma, columns
# age and rate) in the folders 2018m, 2018f, 2021m, 2021f of
# ENTA_input_data/Original_input_data/
# Health_exp_ageing_report_WebPlotDigitizerDaten.zip.
# Each curve is cleaned: ages rounded to whole years, duplicate points
# averaged, missing ages filled by linear interpolation.
#
# Output: one row per country, year and age, rates of men and women side by
# side (RATm, RATf).
#
# Run from the ENTA project root:
#   Rscript ENTA_input_data/Original_input_data/Health_exp_ageing_report_data_cleaning.R [output.csv]
# The optional argument writes elsewhere (for testing). Check charts per
# country are drawn only in an interactive session.

library(dplyr)
library(tidyr)
library(ggplot2)

if (!file.exists("ENTA_compilation1_esa.do")) stop("Run from the ENTA project root.")

indir <- file.path("ENTA_input_data", "Original_input_data")
zipf <- file.path(indir, "Health_exp_ageing_report_WebPlotDigitizerDaten.zip")
args <- commandArgs(trailingOnly = TRUE)
outf <- if (length(args) > 0) args[1] else file.path(indir, "Health_exp_ageing_report.csv")

unzip(zipf, exdir = tempdir())
src <- file.path(tempdir(), "WebPlotDigitizerDaten")

impute <- function(v, o, nam = c("AGE", "RAT")){ # Function to impute missing age data points
  num <- c(v[1]:v[length(v)])[which(!(c(v[1]:v[length(v)]) %in% v))]
  if(length(num) != 0){
    ind1 <- num - 1
    ind2 <- num + 1
    ind1 <- ind1[!(ind1 %in% num)]
    ind2 <- ind2[!(ind2 %in% num)]
    erg <- vector()
    for(i in 1:length(ind1)){
      diff <- ind2[i] - ind1[i] 
      erg <- c(erg, o[v == ind1[i]] + (o[v == ind2[i]] - o[v == ind1[i]]) * 
                 (c(1:(diff-1)) / diff))
    } 
    res <- data.frame(cbind(num, erg))
  }
  else{
    res <- data.frame(AGE = logical(), RAT = logical())
  }

  names(res) <- nam
  return(res)
}


clean <- function(df){ # Function to clean data and impute missing data using impute()
  names(df) <- c("AGE", "RAT")
  
  df$AGE <- round(df$AGE)
  
  df <- aggregate(df, RAT ~ AGE, mean)
  
  df.imp <- rbind(df, impute(df$AGE, df$RAT))
  df.imp <- df.imp[order(df.imp$AGE),]
  return(df.imp)
}


## read and clean each Dataset from WebPlotDigitizer

folders <- c("2018m", "2018f", "2021m", "2021f")
data <- list()

for (i in folders){
  year <- substr(i, 1, 4)
  sex <- substr(i, 5, 5)
  
  files <- list.files(file.path(src, i), full.names = TRUE)
  
  for(j in files){
    cou <- tools::file_path_sans_ext(basename(j))
    df <- read.csv2(j, sep = ";", header = FALSE)
    df <- clean(df)
    
    df$YEAR <- as.numeric(year)
    df$SEX <- sex
    df$CNT2 <- cou
    
    data <- append(data, list(df))
  }
}


data <- bind_rows(data)
data <- data[order(data$CNT2, data$SEX, data$YEAR),]

# long structure to wide structure by making sex indicator to own variables

data.wide <- data %>% 
  pivot_wider(
    names_from = SEX,
    values_from = RAT,
    names_prefix = "RAT"
  )

write.csv(data.wide, outf, row.names = FALSE)
cat("Written:", outf, "\n")

# Plots to check the data (interactive sessions only)

if (interactive()) {

for(i in unique(data$CNT2)){
  data.at <- data[data$CNT2 == i,]

  data.at$IND <- paste0(data.at$YEAR, data.at$SEX)
  data.at$YEAR <- factor(data.at$YEAR)
  data.at$SEX <- factor(data.at$SEX)

  p <- ggplot(data.at, aes(AGE, RAT, col = SEX, group = IND, linetype = YEAR)) +
    geom_line(linewidth = 1) +
    scale_linetype_manual(values = c("2018" = "dashed", "2021" = "solid")) +
    scale_color_manual(values = c("F" = "darkgreen", "M" = "goldenrod")) +
    labs(title = i) +
    theme(
      axis.text.x = element_text(size = 12),
      axis.text.y = element_text(margin = margin(t=3, r=3, b=3, l=3)),
      axis.title = element_text(size = 13),
      axis.ticks.length =  unit(0.1, "cm"),
      legend.background = element_rect(fill = "white"),
      legend.key = element_rect(fill = "white"),
      legend.text = element_text(size = 14),
      legend.title = element_blank(),
      strip.background = element_rect(fill = "white"),
      strip.text = element_text(size = 12),
      legend.position = "right",
      panel.background = element_rect(fill = "white"),
      panel.grid.major = element_line(colour = "grey90", linewidth = 0.25))
    plot(p)
}

EU14 <- c("BE", "DK", "DE", "IE", "EL", "ES", "FR", "IT", "LU", "NL", "AT", "PT", "FI", "SE", "NO")

ggplot(data[data$CNT2 %in% EU14 & data$YEAR == 2021 & data$SEX == "M",], aes(AGE, RAT, group = CNT2, col = CNT2)) +
  geom_line(linewidth = 1) +
  scale_y_continuous(limits = c(0, 40), breaks = seq(0, 40, by = 5)) +
  theme(
    axis.text.x = element_text(size = 12),
    axis.text.y = element_text(margin = margin(t=3, r=3, b=3, l=3)),
    axis.title = element_text(size = 13),
    axis.ticks.length =  unit(0.1, "cm"),
    legend.background = element_rect(fill = "white"),
    legend.key = element_rect(fill = "white"),
    legend.text = element_text(size = 14),
    legend.title = element_blank(),
    strip.background = element_rect(fill = "white"),
    strip.text = element_text(size = 12),
    legend.position = "right",
    panel.background = element_rect(fill = "white"),
    panel.grid.major = element_line(colour = "grey90", linewidth = 0.25))

}
