# Përgatitja e serive: koha, dublikatat, grid-i i rregullt.

make_df_dyn <- function(df, time_col) {
  d <- df

  if (is.null(time_col) || length(time_col) != 1 || is.na(time_col) ||
      !nzchar(as.character(time_col)) || !(time_col %in% names(d))) {
    stop(tr("err.time_choose"))
  }

  tm <- tryCatch(
    parse_time_safe(d[[time_col]], allow_index = TRUE),
    error = function(e) stop(tr("err.time_parse_detail", msg = conditionMessage(e)))
  )

  if (sum(!is.na(tm)) < 2) {
    stop(tr("err.time_min2"))
  }

  d$Time <- tm
  d <- d[order(d$Time), , drop = FALSE]
  d
}

apply_dup_policy <- function(d, vc, method = "mean") {
  if (!("Time" %in% names(d))) stop(tr("err.no_time_col"))
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
    "sum"  = function(x) if (all(is.na(x))) NA_real_ else sum(x, na.rm = TRUE),
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
  if (!("Time" %in% names(d))) stop(tr("err.no_time_col"))
  if (is.null(vc)) vc <- setdiff(names(d), "Time")
  if (length(vc) == 0) return(d)

  tt <- d$Time
  tt_ok <- tt[!is.na(tt)]
  if (length(tt_ok) < 2) return(d)

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

    if (f %in% c("month", "quarter")) {
      key <- if (f == "month") "monthly" else "quarterly"
      obs_key <- date_period_key(tt_ok, key)
      if (any(duplicated(obs_key))) return(d)

      full_time <- expected_time_grid(tt_ok, key)
      if (is.null(full_time) || length(full_time) < 2) return(d)

      full_key <- date_period_key(full_time, key)
      if (!all(sort(unique(obs_key)) %in% full_key)) return(d)

      d_obs <- d[, c("Time", vc), drop = FALSE]
      d_obs$.period_key <- date_period_key(d_obs$Time, key)
      names(d_obs)[names(d_obs) == "Time"] <- "Time.obs"

      full <- data.frame(
        .period_key = full_key,
        .order = seq_along(full_key),
        Time.grid = full_time,
        stringsAsFactors = FALSE
      )

      out <- merge(full, d_obs, by = ".period_key", all.x = TRUE, sort = FALSE)
      out <- out[order(out$.order), , drop = FALSE]

      out$Time <- out$Time.grid
      idx <- !is.na(out$Time.obs)
      out$Time[idx] <- out$Time.obs[idx]

      return(out[, c("Time", vc), drop = FALSE])
    }

    full_time <- seq.Date(min(tt_ok), max(tt_ok), by = by)
    if (!all(sort(unique(tt_ok)) %in% full_time)) return(d)

    full <- data.frame(Time = full_time)
    out <- merge(full, d[, c("Time", vc), drop = FALSE], by = "Time", all.x = TRUE, sort = TRUE)
    return(out)
  }

  if (is.numeric(tt)) {
    step <- switch(f, "year" = 1, NULL)
    if (is.null(step)) return(d)

    full_time <- seq(min(tt_ok), max(tt_ok), by = step)
    if (!all(sort(unique(tt_ok)) %in% full_time)) return(d)

    full <- data.frame(Time = full_time)
    out <- merge(full, d[, c("Time", vc), drop = FALSE], by = "Time", all.x = TRUE, sort = TRUE)
    return(out)
  }

  d
}


# Seritë e gatshme për analizë nga dataset-i aktiv (V-04, T-14). Të njëjtët hapa si
# df_dyn() i vjetër: numrat, koha, dublikatat (DUP_POLICY), grid-i (FREQ_POLICY).
# active: list(file, data, time_col, value_cols) nga mod_datasets_server(); NULL -> NULL.
prepare_series <- function(active) {
  if (is.null(active) || is.null(active$data)) return(NULL)
  vc <- active$value_cols
  if (is.null(active$time_col) || length(vc) == 0) return(NULL)

  d <- active$data
  for (v in vc) d[[v]] <- to_numeric_safe(d[[v]])

  d <- make_df_dyn(d, active$time_col)
  d <- d[, c("Time", vc), drop = FALSE]
  d <- apply_dup_policy(d, vc = vc, method = DUP_POLICY)
  d <- apply_freq_policy(d, freq = FREQ_POLICY, vc = vc)

  list(data = d, value_cols = vc, meta = build_meta(vc))
}

# Seritë e zgjedhura: `preferred` (p.sh. nga state-i), pastaj `current` (inputi),
# përndryshe 3 kolonat e para numerike.
pick_value_cols <- function(num_cols, preferred = NULL, current = NULL) {
  preferred <- unique(preferred)
  vals <- preferred[preferred %in% num_cols]
  if (!length(vals)) vals <- current[current %in% num_cols]
  if (!length(vals)) vals <- head(num_cols, min(3, length(num_cols)))
  vals
}

# Kolona e kohës dhe seritë default për një dataset (P-03).
# cfg: list(time_col, value_cols) nga state-i ose nga modali; current_*: inputet aktuale.
resolve_dataset_defaults <- function(d, cfg = NULL, current_time = NULL, current_values = NULL) {
  nm <- names(d)
  s  <- detection_sample(d)   # B-27: e njëjta gjë kur dataset-i ka pak rreshta

  cand <- tryCatch(detect_time_candidates(s), error = function(e) data.frame(col = nm, score = 0))
  time_choices <- unique(cand$col)
  if (length(time_choices) == 0) time_choices <- nm

  is_choice <- function(x) {
    !is.null(x) && length(x) == 1 && !is.na(x) && nzchar(x) && x %in% time_choices
  }

  time_col <- if (is_choice(cfg$time_col)) cfg$time_col
              else if (is_choice(current_time)) current_time
              else time_choices[1]

  num_cols <- detect_numeric_cols(s, exclude = time_col)

  list(
    time_choices = time_choices,
    time_col     = time_col,
    num_cols     = num_cols,
    value_cols   = pick_value_cols(num_cols, cfg$value_cols, current_values)
  )
}
