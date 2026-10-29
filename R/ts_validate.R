# Validimi i serive kohore për analizat statistikore.

# Mesazhet e validimit (R15), në gjuhën aktuale: "incomplete", "short", "freq", "index".
ts_msg <- function(key) tr(paste0("ts.", key))

# Frekuenca e panjohur: kur koha është numër që s'është vit, mesazhi thotë pse dhe çfarë
# formati të përdoret (B-09, V-11, V-19 c).
ts_freq_msg <- function(tt) if (is.numeric(tt) && !inherits(tt, "Date")) ts_msg("index") else ts_msg("freq")

assess_time_regular <- function(Time, freq_choice = "auto") {
  empty <- Time[0]
  tt <- Time[!is.na(Time)]

  if (length(tt) < 2) {
    return(list(
      ok = FALSE, freq_key = NULL, message = ts_msg("short"),
      missing_periods = empty, off_grid_periods = empty,
      expected_n = 0L, observed_n = length(tt)
    ))
  }

  key <- canonical_freq_key(tt, freq_choice)
  if (is.null(key)) {
    return(list(
      ok = FALSE, freq_key = NULL, message = ts_freq_msg(tt),
      missing_periods = empty, off_grid_periods = empty,
      expected_n = NA_integer_, observed_n = length(unique(tt))
    ))
  }

  if (inherits(tt, "Date") && key %in% c("monthly", "quarterly")) {
    observed_key <- date_period_key(tt, key)
    dup_key <- sort(unique(observed_key[duplicated(observed_key)]))
    if (length(dup_key) > 0) {
      return(list(
        ok = FALSE, freq_key = key, message = ts_msg("incomplete"),
        missing_periods = empty,
        off_grid_periods = sort(unique(tt[observed_key %in% dup_key])),
        expected_n = NA_integer_,
        observed_n = length(unique(observed_key))
      ))
    }

    grid <- expected_time_grid(tt, key)
    if (is.null(grid) || length(grid) < 2) {
      return(list(
        ok = FALSE, freq_key = key, message = ts_msg("freq"),
        missing_periods = empty, off_grid_periods = empty,
        expected_n = length(grid %||% empty), observed_n = length(unique(observed_key))
      ))
    }

    expected_key <- date_period_key(grid, key)
    observed <- sort(unique(observed_key))
    expected <- sort(unique(expected_key))
    missing_key <- expected[!(expected %in% observed)]
    off_key <- observed[!(observed %in% expected)]

    missing_periods <- grid[match(missing_key, expected_key)]
    off_grid_periods <- sort(unique(tt[observed_key %in% off_key]))
    ok <- length(missing_key) == 0 && length(off_key) == 0

    return(list(
      ok = ok,
      freq_key = key,
      message = if (ok) NULL else ts_msg("incomplete"),
      missing_periods = missing_periods,
      off_grid_periods = off_grid_periods,
      expected_n = length(expected),
      observed_n = length(observed)
    ))
  }

  dup <- sort(unique(tt[duplicated(tt)]))
  if (length(dup) > 0) {
    return(list(
      ok = FALSE, freq_key = key, message = ts_msg("incomplete"),
      missing_periods = empty, off_grid_periods = dup,
      expected_n = NA_integer_, observed_n = length(unique(tt))
    ))
  }

  grid <- expected_time_grid(tt, key)
  if (is.null(grid) || length(grid) < 2) {
    return(list(
      ok = FALSE, freq_key = key, message = ts_msg("freq"),
      missing_periods = empty, off_grid_periods = empty,
      expected_n = length(grid %||% empty), observed_n = length(unique(tt))
    ))
  }

  observed <- sort(unique(tt))
  expected <- sort(unique(grid))
  missing_periods <- expected[!(expected %in% observed)]
  off_grid_periods <- observed[!(observed %in% expected)]
  ok <- length(missing_periods) == 0 && length(off_grid_periods) == 0

  list(
    ok = ok,
    freq_key = key,
    message = if (ok) NULL else ts_msg("incomplete"),
    missing_periods = missing_periods,
    off_grid_periods = off_grid_periods,
    expected_n = length(expected),
    observed_n = length(observed)
  )
}

assess_complete_series <- function(d, value_col, freq_choice = "auto") {
  if (is.null(d) || !is.data.frame(d) || !("Time" %in% names(d))) {
    return(list(ok = FALSE, message = tr("err.no_time_col"), data = NULL,
                freq_key = NULL, n = 0L, missing_periods = NULL, off_grid_periods = NULL))
  }

  if (is.null(value_col) || length(value_col) != 1 || !(value_col %in% names(d))) {
    return(list(ok = FALSE, message = tr("err.series_missing"), data = NULL,
                freq_key = NULL, n = 0L, missing_periods = NULL, off_grid_periods = NULL))
  }

  dd <- d[, c("Time", value_col), drop = FALSE]
  names(dd) <- c("Time", "y")

  if (any(is.na(dd$Time))) {
    return(list(ok = FALSE, message = ts_msg("incomplete"), data = dd,
                freq_key = NULL, n = sum(!is.na(dd$y)), missing_periods = NULL, off_grid_periods = NULL))
  }

  dd <- dd[order(dd$Time), , drop = FALSE]

  reg <- assess_time_regular(dd$Time, freq_choice)
  if (!isTRUE(reg$ok)) {
    return(list(ok = FALSE, message = reg$message, data = dd,
                freq_key = reg$freq_key, n = sum(!is.na(dd$y)),
                missing_periods = reg$missing_periods, off_grid_periods = reg$off_grid_periods))
  }

  dd$y <- suppressWarnings(as.numeric(dd$y))
  n_real <- sum(!is.na(dd$y))

  if (n_real < 2) {
    return(list(ok = FALSE, message = ts_msg("short"), data = dd,
                freq_key = reg$freq_key, n = n_real,
                missing_periods = reg$missing_periods, off_grid_periods = reg$off_grid_periods))
  }

  if (any(is.na(dd$y))) {
    return(list(ok = FALSE, message = ts_msg("incomplete"), data = dd,
                freq_key = reg$freq_key, n = n_real,
                missing_periods = reg$missing_periods, off_grid_periods = reg$off_grid_periods))
  }

  list(
    ok = TRUE,
    message = NULL,
    data = dd,
    freq_key = reg$freq_key,
    n = nrow(dd),
    missing_periods = reg$missing_periods,
    off_grid_periods = reg$off_grid_periods
  )
}

validate_ts_ready <- function(d, value_col, freq_choice = "auto", min_n = 2L) {
  res <- assess_complete_series(d, value_col, freq_choice)
  if (!isTRUE(res$ok)) return(res)

  min_n <- suppressWarnings(as.integer(min_n))
  if (is.na(min_n) || min_n < 2L) min_n <- 2L

  if (res$n < min_n) {
    res$ok <- FALSE
    res$message <- ts_msg("short")
  }

  res
}

