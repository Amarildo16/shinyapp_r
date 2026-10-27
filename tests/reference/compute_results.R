# Llogarit rezultatet statistike të app-it për një dataset shembull (V-07, R21).
#
# Faza 0: thërret kodin aktual (helpers.R + server_plots.R).
#   - Pjesët reaktive (df_dyn, ADF, modelet, parashikimet, kufijtë e slider-ave)
#     merren nga vetë server_plots() me shiny::testServer.
#   - Llogaritjet që jetojnë brenda render*-ave (mesatarja lëvizëse, regresioni,
#     korrelacioni, diferenca, ACF/PACF, parashikimet e Modelimit) riprodhohen
#     me të njëjtat thirrje, të kopjuara nga server_plots.R (commit 976dce0).
#
# Kur logjika kalon te R/ (Fazat 2–5), përditësohet VETËM ky skedar që të thërrasë
# funksionet e reja. Referenca te tests/reference/*.rds nuk rigjenerohet.
#
# Rezultati ndahet sipas tolerancave te docs/ai/QUALITY.md:
#   deterministic  -> all.equal(tolerance = 1e-10)
#   models$forms   -> identical()
#   models$values  -> all.equal(tolerance = 1e-8)

REFERENCE_DATASETS <- list(
  albania_agriculture_timeseries_1998_2024 = list(
    file       = "albania_agriculture_timeseries_1998_2024.csv",
    time_col   = "Year",
    value_cols = c("Production_ton", "Area_ha", "Rainfall_mm")
  ),
  Digjitalizimi_Financiar_Shqiperi_data = list(
    file       = "Digjitalizimi_Financiar_Shqiperi_data.csv",
    time_col   = "Data",
    value_cols = c("Internet_Pct", "Transaksionet_Online", "Blerje_Online_Karte")
  )
)

ROLL_K <- c(3L, 5L)
FORECAST_METHODS <- c("ses", "holt", "arima")

# Shembujt jetojnë te data/ (Faza 0) dhe kalojnë te data/samples/ (Faza 3).
dataset_path <- function(root, file) {
  cand <- file.path(root, c("data/samples", "data"), file)
  hit <- cand[file.exists(cand)]
  if (length(hit) == 0) stop("Dataset-i shembull nuk u gjet: ", file)
  hit[1]
}

# Ngarkon kodin e app-it në një mjedis të veçantë. APP_DIR drejtohet te një
# sandbox i përkohshëm, që asgjë të mos shkruhet te data/ e projektit.
load_app_code <- function(root, sandbox) {
  app_code <- new.env(parent = globalenv())
  old <- options(shiny.appdir = sandbox)
  on.exit(options(old), add = TRUE)
  sys.source(file.path(root, "helpers.R"), envir = app_code, keep.source = FALSE)
  sys.source(file.path(root, "server_plots.R"), envir = app_code, keep.source = FALSE)
  app_code
}

# testServer() pranon argumente vetëm për module. Ky modul i hollë thërret
# server_plots() pa ndryshime; kopja e funksionit kthen edhe mjedisin e vet,
# që testi të lexojë reaktivët e brendshëm (df_dyn, adf_res, .model_fits...).
legacy_plots_module <- function(app_code) {
  server_plots_env <- app_code$server_plots
  body(server_plots_env) <- call("{", body(server_plots_env), quote(environment()))

  function(id, df) {
    shiny::moduleServer(id, function(input, output, session) {
      sp <- server_plots_env(input, output, session, df)
    })
  }
}

# --- Llogaritjet e kopjuara nga render*-at e server_plots.R -----------------

# output$summary_tbl (vlerat numerike, para formatimit)
summary_stats <- function(d, vc) {
  X <- setNames(lapply(vc, function(v) d[[v]]), vc)

  safe_stat <- function(x, fun) {
    x <- x[!is.na(x)]
    if (length(x) == 0) return(NA_real_)
    fun(x)
  }

  safe_sd <- function(x) {
    x <- x[!is.na(x)]
    if (length(x) < 2) return(NA_real_)
    stats::sd(x)
  }

  data.frame(
    variable    = vc,
    mean        = vapply(vc, function(v) safe_stat(X[[v]], base::mean), numeric(1)),
    sd          = vapply(vc, function(v) safe_sd(X[[v]]), numeric(1)),
    min         = vapply(vc, function(v) safe_stat(X[[v]], base::min), numeric(1)),
    max         = vapply(vc, function(v) safe_stat(X[[v]], base::max), numeric(1)),
    n           = vapply(vc, function(v) sum(!is.na(X[[v]])), integer(1)),
    missing_pct = vapply(vc, function(v) round(100 * mean(is.na(X[[v]])), 2), numeric(1)),
    row.names   = NULL,
    stringsAsFactors = FALSE
  )
}

# output$eda_ts_roll
rolling_mean <- function(d0, series, k) {
  y <- d0[[series]]
  n_non_na <- sum(!is.na(y))

  k <- as.integer(k)
  k <- max(2L, k)
  if (n_non_na < 3) return(list(ok = FALSE))

  k_max <- max(2L, n_non_na - 1L)
  if (k > k_max) k <- k_max

  d <- dplyr::arrange(d0, Time)
  d <- dplyr::mutate(d, roll_mean = zoo::rollapply(
    .data[[series]],
    width = k,
    FUN = function(z) {
      if (all(is.na(z))) NA_real_
      else mean(z, na.rm = TRUE)
    },
    fill = NA,
    align = "right",
    partial = FALSE
  ))

  list(ok = TRUE, k = k, time = d$Time, roll_mean = d$roll_mean)
}

# output$eda_rel_scatter
relation_fit <- function(d0, x, y) {
  d <- dplyr::mutate(d0, xval = .data[[x]], yval = .data[[y]])
  d <- dplyr::filter(d, is.finite(xval), is.finite(yval))

  if (nrow(d) <= 1 || length(unique(d$xval)) <= 1) return(list(ok = FALSE, n = nrow(d)))

  fit <- tryCatch(stats::lm(yval ~ xval, data = d), error = function(e) NULL)
  if (is.null(fit) || !all(is.finite(stats::coef(fit)))) return(list(ok = FALSE, n = nrow(d)))

  xs <- seq(min(d$xval), max(d$xval), length.out = 100)
  line_df <- data.frame(xval = xs)
  line_df$yhat <- as.numeric(stats::predict(fit, newdata = line_df))

  list(ok = TRUE, n = nrow(d), coef = stats::coef(fit), line_x = xs, line_y = line_df$yhat)
}

# output$eda_rel_corr
correlation_matrix <- function(d0) {
  num_df <- dplyr::select(d0, dplyr::where(is.numeric))
  num_df <- dplyr::select(num_df, -dplyr::any_of("Time"))

  if (ncol(num_df) < 2) return(list(ok = FALSE))
  if (ncol(num_df) > 20) num_df <- num_df[, 1:20, drop = FALSE]

  num_df <- dplyr::select(num_df, dplyr::where(~ {
    s <- stats::sd(.x, na.rm = TRUE)
    is.finite(s) && s > 0
  }))

  if (ncol(num_df) < 2) return(list(ok = FALSE))

  list(ok = TRUE, corr = stats::cor(num_df, use = "pairwise.complete.obs"))
}

# output$stat_diff_plot
first_difference <- function(app_code, d0, series) {
  ts_ok <- app_code$validate_ts_ready(d0, series, "auto", min_n = 3L, context = "diferencë")
  if (!isTRUE(ts_ok$ok) || nrow(ts_ok$data) < 3) return(list(ok = FALSE))

  dd <- ts_ok$data
  list(ok = TRUE, time = dd$Time[-1], diff = as.numeric(diff(dd$y)))
}

# output$stat_acf_pacf
acf_pacf <- function(app_code, d0, series) {
  ts_ok <- app_code$validate_ts_ready(d0, series, "auto", min_n = 6L, context = "ACF/PACF")
  if (!isTRUE(ts_ok$ok) || nrow(ts_ok$data) < 6) return(list(ok = FALSE))

  dd <- ts_ok$data
  spec <- app_code$ts_spec_from_time(dd$Time, "auto")
  y_ts <- stats::ts(as.numeric(dd$y), frequency = spec$freq, start = spec$start)
  dy   <- diff(y_ts)
  n    <- length(dy)
  if (n < 5) return(list(ok = FALSE))

  acf_obj  <- stats::acf(dy, plot = FALSE)
  pacf_obj <- stats::pacf(dy, plot = FALSE)

  freq0 <- stats::frequency(y_ts)
  if (is.null(freq0) || is.na(freq0) || freq0 < 1) freq0 <- 1

  list(
    ok        = TRUE,
    acf_lag   = as.integer(round(as.numeric(acf_obj$lag[-1]) * freq0)),
    acf       = as.numeric(acf_obj$acf[-1]),
    pacf_lag  = as.integer(round(as.numeric(pacf_obj$lag) * freq0)),
    pacf      = as.numeric(pacf_obj$acf),
    conf      = 1.96 / sqrt(n)
  )
}

# adf_res() rrumbullakos statistikën; këtu ruhen edhe vlerat e plota.
adf_raw <- function(app_code, d0, series) {
  ts_ok <- app_code$validate_ts_ready(d0, series, "auto", min_n = 20L, context = "ADF")
  if (!isTRUE(ts_ok$ok)) return(list(ok = FALSE))

  y <- suppressWarnings(as.numeric(ts_ok$data$y))
  if (length(y) < 20) return(list(ok = FALSE))

  one <- function(obj) {
    if (inherits(obj, "try-error")) return(NULL)
    list(statistic = as.numeric(obj$statistic), p_value = as.numeric(obj$p.value),
         lag_order = as.numeric(obj$parameter))
  }

  dy <- diff(y)
  list(
    ok    = TRUE,
    level = one(try(tseries::adf.test(y), silent = TRUE)),
    diff  = if (length(dy) >= 20) one(try(tseries::adf.test(dy), silent = TRUE)) else NULL
  )
}

forecast_values <- function(fc) {
  list(
    mean  = as.numeric(fc$mean),
    lower = unclass(fc$lower),
    upper = unclass(fc$upper),
    level = fc$level
  )
}

accuracy_values <- function(acc) {
  if (is.null(acc)) return(NULL)
  unclass(acc)
}

# --- Llogaritja e plotë për një dataset ---------------------------------------

compute_results <- function(root, ds) {
  sandbox <- tempfile("ref_sandbox_")
  dir.create(file.path(sandbox, "data"), recursive = TRUE)
  on.exit(unlink(sandbox, recursive = TRUE), add = TRUE)

  csv <- file.path(sandbox, "data", ds$file)
  if (!file.copy(dataset_path(root, ds$file), csv)) stop("Kopjimi i dataset-it dështoi: ", ds$file)

  app_code <- load_app_code(root, sandbox)
  raw <- app_code$read_data_safe(csv, ds$file)
  vc  <- ds$value_cols

  out <- new.env()

  shiny::testServer(legacy_plots_module(app_code), args = list(df = shiny::reactive(raw)), {
    session$setInputs(
      data_time_col   = ds$time_col,
      data_value_cols = vc,
      data_dup        = "mean",
      data_freq       = "auto"
    )

    d0 <- sp$df_dyn()
    if (!identical(names(d0), c("Time", vc))) stop("df_dyn() nuk ka kolonat e pritura.")

    det <- list(
      value_cols = sp$value_cols(),
      df_dyn     = d0,
      summary    = summary_stats(d0, vc),
      corr       = correlation_matrix(d0)
    )
    forms  <- list()
    values <- list()

    # Kufijtë e slider-ave (R16), sipas observer-ave të server_plots.R
    step <- sp$.h_step(d0$Time)
    det$time_step <- step
    det$time_unit <- sp$.h_unit(d0$Time)

    pairs <- utils::combn(vc, 2, simplify = FALSE)
    det$relation <- setNames(
      lapply(pairs, function(p) relation_fit(d0, p[1], p[2])),
      vapply(pairs, paste, character(1), collapse = "~")
    )

    for (s in vc) {
      y <- d0[[s]]
      n_non_na <- sum(!is.na(y))

      k_min <- 3L
      k_max_raw <- if (is.finite(n_non_na) && n_non_na >= 2L) as.integer(n_non_na - 1L) else k_min
      k_max <- min(k_max_raw, sp$.roll_cap_by_step(step), max(k_min, as.integer(floor(n_non_na / 2))))
      k_max <- max(k_min, k_max)
      hb <- sp$.h_bounds(n_non_na, d0$Time)

      session$setInputs(stat_series = s)
      adf_app <- sp$adf_res()

      det$series[[s]] <- list(
        roll_bounds = list(min = k_min, max = k_max),
        h_bounds    = hb,
        roll        = setNames(lapply(ROLL_K, function(k) rolling_mean(d0, s, k)), paste0("k", ROLL_K)),
        ts_ready    = lapply(c(diff = 3L, acf = 6L, adf = 20L, model = 20L, forecast = 2L), function(mn) {
          r <- app_code$validate_ts_ready(d0, s, "auto", min_n = mn)
          list(ok = isTRUE(r$ok), n = r$n)
        }),
        diff        = first_difference(app_code, d0, s),
        acf_pacf    = acf_pacf(app_code, d0, s),
        adf         = list(
          ok     = adf_app$ok,
          reason = adf_app$reason,
          y_len  = adf_app$y_len,
          statistic_rounded = adf_app$table$Statistic,
          p_lvl  = adf_app$p_lvl,
          p_diff = adf_app$p_diff,
          reject_lvl_5pct  = !is.na(adf_app$p_lvl)  && adf_app$p_lvl  < 0.05,
          reject_diff_5pct = !is.na(adf_app$p_diff) && adf_app$p_diff < 0.05,
          raw    = adf_raw(app_code, d0, s)
        )
      )

      hs <- unique(pmin(c(1L, 5L, hb$max), hb$max))

      # Modelimi: .model_fits() + output$model_plot / output$model_acc_tbl
      session$setInputs(model_series = s)
      x <- sp$.model_fits()
      if (isTRUE(x$ok)) {
        forms$modeling[[s]] <- list(
          ok         = TRUE,
          ets_method = x$fit_ets$method,
          ets_components = x$fit_ets$components,
          arima_order    = forecast::arimaorder(x$fit_arima)
        )
        values$modeling[[s]] <- list(
          ets_par       = x$fit_ets$par,
          ets_sigma2    = x$fit_ets$sigma2,
          arima_coef    = stats::coef(x$fit_arima),
          arima_sigma2  = x$fit_arima$sigma2,
          ets_accuracy   = accuracy_values(forecast::accuracy(x$fit_ets)),
          arima_accuracy = accuracy_values(forecast::accuracy(x$fit_arima)),
          forecasts = setNames(lapply(hs, function(h) list(
            ets   = forecast_values(forecast::forecast(x$fit_ets,   h = h)),
            arima = forecast_values(forecast::forecast(x$fit_arima, h = h))
          )), paste0("h", hs))
        )
      } else {
        forms$modeling[[s]] <- list(ok = FALSE)
      }

      # Parashikimi: forecast_obj() + acc_obj()
      for (m in FORECAST_METHODS) {
        f_forms  <- list()
        f_values <- list()
        for (h in hs) {
          session$setInputs(forecast_series = s, method = m, h = h)
          session$elapse(1000)  # debounce i h-së (350 ms)
          fc <- sp$forecast_obj()

          if (is.null(fc)) {
            f_forms[[paste0("h", h)]] <- list(ok = FALSE)
            next
          }
          if (length(fc$mean) != h) stop("forecast_obj() nuk mori h = ", h, " (", s, ", ", m, ").")

          f_forms[[paste0("h", h)]] <- list(ok = TRUE, method = fc$method)
          f_values[[paste0("h", h)]] <- list(
            forecast  = forecast_values(fc),
            model_par = if (!is.null(fc$model$par)) fc$model$par else stats::coef(fc$model),
            accuracy  = accuracy_values(sp$acc_obj())
          )
        }
        if (m == "arima") {
          af <- sp$arima_fit()
          f_forms$arima_fit_ok <- isTRUE(af$ok)
          if (isTRUE(af$ok)) f_forms$arima_order <- forecast::arimaorder(af$fit)
        }
        forms$forecast[[s]][[m]]  <- f_forms
        values$forecast[[s]][[m]] <- f_values
      }
    }

    out$res <- list(
      dataset       = ds,
      deterministic = det,
      models        = list(forms = forms, values = values)
    )
  })

  if (is.null(out$res)) stop("Llogaritja nuk u krye për ", ds$file)
  out$res
}
