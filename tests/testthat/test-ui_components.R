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

test_that("CSS-ja e ndarë: kllapat të balancuara dhe asnjë URL e jashtme", {
  for (f in APP_CSS) {
    s <- paste(readLines(file.path(APP_ROOT, "www", "css", paste0(f, ".css")), warn = FALSE), collapse = "\n")
    s <- gsub("/\\*.*?\\*/", "", s, perl = TRUE)
    expect_equal(lengths(regmatches(s, gregexpr("\\{", s))), lengths(regmatches(s, gregexpr("\\}", s))), info = f)
    expect_false(grepl("\\{,|url\\((['\"])?https?:", s), info = f)
  }
})
