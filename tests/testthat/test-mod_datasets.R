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

# Një kërkesë e FilePond-it te pritja, pastaj njoftimi që skedari ka mbërritur (V-33).
pond_upload <- function(session, stage, fixture_name, name = fixture_name) {
  x <- readBin(fixture(fixture_name), "raw", file.size(fixture(fixture_name)))
  done <- FALSE
  r <- csv_stage_add(stage, function() { if (done) return(raw()); done <<- TRUE; x }, name)
  if (isTRUE(r$ok)) session$setInputs(csv_uploaded = r$id)
  r
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
    pond_upload(session, csv_stage, "text_cols.csv")
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

    pond_upload(session, csv_stage, "semicolon_decimal_comma.csv")
    session$setInputs(btn_proceed_upload = 1)
    session$setInputs(modal_time_col = "Viti", modal_value_cols = c("Shitjet", "Kostot"))
    session$setInputs(btn_save_config = 1)

    expect_equal(active()$file, "semicolon_decimal_comma.csv")
    saved <- file.path(ds_dir, "semicolon_decimal_comma.csv")
    expect_equal(md5(saved), md5(fixture("semicolon_decimal_comma.csv")))
    expect_equal(prepare_series(active())$data$Shitjet[1], 1234.5)

    pond_upload(session, csv_stage, "text_cols.csv", name = "semicolon_decimal_comma.csv")
    session$setInputs(btn_proceed_upload = 2)
    session$setInputs(modal_time_col = "Year", modal_value_cols = "Value")
    session$setInputs(btn_save_config = 2)

    expect_equal(md5(saved), md5(fixture("semicolon_decimal_comma.csv")))
    expect_match(active()$file, "^semicolon_decimal_comma_[0-9]{8}_[0-9]{6}[.]csv$")
    expect_length(list.files(ds_dir), 3)
  })
})

test_that("Q07: Upload i pavlefshëm nuk ruan asgjë", {
  root <- local_ds_storage(AGRI)
  ds_dir <- file.path(root, "datasets")
  testServer(mod_datasets_server, {
    session$flushReact()
    expect_equal(pond_upload(session, csv_stage, "text_cols.csv", name = "shenime.txt")$msg, tr("ds.only_csv"))
    expect_null(pending_data())

    pond_upload(session, csv_stage, "header_only.csv")
    expect_null(glance())
    expect_null(uploaded_tmp_path())
    session$setInputs(btn_proceed_upload = 1)
    session$setInputs(btn_save_config = 1)

    expect_equal(list.files(ds_dir), AGRI)
    expect_equal(session$getReturned()()$file, AGRI)
  })
})

test_that("V-33: numri i rreshtave dhe fillimi janë si te leximi i plotë", {
  csvs <- setdiff(list.files(dirname(fixture("text_cols.csv")), pattern = "[.]csv$"), "header_only.csv")
  expect_gt(length(csvs), 5)
  for (f in csvs) {
    p <- fixture(f)
    full <- read_data_safe(p, f)
    expect_equal(count_csv_rows(p), nrow(full), info = f)
    n <- min(PREVIEW_ROWS, nrow(full))
    expect_equal(read_data_safe(p, f, n_max = PREVIEW_ROWS), full[seq_len(n), , drop = FALSE], info = f)
    g <- csv_glance(p, f)
    expect_lte(nrow(g$head), PREVIEW_ROWS)
    expect_lte(ncol(g$head), PREVIEW_COLS)
    expect_equal(g$cols, ncol(full), info = f)
  }
  expect_error(csv_glance(fixture("header_only.csv"), "header_only.csv"), tr("err.ds_empty"), fixed = TRUE)
})

test_that("V-33: pritja e CSV-së: vetëm .csv, kufiri, heqja dhe filtri i FilePond-it", {
  stg <- stage_new(tempfile("stg_"))
  x <- charToRaw("Year;Value\n2000;1\n2001;2\n")
  reader <- function() { done <- FALSE; function() { if (done) return(raw()); done <<- TRUE; x } }

  r <- csv_stage_add(stg, reader(), "ime.CSV")
  expect_true(r$ok)
  expect_equal(stg$files[[r$id]]$name, "ime.CSV")
  expect_equal(file.size(stg$files[[r$id]]$path), length(x))
  expect_equal(csv_stage_add(stg, reader(), "a.txt")$msg, tr("ds.only_csv"))
  expect_equal(csv_stage_add(stg, reader(), "e_madhe.csv", max_bytes = 5)$msg, tr("pond.too_large"))
  expect_length(list.files(stg$dir), 1)

  h <- pond_handler(stg, function(read_chunk, name, mime) csv_stage_add(stg, read_chunk, name))
  done <- FALSE
  req <- list(REQUEST_METHOD = "POST", HTTP_X_POND_OP = "process", HTTP_X_FILE_NAME = "e%20dyta.csv",
              rook.input = list(read = function(n = -1L) { if (done) return(raw()); done <<- TRUE; x }))
  ok <- h(NULL, req)
  expect_equal(ok$headers$`X-Pond-Status`, "ok")
  expect_equal(stg$files[[ok$content]]$name, "e dyta.csv")
  expect_true(stage_remove(stg, ok$content))
  stage_discard(stg)
  expect_length(list.files(stg$dir), 0)
})

test_that("V-33: pamja e vogël del pas ngarkimit, leximi i plotë te Vazhdo", {
  root <- local_ds_storage(AGRI)
  ds_dir <- file.path(root, "datasets")
  testServer(mod_datasets_server, {
    session$flushReact()
    pond_upload(session, csv_stage, "text_cols.csv")
    expect_equal(glance()$title, "Text Cols")
    expect_true(glance()$rows > 0)
    expect_match(as.character(output$csv_glance$html), "csv-glance-table", fixed = TRUE)
    expect_null(pending_data())                       # vetëm fillimi, jo gjithë skedari
    expect_equal(list.files(ds_dir), AGRI)            # asgjë te storage para "Ruaj"

    session$setInputs(btn_proceed_upload = 1)
    expect_equal(nrow(pending_data()), glance()$rows)
    d <- pending_data()
    session$setInputs(btn_cancel_config = 1)          # kthimi: skedari mbetet, pa lexim të dytë
    session$setInputs(btn_proceed_upload = 2)
    expect_identical(pending_data(), d)

    expect_match(as.character(output$csv_glance$html), "csv_glance_remove", fixed = TRUE)
    session$setInputs(csv_glance_remove = 1)          # X-i te pamja (V-34)
    expect_null(glance())
    expect_null(pending_data())
    expect_length(csv_stage$files, 0)
    session$setInputs(btn_proceed_upload = 3)
    expect_null(pending_data())

    pond_upload(session, csv_stage, "text_cols.csv")
    expect_length(csv_stage$files, 1)
    session$setInputs(btn_cancel_upload = 1)
    expect_length(csv_stage$files, 0)
    expect_null(glance())
    expect_equal(list.files(ds_dir), AGRI)

    pond_upload(session, csv_stage, "text_cols.csv")
    session$setInputs(btn_open_upload = 1)            # modali u mbyll me X, pastaj u rihap
    expect_length(csv_stage$files, 0)
    expect_null(glance())
    expect_match(as.character(output$modal_sm_body$html), 'data-pond-mode="csv"', fixed = TRUE)
    expect_false(grepl("csv_file_modal", as.character(output$modal_sm_body$html), fixed = TRUE))
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
