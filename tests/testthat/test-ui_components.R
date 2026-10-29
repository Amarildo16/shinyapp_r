# app_head(): CSS dhe JS e ndara në Fazën 7, me radhën e kaskadës, asete vetëm lokale (R03)
# dhe tekstet e FilePond sipas gjuhës (R26, V-23 b, V-24 a).

test_that("app_head ngarkon 6 CSS-të dhe 4 JS-të në radhë, pa custom-style/custom.js", {
  html <- htmltools::renderTags(app_head())$head
  css <- regmatches(html, gregexpr('href="css/[a-z-]+\\.css"', html))[[1]]
  expect_equal(css, sprintf('href="css/%s.css"', APP_CSS))
  expect_equal(APP_CSS, c("tokens", "layout", "components", "modals", "datatables", "background"))
  js <- regmatches(html, gregexpr('src="js/[a-z-]+\\.js"', html))[[1]]
  expect_equal(js, sprintf('src="js/%s.js"', c("bg", "sidebar", "plotly-animate", APP_JS)))
  expect_false(grepl("custom-style|custom\\.js", html))
  for (f in c(paste0("css/", APP_CSS, ".css"), paste0("js/", APP_JS, ".js"))) {
    expect_true(file.exists(file.path(APP_ROOT, "www", f)), info = f)
  }
  # R03: asnjë aset nga interneti.
  expect_false(grepl('(href|src)="(https?:)?//', html))
})

test_that("tekstet e FilePond vijnë nga tr(), në të dyja gjuhët", {
  sq <- as.character(js_i18n())
  expect_match(sq, '"pond.drop":"Lëshoji skedarët këtu ose"', fixed = TRUE)   # V-24 a
  expect_match(sq, '"pond.type_not_allowed":"Ky fajll s\'pranohet"', fixed = TRUE)
  expect_match(sq, '"pond.only_csv":"Lejohet vetëm: .csv"', fixed = TRUE)

  old <- current_lang(); on.exit(set_lang(old))
  set_lang("en")
  en <- as.character(js_i18n())
  expect_match(en, '"pond.type_not_allowed":"This file is not accepted"', fixed = TRUE)
  expect_match(en, '"pond.only_images":"Only allowed: JPG, PNG, WEBP"', fixed = TRUE)
})

test_that("U-08: tekstet e DataTables nga tr(); anglishtja si default-i i DT-së", {
  sq <- dt_language()
  expect_equal(sq$search, "Kërko:")
  expect_equal(sq$paginate$`next`, "E radhës")
  expect_match(sq$info, "_START_.*_END_.*_TOTAL_")

  old <- current_lang(); on.exit(set_lang(old))
  set_lang("en")
  en <- dt_language()
  expect_equal(en[c("lengthMenu", "search", "info", "zeroRecords")],
               list(lengthMenu = "Show _MENU_ entries", search = "Search:",
                    info = "Showing _START_ to _END_ of _TOTAL_ entries", zeroRecords = "No matching records found"))
  expect_equal(unlist(en$paginate), c(first = "First", last = "Last", `next` = "Next", previous = "Previous"))
})

test_that("CSS-ja e ndarë: kllapat të balancuara dhe asnjë URL e jashtme", {
  for (f in APP_CSS) {
    s <- paste(readLines(file.path(APP_ROOT, "www", "css", paste0(f, ".css")), warn = FALSE), collapse = "\n")
    s <- gsub("/\\*.*?\\*/", "", s, perl = TRUE)
    expect_equal(lengths(regmatches(s, gregexpr("\\{", s))), lengths(regmatches(s, gregexpr("\\}", s))), info = f)
    expect_false(grepl("\\{,|url\\((['\"])?https?:", s), info = f)
  }
})

test_that("V-26: glass_modal() merr madhësinë si klasë, header-i titull + X", {
  for (sz in GLASS_MODAL_SIZES) {
    h <- as.character(glass_modal("m", "m_title", "m_body", NULL, size = sz))
    expect_match(h, sprintf('class="modal fade glass-modal glass-modal-%s"', sz), fixed = TRUE, info = sz)
    expect_match(h, '<div class="modal-dialog">', fixed = TRUE, info = sz)
  }
  expect_error(glass_modal("m", "t", "b", NULL, size = "xxl"))
  h <- as.character(glass_modal("m", "m_title", "m_body", NULL))
  expect_match(h, "glass-modal-sm", fixed = TRUE)   # e paracaktuara: e para e listës
  # Titulli para X-it, brenda header-it (U-09).
  expect_match(h, 'class="modal-header">\\s*<div class="shiny-html-output glass-modal-title" id="m_title"></div>\\s*<button[^>]*class="close"')
  # U-10 (V-27): teksti i X-it për lexuesin e ekranit, sipas gjuhës.
  expect_match(h, 'aria-label="Mbyll"', fixed = TRUE)
  old <- current_lang(); on.exit(set_lang(old))
  set_lang("en")
  expect_match(as.character(glass_modal("m", "t", "b", NULL)), 'aria-label="Close"', fixed = TRUE)
})

test_that("V-26: madhësitë e modaleve të moduleve", {
  ds <- as.character(mod_datasets_modals_ui("datasets"))
  bg <- as.character(mod_background_modals_ui("bg"))
  size_of <- function(h, id) regmatches(h, regexpr(sprintf('glass-modal-[a-z]+(?=" id="%s")', id), h, perl = TRUE))
  expect_equal(size_of(ds, "datasets-main_modal_sm"), "glass-modal-lg")
  expect_equal(size_of(ds, "datasets-main_modal_fs"), "glass-modal-fs")
  expect_equal(size_of(ds, "datasets-delete_modal"), "glass-modal-sm")
  expect_equal(size_of(bg, "bg-modal_fs"), "glass-modal-fs")
  expect_equal(size_of(bg, "bg-delete_modal"), "glass-modal-sm")
  expect_false(grepl("[ \"]modal-lg", paste(ds, bg)))
})

test_that("V-26: modals.css sipas klasës, pa madhësi sipas ID-së dhe pa vijat e vjetra", {
  s <- paste(readLines(file.path(APP_ROOT, "www", "css", "modals.css"), warn = FALSE), collapse = "\n")
  s <- gsub("/\\*.*?\\*/", "", s, perl = TRUE)
  for (sz in GLASS_MODAL_SIZES) expect_match(s, sprintf(".glass-modal-%s", sz), fixed = TRUE, info = sz)
  # ID-të e modaleve mbeten vetëm te rregullat e FilePond-it.
  ids <- regmatches(s, gregexpr("#(datasets|bg)-[a-z_]*modal[a-z_]*[^{]*\\{", s))[[1]]
  expect_true(all(grepl("pond", ids)))
  expect_false(grepl("#csv_upload_modal", s, fixed = TRUE))
  expect_match(s, "\\.glass-modal \\.modal-header \\{[^}]*border-bottom: 0;")
  expect_match(s, "\\.glass-modal \\.modal-footer \\{[^}]*border-top: 0;")
})

test_that("V-28: kufiri i ngarkimit dhe tekstet e FilePond-it për madhësinë", {
  expect_equal(UPLOAD_MAX_MB, 150)
  sq <- as.character(js_i18n())
  expect_match(sq, 'window.APP_CONFIG = {"uploadMaxMB":150};', fixed = TRUE)
  expect_match(sq, '"pond.too_large":"Skedari është shumë i madh"', fixed = TRUE)
  expect_match(sq, '"pond.max_size":"Maksimumi: {filesize}"', fixed = TRUE)
  old <- current_lang(); on.exit(set_lang(old))
  set_lang("en")
  en <- as.character(js_i18n())
  expect_match(en, '"pond.too_large":"File is too large"', fixed = TRUE)
  expect_match(en, '"pond.upload_failed":"Upload failed"', fixed = TRUE)
  # B-25: proxy-t i shtohet tipi që pret FilePond-i, përveç `accept`-it të fileInput-it.
  js <- paste(readLines(file.path(APP_ROOT, "www", "js", "filepond-bridge.js"), warn = FALSE), collapse = "\n")
  expect_match(js, "concat(cfg.acceptedFileTypes)", fixed = TRUE)
  expect_match(js, "fi.status !== S.LOAD_ERROR", fixed = TRUE)
  expect_false(grepl('pond.on("updatefiles"', js, fixed = TRUE))
})
