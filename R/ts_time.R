# Frekuenca, hapi dhe koha e serive.

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

canonical_freq_key <- function(Time, freq_choice = "auto") {
  tt <- Time[!is.na(Time)]
  if (length(tt) < 2) return(NULL)

  key <- tolower(as.character(freq_choice %||% "auto")[1])
  key <- switch(key,
    "auto"      = "auto",
    "year"      = "yearly",
    "yearly"    = "yearly",
    "quarter"   = "quarterly",
    "quarterly" = "quarterly",
    "month"     = "monthly",
    "monthly"   = "monthly",
    "week"      = "weekly",
    "weekly"    = "weekly",
    "day"       = "daily",
    "daily"     = "daily",
    key
  )

  if (identical(key, "auto")) {
    det <- tryCatch(detect_freq_from_time(tt), error = function(e) "index")
    key <- switch(tolower(det %||% "index"),
      "year"    = "yearly",
      "quarter" = "quarterly",
      "month"   = "monthly",
      "week"    = "weekly",
      "day"     = "daily",
      NA_character_
    )
  }

  if (is.null(key) || is.na(key) || !(key %in% c("yearly", "quarterly", "monthly", "weekly", "daily"))) {
    return(NULL)
  }

  if (inherits(tt, "Date")) return(key)

  if (is.numeric(tt)) {
    if (!identical(key, "yearly")) return(NULL)
    if (!all(is.finite(tt))) return(NULL)
    if (!all(abs(tt - round(tt)) < 1e-8, na.rm = TRUE)) return(NULL)
    return(key)
  }

  NULL
}

date_period_key <- function(Time, freq_key) {
  if (!inherits(Time, "Date")) return(as.character(Time))

  if (identical(freq_key, "monthly")) {
    return(format(Time, "%Y-%m"))
  }

  if (identical(freq_key, "quarterly")) {
    m <- as.integer(format(Time, "%m"))
    q <- ((m - 1L) %/% 3L) + 1L
    return(paste0(format(Time, "%Y"), "-Q", q))
  }

  as.character(Time)
}

date_period_start <- function(Time, freq_key) {
  if (!inherits(Time, "Date")) return(Time)

  y <- as.integer(format(Time, "%Y"))
  m <- as.integer(format(Time, "%m"))

  if (identical(freq_key, "monthly")) {
    return(as.Date(sprintf("%04d-%02d-01", y, m)))
  }

  if (identical(freq_key, "quarterly")) {
    qm <- ((m - 1L) %/% 3L) * 3L + 1L
    return(as.Date(sprintf("%04d-%02d-01", y, qm)))
  }

  Time
}

expected_time_grid <- function(Time, freq_choice = "auto") {
  tt <- Time[!is.na(Time)]
  if (length(tt) < 2) return(tt)

  key <- canonical_freq_key(tt, freq_choice)
  if (is.null(key)) return(NULL)

  if (inherits(tt, "Date")) {
    if (key %in% c("monthly", "quarterly")) {
      start <- min(date_period_start(tt, key))
      end   <- max(date_period_start(tt, key))
      by    <- if (identical(key, "monthly")) "month" else "quarter"
      return(tryCatch(seq.Date(start, end, by = by), error = function(e) NULL))
    }

    by <- switch(key,
      "yearly"    = "year",
      "quarterly" = "quarter",
      "monthly"   = "month",
      "weekly"    = "week",
      "daily"     = "day",
      NULL
    )
    if (is.null(by)) return(NULL)
    return(tryCatch(seq.Date(min(tt), max(tt), by = by), error = function(e) NULL))
  }

  if (is.numeric(tt) && identical(key, "yearly")) {
    from <- as.integer(min(round(tt), na.rm = TRUE))
    to   <- as.integer(max(round(tt), na.rm = TRUE))
    if (is.na(from) || is.na(to) || to < from) return(NULL)
    return(seq(from, to, by = 1L))
  }

  NULL
}

# ---- Kufijtë e slider-ave (R16): hapi i kohës, horizonti, dritarja lëvizëse ----

# "year" | "quarter" | "month" | "week" | "day" | "period"
time_step <- function(Time) {
  tt <- Time[!is.na(Time)]
  if (length(tt) < 2) return("period")

  info <- tryCatch(infer_step_from_time(tt), error = function(e) NULL)
  if (!is.null(info) && identical(info$type, "date")) {
    return(info$step)
  }

  if (is.numeric(tt) && all(tt >= 1500 & tt <= 3000, na.rm = TRUE)) return("year")

  "period"
}

time_step_unit <- function(Time) {
  switch(time_step(Time),
    year    = "vite",
    quarter = "tremujor",
    month   = "muaj",
    week    = "javë",
    day     = "ditë",
    "periudha"
  )
}

# Horizonti i parashikimit: [min, max] sipas pikave reale dhe hapit (H_CAP).
h_bounds <- function(n_real, Time) {
  n_real <- as.integer(n_real)
  if (is.na(n_real) || n_real < 2L) return(list(min = 1L, max = 1L, step = "period"))

  step <- time_step(Time)
  cap  <- if (step %in% names(H_CAP)) H_CAP[[step]] else H_CAP_DEFAULT

  hmax <- min(as.integer(n_real - 1L), cap)
  hmax <- max(1L, hmax)

  hmin <- if (hmax <= 8L) 2L else 1L
  hmin <- min(hmin, hmax)

  list(min = hmin, max = hmax, step = step)
}

# Dritarja lëvizëse: [3, max] sipas pikave reale dhe hapit (ROLL_CAP).
roll_bounds <- function(n_non_na, Time) {
  k_min <- 3L
  step  <- time_step(Time)
  capk  <- if (step %in% names(ROLL_CAP)) ROLL_CAP[[step]] else ROLL_CAP_DEFAULT

  k_max_raw <- if (is.finite(n_non_na) && n_non_na >= 2L) as.integer(n_non_na - 1L) else k_min
  k_max <- min(k_max_raw, capk, max(k_min, as.integer(floor(n_non_na / 2))))
  list(min = k_min, max = max(k_min, k_max))
}

