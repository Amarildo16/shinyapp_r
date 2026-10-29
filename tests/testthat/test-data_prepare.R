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

# df_dyn() i vjetër (legacy_server_plots.R para Fazës 4), për krahasim me prepare_series().
legacy_df_dyn <- function(d, time_col, vc) {
  for (v in vc) d[[v]] <- to_numeric_safe(d[[v]])
  d <- make_df_dyn(d, time_col)
  d <- d[, c("Time", vc), drop = FALSE]
  d <- apply_dup_policy(d, vc = vc, method = "mean")
  apply_freq_policy(d, freq = "auto", vc = vc)
}

test_that("prepare_series = df_dyn() i vjetër për fixtures dhe shembujt (V-04, T-14)", {
  csvs <- c(
    list.files(file.path(APP_ROOT, "tests", "fixtures"), "[.]csv$", full.names = TRUE),
    list.files(file.path(APP_ROOT, "data", "samples"), "[.]csv$", full.names = TRUE)
  )
  n_cmp <- 0L
  for (f in csvs) {
    d <- tryCatch(read_data_safe(f, basename(f)), error = function(e) NULL)
    if (is.null(d) || ncol(d) < 2) next
    def <- resolve_dataset_defaults(d)
    for (tc in def$time_choices) {
      num <- detect_numeric_cols(d, exclude = tc)
      for (vc in list(num, head(num, 1), rev(num))) {
        if (!length(vc)) next
        old <- tryCatch(legacy_df_dyn(d, tc, vc), error = function(e) conditionMessage(e))
        new <- tryCatch(
          prepare_series(list(file = basename(f), data = d, time_col = tc, value_cols = vc)),
          error = function(e) conditionMessage(e)
        )
        if (is.character(old)) {
          expect_identical(new, old, info = paste(basename(f), tc))
        } else {
          expect_identical(new$data, old, info = paste(basename(f), tc))
          expect_identical(new$value_cols, vc)
          expect_identical(new$meta, build_meta(vc))
        }
        n_cmp <- n_cmp + 1L
      }
    }
  }
  expect_gt(n_cmp, 20)
})

test_that("prepare_series kthen NULL pa dataset, pa kohë ose pa seri", {
  d <- data.frame(Year = c("2000", "2001"), v = c("1", "2"), stringsAsFactors = FALSE)
  expect_null(prepare_series(NULL))
  expect_null(prepare_series(list(file = "x.csv", data = NULL, time_col = "Year", value_cols = "v")))
  expect_null(prepare_series(list(file = "x.csv", data = d, time_col = NULL, value_cols = "v")))
  expect_null(prepare_series(list(file = "x.csv", data = d, time_col = "Year", value_cols = character(0))))
  expect_equal(prepare_series(list(file = "x.csv", data = d, time_col = "Year", value_cols = "v"))$data$v, c(1, 2))
})

test_that("B-19: kolona e kohës me numra 1, 2, 3… lexohet si kohë numerike, jo error (V-24 b)", {
  d <- data.frame(Nr = as.character(1:30), V = as.character(round(cumsum(sin(1:30)), 3)), stringsAsFactors = FALSE)
  s <- prepare_series(list(file = "index.csv", data = d, time_col = "Nr", value_cols = "V"))
  expect_equal(s$data$Time, 1:30)
  # Analizat statistikore e refuzojnë me mesazhin e B-09 (V-19 c); EDA e ka serinë.
  v <- validate_ts_ready(s$data, "V", FREQ_POLICY, min_n = 20L)
  expect_false(v$ok)
  expect_match(v$message, "nuk janë vite", fixed = TRUE)

  # Pa allow_index (zbulimi i kolonave) numrat si tekst nuk bëhen kohë: zbulimi nuk ndryshon.
  expect_error(parse_time_safe(c("1", "2", "3")))
  expect_equal(parse_time_safe(c("1", "2", "3"), allow_index = TRUE), c(1, 2, 3))
  expect_equal(parse_time_safe(c("2001", "2002"), allow_index = TRUE), c(2001, 2002))
})
