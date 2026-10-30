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

test_that("V-30: preview-ja e fotove nga shtojca lokale dhe shkronjat e FilePond-it", {
  html <- htmltools::renderTags(app_head())$head
  for (f in c("filepond-plugin-image-preview.min.css", "filepond-plugin-image-preview.min.js")) {
    expect_match(html, paste0("vendor/filepond/", f), fixed = TRUE, info = f)
    expect_true(file.exists(file.path(APP_ROOT, "www", "vendor", "filepond", f)), info = f)
  }
  js <- paste(readLines(file.path(APP_ROOT, "www", "js", "filepond-bridge.js"), warn = FALSE), collapse = "\n")
  expect_match(js, "allowImagePreview: true", fixed = TRUE)
  css <- paste(readLines(file.path(APP_ROOT, "www", "css", "background.css"), warn = FALSE), collapse = "\n")
  # Bootstrap 3 e ka html në 10 px: pa këtë rregull, emri i skedarit del rreth 7,5 px.
  expect_match(css, "\\.bg-pond-host \\.filepond--root \\{[^}]*font-size: 16px;")
})

test_that("V-31, V-32: pa ngjyra; unaza me X gjatë ngarkimit; riprovimi kur dështon", {
  css <- paste(readLines(file.path(APP_ROOT, "www", "css", "background.css"), warn = FALSE), collapse = "\n")
  expect_match(css, "overlay-success,\\s*\\.bg-pond-host \\.filepond--image-preview-overlay-failure \\{\\s*color: rgba\\(40, 40, 40, \\.85\\);")
  expect_false(grepl("rgba(52, 199, 89", css, fixed = TRUE))
  expect_false(grepl("rgba(255, 69, 58", css, fixed = TRUE))
  # Vetëm unaza jonë: treguesit e FilePond-it dhe X-i i ndalimit në qoshe fshihen.
  expect_match(css, "\\.bg-pond-host \\.filepond--progress-indicator,\\s*\\.bg-pond-host \\.filepond--action-abort-item-processing,")
  expect_match(css, "conic-gradient", fixed = TRUE)
  expect_match(css, "filepond--action-retry-item-processing\\[data-align\\] \\{[^}]*left: calc\\(50% - 30px\\);")
  js <- paste(readLines(file.path(APP_ROOT, "www", "js", "filepond-bridge.js"), warn = FALSE), collapse = "\n")
  expect_match(js, 'styleButtonRemoveItemPosition: "right"', fixed = TRUE)
  expect_match(js, 'pond.on("processfileabort", (item) => { dropOverlay(item); pond.removeFile(item.id); });', fixed = TRUE)
  expect_false(grepl("pond-cancel", paste(js, css), fixed = TRUE))
})

test_that("V-28: kufiri i ngarkimit dhe tekstet e FilePond-it për madhësinë", {
  expect_equal(UPLOAD_MAX_MB, 150)
  sq <- as.character(js_i18n())
  expect_match(sq, '"pond.too_large":"Skedari është shumë i madh"', fixed = TRUE)
  expect_match(sq, '"pond.max_size":"Maksimumi: {filesize}"', fixed = TRUE)
  old <- current_lang(); on.exit(set_lang(old))
  set_lang("en")
  en <- as.character(js_i18n())
  expect_match(en, '"pond.too_large":"File is too large"', fixed = TRUE)
  # B-25: `accept` i input-it përmban tipin që pret FilePond-i.
  js <- paste(readLines(file.path(APP_ROOT, "www", "js", "filepond-bridge.js"), warn = FALSE), collapse = "\n")
  expect_match(js, 'accept: ".csv,text/csv"', fixed = TRUE)
  expect_match(js, 'acceptedFileTypes: ["text/csv"]', fixed = TRUE)
})

test_that("V-33: pamja e vogël: titulli, 5 × 8, madhësia dhe vlerat e sigurta", {
  expect_equal(csv_title("albania_agriculture_timeseries_1998_2024.csv"), "Albania Agriculture Timeseries 1998 2024")
  expect_equal(csv_title("çmimet-e_tregut.2024.csv"), "Çmimet E Tregut 2024")

  head <- as.data.frame(matrix("v", 5, 8), stringsAsFactors = FALSE)
  head[1, 1] <- "<b>x</b>"
  head[2, 2] <- NA
  g <- list(title = "T", rows = 2000000, cols = 12L, size = 120.6 * 1024^2, head = head)
  html <- as.character(csv_glance_ui(g, "x-hiq"))
  expect_match(html, 'id="x-hiq"', fixed = TRUE)                                # V-34: X-i te pamja
  expect_match(html, "2 000 000 rreshta × 12 kolona · 120,6 MB", fixed = TRUE)
  expect_match(html, "&lt;b&gt;x&lt;/b&gt;", fixed = TRUE)
  expect_false(grepl(">NA<", html, fixed = TRUE))
  expect_equal(lengths(regmatches(html, gregexpr("<tr>", html, fixed = TRUE))), 6L)
  expect_equal(lengths(regmatches(html, gregexpr("<th>", html, fixed = TRUE))), 9L)   # numri + 8 kolona

  g$rows <- 1; g$cols <- 1L; g$size <- 2048
  expect_match(as.character(csv_glance_ui(g, "x-hiq")), "1 rresht × 1 kolonë · 2,0 KB", fixed = TRUE)
  css <- paste(readLines(file.path(APP_ROOT, "www", "css", "modals.css"), warn = FALSE), collapse = "\n")
  expect_match(css, "\\.csv-pond-host \\.filepond--root \\{[^}]*font-size: 16px;")
  expect_false(grepl("(^|\\n)\\.filepond--panel-root", css, perl = TRUE))        # kutia e dytë (U-13)
  for (f in c("excel.svg", "csv-file.svg")) {
    svg <- paste(readLines(file.path(APP_ROOT, "www", "icons", f), warn = FALSE), collapse = "")
    hex <- substring(unique(regmatches(svg, gregexpr("#[0-9a-fA-F]{3,6}", svg))[[1]]), 2)
    hex <- ifelse(nchar(hex) == 3, gsub("(.)", "\\1\\1", hex), hex)
    expect_true(all(substr(hex, 1, 2) == substr(hex, 3, 4) & substr(hex, 3, 4) == substr(hex, 5, 6)), info = f)   # V-34: pa ngjyra
  }
})
