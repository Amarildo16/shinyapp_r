suppressPackageStartupMessages({
  library(shiny)
  library(plotly)
  library(ggplot2)
  library(dplyr)
  library(readr)
  library(forecast)
  library(scales)
  library(shinyjs)
  library(tidyr)
})
options(scipen = 999)

get_app_dir <- function() {
  d <- getOption("shiny.appdir")
  if (!is.null(d) && dir.exists(d)) {
    return(normalizePath(d, winslash = "/", mustWork = FALSE))
  }

  if (interactive() &&
      requireNamespace("rstudioapi", quietly = TRUE) &&
      rstudioapi::isAvailable()) {
    p <- tryCatch(rstudioapi::getActiveDocumentContext()$path, error = function(e) "")
    if (nzchar(p)) return(dirname(normalizePath(p, winslash = "/", mustWork = FALSE)))
  }

  normalizePath(getwd(), winslash = "/", mustWork = FALSE)
}

APP_DIR   <- get_app_dir()
DATA_PATH <- file.path(APP_DIR, "data", "albania_agriculture_timeseries_1998_2024.csv")

has_vars   <- requireNamespace("vars", quietly = TRUE)
has_rugarch <- requireNamespace("rugarch", quietly = TRUE)

read_data_safe <- function(path) {
  if (!file.exists(path)) {
    stop("Dataset nuk u gjet në shtegun: ", normalizePath(path, winslash = "/", mustWork = FALSE))
  }

  readr::read_csv(path, show_col_types = FALSE) %>%
    mutate(Year = as.integer(Year))
}

# =========================================================
# Meta-informacion (etiketa + njësi) për variablat
# =========================================================
var_meta <- function(var) {
  switch(
    var,
    "Production_ton"   = list(label = "Prodhimi bujqësor", unit = "ton"),
    "Yield_ton_per_ha" = list(label = "Rendimenti bujqësor", unit = "ton/ha"),
    "Rainfall_mm"      = list(label = "Reshjet vjetore", unit = "mm"),
    list(label = var, unit = "")
  )
}

# =========================================================
# Formatim akademik i numrave (pa 1e+06)
# =========================================================
fmt_fixed <- function(x, digits = 2) {
  ifelse(
    is.na(x),
    NA_character_,
    format(
      round(x, digits),
      nsmall = digits,
      big.mark = " ",
      decimal.mark = ",",
      scientific = FALSE,
      trim = TRUE
    )
  )
}

fmt_compact <- function(x, digits = 1) {
  out <- vapply(x, function(v) {
    if (is.na(v)) return(NA_character_)
    av <- abs(v)

    if (av >= 1e9) {
      val <- v / 1e9; suf <- " mld"
    } else if (av >= 1e6) {
      val <- v / 1e6; suf <- " mln"
    } else if (av >= 1e3) {
      val <- v / 1e3; suf <- " mijë"
    } else {
      val <- v; suf <- ""
    }

    s <- format(
      round(val, digits),
      nsmall = digits,
      big.mark = " ",
      decimal.mark = ",",
      scientific = FALSE,
      trim = TRUE
    )

    s <- sub(",0+$", "", s)
    paste0(s, suf)
  }, character(1))

  out
}

fmt_by_var <- function(x, var, for_axis = TRUE) {
  if (var == "Production_ton") {
    return(fmt_compact(x, digits = 1))
  }
  if (var == "Yield_ton_per_ha") {
    return(fmt_fixed(x, digits = 2))
  }
  if (var == "Rainfall_mm") {
    return(fmt_fixed(x, digits = 1))
  }

  if (for_axis) fmt_compact(x, digits = 1) else fmt_fixed(x, digits = 2)
}

fmt_unit <- function(x, var) {
  m <- var_meta(var)
  paste0(fmt_by_var(x, var, for_axis = FALSE), " ", m$unit)
}
