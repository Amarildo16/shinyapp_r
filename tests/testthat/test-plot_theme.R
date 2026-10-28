# Ndihmësit e ggplotly; zhduken me plot_ly në Fazën 5 (V-08).

test_that("find_traces, set_trace_text dhe skip_trace_hover", {
  pl <- list(x = list(data = list(
    list(type = "scatter", mode = "lines"),
    list(type = "bar"),
    list(type = "scatter", mode = "lines+markers")
  )))

  lines <- find_traces(pl, function(tr) grepl("lines", tr$mode %||% ""))
  expect_equal(lines, c(1L, 3L))

  pl2 <- set_trace_text(pl, 1, c("a", "b"))
  expect_equal(pl2$x$data[[1]]$text, c("a", "b"))
  expect_equal(pl2$x$data[[1]]$hoverinfo, "text")
  expect_identical(set_trace_text(pl, integer(0), "x"), pl)
  expect_identical(set_trace_text(pl, NA, "x"), pl)

  pl3 <- skip_trace_hover(pl, c(2, 3))
  expect_equal(pl3$x$data[[2]]$hoverinfo, "skip")
  expect_null(pl3$x$data[[1]]$hoverinfo)
})

test_that("glass_sizes = madhësitë që ggplotly nxirrte nga theme_minimal()", {
  expect_equal(unlist(glass_sizes(11)), c(text = 14.6119, title = 17.5342, tick = 11.6895,
                                          ticklen = 3.653, margin = 7.3059), tolerance = 1e-4)
  expect_equal(glass_sizes(13)$text, 17.2686, tolerance = 1e-4)
  expect_equal(glass_sizes(13)$title, 20.7223, tolerance = 1e-4)
})

test_that("gg_ticks = boshtet e ggplot2: kufijtë, thyerjet dhe etiketat", {
  skip_if_not_installed("ggplot2")
  check <- function(x, labels = NULL) {
    p <- ggplot2::ggplot(data.frame(x = x, y = seq_along(x)), ggplot2::aes(x, y)) + ggplot2::geom_point()
    if (!is.null(labels)) p <- p + ggplot2::scale_x_continuous(labels = labels)
    pp <- suppressWarnings(ggplot2::ggplot_build(p))$layout$panel_params[[1]]$x
    br <- pp$breaks
    t <- gg_ticks(x, labels, date = inherits(x, "Date"))
    expect_equal(t$range, pp$continuous_range)
    expect_equal(t$tickvals, as.numeric(br[!is.na(br)]))
    expect_equal(t$ticktext, unname(pp$get_labels()[!is.na(br)]))
  }
  fmt <- function(x) fmt_by_series(x, for_axis = TRUE)
  check(1998:2024)
  check(c(5832128, 10166038, NA, 7e6), fmt)
  check(c(0.12, 0.13, 0.19), fmt)
  check(rep(5, 10), fmt)
  check(seq(as.Date("2021-01-01"), by = "month", length.out = 57))
  check(seq(as.Date("2021-01-01"), by = "day", length.out = 40))
})

test_that("plotly_cfg fsheh shiritin e veglave", {
  p <- plotly_cfg(plotly::plot_ly(x = 1:3, y = 1:3, type = "scatter", mode = "lines"))
  expect_false(p$x$config$displayModeBar)
  expect_true(p$x$config$responsive)
})
