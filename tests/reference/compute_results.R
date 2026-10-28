# Llogarit rezultatet statistike të app-it për një dataset shembull (V-07, R21).
#
# Faza 0: thërriste helpers.R + server_plots.R. Që nga Faza 2 ngarkon R/ me
# shiny::loadSupport(), njësoj si app-i (server_plots() jeton te R/legacy_server_plots.R).
#   - Pjesët reaktive (df_dyn, ADF, modelet, parashikimet, kufijtë e slider-ave)
#     merren nga vetë server_plots() me shiny::testServer.
#   - Llogaritjet që jetonin brenda render*-ave (mesatarja lëvizëse, regresioni,
#     korrelacioni, diferenca, ACF/PACF, ADF) merren që nga Faza 5 nga funksionet e
#     pastra të app-it (R/stats_eda.R, R/ts_models.R, R/ts_time.R); këtu vetëm
#     sillen në formën e referencës.
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

# Paketat që app.R ngarkon me library().
APP_PACKAGES <- c("shiny", "shinyjs", "plotly", "ggplot2", "dplyr", "tidyr", "readr",
                  "forecast", "scales", "tseries", "DT", "jsonlite", "zoo")

# Ngarkon kodin e app-it në një mjedis të veçantë. APP_DIR drejtohet te një
# sandbox i përkohshëm, që asgjë të mos shkruhet te data/ e projektit.
load_app_code <- function(root, sandbox) {
  for (p in APP_PACKAGES) suppressPackageStartupMessages(library(p, character.only = TRUE))
  options(scipen = 999)

  app_code <- new.env(parent = globalenv())
  old <- options(shiny.appdir = sandbox, app.code_dir = root)
  on.exit(options(old), add = TRUE)
  shiny::loadSupport(root, renv = app_code, globalrenv = NULL)
  app_code
}

# testServer() pranon argumente vetëm për module. Ky modul i hollë thërret
# server_plots() pa ndryshime; kopja e funksionit kthen edhe mjedisin e vet,
# që testi të lexojë reaktivët e brendshëm (df_dyn, adf_res, .model_fits...).
legacy_plots_module <- function(app_code) {
  server_plots_env <- app_code$server_plots
  body(server_plots_env) <- call("{", body(server_plots_env), quote(environment()))

  function(id, series, active, fits) {
    shiny::moduleServer(id, function(input, output, session) {
      sp <- server_plots_env(input, output, session, series, active, fits)
    })
  }
}

# --- Funksionet e app-it, në formën e referencës --------------------------------

# output$eda_ts_roll
rolling_mean_ref <- function(app_code, d0, series, k) {
  r <- app_code$rolling_mean(d0, series, k)
  if (!isTRUE(r$ok)) return(list(ok = FALSE))
  list(ok = TRUE, k = r$k, time = r$data$Time, roll_mean = r$data$roll_mean)
}

# output$eda_rel_scatter
relation_fit_ref <- function(app_code, d0, x, y) {
  r <- app_code$relation_fit(d0, x, y)
  if (!isTRUE(r$ok) || is.null(r$line)) return(list(ok = FALSE, n = r$n))
  list(ok = TRUE, n = r$n, coef = r$coef, line_x = r$line$xval, line_y = r$line$yhat)
}

# output$eda_rel_corr
correlation_matrix_ref <- function(app_code, d0) {
  r <- app_code$correlation_matrix(d0)
  if (!isTRUE(r$ok)) return(list(ok = FALSE))
  list(ok = TRUE, corr = r$corr)
}

# output$stat_diff_plot
first_difference_ref <- function(app_code, d0, series) {
  ts_ok <- app_code$validate_ts_ready(d0, series, "auto", min_n = 3L)
  if (!isTRUE(ts_ok$ok)) return(list(ok = FALSE))
  fd <- app_code$first_difference(ts_ok$data)
  if (is.null(fd)) return(list(ok = FALSE))
  list(ok = TRUE, time = fd$Time, diff = fd$diff)
}

# output$stat_acf_pacf
acf_pacf_ref <- function(app_code, d0, series) {
  ts_ok <- app_code$validate_ts_ready(d0, series, "auto", min_n = 6L)
  if (!isTRUE(ts_ok$ok)) return(list(ok = FALSE))
  ap <- app_code$acf_pacf_data(ts_ok$data)
  if (is.null(ap)) return(list(ok = FALSE))
  list(
    ok       = TRUE,
    acf_lag  = ap$acf$lag,
    acf      = ap$acf$value,
    pacf_lag = ap$pacf$lag,
    pacf     = ap$pacf$value,
    conf     = ap$conf
  )
}

# adf_res() rrumbullakos statistikën; këtu ruhen edhe vlerat e plota.
adf_raw_ref <- function(app_code, d0, series) {
  ts_ok <- app_code$validate_ts_ready(d0, series, "auto", min_n = 20L)
  if (!isTRUE(ts_ok$ok)) return(list(ok = FALSE))

  r <- app_code$run_adf(ts_ok$data$y)
  if (!isTRUE(r$ok)) return(list(ok = FALSE))

  one <- function(o) {
    if (is.null(o)) return(NULL)
    list(statistic = o$statistic, p_value = o$p_value, lag_order = o$lag_order)
  }
  list(ok = TRUE, level = one(r$level), diff = one(r$diff))
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

  # Faza 4 (V-04): dataset-i aktiv vjen si active(), seritë nga prepare_series().
  active <- list(file = ds$file, data = raw, time_col = ds$time_col, value_cols = vc)
  module_args <- list(
    series = shiny::reactive(app_code$prepare_series(active)),
    active = shiny::reactive(active),
    fits   = app_code$model_store()
  )

  shiny::testServer(legacy_plots_module(app_code), args = module_args, {

    d0 <- sp$df_dyn()
    if (!identical(names(d0), c("Time", vc))) stop("df_dyn() nuk ka kolonat e pritura.")

    det <- list(
      value_cols = sp$value_cols(),
      df_dyn     = d0,
      summary    = app_code$summary_stats(d0, vc),
      corr       = correlation_matrix_ref(app_code, d0)
    )
    forms  <- list()
    values <- list()

    # Kufijtë e slider-ave (R16), sipas observer-ave të server_plots.R
    det$time_step <- app_code$time_step(d0$Time)
    det$time_unit <- app_code$time_step_unit(d0$Time)

    pairs <- utils::combn(vc, 2, simplify = FALSE)
    det$relation <- setNames(
      lapply(pairs, function(p) relation_fit_ref(app_code, d0, p[1], p[2])),
      vapply(pairs, paste, character(1), collapse = "~")
    )

    for (s in vc) {
      y <- d0[[s]]
      n_non_na <- sum(!is.na(y))

      rb <- app_code$roll_bounds(n_non_na, d0$Time)
      hb <- app_code$h_bounds(n_non_na, d0$Time)

      session$setInputs(stat_series = s)
      adf_app <- sp$adf_res()

      det$series[[s]] <- list(
        roll_bounds = rb,
        h_bounds    = hb,
        roll        = setNames(lapply(ROLL_K, function(k) rolling_mean_ref(app_code, d0, s, k)), paste0("k", ROLL_K)),
        ts_ready    = lapply(c(diff = 3L, acf = 6L, adf = 20L, model = 20L, forecast = 2L), function(mn) {
          r <- app_code$validate_ts_ready(d0, s, "auto", min_n = mn)
          list(ok = isTRUE(r$ok), n = r$n)
        }),
        diff        = first_difference_ref(app_code, d0, s),
        acf_pacf    = acf_pacf_ref(app_code, d0, s),
        adf         = list(
          ok     = adf_app$ok,
          reason = adf_app$reason,
          y_len  = adf_app$y_len,
          statistic_rounded = adf_app$table$Statistic,
          p_lvl  = adf_app$p_lvl,
          p_diff = adf_app$p_diff,
          reject_lvl_5pct  = !is.na(adf_app$p_lvl)  && adf_app$p_lvl  < 0.05,
          reject_diff_5pct = !is.na(adf_app$p_diff) && adf_app$p_diff < 0.05,
          raw    = adf_raw_ref(app_code, d0, s)
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
