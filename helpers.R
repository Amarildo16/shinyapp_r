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

APP_DIR  <- get_app_dir()
DATA_PATH <- file.path(APP_DIR, "data", "albania_agriculture_timeseries_1998_2024.csv")

has_vars <- requireNamespace("vars", quietly = TRUE)
has_rugarch <- requireNamespace("rugarch", quietly = TRUE)

read_data_safe <- function(path) {
  if (!file.exists(path)) {
    stop("Dataset not found at: ", normalizePath(path, winslash = "/", mustWork = FALSE))
  }
  readr::read_csv(path, show_col_types = FALSE) %>%
    mutate(Year = as.integer(Year))
}