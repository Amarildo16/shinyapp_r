# Kufijtë e slider-ave (R16): hapi i kohës, horizonti dhe dritarja lëvizëse.

test_that("time_step dhe time_step_unit sipas frekuencës", {
  expect_equal(time_step(2000:2010), "year")
  expect_equal(time_step(seq(as.Date("2021-01-01"), by = "month", length.out = 12)), "month")
  expect_equal(time_step(seq(as.Date("2021-01-01"), by = "quarter", length.out = 8)), "quarter")
  expect_equal(time_step(1:10), "period")
  expect_equal(time_step(2000), "period")

  expect_equal(time_step_unit(2000:2010), "vite")
  expect_equal(time_step_unit(seq(as.Date("2021-01-01"), by = "month", length.out = 12)), "muaj")
  expect_equal(time_step_unit(1:10), "periudha")

  on.exit(set_lang("sq"), add = TRUE)
  set_lang("en")
  expect_equal(time_step_unit(2000:2010), "years")
  expect_equal(time_axis_label(c(2000, 2001)), "Year")
})

test_that("h_bounds: n − 1 deri te kufiri H_CAP; min 2 kur max ≤ 8", {
  years <- 2000:2026
  expect_equal(h_bounds(27, years), list(min = 1L, max = 10L, step = "year"))
  expect_equal(h_bounds(6, years), list(min = 2L, max = 5L, step = "year"))
  expect_equal(h_bounds(2, years), list(min = 1L, max = 1L, step = "year"))
  expect_equal(h_bounds(1, years)$max, 1L)

  months <- seq(as.Date("2021-01-01"), by = "month", length.out = 57)
  expect_equal(h_bounds(57, months)$max, 24L)
  expect_equal(h_bounds(500, 1:500)$max, H_CAP_DEFAULT)
})

test_that("roll_bounds: [3, min(n − 1, ROLL_CAP, n/2)]", {
  years <- 2000:2026
  expect_equal(roll_bounds(27, years), list(min = 3L, max = 5L))
  months <- seq(as.Date("2021-01-01"), by = "month", length.out = 57)
  expect_equal(roll_bounds(57, months), list(min = 3L, max = 12L))
  expect_equal(roll_bounds(4, years), list(min = 3L, max = 3L))
})
