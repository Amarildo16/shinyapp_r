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
options(shiny.appdir = TEST_SANDBOX, app.code_dir = APP_ROOT)

shiny::loadSupport(APP_ROOT, renv = environment(), globalrenv = NULL)

# storage/ i sandbox-it, si te nisja e app-it; gjuha e testeve është shqipja.
init_storage()
set_lang("sq")

fixture <- function(name) file.path(APP_ROOT, "tests", "fixtures", name)

# Seria e përgatitur si te app-i: prepare_series() mbi fixture-in.
prepare_fixture <- function(name, time_col, value_cols) {
  d <- read_data_safe(fixture(name), name)
  prepare_series(list(file = name, data = d, time_col = time_col, value_cols = value_cols))$data
}
