# State-i i dataset-eve: datasets_state.json.

default_state <- function() {
  data.frame(
    file      = character(),
    added_at  = character(),
    is_active = logical(),
    time_col  = character(),
    value_cols = I(list()),
    stringsAsFactors = FALSE
  ) |>
    (\(df) list(active = NULL, datasets = df))()
}

read_state <- function(path = STATE_FILE) {
  if (!requireNamespace("jsonlite", quietly = TRUE)) {
    stop("Mungon paketa 'jsonlite'. Instalo: install.packages('jsonlite')")
  }

  if (!file.exists(path)) return(default_state())

  sz <- suppressWarnings(file.size(path))
  if (is.na(sz) || sz == 0) return(default_state())

  raw <- tryCatch(
    paste(readLines(path, warn = FALSE, encoding = "UTF-8"), collapse = "\n"),
    error = function(e) ""
  )
  if (!nzchar(trimws(raw))) return(default_state())

  st <- tryCatch(
    jsonlite::fromJSON(raw, simplifyVector = TRUE),
    error = function(e) {
      ts <- format(Sys.time(), "%Y%m%d_%H%M%S")
      bak <- paste0(path, ".corrupt_", ts)
      try(file.copy(path, bak, overwrite = TRUE), silent = TRUE)
      try(file.remove(path), silent = TRUE)
      default_state()
    }
  )

  if (is.null(st$active)) st$active <- NULL

  if (is.null(st$datasets) || !is.data.frame(st$datasets)) {
    st$datasets <- default_state()$datasets
  }

  if (!("time_col" %in% names(st$datasets))) st$datasets$time_col <- NA_character_
  if (!("value_cols" %in% names(st$datasets))) st$datasets$value_cols <- I(vector("list", nrow(st$datasets)))
  if (!is.list(st$datasets$value_cols)) {
    st$datasets$value_cols <- as.list(st$datasets$value_cols)
  }

  needed <- c("file","added_at","is_active","time_col","value_cols")
  for (k in needed) if (!(k %in% names(st$datasets))) st$datasets[[k]] <- NA

  st$datasets$file <- as.character(st$datasets$file)
  st$datasets$added_at <- as.character(st$datasets$added_at)
  st$datasets$is_active <- as.logical(st$datasets$is_active)
  st$datasets$time_col <- as.character(st$datasets$time_col)

  st
}

write_state <- function(obj, path = STATE_FILE) {
  dir.create(dirname(path), showWarnings = FALSE, recursive = TRUE)

  tmp <- paste0(path, ".tmp")

  json <- jsonlite::toJSON(
    obj,
    auto_unbox = TRUE,
    pretty = TRUE,
    null = "null"
  )

  writeLines(json, tmp, useBytes = TRUE)

  if (file.exists(path)) file.remove(path)
  ok <- file.rename(tmp, path)

  if (!ok) {
    file.copy(tmp, path, overwrite = TRUE)
    file.remove(tmp)
  }

  TRUE
}

sync_state <- function(files) {
  st <- read_state()

  if (nrow(st$datasets) > 0) {
    st$datasets <- st$datasets[st$datasets$file %in% files, , drop = FALSE]
  }

  existing <- st$datasets$file
  new_files <- setdiff(files, existing)

  if (length(new_files) > 0) {
    add_df <- data.frame(
      file      = new_files,
      added_at  = as.character(Sys.time()),
      is_active = FALSE,
      time_col  = NA_character_,
      value_cols = I(rep(list(character(0)), length(new_files))),
      stringsAsFactors = FALSE
    )
    st$datasets <- rbind(st$datasets, add_df)
  }

  if (is.null(st$active) || !nzchar(st$active) || !(st$active %in% files)) {
    if (nrow(st$datasets) > 0 && any(st$datasets$is_active)) {
      st$active <- st$datasets$file[which(st$datasets$is_active)[1]]
    } else {
      st$active <- if (length(files) > 0) files[1] else NULL
    }
  }

  st$datasets$is_active <- !is.null(st$active) & (st$datasets$file == st$active)

  write_state(st)
  st
}

set_active_dataset <- function(file) {
  files <- list_saved_datasets()
  st <- sync_state(files)

  if (is.null(file) || !nzchar(file) || !(file %in% files)) return(st)

  st$active <- file
  st$datasets$is_active <- st$datasets$file == file

  write_state(st)
  st
}

get_ds_idx <- function(st, file) {
  if (is.null(st$datasets) || nrow(st$datasets) == 0) return(NA_integer_)
  idx <- which(st$datasets$file == file)
  if (length(idx) == 0) return(NA_integer_)
  idx[1]
}

update_dataset_config <- function(st, file, time_col, value_cols) {
  i <- get_ds_idx(st, file)
  if (is.na(i)) return(st)

  st$datasets$time_col[i] <- as.character(time_col)

  value_cols <- as.character(value_cols %||% character(0))
  st$datasets$value_cols[[i]] <- value_cols

  st
}

get_dataset_config <- function(st, file) {
  i <- get_ds_idx(st, file)
  if (is.na(i)) return(list(time_col = NULL, value_cols = character(0)))

  tc <- st$datasets$time_col[i]
  if (is.na(tc) || !nzchar(tc)) tc <- NULL

  vc <- st$datasets$value_cols[[i]]
  vc <- as.character(vc %||% character(0))

  list(time_col = tc, value_cols = vc)
}

list_saved_datasets <- function() {
  sort(list.files(
    DATA_DIR,
    pattern = "\\.(csv|tsv|xlsx|xls)$",
    ignore.case = TRUE,
    full.names = FALSE
  ))
}

