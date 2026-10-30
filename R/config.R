# Shtigjet, faqet dhe konstantet e app-it: një vend i vetëm.

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

# ---- Shtigjet ----------------------------------------------------------------
# APP_DIR: ku jetojnë të dhënat (storage/ dhe data/ e vjetër).
# CODE_DIR: asetet që vijnë me kodin (i18n/, data/samples/). Në app janë i njëjti
# folder; testet e drejtojnë APP_DIR te një sandbox me option "app.code_dir" (T-09).
APP_DIR  <- get_app_dir()
CODE_DIR <- normalizePath(getOption("app.code_dir", APP_DIR), winslash = "/", mustWork = FALSE)

LEGACY_DATA_DIR <- file.path(APP_DIR, "data")
SAMPLES_DIR     <- file.path(CODE_DIR, "data", "samples")
I18N_DIR        <- file.path(CODE_DIR, "i18n")

STORAGE_DIR  <- file.path(APP_DIR, "storage")
DATASETS_DIR <- file.path(STORAGE_DIR, "datasets")
IMAGES_DIR   <- file.path(STORAGE_DIR, "images")
STATE_DIR    <- file.path(STORAGE_DIR, "state")

#  Fotot e background-it (Faza 6): 12 fotot default vijnë me kodin te www/images/
#  ("images/..."); fotot e ngarkuara jetojnë te storage/images/ ("user-images/...").
#  Dosja e vjetër www/images/ e APP_DIR mund të ketë fotot e ngarkuara para Fazës 6.
DEFAULT_BG_IMAGES  <- sprintf("image%d.jpeg", 0:11)
BG_DEFAULT_DIR     <- file.path(CODE_DIR, "www", "images")
LEGACY_IMAGES_DIR  <- file.path(APP_DIR, "www", "images")
USER_IMAGES_PREFIX <- "user-images"

STATE_FILE    <- file.path(STATE_DIR, "datasets_state.json")
BG_STATE_FILE <- file.path(STATE_DIR, "background_state.json")
SETTINGS_FILE <- file.path(STATE_DIR, "settings.json")

# ---- Faqet (P-12) -------------------------------------------------------------
# id -> tab "tab_<id>" dhe butoni "go_<id>". ID-të janë ato ekzistuese: përdoren nga
# JS dhe si çelësa te background_state.json (fotot për çdo faqe).
# Tekstet: i18n "page.<id>.menu" (menyja) dhe "page.<id>.title" (topbar-i).
PAGES <- list(
  list(id = "settings",   nav = FALSE),
  list(id = "overview",   nav = TRUE),
  list(id = "eda_ts",     nav = TRUE),
  list(id = "eda_rel",    nav = TRUE),
  list(id = "stationary", nav = TRUE),
  list(id = "modeling",   nav = TRUE),
  list(id = "forecast",   nav = TRUE)
)
DEFAULT_PAGE <- "overview"

page_ids  <- function(nav_only = FALSE) {
  ids <- vapply(PAGES, `[[`, character(1), "id")
  if (nav_only) ids[vapply(PAGES, `[[`, logical(1), "nav")] else ids
}
page_tab  <- function(id) paste0("tab_", id)
page_btn  <- function(id) paste0("go_", id)

# ---- Seritë dhe kufijtë (të njëjtat vlera si te legacy_server_plots.R) ----------
DUP_POLICY  <- "mean"   # P-11: dublikatat e kohës
FREQ_POLICY <- "auto"   # P-11: frekuenca

SERIES_COLORS <- c(observed = "white", ets = "#0a84ff", arima = "#ff3b30")

# ---- Ngarkimi i CSV-së (V-28) ---------------------------------------------------
# Kufiri i njëjtë për Shiny-n (shiny.maxRequestSize, te app.R) dhe FilePond-in (data-max-mb).
UPLOAD_MAX_MB <- 150
# Kolona e kohës dhe seritë propozohen nga kaq rreshta të shpërndarë njëtrajtësisht (B-27).
DETECT_SAMPLE_ROWS <- 5000L
# Pamja e vogël pas ngarkimit (V-33): vetëm kaq rreshta dhe kolona, jo gjithë skedari.
PREVIEW_ROWS <- 5L
PREVIEW_COLS <- 8L

# Horizonti maksimal i parashikimit dhe dritarja lëvizëse sipas hapit të kohës.
H_CAP    <- c(day = 90L, week = 26L, month = 24L, quarter = 12L, year = 10L)
H_CAP_DEFAULT <- 120L
ROLL_CAP <- c(day = 30L, week = 12L, month = 12L, quarter = 8L, year = 5L)
ROLL_CAP_DEFAULT <- 60L

# ---- Gjuhët (V-09) ---------------------------------------------------------------
LANGS <- c(sq = "Shqip", en = "English")
DEFAULT_LANG <- "sq"
