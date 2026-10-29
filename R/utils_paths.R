# Siguria e shtigjeve dhe emrave të skedarëve.

normalize_app_path <- function(path) {
  normalizePath(path, winslash = "/", mustWork = FALSE)
}

is_path_inside_dir <- function(path, dir) {
  path_norm <- sub("/+$", "", normalize_app_path(path))
  dir_norm  <- sub("/+$", "", normalize_app_path(dir))

  if (.Platform$OS.type == "windows") {
    path_norm <- tolower(path_norm)
    dir_norm  <- tolower(dir_norm)
  }

  identical(path_norm, dir_norm) || startsWith(path_norm, paste0(dir_norm, "/"))
}

resolve_saved_dataset_path <- function(file, data_dir = DATASETS_DIR) {
  bad <- function(msg = "Dataset i pavlefshëm.") {
    list(ok = FALSE, file = NULL, path = NULL, msg = msg)
  }

  if (is.null(file) || length(file) != 1 || is.na(file) || !nzchar(as.character(file))) {
    return(bad())
  }

  file <- as.character(file)
  files <- list_saved_datasets()

  if (sum(files == file) != 1) {
    return(bad("Dataset-i i zgjedhur nuk është i ruajtur ose nuk lejohet."))
  }

  base_dir <- normalize_app_path(data_dir)
  path <- normalize_app_path(file.path(data_dir, file))

  if (!is_path_inside_dir(path, base_dir)) {
    return(bad("Shtegu i dataset-it nuk lejohet."))
  }

  if (!file.exists(path)) {
    return(bad("Dataset-i s’u gjet në /data."))
  }

  list(ok = TRUE, file = file, path = path, msg = NULL)
}

sanitize_filename <- function(x, default_ext = "csv") {
  x <- basename(as.character(x %||% ""))
  x <- trimws(x)
  x <- gsub("[^A-Za-z0-9._-]+", "_", x)
  x <- gsub("_+", "_", x)
  x <- sub("^_+", "", x)
  x <- sub("_+$", "", x)

  if (!nzchar(x)) {
    x <- paste0("dataset_", format(Sys.time(), "%Y%m%d_%H%M%S"), ".", default_ext)
  }

  ext <- tools::file_ext(x)
  if (!nzchar(ext)) x <- paste0(x, ".", default_ext)
  x
}

