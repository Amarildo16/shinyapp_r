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

STATE_FILE <- file.path(DATA_DIR, "datasets_state.json")

read_state <- function() {
  if (!requireNamespace("jsonlite", quietly = TRUE)) {
    stop("Mungon paketa 'jsonlite'. Instalo: install.packages('jsonlite')")
  }

  if (!file.exists(STATE_FILE)) {
    return(list(
      active   = NULL,
      datasets = data.frame(file = character(), added_at = character(), is_active = logical(),
                            stringsAsFactors = FALSE)
    ))
  }

  st <- jsonlite::fromJSON(STATE_FILE)

  if (is.null(st$datasets) || !is.data.frame(st$datasets)) {
    st$datasets <- data.frame(file = character(), added_at = character(), is_active = logical(),
                              stringsAsFactors = FALSE)
  }

  if (is.null(st$active)) st$active <- NULL
  st
}

write_state <- function(st) {
  if (!is.null(st$active) && nzchar(st$active)) {
    st$datasets$is_active <- st$datasets$file == st$active
  } else {
    st$datasets$is_active <- FALSE
  }

  jsonlite::write_json(st, STATE_FILE, auto_unbox = TRUE, pretty = TRUE)
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

  st$datasets$is_active <- st$datasets$file == st$active

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
# 1) Read data safe (CSV/TSV/Excel optional)
# =========================================================
read_data_safe <- function(path, filename = NULL) {
  if (!file.exists(path)) {
    stop("Dataset nuk u gjet në shtegun: ", normalizePath(path, winslash = "/", mustWork = FALSE))
  }

  ext <- tolower(tools::file_ext(filename %||% path))

  if (ext %in% c("csv")) {
    d <- readr::read_csv(path, show_col_types = FALSE)
  } else if (ext %in% c("tsv")) {
    d <- readr::read_tsv(path, show_col_types = FALSE)
  } else if (ext %in% c("xlsx", "xls")) {
    if (!has_readxl) stop("Për Excel duhet paketa 'readxl' (instaloje).")
    d <- readxl::read_excel(path)
  } else {
    d <- readr::read_csv(path, show_col_types = FALSE)
  }

  as.data.frame(d, stringsAsFactors = FALSE)
}

# =========================================================
# 2) Time parsing (YYYY, YYYY-MM, YYYYQ#, Date)
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
# 3) Numeric normalization (1 234,56 -> 1234.56 etc.)
# =========================================================
to_numeric_safe <- function(x) {
  if (is.numeric(x)) return(x)
  if (is.integer(x)) return(as.numeric(x))

  s <- trimws(as.character(x))
  s[s == ""] <- NA_character_

  s <- gsub("[^0-9,\\.\\- ]", "", s)

  s <- gsub(" ", "", s)
  has_comma <- grepl(",", s, fixed = TRUE)
  has_dot   <- grepl("\\.", s)
  both <- has_comma & has_dot
  s[both] <- gsub("\\.", "", s[both])
  s[both] <- sub(",", ".", s[both], fixed = TRUE)

  only_comma <- has_comma & !has_dot
  s[only_comma] <- sub(",", ".", s[only_comma], fixed = TRUE)

  suppressWarnings(as.numeric(s))
}

# =========================================================
# 4) Detect candidate time columns (scoring)
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
      "quarter"= "3 months",
      "week"   = "7 days",
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
  # kthen list(type=..., step=...) ku:
  # type: "date" ose "numeric"
  # step: për date -> "day"/"month"/"quarter"/"year"
  #       për numeric -> numeric step (p.sh. 1)
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
      "quarter" = "3 months",
      "week"    = "7 days",
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


