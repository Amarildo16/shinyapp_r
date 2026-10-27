# Ngarkon R/ për testet njësoj si Shiny (loadSupport), me APP_DIR te një sandbox
# i përkohshëm: asnjë test nuk prek data/ e projektit (QUALITY.md).

library(testthat)  # edhe që renv ta regjistrojë te renv.lock

APP_ROOT <- normalizePath(file.path("..", ".."), winslash = "/", mustWork = TRUE)

for (p in c("shiny", "shinyjs", "plotly", "ggplot2", "dplyr", "tidyr", "readr",
            "forecast", "scales", "tseries", "DT", "jsonlite", "zoo")) {
  suppressPackageStartupMessages(library(p, character.only = TRUE))
}
options(scipen = 999)

TEST_SANDBOX <- normalizePath(tempfile("app_sandbox_"), winslash = "/", mustWork = FALSE)
dir.create(TEST_SANDBOX, recursive = TRUE)
options(shiny.appdir = TEST_SANDBOX)

shiny::loadSupport(APP_ROOT, renv = environment(), globalrenv = NULL)

fixture <- function(name) file.path(APP_ROOT, "tests", "fixtures", name)

# Seria e përgatitur si te df_dyn() i app-it: numrat, koha, dublikatat, grid-i.
prepare_fixture <- function(name, time_col, value_cols) {
  d <- read_data_safe(fixture(name), name)
  for (v in value_cols) d[[v]] <- to_numeric_safe(d[[v]])
  d <- make_df_dyn(d, time_col)
  d <- d[, c("Time", value_cols), drop = FALSE]
  d <- apply_dup_policy(d, vc = value_cols, method = "mean")
  apply_freq_policy(d, freq = "auto", vc = value_cols)
}
