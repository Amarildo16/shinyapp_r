# Statistikat e Përmbledhjes dhe të EDA-s (R09–R11). Vlerat e dataset-eve shembull
# mbrohen nga Q30; këtu testohen rregullat dhe rastet kufitare.

test_that("summary_stats: mesatarja, sd, min, max, N dhe % që mungon", {
  d <- data.frame(Time = 1:5, a = c(1, 2, NA, 4, 5), b = c(NA, NA, NA, NA, 7))
  st <- summary_stats(d, c("a", "b"))

  expect_equal(st$variable, c("a", "b"))
  expect_equal(st$mean, c(3, 7))
  expect_equal(st$sd[1], sd(c(1, 2, 4, 5)))
  expect_true(is.na(st$sd[2]))          # një vlerë e vetme → pa sd
  expect_equal(st$min, c(1, 7))
  expect_equal(st$max, c(5, 7))
  expect_equal(st$n, c(4L, 1L))
  expect_equal(st$missing_pct, c(20, 80))
})

test_that("rolling_mean: dritarja e djathtë, k përshtatet, < 3 pika → ok = FALSE", {
  d <- data.frame(Time = 5:1, v = c(5, 4, 3, 2, 1))   # e pa renditur
  r <- rolling_mean(d, "v", 3)
  expect_true(r$ok)
  expect_false(r$k_adjusted)
  expect_equal(r$data$Time, 1:5)
  expect_equal(r$data$roll_mean, c(NA, NA, 2, 3, 4))

  big <- rolling_mean(d, "v", 10)
  expect_true(big$k_adjusted)
  expect_equal(big$k, 4L)

  expect_equal(rolling_mean(d, "v", NA)$k, 4L)          # NA → 5 → përshtatet në 4
  expect_equal(rolling_mean(d, "v", 1)$k, 2L)           # minimumi 2
  expect_false(rolling_mean(data.frame(Time = 1:4, v = c(1, NA, NA, 2)), "v", 3)$ok)
})

test_that("relation_fit: regresioni dhe arsyet e refuzimit", {
  d <- data.frame(Time = 1:6, x = c(1, 2, 3, 4, 5, NA), y = c(2, 4, 6, 8, 10, 12))
  r <- relation_fit(d, "x", "y")
  expect_true(r$ok)
  expect_equal(r$n, 5L)
  expect_equal(unname(r$coef), c(0, 2))
  expect_equal(nrow(r$line), 100L)
  expect_equal(r$line$yhat[100], 10)

  expect_equal(relation_fit(d[1, ], "x", "y")$reason, "few_points")
  expect_equal(relation_fit(transform(d, x = 3), "x", "y")$reason, "no_x_variation")
})

test_that("correlation_matrix: pa Time, sd > 0, maksimumi 20 kolona", {
  d <- data.frame(Time = 1:5, a = c(1, 2, 3, 4, 5), b = c(2, 4, 6, 8, 11), k = 1)
  r <- correlation_matrix(d)
  expect_true(r$ok)
  expect_equal(colnames(r$corr), c("a", "b"))   # Time dhe kolona konstante jashtë
  expect_false(r$truncated)

  expect_equal(correlation_matrix(d[, c("Time", "a")])$reason, "few_cols")
  expect_equal(correlation_matrix(d[, c("Time", "a", "k")])$reason, "few_cols_after_sd")

  wide <- as.data.frame(matrix(rnorm(5 * 22), nrow = 5))
  rw <- correlation_matrix(cbind(Time = 1:5, wide))
  expect_true(rw$truncated)
  expect_equal(ncol(rw$corr), 20L)
})
