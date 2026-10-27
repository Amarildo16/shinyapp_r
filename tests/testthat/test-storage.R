# init_storage() mbi sandbox-e të përkohshme: asnjëherë mbi të dhënat reale.

make_app_dir <- function() {
  d <- normalizePath(tempfile("storage_app_"), winslash = "/", mustWork = FALSE)
  dir.create(d, recursive = TRUE)
  d
}

make_samples <- function() {
  s <- file.path(make_app_dir(), "samples")
  dir.create(s)
  writeLines(c("Year,A", "2000,1", "2001,2"), file.path(s, "sample_a.csv"))
  writeLines(c("Year,B", "2000,3", "2001,4"), file.path(s, "sample_b.csv"))
  s
}

md5 <- function(files) unname(tools::md5sum(files))

test_that("Q02: storage bosh pa data/ të vjetër merr shembujt një herë", {
  app <- make_app_dir()
  samples <- make_samples()

  info <- init_storage(app, samples)
  ds <- file.path(app, "storage", "datasets")
  expect_true(all(dir.exists(file.path(app, "storage", c("datasets", "images", "state")))))
  expect_equal(sort(list.files(ds)), c("sample_a.csv", "sample_b.csv"))
  expect_equal(md5(file.path(ds, "sample_a.csv")), md5(file.path(samples, "sample_a.csv")))
  expect_true(file.exists(file.path(app, "storage", "state", "storage.json")))
  expect_equal(sort(as.character(info$samples)), c("sample_a.csv", "sample_b.csv"))

  # Pas fshirjes së dataset-eve nga përdoruesi, shembujt nuk rikthehen (Q08).
  unlink(file.path(ds, c("sample_a.csv", "sample_b.csv")))
  init_storage(app, samples)
  expect_length(list.files(ds), 0)
})

test_that("Q03: migrimi kopjon strukturën e vjetër, me kopje rezervë, pa prekur origjinalet", {
  app <- make_app_dir()
  samples <- make_samples()
  legacy <- file.path(app, "data")
  dir.create(legacy)

  writeLines(c("Data,Vlera", "2021-01-01,5", "2021-02-01,6"), file.path(legacy, "imi.csv"))
  st <- default_state()
  st$datasets <- data.frame(file = c("imi.csv", "sample_a.csv"), added_at = c("t1", "t2"),
                            is_active = c(TRUE, FALSE), time_col = c("Data", "Year"),
                            stringsAsFactors = FALSE)
  st$datasets$value_cols <- I(list("Vlera", "A"))
  st$active <- "imi.csv"
  write_state(st, file.path(legacy, "datasets_state.json"))
  writeLines('{"active_mode": "color", "modes": {"color": {"value": "#111111"}}}',
             file.path(legacy, "background_state.json"))

  before_files <- sort(list.files(legacy, recursive = TRUE))
  before_md5   <- md5(file.path(legacy, before_files))

  info <- init_storage(app, samples)
  ds    <- file.path(app, "storage", "datasets")
  state <- file.path(app, "storage", "state")

  # Dataset-i i përdoruesit + shembulli i listuar në state (nga data/samples/); jo shembulli tjetër.
  expect_equal(sort(list.files(ds)), c("imi.csv", "sample_a.csv"))
  expect_equal(md5(file.path(ds, "imi.csv")), md5(file.path(legacy, "imi.csv")))

  # JSON-et: kopje identike te storage/state dhe kopje rezervë.
  for (f in c("datasets_state.json", "background_state.json")) {
    expect_equal(md5(file.path(state, f)), md5(file.path(legacy, f)))
  }
  backup <- file.path(state, info$backup)
  expect_true(dir.exists(backup))
  expect_equal(sort(list.files(backup)), c("background_state.json", "datasets_state.json"))

  # Origjinalet nuk preken.
  expect_equal(sort(list.files(legacy, recursive = TRUE)), before_files)
  expect_equal(md5(file.path(legacy, before_files)), before_md5)

  # Konfigurimi mbetet i vlefshëm: emrat e skedarëve janë të njëjtë.
  migrated <- read_state(file.path(state, "datasets_state.json"))
  expect_equal(get_dataset_config(migrated, "imi.csv"), list(time_col = "Data", value_cols = "Vlera"))
  expect_equal(migrated$active, "imi.csv")

  # Migrimi bëhet një herë: dataset-i i fshirë nga përdoruesi nuk rikthehet.
  unlink(file.path(ds, "imi.csv"))
  init_storage(app, samples)
  expect_false(file.exists(file.path(ds, "imi.csv")))
  expect_true(file.exists(file.path(legacy, "imi.csv")))
})

test_that("migrimi nuk mbishkruan skedarë që ekzistojnë te storage/", {
  app <- make_app_dir()
  samples <- make_samples()
  legacy <- file.path(app, "data")
  dir.create(legacy)
  writeLines('{"active_mode": "none"}', file.path(legacy, "background_state.json"))

  state <- file.path(app, "storage", "state")
  dir.create(state, recursive = TRUE)
  writeLines('{"active_mode": "color"}', file.path(state, "background_state.json"))
  before <- md5(file.path(state, "background_state.json"))

  init_storage(app, samples)
  expect_equal(md5(file.path(state, "background_state.json")), before)
})

test_that("settings.json: gjuha ruhet dhe vlerat e pavlefshme kthehen te shqipja", {
  f <- tempfile(fileext = ".json")
  expect_equal(read_settings(f), list(lang = "sq"))

  write_settings(list(lang = "en"), f)
  expect_equal(read_settings(f)$lang, "en")

  writeLines('{"lang": "de"}', f)
  expect_equal(read_settings(f)$lang, "sq")

  writeLines("jo json", f)
  expect_equal(read_settings(f)$lang, "sq")
})
