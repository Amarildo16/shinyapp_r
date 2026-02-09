suppressPackageStartupMessages({
  library(shiny)
  library(shinyjs)
  library(plotly)
  library(ggplot2)
  library(dplyr)
  library(tidyr)
  library(readr)
  library(forecast)
  library(scales)
  library(tseries)
  library(DT)
})

options(scipen = 999)

`%||%` <- function(a, b) {
  if (is.null(a)) return(b)
  if (length(a) == 0) return(b)

  if (is.character(a) && length(a) == 1) {
    if (!nzchar(a) || is.na(a)) return(b)
  }
  a
}

# -------------------------
# App dir
# -------------------------
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

APP_DIR <- get_app_dir()

DATA_DIR  <- file.path(APP_DIR, "data")
if (!dir.exists(DATA_DIR)) dir.create(DATA_DIR, recursive = TRUE)
DATA_PATH <- file.path(DATA_DIR, "albania_agriculture_timeseries_1998_2024.csv")


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

  # Siguro strukturën
  if (is.null(st$active)) st$active <- NULL

  if (is.null(st$datasets) || !is.data.frame(st$datasets)) {
    st$datasets <- default_state()$datasets
  }

  # Migrim nga format i vjetër (pa time_col / value_cols)
  if (!("time_col" %in% names(st$datasets))) st$datasets$time_col <- NA_character_
  if (!("value_cols" %in% names(st$datasets))) st$datasets$value_cols <- I(vector("list", nrow(st$datasets)))

  # Siguro list-column si duhet
  if (!is.list(st$datasets$value_cols)) {
    st$datasets$value_cols <- as.list(st$datasets$value_cols)
  }

  # Siguro kolonat bazë
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

  # atomic write: shkruaj tmp -> rename
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

  # filtro vetëm file-at që ekzistojnë
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

  # active validim
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

# ---- NEW: config helpers (time_col + value_cols) ----

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

  # value_cols si list-column
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

# -------------------------
# Optional packages checks
# -------------------------
has_zoo    <- requireNamespace("zoo", quietly = TRUE)
has_readxl <- requireNamespace("readxl", quietly = TRUE)
has_vars   <- requireNamespace("vars", quietly = TRUE)
has_rugarch <- requireNamespace("rugarch", quietly = TRUE)

# =========================================================
# 1) Read data safe
# =========================================================
read_data_safe <- function(path, filename = NULL) {
  if (!file.exists(path)) {
    stop("Dataset nuk u gjet në shtegun: ", normalizePath(path, winslash = "/", mustWork = FALSE))
  }

  ext <- tolower(tools::file_ext(filename %||% path))

  if (ext == "csv") {
    d <- readr::read_csv(
      path,
      show_col_types = FALSE,
      na = c("", "NA", "N/A", "null", "NULL"),
      col_types = readr::cols(.default = readr::col_character())
    )

  } else if (ext == "tsv") {
    d <- readr::read_tsv(
      path,
      show_col_types = FALSE,
      na = c("", "NA", "N/A", "null", "NULL"),
      col_types = readr::cols(.default = readr::col_character())
    )

  } else if (ext %in% c("xlsx", "xls")) {
    if (!has_readxl) stop("Për Excel duhet paketa 'readxl' (instaloje).")
    d <- readxl::read_excel(path, .name_repair = "unique_quiet")

    d <- dplyr::mutate(dplyr::as_tibble(d), dplyr::across(dplyr::everything(), as.character))

  } else {
    d <- readr::read_csv(
      path,
      show_col_types = FALSE,
      na = c("", "NA", "N/A", "null", "NULL"),
      col_types = readr::cols(.default = readr::col_character())
    )
  }

  as.data.frame(d, stringsAsFactors = FALSE)
}

# =========================================================
# 2) Time parsing
# =========================================================
parse_time_safe <- function(x) {
  if (inherits(x, "Date")) return(x)
  if (inherits(x, "POSIXt")) return(as.Date(x))
  if (is.numeric(x) || is.integer(x)) {
    xn  <- as.numeric(x)
    xn0 <- xn[!is.na(xn)]

    if (length(xn0) < 2) return(xn)

    if (all(xn0 >= 1500 & xn0 <= 3000) &&
        mean(abs(xn0 - round(xn0)) < 1e-8) >= 0.95) {
      return(round(xn))
    }

    xu <- sort(unique(xn0))
    if (length(xu) >= 3) {
      steps <- diff(xu)
      if (all(steps > 0) && (sd(steps) / mean(steps)) < 1e-6) {
        return(xn)
      }
    }

    return(xn)
  }

  x0 <- trimws(as.character(x))
  x0[x0 == ""] <- NA_character_

  if (all(grepl("^\\d{4}$", x0[!is.na(x0)]))) return(as.numeric(x0))

  if (all(grepl("^\\d{4}-\\d{2}$", x0[!is.na(x0)]))) {
    return(as.Date(paste0(x0, "-01")))
  }

  if (all(grepl("^\\d{4}Q[1-4]$", x0[!is.na(x0)]))) {
    yr <- as.integer(substr(x0, 1, 4))
    q  <- as.integer(substr(x0, 6, 6))
    m  <- (q - 1) * 3 + 1
    return(as.Date(sprintf("%04d-%02d-01", yr, m)))
  }

  try_formats <- c("%Y-%m-%d", "%d/%m/%Y", "%d-%m-%Y", "%Y/%m/%d", "%m/%d/%Y")
  ok_rate <- function(v) sum(!is.na(v)) / max(1, sum(!is.na(x0)))

  for (f in try_formats) {
    t <- suppressWarnings(as.Date(x0, format = f))
    if (ok_rate(t) >= 0.95) return(t)
  }

  t <- suppressWarnings(as.Date(x0))
  if (ok_rate(t) >= 0.95) return(t)

  stop("Kolona e kohës nuk u parse dot. Formate: YYYY, YYYY-MM, YYYY-MM-DD, YYYYQ#.")
}

# =========================================================
# 3) Numeric normalization
# =========================================================
to_numeric_safe <- function(x) {
  if (is.numeric(x))  return(as.numeric(x))
  if (is.integer(x))  return(as.numeric(x))

  s <- trimws(as.character(x))
  s[s == ""] <- NA_character_

  s <- gsub("^\\((.*)\\)$", "-\\1", s)

  s <- gsub("[^0-9., -]", "", s)

  s <- gsub("\\s+", "", s)

  s <- ifelse(is.na(s), NA_character_,
              paste0(ifelse(grepl("-", s, fixed = TRUE), "-", ""),
                     gsub("-", "", s, fixed = TRUE)))
  s <- ifelse(is.na(s), NA_character_, sub("^--+", "-", s))

  has_comma <- grepl(",", s, fixed = TRUE)
  has_dot   <- grepl("\\.", s)

  both <- has_comma & has_dot

  if (any(both, na.rm = TRUE)) {
    idx <- which(both & !is.na(s))

    for (i in idx) {
      si <- s[i]
      last_comma <- max(unlist(gregexpr(",", si, fixed = TRUE)))
      last_dot   <- max(unlist(gregexpr(".", si, fixed = TRUE)))

      if (last_comma > last_dot) {
        si <- gsub("\\.", "", si)
        si <- sub(",", ".", si, fixed = TRUE)
      } else {
        si <- gsub(",", "", si, fixed = TRUE)
      }
      s[i] <- si
    }
  }

  only_comma <- has_comma & !has_dot
  s[only_comma] <- sub(",", ".", s[only_comma], fixed = TRUE)

  has_multi_dot <- !is.na(s) & lengths(regmatches(s, gregexpr("\\.", s))) > 1
  if (any(has_multi_dot)) {
    idx <- which(has_multi_dot)
    for (i in idx) {
      si <- s[i]
      parts <- strsplit(si, "\\.", fixed = FALSE)[[1]]
      si2 <- paste0(paste(parts[-length(parts)], collapse = ""), ".", parts[length(parts)])
      s[i] <- si2
    }
  }

  suppressWarnings(as.numeric(s))
}

# =========================================================
# 4) Detect candidate time columns
# =========================================================
detect_time_candidates <- function(df) {
  nm <- names(df)
  scores <- rep(0, length(nm))

  for (i in seq_along(nm)) {
    col <- df[[i]]
    name_l <- tolower(nm[i])

    if (name_l %in% c("year","date","time","timestamp","period","month","quarter")) scores[i] <- scores[i] + 3
    if (grepl("date|time|year|month|quarter|period", name_l)) scores[i] <- scores[i] + 1

    ok <- tryCatch({
      t <- parse_time_safe(col)
      t0 <- t[!is.na(t)]
      if (length(t0) < 2) return(0)

      uniq_ratio <- length(unique(t0)) / length(t0)
      base_ok <- mean(!is.na(t))

      if (uniq_ratio < 0.85) base_ok <- base_ok - 0.25

      base_ok
    }, error = function(e) 0)


    if (ok >= 0.95) scores[i] <- scores[i] + 5
    else if (ok >= 0.70) scores[i] <- scores[i] + 2
  }

  out <- data.frame(
    col = nm,
    score = scores,
    stringsAsFactors = FALSE
  ) %>%
    arrange(desc(score))

  out
}

# =========================================================
# 5) Build dynamic meta
# =========================================================
make_label <- function(x) {
  s <- gsub("_", " ", x)
  s <- gsub("\\s+", " ", s)
  trimws(s)
}

build_meta <- function(value_cols) {
  meta <- lapply(value_cols, function(v) list(label = make_label(v), unit = ""))
  names(meta) <- value_cols
  meta
}

var_meta <- function(var, meta = NULL) {
  if (!is.null(meta) && !is.null(meta[[var]])) return(meta[[var]])
  list(label = make_label(var), unit = "")
}

# =========================================================
# 6) Academic formatting
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

    if (av >= 1e9) { val <- v / 1e9; suf <- " mld"
    } else if (av >= 1e6) { val <- v / 1e6; suf <- " mln"
    } else if (av >= 1e3) { val <- v / 1e3; suf <- " mijë"
    } else { val <- v; suf <- "" }

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

fmt_by_series <- function(x, for_axis = TRUE) {
  if (all(is.na(x))) return(rep(NA_character_, length(x)))
  rng <- range(x, na.rm = TRUE)
  span <- abs(rng[2] - rng[1])

  if (for_axis) {
    if (max(abs(rng), na.rm = TRUE) >= 1e3) return(fmt_compact(x, digits = 1))
    if (span < 1) return(fmt_fixed(x, digits = 3))
    if (span < 10) return(fmt_fixed(x, digits = 2))
    if (span < 100) return(fmt_fixed(x, digits = 1))
    return(fmt_fixed(x, digits = 0))
  } else {
    if (span < 1) return(fmt_fixed(x, digits = 4))
    if (span < 10) return(fmt_fixed(x, digits = 2))
    return(fmt_fixed(x, digits = 2))
  }
}

fmt_unit <- function(x, var, meta = NULL) {
  m <- var_meta(var, meta)
  u <- m$unit %||% ""
  if (nzchar(u)) paste0(fmt_by_series(x, for_axis = FALSE), " ", u)
  else fmt_by_series(x, for_axis = FALSE)
}

# =========================================================
# 7) Plotly helpers
# =========================================================
plotly_cfg <- function(p) {
  config(p, displayModeBar = FALSE, responsive = TRUE)
}

find_traces <- function(pl, predicate) {
  idx <- integer(0)
  for (i in seq_along(pl$x$data)) {
    tr <- pl$x$data[[i]]
    if (isTRUE(predicate(tr))) idx <- c(idx, i)
  }
  idx
}

set_trace_text <- function(pl, trace_index, text_vec) {
  if (length(trace_index) == 0 || is.na(trace_index)) return(pl)
  pl$x$data[[trace_index]]$text <- text_vec
  pl$x$data[[trace_index]]$hoverinfo <- "text"
  pl
}

skip_trace_hover <- function(pl, idx) {
  if (length(idx) == 0) return(pl)
  for (i in idx) {
    pl$x$data[[i]]$hoverinfo <- "skip"
  }
  pl
}

# =========================================================
# 8) Build dynamic standardized df
# =========================================================
make_df_dyn <- function(df, time_col) {
  d <- df

  tm <- tryCatch(
    parse_time_safe(d[[time_col]]),
    error = function(e) stop("Kolona e kohës s’u parse dot: ", e$message)
  )

  d$Time <- tm
  d <- d[order(d$Time), , drop = FALSE]
  d
}

apply_dup_policy <- function(d, vc, method = "mean") {
  if (!("Time" %in% names(d))) stop("Mungon kolona Time.")
  if (length(vc) == 0) return(d)

  d <- d[order(d$Time), c("Time", vc), drop = FALSE]
  if (!any(duplicated(d$Time))) return(d)

  method <- tolower(method %||% "mean")

  if (method == "first") {
    keep <- !duplicated(d$Time)
    return(d[keep, , drop = FALSE])
  }

  if (method == "last") {
    keep <- !duplicated(d$Time, fromLast = TRUE)
    return(d[keep, , drop = FALSE])
  }

  fun <- switch(
    method,
    "sum"  = function(x) sum(x, na.rm = TRUE),
    "mean" = function(x) mean(x, na.rm = TRUE),
    function(x) mean(x, na.rm = TRUE)
  )

  out <- stats::aggregate(d[vc], by = list(Time = d$Time), FUN = fun)
  out <- out[order(out$Time), , drop = FALSE]

  for (v in vc) {
    if (is.numeric(out[[v]])) out[[v]][is.nan(out[[v]])] <- NA_real_
  }

  out
}

apply_freq_policy <- function(d, freq = "auto", vc = NULL) {
  if (!("Time" %in% names(d))) stop("Mungon kolona Time.")
  if (is.null(vc)) vc <- setdiff(names(d), "Time")
  if (length(vc) == 0) return(d)

  tt <- d$Time
  if (length(tt) < 2) return(d)

  f <- tolower(freq %||% "auto")

  if (f == "auto") {
    f <- detect_freq_from_time(tt)
  } else {
    f <- switch(f,
      "yearly" = "year",
      "quarterly" = "quarter",
      "monthly" = "month",
      "weekly" = "week",
      "daily" = "day",
      f
    )
  }

  if (f == "index") return(d)

  if (inherits(tt, "Date")) {
    by <- switch(
      f,
      "day"    = "day",
      "month"  = "month",
      "quarter"= "quarter",
      "week"   = "week",
      "year"   = "year",
      NULL
    )
    if (is.null(by)) return(d)

    full_time <- seq.Date(min(tt, na.rm = TRUE), max(tt, na.rm = TRUE), by = by)
    full <- data.frame(Time = full_time)
    out <- merge(full, d[, c("Time", vc), drop = FALSE], by = "Time", all.x = TRUE, sort = TRUE)
    return(out)
  }

  if (is.numeric(tt)) {
    step <- switch(f, "year" = 1, NULL)
    if (is.null(step)) return(d)

    full_time <- seq(min(tt, na.rm = TRUE), max(tt, na.rm = TRUE), by = step)
    full <- data.frame(Time = full_time)
    out <- merge(full, d[, c("Time", vc), drop = FALSE], by = "Time", all.x = TRUE, sort = TRUE)
    return(out)
  }

  d
}

time_axis_label <- function(Time) {
  if (inherits(Time, "Date")) return("Data")
  if (is.numeric(Time) && all(Time >= 1500 & Time <= 3000, na.rm = TRUE)) return("Viti")
  "Koha"
}

fmt_time <- function(x) {
  if (inherits(x, "Date")) return(format(x, "%Y-%m-%d"))
  as.character(x)
}

infer_step_from_time <- function(Time) {
  tt <- Time[!is.na(Time)]
  if (length(tt) < 3) {
    if (inherits(Time, "Date")) return(list(type="date", step="day"))
    return(list(type="numeric", step=1))
  }

  if (inherits(tt, "Date")) {
    dd <- as.numeric(diff(tt))
    dd <- dd[is.finite(dd)]
    if (length(dd) == 0) return(list(type="date", step="day"))
    md <- stats::median(dd)

    if (md <= 2) return(list(type="date", step="day"))
    if (md >= 5 && md <= 10) return(list(type="date", step="week"))
    if (md >= 27 && md <= 32) return(list(type="date", step="month"))
    if (md >= 80 && md <= 100) return(list(type="date", step="quarter"))
    if (md >= 330 && md <= 400) return(list(type="date", step="year"))

    return(list(type="date", step="day"))
  }

  vn <- as.numeric(tt)
  dv <- diff(vn)
  dv <- dv[is.finite(dv)]
  if (length(dv) == 0) return(list(type="numeric", step=1))
  st <- stats::median(dv)
  if (!is.finite(st) || st == 0) st <- 1
  list(type="numeric", step=st)
}

make_future_time <- function(Time, h) {
  req_h <- as.integer(h)
  if (is.na(req_h) || req_h < 1) return(Time[0])

  tt <- Time[!is.na(Time)]
  if (length(tt) == 0) return(Time[0])
  last_t <- tt[length(tt)]

  info <- infer_step_from_time(tt)

  if (info$type == "date") {
    by <- info$step

    if (is.null(by) || is.na(by) || by == "") {
      by <- "day"
    }

    rby <- switch(by,
      "quarter" = "quarter",
      "week"    = "week",
      by
    )

    return(seq.Date(from = as.Date(last_t), by = rby, length.out = req_h + 1)[-1])

  } else {
    st <- suppressWarnings(as.numeric(info$step))
    if (is.na(st) || st == 0) st <- 1
    return(last_t + st * seq_len(req_h))
  }
}

# =========================================================
# Future time builder
# =========================================================
ts_spec_from_time <- function(Time, freq_choice = "auto") {
  tt <- Time[!is.na(Time)]
  if (length(tt) == 0) return(list(key="index", freq=1, start=c(1,1)))

  key <- tolower(freq_choice %||% "auto")
  key <- switch(key,
    "auto"      = "auto",
    "yearly"    = "year",
    "year"      = "year",
    "quarterly" = "quarter",
    "quarter"   = "quarter",
    "monthly"   = "month",
    "month"     = "month",
    "weekly"    = "week",
    "week"      = "week",
    "daily"     = "day",
    "day"       = "day",
    key
  )

  if (key == "auto") key <- detect_freq_from_time(tt)

  if (inherits(tt, "Date")) {
    d0 <- sort(tt)[1]
    y  <- as.integer(format(d0, "%Y"))
    m  <- as.integer(format(d0, "%m"))

    if (key == "year")    return(list(key=key, freq=1,   start=c(y, 1)))
    if (key == "quarter") return(list(key=key, freq=4,   start=c(y, (m-1) %/% 3 + 1)))
    if (key == "month")   return(list(key=key, freq=12,  start=c(y, m)))

    if (key == "week") {
      w  <- suppressWarnings(as.integer(strftime(d0, "%V")))
      yy <- suppressWarnings(as.integer(strftime(d0, "%G")))
      if (is.na(w))  w  <- as.integer(strftime(d0, "%U")) + 1
      if (is.na(yy)) yy <- y
      return(list(key=key, freq=52, start=c(yy, w)))
    }

    if (key == "day") {
      doy <- as.POSIXlt(d0)$yday + 1
      return(list(key=key, freq=365, start=c(y, doy)))
    }

    return(list(key="index", freq=1, start=c(1,1)))
  }

  if (is.numeric(tt) && all(tt >= 1500 & tt <= 3000, na.rm = TRUE)) {
    y0 <- as.integer(min(tt, na.rm = TRUE))
    return(list(key="year", freq=1, start=c(y0, 1)))
  }

  list(key="index", freq=1, start=c(1,1))
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

pick <- function(..., default = NULL) {
  xs <- list(...)
  for (x in xs) {
    if (is.null(x)) next
    if (length(x) == 0) next
    if (is.character(x) && all(trimws(x) == "")) next
    return(x)
  }
  default
}

detect_freq_from_time <- function(Time) {
  if (inherits(Time, "Date")) {
    dt <- sort(unique(Time))
    if (length(dt) < 2) return("day")
    md <- as.integer(stats::median(diff(dt), na.rm = TRUE))

    if (md >= 350) return("year")
    if (md >= 80)  return("quarter")
    if (md >= 25)  return("month")
    if (md >= 5)   return("week")
    return("day")
  }

  if (is.numeric(Time)) {
    if (all(Time >= 1500 & Time <= 3000, na.rm = TRUE)) return("year")
    return("index")
  }

  "index"
}

# =========================================================
# 9) Backround settings
# =========================================================

BG_STATE_FILE <- file.path(DATA_DIR, "background_state.json")

default_bg_state <- function() {
  list(
    active_mode = "image",
    version     = 0L,
    modes = list(
      none  = list(),
      color = list(value = "#0b1c24"),
      image = list(
        active_scope = "custom",
        blur = list(on = TRUE, amount = 10L),
        scopes = list(
          custom = list(per_tab = setNames(list(), character())),
          global = list(global = NULL)
        )
      )
    )
  )
}

# ensure per_tab is a named list so JSON becomes {} when empty (not [])
normalize_per_tab <- function(x) {
  if (is.null(x)) return(setNames(list(), character()))
  if (!is.list(x)) return(setNames(list(), character()))
  if (length(x) == 0 && is.null(names(x))) return(setNames(list(), character()))
  x
}

# Migration: old schema -> new schema
migrate_bg_state_if_needed <- function(st) {
  # Old schema had: mode, scope, blur_on, blur, color, global, per_tab, version
  if (!is.null(st$mode) && is.null(st$active_mode)) {
    d <- default_bg_state()

    active_mode <- st$mode %||% d$active_mode
    if (!active_mode %in% c("image","color","none")) active_mode <- "image"

    d$active_mode <- active_mode
    d$version     <- as.integer(st$version %||% d$version)

    # remember color even if active_mode != color
    d$modes$color$value <- st$color %||% d$modes$color$value

    # image settings
    d$modes$image$active_scope <- st$scope %||% d$modes$image$active_scope
    if (!d$modes$image$active_scope %in% c("custom","global")) d$modes$image$active_scope <- "custom"

    d$modes$image$blur$on     <- isTRUE(st$blur_on %||% d$modes$image$blur$on)
    d$modes$image$blur$amount <- as.integer(st$blur %||% d$modes$image$blur$amount)

    d$modes$image$scopes$global$global <- st$global %||% NULL
    d$modes$image$scopes$custom$per_tab <- normalize_per_tab(st$per_tab)

    return(d)
  }

  st
}

read_bg_state <- function() {
  if (!requireNamespace("jsonlite", quietly = TRUE)) {
    stop("Mungon paketa 'jsonlite'. Instalo: install.packages('jsonlite')")
  }

  d <- default_bg_state()
  if (!file.exists(BG_STATE_FILE)) return(d)

  st <- jsonlite::fromJSON(BG_STATE_FILE)

  # migrate if old schema
  st <- migrate_bg_state_if_needed(st)

  # normalize + fill defaults (NEW schema)
  st$active_mode <- st$active_mode %||% d$active_mode
  if (!st$active_mode %in% c("image","color","none")) st$active_mode <- d$active_mode

  st$version <- as.integer(st$version %||% d$version)

  if (is.null(st$modes) || !is.list(st$modes)) st$modes <- d$modes

  # none
  if (is.null(st$modes$none) || !is.list(st$modes$none)) st$modes$none <- d$modes$none

  # color
  if (is.null(st$modes$color) || !is.list(st$modes$color)) st$modes$color <- d$modes$color
  st$modes$color$value <- st$modes$color$value %||% d$modes$color$value

  # image
  if (is.null(st$modes$image) || !is.list(st$modes$image)) st$modes$image <- d$modes$image
  st$modes$image$active_scope <- st$modes$image$active_scope %||% d$modes$image$active_scope
  if (!st$modes$image$active_scope %in% c("custom","global")) st$modes$image$active_scope <- d$modes$image$active_scope

  if (is.null(st$modes$image$blur) || !is.list(st$modes$image$blur)) st$modes$image$blur <- d$modes$image$blur
  st$modes$image$blur$on     <- isTRUE(st$modes$image$blur$on %||% d$modes$image$blur$on)
  st$modes$image$blur$amount <- as.integer(st$modes$image$blur$amount %||% d$modes$image$blur$amount)

  if (is.null(st$modes$image$scopes) || !is.list(st$modes$image$scopes)) st$modes$image$scopes <- d$modes$image$scopes
  if (is.null(st$modes$image$scopes$custom) || !is.list(st$modes$image$scopes$custom)) st$modes$image$scopes$custom <- d$modes$image$scopes$custom
  if (is.null(st$modes$image$scopes$global) || !is.list(st$modes$image$scopes$global)) st$modes$image$scopes$global <- d$modes$image$scopes$global

  st$modes$image$scopes$custom$per_tab <- normalize_per_tab(st$modes$image$scopes$custom$per_tab)
  st$modes$image$scopes$global$global  <- st$modes$image$scopes$global$global %||% NULL

  st
}

write_bg_state <- function(st) {
  if (!requireNamespace("jsonlite", quietly = TRUE)) {
    stop("Mungon paketa 'jsonlite'. Instalo: install.packages('jsonlite')")
  }

  st$version <- as.integer(Sys.time())

  if (!is.null(st$modes$image$scopes$custom$per_tab)) {
    st$modes$image$scopes$custom$per_tab <- normalize_per_tab(st$modes$image$scopes$custom$per_tab)
  }

  jsonlite::write_json(st, BG_STATE_FILE, auto_unbox = TRUE, pretty = TRUE)
}
