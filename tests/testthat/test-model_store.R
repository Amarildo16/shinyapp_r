# model_store (P-07): një model për seri, i përbashkët për Modelimin dhe Parashikimin.

counting_store <- function() {
  calls <- new.env()
  calls$ets <- 0L
  calls$arima <- 0L
  store <- model_store(fitters = list(
    ets   = function(y) { calls$ets <- calls$ets + 1L; list(kind = "ets", n = length(y)) },
    arima = function(y) { calls$arima <- calls$arima + 1L; NULL }   # dështim
  ))
  list(store = store, calls = calls)
}

test_that("e njëjta seri llogaritet një herë; seri tjetër → model i ri", {
  cs <- counting_store()
  y1 <- stats::ts(c(1, 3, 2, 5, 4), frequency = 1, start = 2000)

  expect_false(cs$store$has("ets", y1))
  f1 <- cs$store$get("ets", y1)
  f2 <- cs$store$get("ets", stats::ts(c(1, 3, 2, 5, 4), frequency = 1, start = 2000))
  expect_identical(f1, f2)
  expect_true(cs$store$has("ets", y1))
  expect_equal(cs$calls$ets, 1L)

  cs$store$get("ets", stats::ts(c(1, 3, 2, 5, 4), frequency = 4, start = 2000))  # tjetër tsp
  cs$store$get("ets", stats::ts(c(1, 3, 2, 5, 9), frequency = 1, start = 2000))  # tjetër vlerë
  expect_equal(cs$calls$ets, 3L)
})

test_that("lloji i modelit është pjesë e çelësit; dështimi (NULL) ruhet", {
  cs <- counting_store()
  y <- stats::ts(1:10)

  cs$store$get("ets", y)
  expect_false(cs$store$has("arima", y))
  expect_null(cs$store$get("arima", y))
  expect_null(cs$store$get("arima", y))
  expect_true(cs$store$has("arima", y))
  expect_equal(cs$calls$arima, 1L)
})

test_that("me fitter-at e vërtetë jep të njëjtin model si fit_arima()", {
  y <- series_ts(validate_ts_ready(prepare_fixture("yearly_full.csv", "Year", "Value"),
                                   "Value", FREQ_POLICY)$data)
  store <- model_store()
  expect_equal(stats::coef(store$get("arima", y)), stats::coef(fit_arima(y)))
})
