# Shtigjet dhe konstantet e app-it.

get_app_dir <- function() {
  d <- getOption("shiny.appdir")
  if (!is.null(d) && dir.exists(d)) {
    return(normalizePath(d, winslash = "/", mustWork = FALSE))
  }

  # Shiny bën setwd(appDir) para se të ngarkojë R/. Kjo ka përparësi ndaj
  # dokumentit aktiv të RStudio-s, që mund të jetë një skedar brenda R/ (T-06).
  wd <- normalizePath(getwd(), winslash = "/", mustWork = FALSE)
  if (file.exists(file.path(wd, "app.R"))) return(wd)

  if (interactive() &&
      requireNamespace("rstudioapi", quietly = TRUE) &&
      rstudioapi::isAvailable()) {
    p <- tryCatch(rstudioapi::getActiveDocumentContext()$path, error = function(e) "")
    if (nzchar(p)) return(dirname(normalizePath(p, winslash = "/", mustWork = FALSE)))
  }

  normalizePath(getwd(), winslash = "/", mustWork = FALSE)
}

APP_DIR <- get_app_dir()

DATA_DIR  <- file.path(APP_DIR, "data")

if (!dir.exists(DATA_DIR)) dir.create(DATA_DIR, recursive = TRUE)

STATE_FILE <- file.path(DATA_DIR, "datasets_state.json")

BG_STATE_FILE <- file.path(DATA_DIR, "background_state.json")

