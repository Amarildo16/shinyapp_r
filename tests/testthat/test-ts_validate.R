test_that("seri e plotë mujore, tremujore dhe vjetore kalojnë validimin", {
  m <- prepare_fixture("monthly_full.csv", "Date", "Sales")
  rm <- validate_ts_ready(m, "Sales", "auto", min_n = 20L)
  expect_true(rm$ok)
  expect_equal(rm$n, 36)
  expect_equal(rm$freq_key, "monthly")
  expect_equal(names(rm$data), c("Time", "y"))

  q <- prepare_fixture("quarterly.csv", "Period", "GDP")
  rq <- validate_ts_ready(q, "GDP")
  expect_true(rq$ok)
  expect_equal(rq$freq_key, "quarterly")

  y <- prepare_fixture("yearly_full.csv", "Year", "Value")
  ry <- validate_ts_ready(y, "Value", min_n = 20L)
  expect_true(ry$ok)
  expect_equal(ry$freq_key, "yearly")
})

test_that("periudha që mungon jep mesazhin e serisë jo të plotë (R15, Q15)", {
  g <- prepare_fixture("monthly_gap.csv", "Date", "Value")
  r <- validate_ts_ready(g, "Value")
  expect_false(r$ok)
  expect_equal(r$message, paste("Seria ka periudha që mungojnë, data të parregullta ose vlera bosh.",
                                "Plotet EDA mund të shfaqen, por analizat statistikore dhe parashikimi kërkojnë seri kohore të rregullt pa boshllëqe."))
  expect_match(validate_ts_ready(g, "Value")$message, "Plotet EDA")

  raw <- read_data_safe(fixture("monthly_gap.csv"), "monthly_gap.csv")
  reg <- assess_time_regular(parse_time_safe(raw$Date))
  expect_false(reg$ok)
  expect_equal(reg$missing_periods, as.Date("2021-06-01"))
})

test_that("datat e dyfishta para politikës së dublikatave refuzohen", {
  raw <- read_data_safe(fixture("monthly_dup.csv"), "monthly_dup.csv")
  reg <- assess_time_regular(parse_time_safe(raw$Date))
  expect_false(reg$ok)
  expect_equal(reg$off_grid_periods, as.Date("2021-03-01"))
})

test_that("seria e shkurtër respekton kufijtë minimalë (R15)", {
  s <- prepare_fixture("short.csv", "Year", "Value")
  expect_true(validate_ts_ready(s, "Value", min_n = 6L)$ok)
  r20 <- validate_ts_ready(s, "Value", min_n = 20L)
  expect_false(r20$ok)
  expect_equal(r20$message, "Seria ka shumë pak vëzhgime të vlefshme për këtë analizë.")
  expect_equal(r20$n, 12)
})

test_that("kolona e kohës index (jo vit) shpjegon formatet e pranuara (B-09, V-19 c)", {
  d <- data.frame(Time = c(1, 2, 3, 4, 5), y = c(2, 4, 6, 8, 10))
  r <- validate_ts_ready(d, "y")
  expect_false(r$ok)
  expect_equal(r$message, paste("Kolona e kohës ka numra që nuk janë vite (p.sh. 1, 2, 3…), ndaj frekuenca e serisë nuk dihet.",
                                "Analizat statistikore kërkojnë kohë në një nga formatet: YYYY, YYYY-MM, YYYY-MM-DD ose YYYYQ#. EDA punon edhe kështu."))
  expect_match(validate_ts_ready(d, "y")$message, "YYYYQ#", fixed = TRUE)
  # Datat me frekuencë të panjohur mbajnë mesazhin e vjetër.
  expect_equal(ts_freq_msg(as.Date(c("2020-01-01", "2020-01-02"))),
               "Nuk u identifikua dot frekuenca e serisë kohore. Zgjidhni një kolonë kohe të rregullt ose kontrolloni të dhënat.")
  expect_match(tr("ts.index", lang = "en"), "not years")
})

test_that("seria konstante kalon validimin (trajtohet nga faqet)", {
  k <- prepare_fixture("constant.csv", "Year", "Value")
  expect_true(validate_ts_ready(k, "Value", min_n = 20L)$ok)
})

test_that("seria që mungon ose Time që mungon kthejnë mesazh", {
  m <- prepare_fixture("monthly_full.csv", "Date", "Sales")
  expect_false(validate_ts_ready(m, "Nope")$ok)
  expect_false(assess_complete_series(data.frame(x = 1:3), "x")$ok)
})

test_that("detect_freq_from_time dhe canonical_freq_key", {
  months <- seq(as.Date("2021-01-01"), by = "month", length.out = 6)
  expect_equal(detect_freq_from_time(months), "month")
  expect_equal(detect_freq_from_time(seq(as.Date("2021-01-01"), by = "quarter", length.out = 4)), "quarter")
  expect_equal(detect_freq_from_time(seq(as.Date("2021-01-04"), by = "week", length.out = 4)), "week")
  expect_equal(detect_freq_from_time(seq(as.Date("2021-01-01"), by = "day", length.out = 4)), "day")
  expect_equal(detect_freq_from_time(seq(as.Date("2001-01-01"), by = "year", length.out = 4)), "year")
  expect_equal(detect_freq_from_time(c(2000, 2001, 2002)), "year")
  expect_equal(detect_freq_from_time(c(1, 2, 3)), "index")

  expect_equal(canonical_freq_key(months), "monthly")
  expect_equal(canonical_freq_key(c(2000, 2001)), "yearly")
  expect_null(canonical_freq_key(c(2000.5, 2001.5)))
  expect_null(canonical_freq_key(2000))
})

test_that("ts_spec_from_time jep frekuencën dhe fillimin", {
  expect_equal(ts_spec_from_time(seq(as.Date("2021-03-01"), by = "month", length.out = 4))[c("freq", "start")],
               list(freq = 12, start = c(2021L, 3L)))
  expect_equal(ts_spec_from_time(as.Date(c("2018-04-01", "2018-07-01", "2018-10-01")))[c("freq", "start")],
               list(freq = 4, start = c(2018L, 2)))
  expect_equal(ts_spec_from_time(c(2000, 2001, 2002))[c("key", "freq", "start")],
               list(key = "year", freq = 1, start = c(2000L, 1)))
  expect_equal(ts_spec_from_time(c(1, 2, 3))$key, "index")
})

test_that("infer_step_from_time dhe make_future_time", {
  months <- seq(as.Date("2023-10-01"), by = "month", length.out = 3)
  expect_equal(infer_step_from_time(months), list(type = "date", step = "month"))
  expect_equal(make_future_time(months, 3), as.Date(c("2024-01-01", "2024-02-01", "2024-03-01")))

  quarters <- as.Date(c("2023-04-01", "2023-07-01", "2023-10-01"))
  expect_equal(make_future_time(quarters, 1), as.Date("2024-01-01"))

  expect_equal(make_future_time(c(2022, 2023, 2024), 2), c(2025, 2026))
  expect_length(make_future_time(c(2022, 2023, 2024), 0), 0)
})

test_that("date_period_key, date_period_start dhe expected_time_grid", {
  x <- as.Date(c("2021-03-15", "2021-05-17"))
  expect_equal(date_period_key(x, "monthly"), c("2021-03", "2021-05"))
  expect_equal(date_period_key(x, "quarterly"), c("2021-Q1", "2021-Q2"))
  expect_equal(date_period_start(x, "quarterly"), as.Date(c("2021-01-01", "2021-04-01")))
  expect_equal(date_period_start(x, "monthly"), as.Date(c("2021-03-01", "2021-05-01")))

  expect_equal(expected_time_grid(as.Date(c("2021-01-01", "2021-04-01"))), as.Date(c("2021-01-01", "2021-04-01")))
  expect_length(expected_time_grid(as.Date(c("2021-01-01", "2021-02-01", "2021-03-01", "2021-12-01"))), 12)
  expect_equal(expected_time_grid(c(2000, 2003)), 2000:2003)
})
