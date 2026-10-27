# mod_datasets_server() me shiny::testServer, mbi një storage të përkohshëm (Q04–Q08).
# DATASETS_DIR dhe STATE_FILE drejtohen te sandbox-i vetëm gjatë testit.

samples_dir <- file.path(APP_ROOT, "data", "samples")
AGRI <- "albania_agriculture_timeseries_1998_2024.csv"
DIGI <- "Digjitalizimi_Financiar_Shqiperi_data.csv"

local_ds_storage <- function(files = c(AGRI, DIGI), env = parent.frame()) {
  root <- normalizePath(tempfile("ds_mod_"), winslash = "/", mustWork = FALSE)
  dir.create(file.path(root, "datasets"), recursive = TRUE)
  dir.create(file.path(root, "state"))
  file.copy(file.path(samples_dir, files), file.path(root, "datasets"))

  e   <- environment(mod_datasets_server)
  old <- mget(c("DATASETS_DIR", "STATE_FILE"), envir = e)
  assign("DATASETS_DIR", file.path(root, "datasets"), envir = e)
  assign("STATE_FILE", file.path(root, "state", "datasets_state.json"), envir = e)
  withr::defer({
    for (n in names(old)) assign(n, old[[n]], envir = e)
  }, envir = env)
  root
}

# Kopje e një fixture-i jashtë storage-it, si skedari i përkohshëm i fileInput-it.
upload_value <- function(fixture_name, name = fixture_name) {
  tmp <- tempfile(fileext = paste0(".", tools::file_ext(fixture_name)))
  file.copy(fixture(fixture_name), tmp)
  list(name = name, size = file.size(tmp), type = "text/csv", datapath = tmp)
}

md5 <- function(f) unname(tools::md5sum(f))

test_that("nisja: active() = dataset-i aktiv i state-it me konfigurimin e ruajtur (P-06)", {
  root <- local_ds_storage()
  st <- sync_state(list_saved_datasets())
  st <- update_dataset_config(st, DIGI, "Data", c("Internet_Pct", "Blerje_Online_Karte"))
  st$active <- DIGI
  write_state(st)

  testServer(mod_datasets_server, {
    session$flushReact()
    a <- session$getReturned()()
    expect_equal(a$file, DIGI)
    expect_equal(a$time_col, "Data")
    expect_equal(a$value_cols, c("Internet_Pct", "Blerje_Online_Karte"))
    expect_true(is.data.frame(a$data))
  })
})

test_that("nisja pa konfigurim: default-et e resolve_dataset_defaults()", {
  root <- local_ds_storage(AGRI)
  testServer(mod_datasets_server, {
    session$flushReact()
    a <- session$getReturned()()
    expect_equal(a$file, AGRI)
    def <- resolve_dataset_defaults(read_data_safe(file.path(root, "datasets", AGRI), AGRI))
    expect_equal(a$time_col, def$time_col)
    expect_equal(a$value_cols, def$value_cols)
  })
})

test_that("Q04: aktivizimi ndryshon active() dhe ruhet te state-i", {
  root <- local_ds_storage()
  testServer(mod_datasets_server, {
    session$flushReact()
    active <- session$getReturned()
    first <- active()$file
    other <- setdiff(c(AGRI, DIGI), first)

    session$setInputs(activate_dataset = other)
    expect_equal(active()$file, other)
    expect_equal(read_state()$active, other)

    session$setInputs(activate_dataset = "../../app.R")
    expect_equal(active()$file, other)
  })
})

test_that("Q05: Edit → Save ruan kolonën e kohës dhe seritë; edhe pas rinisjes", {
  root <- local_ds_storage()
  testServer(mod_datasets_server, {
    session$flushReact()
    active <- session$getReturned()
    session$setInputs(edit_dataset = DIGI)
    expect_equal(editing_file(), DIGI)
    session$setInputs(modal_time_col = "Data", modal_value_cols = "Transaksionet_Online")
    session$setInputs(btn_save_config = 1)

    expect_equal(active()$file, DIGI)
    expect_equal(active()$value_cols, "Transaksionet_Online")
    expect_null(pending_data())
  })

  cfg <- get_dataset_config(read_state(), DIGI)
  expect_equal(cfg$value_cols, "Transaksionet_Online")

  testServer(mod_datasets_server, {
    session$flushReact()
    expect_equal(session$getReturned()()$value_cols, "Transaksionet_Online")
  })
})

test_that("B-03: Upload dhe Edit ofrojnë vetëm kolonat numerike", {
  root <- local_ds_storage(AGRI)
  testServer(mod_datasets_server, {
    session$flushReact()
    session$setInputs(csv_file_modal = upload_value("text_cols.csv"))
    session$setInputs(btn_proceed_upload = 1)
    html <- as.character(output$modal_fs_body$html)
    series_select <- regmatches(html, regexpr("modal_value_cols\"[^>]*>.*?</select>", html))
    expect_length(series_select, 1)
    expect_match(series_select, "Value")
    expect_false(grepl("Region|Notes", series_select))
  })
})

test_that("Q06: Upload kopjon CSV-në; emri ekzistues merr timestamp, asgjë nuk mbishkruhet", {
  root <- local_ds_storage(AGRI)
  ds_dir <- file.path(root, "datasets")
  testServer(mod_datasets_server, {
    session$flushReact()
    active <- session$getReturned()

    up <- upload_value("semicolon_decimal_comma.csv")
    session$setInputs(csv_file_modal = up)
    session$setInputs(btn_proceed_upload = 1)
    session$setInputs(modal_time_col = "Viti", modal_value_cols = c("Shitjet", "Kostot"))
    session$setInputs(btn_save_config = 1)

    expect_equal(active()$file, "semicolon_decimal_comma.csv")
    saved <- file.path(ds_dir, "semicolon_decimal_comma.csv")
    expect_equal(md5(saved), md5(up$datapath))
    expect_equal(prepare_series(active())$data$Shitjet[1], 1234.5)

    up2 <- upload_value("text_cols.csv", name = "semicolon_decimal_comma.csv")
    session$setInputs(csv_file_modal = up2)
    session$setInputs(btn_proceed_upload = 2)
    session$setInputs(modal_time_col = "Year", modal_value_cols = "Value")
    session$setInputs(btn_save_config = 2)

    expect_equal(md5(saved), md5(up$datapath))
    expect_match(active()$file, "^semicolon_decimal_comma_[0-9]{8}_[0-9]{6}[.]csv$")
    expect_length(list.files(ds_dir), 3)
  })
})

test_that("Q07: Upload i pavlefshëm nuk ruan asgjë", {
  root <- local_ds_storage(AGRI)
  ds_dir <- file.path(root, "datasets")
  testServer(mod_datasets_server, {
    session$flushReact()
    session$setInputs(csv_file_modal = upload_value("text_cols.csv", name = "shenime.txt"))
    expect_null(pending_data())

    session$setInputs(csv_file_modal = upload_value("header_only.csv"))
    session$setInputs(btn_proceed_upload = 1)
    session$setInputs(btn_save_config = 1)

    expect_equal(list.files(ds_dir), AGRI)
    expect_equal(session$getReturned()()$file, AGRI)
  })
})

test_that("Q08: fshirja e aktivit kalon te tjetri; pa dataset → active() NULL", {
  root <- local_ds_storage()
  ds_dir <- file.path(root, "datasets")
  testServer(mod_datasets_server, {
    session$flushReact()
    active <- session$getReturned()
    first <- active()$file
    other <- setdiff(c(AGRI, DIGI), first)

    session$setInputs(delete_dataset = first)
    expect_true(file.exists(file.path(ds_dir, first)))   # pa konfirmim nuk fshihet
    session$setInputs(confirm_delete_saved = 1)
    expect_false(file.exists(file.path(ds_dir, first)))
    expect_equal(active()$file, other)
    expect_equal(read_state()$active, other)

    session$setInputs(delete_dataset = other)
    session$setInputs(confirm_delete_saved = 2)
    expect_length(list.files(ds_dir), 0)
    expect_null(active())
  })
})
