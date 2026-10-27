test_that("%||% kthen rezervën për NULL, bosh, '' dhe NA", {
  expect_equal(NULL %||% "b", "b")
  expect_equal(character(0) %||% "b", "b")
  expect_equal("" %||% "b", "b")
  expect_equal(NA_character_ %||% "b", "b")
  expect_equal("a" %||% "b", "a")
  expect_equal(c("a", "c") %||% "b", c("a", "c"))
  expect_equal(0 %||% 1, 0)
})

test_that("get_app_dir përdor shiny.appdir; të dhënat shkojnë te storage/", {
  expect_equal(get_app_dir(), TEST_SANDBOX)
  expect_equal(DATASETS_DIR, file.path(TEST_SANDBOX, "storage", "datasets"))
  expect_equal(STATE_FILE, file.path(TEST_SANDBOX, "storage", "state", "datasets_state.json"))
  expect_equal(BG_STATE_FILE, file.path(TEST_SANDBOX, "storage", "state", "background_state.json"))
  expect_true(dir.exists(DATASETS_DIR))
  expect_equal(CODE_DIR, APP_ROOT)
  expect_true(dir.exists(SAMPLES_DIR))
})

test_that("PAGES: ID-të ekzistuese, tab-et dhe butonat (P-12)", {
  expect_equal(page_ids(), c("settings", "overview", "eda_ts", "eda_rel", "stationary", "modeling", "forecast"))
  expect_equal(page_ids(nav_only = TRUE), c("overview", "eda_ts", "eda_rel", "stationary", "modeling", "forecast"))
  expect_equal(page_tab("stationary"), "tab_stationary")
  expect_equal(page_btn("overview"), "go_overview")
  expect_true(DEFAULT_PAGE %in% page_ids())
})

test_that("kufijtë dhe politikat kanë vlerat e kodit të vjetër", {
  expect_equal(H_CAP, c(day = 90L, week = 26L, month = 24L, quarter = 12L, year = 10L))
  expect_equal(H_CAP_DEFAULT, 120L)
  expect_equal(ROLL_CAP, c(day = 30L, week = 12L, month = 12L, quarter = 8L, year = 5L))
  expect_equal(ROLL_CAP_DEFAULT, 60L)
  expect_equal(c(DUP_POLICY, FREQ_POLICY), c("mean", "auto"))
})

test_that("page_title kthen titullin e faqes ose atë të paracaktuar", {
  expect_equal(page_title("tab_stationary"), "Stacionariteti")
  expect_equal(page_title("tab_nuk_ekziston"), "Time Series Analysis")
  expect_equal(page_title(NULL), "Time Series Analysis")
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
