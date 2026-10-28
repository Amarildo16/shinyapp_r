# Analizat statistikore të serive: funksione të pastra, pa Shiny.
# Të njëjtat thirrje dhe parametra si server_plots.R (976dce0); Q30 i krahason me referencën.
# Hyrja `dd` është data.frame(Time, y) nga validate_ts_ready()$data.

# Seria si objekt ts, me frekuencën dhe fillimin nga koha (FREQ_POLICY).
series_ts <- function(dd) {
  spec <- ts_spec_from_time(dd$Time, FREQ_POLICY)
  stats::ts(as.numeric(dd$y), frequency = spec$freq, start = spec$start)
}

# Diferenca e parë Δyₜ = yₜ − yₜ₋₁; NULL kur ka < 3 pika.
first_difference <- function(dd) {
  if (nrow(dd) < 3) return(NULL)
  data.frame(Time = dd$Time[-1], diff = as.numeric(diff(dd$y)), stringsAsFactors = FALSE)
}

# ACF dhe PACF e diferencës së parë; vonesat në njësi periudhash (lag × frekuenca).
# NULL kur ka < 6 pika ose diferenca ka < 5.
acf_pacf_data <- function(dd) {
  if (nrow(dd) < 6) return(NULL)

  y_ts <- series_ts(dd)
  dy   <- diff(y_ts)
  n    <- length(dy)
  if (n < 5) return(NULL)

  acf_obj  <- stats::acf(dy, plot = FALSE)
  pacf_obj <- stats::pacf(dy, plot = FALSE)

  freq0 <- stats::frequency(y_ts)
  if (is.null(freq0) || is.na(freq0) || freq0 < 1) freq0 <- 1

  list(
    acf  = data.frame(lag = as.integer(round(as.numeric(acf_obj$lag[-1]) * freq0)),
                      value = as.numeric(acf_obj$acf[-1])),
    pacf = data.frame(lag = as.integer(round(as.numeric(pacf_obj$lag) * freq0)),
                      value = as.numeric(pacf_obj$acf)),
    conf = 1.96 / sqrt(n),
    n    = n
  )
}

# Një test ADF (tseries::adf.test, parametrat default). NULL kur testi dështon.
# tseries e pret p-vlerën në skajet e tabelës (0.01 / 0.99) dhe jep warning; vetëm ky
# warning hiqet dhe ruhet si p_bound = "lower" | "upper" (V-17 c). Vlera nuk ndryshon.
adf_one <- function(y) {
  bound <- NA_character_
  res <- tryCatch(
    withCallingHandlers(
      tseries::adf.test(y),
      warning = function(w) {
        msg <- conditionMessage(w)
        if (identical(msg, "p-value smaller than printed p-value")) {
          bound <<- "lower"
          invokeRestart("muffleWarning")
        }
        if (identical(msg, "p-value greater than printed p-value")) {
          bound <<- "upper"
          invokeRestart("muffleWarning")
        }
      }
    ),
    error = function(e) NULL
  )
  if (is.null(res)) return(NULL)

  list(
    statistic = as.numeric(res$statistic),
    p_value   = as.numeric(res$p.value),
    lag_order = as.numeric(res$parameter),
    method    = res$method,
    p_bound   = bound
  )
}

# ADF për nivelin dhe diferencën e parë. ok = FALSE kur ka < 20 pika;
# diff = NULL kur diferenca ka < 20 pika.
run_adf <- function(y) {
  y <- suppressWarnings(as.numeric(y))
  if (length(y) < 20) return(list(ok = FALSE, n = length(y)))

  dy <- diff(y)
  list(
    ok    = TRUE,
    n     = length(y),
    level = adf_one(y),
    diff  = if (length(dy) >= 20) adf_one(dy) else NULL
  )
}

# ETS automatik (forecast::ets, parametrat default). NULL kur dështon.
fit_ets <- function(y) {
  tryCatch(forecast::ets(y), error = function(e) NULL)
}

# ARIMA automatik, me opsionet e app-it: sezonal për frekuencë 4/12/52, stepwise,
# përafrim vetëm për seri të gjata (> 800) ose frekuencë > 12. NULL kur dështon.
fit_arima <- function(y) {
  fq <- stats::frequency(y)
  fastish <- length(y) > 800 || fq > 12
  tryCatch(
    forecast::auto.arima(
      y,
      seasonal = fq %in% c(4, 12, 52),
      stepwise = TRUE,
      approximation = if (fastish) TRUE else FALSE
    ),
    error = function(e) NULL
  )
}

# Parashikimi i Parashikimit: SES, Holt ose ARIMA (nga një model i gatshëm).
forecast_method <- function(y, method, h, arima_fit = NULL) {
  switch(method,
    ses   = forecast::ses(y, h = h),
    holt  = forecast::holt(y, h = h),
    arima = forecast::forecast(arima_fit, h = h),
    stop("Metodë e panjohur: ", method)
  )
}

# Rreshti i setit të trajnimit nga forecast::accuracy() si vektor me emra.
training_accuracy <- function(acc) {
  row <- if ("Training set" %in% rownames(acc)) "Training set" else 1L
  acc[row, , drop = TRUE]
}
