# Q32 (pjesërisht, Faza 3): përkthimet janë të plota dhe formati ndjek gjuhën.

test_that("sq.json dhe en.json kanë të njëjtët çelësa dhe asnjë vlerë bosh", {
  all <- load_translations()
  expect_setequal(names(all$sq), names(all$en))
  expect_gt(length(all$sq), 0)
  for (lang in names(LANGS)) {
    vals <- unlist(all[[lang]])
    expect_true(all(nzchar(trimws(vals))), info = lang)
  }
})

test_that("çdo çelës i përdorur në kod ekziston te përkthimet", {
  files <- c(file.path(APP_ROOT, "app.R"), list.files(file.path(APP_ROOT, "R"), "[.]R$", full.names = TRUE))
  code  <- unlist(lapply(files, readLines, encoding = "UTF-8", warn = FALSE))
  # tr("çelësi") dhe tr("çelësi", param = ...), jashtë komenteve
  code  <- code[!grepl("^\\s*#", code)]
  used  <-unique(unlist(regmatches(code, gregexpr('\\btr\\("[^"]+"[,)]', code, perl = TRUE))))
  used  <- sub('^tr\\("([^"]+)"[,)]$', "\\1", used)
  pages <- c(paste0("page.", page_ids(), ".menu"), paste0("page.", page_ids(), ".title"))

  keys <- names(load_translations()$sq)
  expect_true(length(used) > 0)
  expect_equal(setdiff(c(used, pages), keys), character(0))
})

test_that("tr() zëvendëson parametrat dhe kthen çelësin kur mungon", {
  old <- .i18n$all
  on.exit(.i18n$all <- old, add = TRUE)
  .i18n$all <- list(sq = list(greet = "Përshëndetje {emri}, {n} seri"), en = list(greet = "Hello {emri}"))

  expect_equal(tr("greet", emri = "Ana", n = 3), "Përshëndetje Ana, 3 seri")
  expect_equal(tr("greet", emri = "Ana", lang = "en"), "Hello Ana")
  expect_equal(tr("mungon.krejt"), "mungon.krejt")
})

test_that("set_lang/current_lang pranojnë vetëm sq dhe en", {
  on.exit(set_lang("sq"), add = TRUE)
  expect_equal(current_lang(), "sq")
  set_lang("en"); expect_equal(current_lang(), "en")
  set_lang("de"); expect_equal(current_lang(), "sq")
  expect_equal(tr("page.stationary.menu", lang = "en"), "Stationarity")
})

test_that("formati i numrave ndjek gjuhën; vlerat nuk ndryshojnë (V-09)", {
  on.exit(set_lang("sq"), add = TRUE)

  set_lang("sq")
  expect_equal(fmt_fixed(1234.5, 2), "1 234,50")
  expect_equal(fmt_compact(c(12, 1500, 2.5e6, 3e9)), c("12", "1,5 mijë", "2,5 mln", "3 mld"))
  expect_equal(fmt_table_value(c(63.5, 0.00295)), c("63,50", "0,0030"))

  set_lang("en")
  expect_equal(fmt_fixed(1234.5, 2), "1,234.50")
  expect_equal(fmt_compact(c(12, 1500, 2.5e6, 3e9)), c("12", "1.5K", "2.5M", "3B"))
  expect_equal(fmt_table_value(c(63.5, 0.00295)), c("63.50", "0.0030"))
  expect_equal(fmt_by_series(c(1, 5)), c("1.00", "5.00"))
})
