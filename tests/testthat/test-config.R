test_that("%||% kthen rezervën për NULL, bosh, '' dhe NA", {
  expect_equal(NULL %||% "b", "b")
  expect_equal(character(0) %||% "b", "b")
  expect_equal("" %||% "b", "b")
  expect_equal(NA_character_ %||% "b", "b")
  expect_equal("a" %||% "b", "a")
  expect_equal(c("a", "c") %||% "b", c("a", "c"))
  expect_equal(0 %||% 1, 0)
})

test_that("get_app_dir përdor shiny.appdir kur ekziston", {
  expect_equal(get_app_dir(), TEST_SANDBOX)
  expect_equal(DATA_DIR, file.path(TEST_SANDBOX, "data"))
  expect_true(dir.exists(DATA_DIR))
})

test_that("get_app_dir përdor getwd() kur aty ka app.R (T-06)", {
  app_dir <- normalizePath(tempfile("appdir_"), winslash = "/", mustWork = FALSE)
  dir.create(file.path(app_dir, "R"), recursive = TRUE)
  file.create(file.path(app_dir, "app.R"))

  old_opt <- options(shiny.appdir = NULL)
  old_wd  <- setwd(app_dir)
  on.exit({ setwd(old_wd); options(old_opt) }, add = TRUE)

  expect_equal(get_app_dir(), app_dir)
})
