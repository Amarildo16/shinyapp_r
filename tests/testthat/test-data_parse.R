test_that("parse_time_safe njeh formatet e kohës (R08)", {
  expect_equal(parse_time_safe(c("2001", "2002")), c(2001, 2002))
  expect_equal(parse_time_safe(c("2021-01", "2021-02")), as.Date(c("2021-01-01", "2021-02-01")))
  expect_equal(parse_time_safe(c("2020Q1", "2020Q4")), as.Date(c("2020-01-01", "2020-10-01")))
  expect_equal(parse_time_safe(c("2021-03-15", "2021-03-16")), as.Date(c("2021-03-15", "2021-03-16")))
  expect_equal(parse_time_safe(c("15/03/2021", "16/03/2021")), as.Date(c("2021-03-15", "2021-03-16")))
  expect_equal(parse_time_safe(c("2021/03/15", "2021/03/16")), as.Date(c("2021-03-15", "2021-03-16")))
  expect_equal(parse_time_safe(c("03/25/2021", "04/26/2021")), as.Date(c("2021-03-25", "2021-04-26")))
  expect_equal(parse_time_safe(as.Date(c("2021-01-01", "2021-02-01"))), as.Date(c("2021-01-01", "2021-02-01")))
})

test_that("parse_time_safe lexon dd-mm-YYYY (B-13)", {
  skip("B-13: sot '15-03-2021' lexohet si 0015-03-20; rregullimi pret vendimin e përdoruesit.")
  expect_equal(parse_time_safe(c("15-03-2021", "16-03-2021")), as.Date(c("2021-03-15", "2021-03-16")))
})

test_that("parse_time_safe: vitet numerike rrumbullakohen, numrat e tjerë mbeten (D-05)", {
  expect_equal(parse_time_safe(c(2000, 2001.0000000001)), c(2000, 2001))
  expect_identical(parse_time_safe(c(1, 2, 3, 4)), c(1, 2, 3, 4))
  expect_identical(parse_time_safe(c(1, 5, 6, 20)), c(1, 5, 6, 20))
  expect_identical(parse_time_safe(c(1L, NA, 3L)), c(1, NA, 3))
  expect_identical(parse_time_safe(c(0.5, 0.75)), c(0.5, 0.75))
})

test_that("parse_time_safe refuzon kolona të pamjaftueshme ose të palexueshme", {
  expect_error(parse_time_safe("2021"), "të paktën 2")
  expect_error(parse_time_safe(c(5, NA)), "të paktën 2")
  # Sot mesazhi vjen nga as.Date() i R-së, jo nga app-i.
  expect_error(parse_time_safe(c("abc", "def")))
})

test_that("to_numeric_safe lexon formatet e numrave (R05)", {
  expect_equal(to_numeric_safe("1.234,5"), 1234.5)
  expect_equal(to_numeric_safe("1,234.5"), 1234.5)
  expect_equal(to_numeric_safe("(12)"), -12)
  expect_equal(to_numeric_safe("12,5"), 12.5)
  expect_equal(to_numeric_safe("-5"), -5)
  expect_equal(to_numeric_safe("  42 "), 42)
  expect_equal(to_numeric_safe("€ 1 000"), 1000)
  expect_equal(to_numeric_safe(c("", "abc")), c(NA_real_, NA_real_))
  expect_equal(to_numeric_safe(c(1L, 2L)), c(1, 2))
  # Sjellja ekzistuese: me disa pika, vetëm e fundit mbetet presje dhjetore.
  expect_equal(to_numeric_safe("1.234.567"), 1234.567)
  # Sjellja ekzistuese (B-14): shkronjat hiqen, kështu që tekst me shifra lexohet si numër.
  expect_equal(to_numeric_safe("shenim 2015"), 2015)
})

test_that("detect_csv_delim dallon , ; dhe tab", {
  expect_equal(detect_csv_delim(fixture("yearly_full.csv")), ",")
  expect_equal(detect_csv_delim(fixture("semicolon_decimal_comma.csv")), ";")

  tsv <- tempfile(fileext = ".csv")
  writeLines(c("Year\tValue", "2000\t1", "2001\t2"), tsv)
  expect_equal(detect_csv_delim(tsv), "\t")
})

test_that("read_data_safe lexon çdo kolonë si tekst dhe refuzon skedarët bosh", {
  d <- read_data_safe(fixture("semicolon_decimal_comma.csv"), "semicolon_decimal_comma.csv")
  expect_equal(names(d), c("Viti", "Shitjet", "Kostot"))
  expect_equal(nrow(d), 5)
  expect_true(all(vapply(d, is.character, logical(1))))
  expect_equal(to_numeric_safe(d$Shitjet)[1], 1234.5)

  expect_error(read_data_safe(fixture("header_only.csv"), "header_only.csv"), "bosh")
  expect_error(read_data_safe(fixture("nuk_ekziston.csv")), "nuk u gjet")
})

test_that("detect_time_candidates vendos kolonën e kohës të parën", {
  d <- read_data_safe(fixture("text_cols.csv"), "text_cols.csv")
  expect_equal(detect_time_candidates(d)$col[1], "Year")

  q <- read_data_safe(fixture("quarterly.csv"), "quarterly.csv")
  expect_equal(detect_time_candidates(q)$col[1], "Period")
})

test_that("detect_numeric_cols përdor pragun 0.70 dhe rezervën (P-02)", {
  d <- read_data_safe(fixture("text_cols.csv"), "text_cols.csv")
  expect_equal(detect_numeric_cols(d, exclude = "Year"), "Value")

  p <- data.frame(
    a = c("1", "2", "3", "x", "4", "5", "6", "7", "8", "9"),
    b = c("1", "2", "3", "x", "y", "z", "4", "5", "6", "7"),
    c = c("1", "2", "3", "x", "y", "z", "w", "4", "5", "6"),
    stringsAsFactors = FALSE
  )
  expect_equal(detect_numeric_cols(p), c("a", "b"))
  expect_equal(detect_numeric_cols(p, threshold = 0.9), "a")

  none <- data.frame(t = c("2000", "2001", "2002"), s = c("a", "b", "c"), stringsAsFactors = FALSE)
  expect_equal(detect_numeric_cols(none, exclude = "t"), "s")
  expect_equal(detect_numeric_cols(none, exclude = "t", fallback_all = FALSE), character(0))
})
