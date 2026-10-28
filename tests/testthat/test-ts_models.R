# Analizat statistikore (R12–R14). Vlerat e dataset-eve shembull mbrohen nga Q30;
# këtu testohen parametrat, kufijtë dhe rastet kufitare.

ts_data <- function(name, time_col, value_col, min_n = 2L) {
  d <- prepare_fixture(name, time_col, value_col)
  validate_ts_ready(d, value_col, FREQ_POLICY, min_n = min_n)$data
}

test_that("series_ts merr frekuencën dhe fillimin nga koha", {
  m <- series_ts(ts_data("monthly_full.csv", "Date", "Sales"))
  expect_equal(stats::frequency(m), 12)
  expect_equal(stats::start(m), c(2021, 1))
  expect_length(m, 36)

  q <- series_ts(ts_data("quarterly.csv", "Period", "GDP"))
  expect_equal(stats::frequency(q), 4)

  y <- series_ts(ts_data("yearly_full.csv", "Year", "Value"))
  expect_equal(stats::frequency(y), 1)
  expect_equal(stats::start(y)[1], 2000)
})

test_that("first_difference dhe acf_pacf_data: kufijtë minimalë (R15)", {
  dd <- ts_data("monthly_full.csv", "Date", "Sales")
  fd <- first_difference(dd)
  expect_equal(nrow(fd), 35)
  expect_equal(fd$diff, diff(dd$y))
  expect_equal(fd$Time, dd$Time[-1])
  expect_null(first_difference(dd[1:2, ]))

  ap <- acf_pacf_data(dd)
  expect_equal(ap$n, 35)
  expect_equal(ap$conf, 1.96 / sqrt(35))
  expect_equal(ap$acf$lag[1], 1L)          # lag në periudha, jo në vite
  expect_equal(ap$pacf$lag[1], 1L)
  expect_null(acf_pacf_data(dd[1:5, ]))
})

test_that("run_adf: < 20 pika → ok = FALSE; diferenca vetëm me ≥ 20 pika", {
  expect_false(run_adf(1:19)$ok)

  set.seed(1)
  y20 <- cumsum(rnorm(20))
  r20 <- run_adf(y20)
  expect_true(r20$ok)
  expect_false(is.null(r20$level))
  expect_null(r20$diff)                     # 19 diferenca: pa test (B-17)

  r21 <- run_adf(cumsum(rnorm(21)))
  expect_false(is.null(r21$diff))
})

test_that("run_adf: p-vlera e prerë nga tseries shënohet, pa warning (V-17 c)", {
  set.seed(1)
  noise <- rnorm(200)
  expect_no_warning(r <- run_adf(noise))
  expect_equal(r$level$p_value, 0.01)
  expect_equal(r$level$p_bound, "lower")
  expect_equal(r$level$p_value, suppressWarnings(tseries::adf.test(noise))$p.value)
  expect_equal(r$level$statistic, unname(suppressWarnings(tseries::adf.test(noise))$statistic))

  walk <- cumsum(rnorm(60))
  rw <- run_adf(walk)
  expect_true(is.na(rw$level$p_bound))
  expect_gt(rw$level$p_value, 0.01)
})

test_that("fit_ets / fit_arima: opsionet e app-it dhe NULL kur dështojnë", {
  y <- series_ts(ts_data("monthly_full.csv", "Date", "Sales"))

  e <- fit_ets(y)
  expect_s3_class(e, "ets")
  expect_identical(e$method, forecast::ets(y)$method)

  a <- fit_arima(y)
  expect_s3_class(a, "Arima")
  ref <- forecast::auto.arima(y, seasonal = TRUE, stepwise = TRUE, approximation = FALSE)
  expect_equal(forecast::arimaorder(a), forecast::arimaorder(ref))

  expect_null(fit_ets(numeric(0)))
  expect_null(fit_arima(numeric(0)))
})

test_that("forecast_method dhe training_accuracy", {
  y <- series_ts(ts_data("yearly_full.csv", "Year", "Value"))

  expect_length(forecast_method(y, "ses", 3)$mean, 3)
  expect_length(forecast_method(y, "holt", 4)$mean, 4)
  a <- fit_arima(y)
  expect_equal(as.numeric(forecast_method(y, "arima", 2, a)$mean),
               as.numeric(forecast::forecast(a, h = 2)$mean))
  expect_error(forecast_method(y, "var", 2), "panjohur")

  acc <- training_accuracy(forecast::accuracy(fit_ets(y)))
  expect_true(all(c("ME", "RMSE", "MAE", "MAPE") %in% names(acc)))
})
