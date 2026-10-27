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

test_that("plotly_cfg fsheh shiritin e veglave", {
  p <- plotly_cfg(plotly::plot_ly(x = 1:3, y = 1:3, type = "scatter", mode = "lines"))
  expect_false(p$x$config$displayModeBar)
  expect_true(p$x$config$responsive)
})
