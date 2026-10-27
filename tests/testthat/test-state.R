# State-i i dataset-eve dhe i background-it, vetëm në sandbox-in e testeve.

test_that("default_state dhe konfigurimi i një dataset-i", {
  st <- default_state()
  expect_null(st$active)
  expect_equal(nrow(st$datasets), 0)
  expect_true(is.na(get_ds_idx(st, "x.csv")))
  expect_equal(get_dataset_config(st, "x.csv"), list(time_col = NULL, value_cols = character(0)))

  st$datasets <- data.frame(
    file = c("a.csv", "b.csv"), added_at = c("t1", "t2"), is_active = c(TRUE, FALSE),
    time_col = c("Year", ""), stringsAsFactors = FALSE
  )
  st$datasets$value_cols <- I(list(c("v1", "v2"), character(0)))

  expect_equal(get_ds_idx(st, "b.csv"), 2)
  expect_equal(get_dataset_config(st, "a.csv"), list(time_col = "Year", value_cols = c("v1", "v2")))
  expect_null(get_dataset_config(st, "b.csv")$time_col)

  st2 <- update_dataset_config(st, "b.csv", "Date", c("x"))
  expect_equal(get_dataset_config(st2, "b.csv"), list(time_col = "Date", value_cols = "x"))
  expect_identical(update_dataset_config(st, "mungon.csv", "Date", "x"), st)
})

test_that("write_state dhe read_state ruajnë konfigurimin (rrugë e përkohshme)", {
  f <- tempfile(fileext = ".json")
  st <- default_state()
  st$datasets <- data.frame(file = "a.csv", added_at = "t1", is_active = TRUE, time_col = "Year",
                            stringsAsFactors = FALSE)
  st$datasets$value_cols <- I(list(c("v1", "v2")))
  st$active <- "a.csv"

  write_state(st, f)
  back <- read_state(f)
  expect_equal(back$active, "a.csv")
  expect_equal(get_dataset_config(back, "a.csv"), list(time_col = "Year", value_cols = c("v1", "v2")))
  expect_equal(nrow(read_state(tempfile())$datasets), 0)
})

test_that("default_bg_state, normalize_per_tab dhe migrimi i formatit të vjetër", {
  d <- default_bg_state()
  expect_equal(d$active_mode, "image")
  expect_equal(d$modes$color$value, "#0b1c24")

  expect_equal(normalize_per_tab(NULL), setNames(list(), character()))
  expect_equal(normalize_per_tab("x"), setNames(list(), character()))
  expect_equal(normalize_per_tab(list(tab_a = "images/a.jpg")), list(tab_a = "images/a.jpg"))

  old <- list(mode = "color", color = "#111111", scope = "global", blur_on = FALSE, blur = 4,
              global = "images/g.jpg", per_tab = list(tab_a = "images/a.jpg"), version = 7)
  m <- migrate_bg_state_if_needed(old)
  expect_equal(m$active_mode, "color")
  expect_equal(m$modes$color$value, "#111111")
  expect_equal(m$modes$image$active_scope, "global")
  expect_false(m$modes$image$blur$on)
  expect_equal(m$modes$image$blur$amount, 4L)
  expect_equal(m$modes$image$scopes$global$global, "images/g.jpg")
  expect_equal(m$version, 7L)

  expect_equal(migrate_bg_state_if_needed(list(mode = "foo"))$active_mode, "image")
  expect_identical(migrate_bg_state_if_needed(d), d)
})
