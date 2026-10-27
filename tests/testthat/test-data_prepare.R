test_that("make_df_dyn shton Time të renditur dhe refuzon kolonë kohe të pavlefshme", {
  d <- data.frame(Year = c("2002", "2000", "2001"), v = c("3", "1", "2"), stringsAsFactors = FALSE)
  out <- make_df_dyn(d, "Year")
  expect_equal(out$Time, c(2000, 2001, 2002))
  expect_equal(out$v, c("1", "2", "3"))

  expect_error(make_df_dyn(d, "Nope"), "kolonë kohe")
  expect_error(make_df_dyn(d, NULL), "kolonë kohe")
})

test_that("apply_dup_policy bashkon datat e dyfishta (Q16)", {
  d <- read_data_safe(fixture("monthly_dup.csv"), "monthly_dup.csv")
  d$Value <- to_numeric_safe(d$Value)
  d <- make_df_dyn(d, "Date")[, c("Time", "Value")]

  mar <- as.Date("2021-03-01")
  m <- apply_dup_policy(d, "Value", "mean")
  expect_equal(nrow(m), 6)
  expect_equal(m$Value[m$Time == mar], 15)

  expect_equal(apply_dup_policy(d, "Value", "first")$Value[2:3], c(15, 10))
  expect_equal(apply_dup_policy(d, "Value", "last")$Value[3], 20)
  expect_equal(apply_dup_policy(d, "Value", "sum")$Value[3], 30)
})

test_that("apply_freq_policy plotëson grid-in me NA ku mungon një periudhë", {
  g <- prepare_fixture("monthly_gap.csv", "Date", "Value")
  expect_equal(nrow(g), 12)
  expect_true(is.na(g$Value[g$Time == as.Date("2021-06-01")]))

  y <- data.frame(Time = c(2000, 2001, 2003), v = c(1, 2, 4))
  yy <- apply_freq_policy(y, "auto", "v")
  expect_equal(yy$Time, 2000:2003)
  expect_equal(yy$v, c(1, 2, NA, 4))

  full <- prepare_fixture("monthly_full.csv", "Date", "Sales")
  expect_equal(nrow(full), 36)
  expect_false(anyNA(full$Sales))
})

test_that("pick_value_cols: preferred, pastaj current, pastaj 3 të parat", {
  num <- c("a", "b", "c", "d")
  expect_equal(pick_value_cols(num, c("d", "x")), "d")
  expect_equal(pick_value_cols(num, c("a", "a")), "a")
  expect_equal(pick_value_cols(num, "x", current = c("c", "y")), "c")
  expect_equal(pick_value_cols(num), c("a", "b", "c"))
  expect_equal(pick_value_cols(character(0)), character(0))
})

test_that("resolve_dataset_defaults ruan rregullat e default-eve (P-03)", {
  d <- data.frame(
    Year = c("2000", "2001", "2002"),
    a = c("1", "2", "3"), b = c("4", "5", "6"), c = c("7", "8", "9"), d = c("1", "1", "2"),
    txt = c("x", "y", "z"),
    stringsAsFactors = FALSE
  )

  def <- resolve_dataset_defaults(d)
  expect_equal(def$time_col, "Year")
  expect_equal(def$time_choices[1], "Year")
  expect_equal(def$num_cols, c("a", "b", "c", "d"))
  expect_equal(def$value_cols, c("a", "b", "c"))

  cfg <- list(time_col = "Year", value_cols = c("d", "txt", "nope"))
  expect_equal(resolve_dataset_defaults(d, cfg)$value_cols, "d")

  bad_cfg <- list(time_col = "Nope", value_cols = character(0))
  expect_equal(resolve_dataset_defaults(d, bad_cfg)$time_col, "Year")
  expect_equal(resolve_dataset_defaults(d, list(time_col = ""))$time_col, "Year")
  expect_equal(resolve_dataset_defaults(d, list(time_col = NA_character_))$time_col, "Year")

  cur <- resolve_dataset_defaults(d, bad_cfg, current_time = "Year", current_values = c("b", "zz"))
  expect_equal(cur$time_col, "Year")
  expect_equal(cur$value_cols, "b")
})
