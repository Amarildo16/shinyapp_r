test_that("fmt_fixed dhe fmt_compact përdorin formatin shqip", {
  expect_equal(fmt_fixed(1234.5, 2), "1 234,50")
  expect_equal(fmt_fixed(c(1, NA), 1), c("1,0", NA))
  expect_equal(fmt_compact(c(12, 1500, 2.5e6, 3e9)), c("12", "1,5 mijë", "2,5 mln", "3 mld"))
  expect_equal(fmt_compact(NA_real_), NA_character_)
})

test_that("fmt_by_series zgjedh shifrat sipas hapësirës së serisë", {
  expect_equal(fmt_by_series(c(1000, 5000)), c("1 mijë", "5 mijë"))
  expect_equal(fmt_by_series(c(0.1, 0.5)), c("0,100", "0,500"))
  expect_equal(fmt_by_series(c(1, 5)), c("1,00", "5,00"))
  expect_equal(fmt_by_series(c(0.1, 0.5), for_axis = FALSE), c("0,1000", "0,5000"))
  expect_equal(fmt_by_series(c(10, 50), for_axis = FALSE), c("10,00", "50,00"))
  expect_equal(fmt_by_series(c(NA, NA)), c(NA_character_, NA_character_))
})

test_that("B-01: vlerat e veçanta në tabela formatohen sipas madhësisë së tyre", {
  # Kodi i vjetër: fmt_by_series(63.5, for_axis = FALSE) -> "63,5000" (gjithmonë 4 decimale).
  expect_equal(
    fmt_table_value(c(63.5, 6.8173091, 0.00295277, 249461.8548, NA, -0.4035413)),
    c("63,50", "6,82", "0,0030", "249 461,85", NA, "-0,4035")
  )
  expect_equal(fmt_table_value(116081.8665), "116 081,87")
})

test_that("etiketat dhe meta-të", {
  expect_equal(make_label("Internet_Pct"), "Internet Pct")
  expect_equal(build_meta(c("a_b", "c"))$a_b, list(label = "a b", unit = ""))
  expect_equal(var_meta("x_y"), list(label = "x y", unit = ""))
  expect_equal(var_meta("v", list(v = list(label = "V", unit = "kg")))$unit, "kg")
  expect_equal(fmt_unit(c(10, 50), "v", list(v = list(label = "V", unit = "kg"))), c("10,00 kg", "50,00 kg"))
  expect_equal(fmt_unit(c(10, 50), "v"), c("10,00", "50,00"))
})

test_that("time_axis_label dhe fmt_time", {
  expect_equal(time_axis_label(as.Date("2021-01-01")), "Data")
  expect_equal(time_axis_label(c(2000, 2001)), "Viti")
  expect_equal(time_axis_label(c(1, 2)), "Koha")
  expect_equal(fmt_time(as.Date("2021-01-05")), "2021-01-05")
  expect_equal(fmt_time(2000), "2000")
})
