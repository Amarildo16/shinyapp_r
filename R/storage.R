# storage/ (V-05, U-04): të dhënat e përdoruesit jashtë kodit, me migrim që KOPJON.
#
# storage/datasets  CSV-të e përdoruesit
# storage/images    fotot e ngarkuara (përdoren nga Faza 6)
# storage/state     datasets_state.json, background_state.json, settings.json, storage.json
#
# Migrimi bëhet një herë, kur mungon storage/state/storage.json (T-08):
#  1. kopje rezervë e JSON-eve të vjetra te storage/state/backup-<data>/
#  2. CSV-të e data/ -> storage/datasets; dataset-et e listuara në state-in e vjetër
#     që mungojnë te data/ (shembujt që kaluan te data/samples/) merren nga data/samples/
#  3. JSON-et e data/ -> storage/state
#  4. nëse storage/datasets mbetet bosh: shembujt nga data/samples/
# Asgjë nuk fshihet ose mbishkruhet te data/. Çdo kopje verifikohet me md5.

DATA_FILE_PATTERN <- "\\.(csv|tsv|xlsx|xls)$"
LEGACY_STATE_FILES <- c("datasets_state.json", "background_state.json")

# Kopjon vetëm skedarët që mungojnë te `to_dir`; kthen destinacionet e reja.
copy_missing_files <- function(from, to_dir) {
  done <- character(0)
  for (f in from) {
    dest <- file.path(to_dir, basename(f))
    if (file.exists(dest)) next

    ok <- file.copy(f, dest, overwrite = FALSE, copy.date = TRUE)
    if (!isTRUE(ok) || !identical(unname(tools::md5sum(f)), unname(tools::md5sum(dest)))) {
      if (isTRUE(ok)) unlink(dest)  # vetëm kopja e sapokrijuar, kurrë origjinali
      stop("Kopjimi i skedarit dështoi: ", f)
    }
    done <- c(done, dest)
  }
  done
}

list_data_files <- function(dir) {
  if (!dir.exists(dir)) return(character(0))
  sort(list.files(dir, pattern = DATA_FILE_PATTERN, ignore.case = TRUE))
}

init_storage <- function(app_dir = APP_DIR, samples_dir = SAMPLES_DIR) {
  storage   <- file.path(app_dir, "storage")
  ds_dir    <- file.path(storage, "datasets")
  state_dir <- file.path(storage, "state")
  for (d in c(ds_dir, file.path(storage, "images"), state_dir)) {
    if (!dir.exists(d)) dir.create(d, recursive = TRUE)
  }

  marker <- file.path(state_dir, "storage.json")
  if (file.exists(marker)) return(invisible(jsonlite::fromJSON(marker)))

  legacy <- file.path(app_dir, "data")
  legacy_files <- list_data_files(legacy)
  legacy_json  <- LEGACY_STATE_FILES[file.exists(file.path(legacy, LEGACY_STATE_FILES))]

  backup <- NULL
  if (length(legacy_json) > 0) {
    backup <- file.path(state_dir, paste0("backup-", format(Sys.time(), "%Y%m%d-%H%M%S")))
    dir.create(backup, recursive = TRUE)
    copy_missing_files(file.path(legacy, legacy_json), backup)
  }

  listed <- character(0)
  if ("datasets_state.json" %in% legacy_json) {
    st <- tryCatch(read_state(file.path(legacy, "datasets_state.json")), error = function(e) NULL)
    listed <- as.character(st$datasets$file %||% character(0))
  }
  from_samples <- setdiff(listed, legacy_files)
  from_samples <- from_samples[from_samples == basename(from_samples) &
                               file.exists(file.path(samples_dir, from_samples))]

  migrated <- c(
    copy_missing_files(file.path(legacy, legacy_files), ds_dir),
    copy_missing_files(file.path(samples_dir, from_samples), ds_dir),
    copy_missing_files(file.path(legacy, legacy_json), state_dir)
  )

  samples <- character(0)
  if (length(list_data_files(ds_dir)) == 0) {
    samples <- copy_missing_files(file.path(samples_dir, list_data_files(samples_dir)), ds_dir)
  }

  info <- list(
    version    = 1L,
    created_at = format(Sys.time(), "%Y-%m-%d %H:%M:%S"),
    migrated   = I(basename(migrated)),
    samples    = I(basename(samples)),
    backup     = if (is.null(backup)) NULL else basename(backup)
  )
  jsonlite::write_json(info, marker, auto_unbox = TRUE, pretty = TRUE)
  invisible(info)
}

# ---- settings.json: gjuha (V-09) ----------------------------------------------

read_settings <- function(path = SETTINGS_FILE) {
  s <- list(lang = DEFAULT_LANG)
  if (!file.exists(path)) return(s)

  x <- tryCatch(jsonlite::fromJSON(path), error = function(e) NULL)
  if (is.list(x) && length(x$lang) == 1 && x$lang %in% names(LANGS)) s$lang <- x$lang
  s
}

write_settings <- function(settings, path = SETTINGS_FILE) {
  jsonlite::write_json(settings, path, auto_unbox = TRUE, pretty = TRUE)
}
