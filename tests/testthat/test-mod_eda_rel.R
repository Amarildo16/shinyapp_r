# mod_eda_rel: grafiku i shpërndarjes dhe matrica e korrelacionit me plot_ly (V-08),
# mesazhet me validate() (B-06) dhe teksti hyrës (B-07).

agri_rel <- function(vc = c("Production_ton", "Area_ha", "Rainfall_mm")) {
  f <- "albania_agriculture_timeseries_1998_2024.csv"
  d <- read_data_safe(file.path(APP_ROOT, "data", "samples", f), f)
  prepare_series(list(file = f, data = d, time_col = "Year", value_cols = vc))
}

test_that("grafiku i shpërndarjes: boshtet, ngjyrat dhe hover-i si te ggplotly (Q27)", {
  s <- agri_rel()
  rel <- relation_fit(s$data, "Production_ton", "Area_ha")
  b <- plotly::plotly_build(eda_rel_scatter_plot(rel, "Production_ton", "Area_ha", s$data$Time, s$meta))$x
  # Vlerat e ggplotly-t në ffd8e99 për të njëjtin çift.
  expect_equal(b$layout$xaxis$ticktext, c("6 mln", "7 mln", "8 mln", "9 mln", "10 mln"))
  expect_equal(b$layout$xaxis$range, c(5615432.5, 10382733.5))
  expect_equal(b$layout$yaxis$ticktext, c("550 mijë", "600 mijë"))
  expect_equal(b$layout$yaxis$range, c(512255.75, 645537.25))
  expect_equal(unlist(b$layout$margin[c("t", "r", "b", "l")]), c(t = 60, r = 20, b = 60, l = 50))
  expect_equal(b$layout$title$text, "<b> Marrëdhënia ndërmjet variablave </b>")
  expect_equal(b$layout$title$font$color, "rgba(255,255,255,0.949)")
  expect_equal(b$data[[1]]$marker$size, 9.8268, tolerance = 1e-4)
  expect_equal(b$data[[1]]$marker$color, "rgba(46,134,255,1)")
  expect_equal(b$data[[1]]$text[1], "Viti: 1998<br>Production ton: 5 832 128,00<br>Area ha: 639 479,00")
  expect_length(b$data[[2]]$x, 100)
  expect_equal(b$data[[2]]$line$color, "rgba(255,59,48,1)")
})

test_that("matrica: ngjyrat dhe shkalla janë ato të scale_fill_gradient2 (ggplot2)", {
  skip_if_not_installed("ggplot2")
  cm <- correlation_matrix(agri_rel()$data)
  r  <- as.vector(cm$corr)
  p <- ggplot2::ggplot(data.frame(a = factor(seq_along(r)), f = r), ggplot2::aes(a, 1, fill = f)) +
    ggplot2::geom_tile() +
    ggplot2::scale_fill_gradient2(low = "#0a84ff", mid = "white", high = "#ff3b30", midpoint = 0)
  expect_equal(corr_fill(r, range(r)), ggplot2::layer_data(p)$fill)

  b  <- plotly::plotly_build(eda_rel_corr_plot(cm))$x
  cb <- b$data[[3]]$marker$colorbar
  g  <- ggplot2::get_guide_data(p, "fill")
  expect_equal(as.vector(cb$tickvals), g$.value)
  expect_equal(as.vector(cb$ticktext), g$.label)
  expect_equal(b$data[[1]]$type, "heatmap")
  expect_equal(b$data[[1]]$text[1, 2], "Area_ha × Production_ton<br>Korrelacioni: -0,42")
  expect_equal(b$data[[2]]$text[1:2], c("1,00", "-0,42"))
  expect_equal(b$layout$xaxis$ticktext, c("Production_ton", "Area_ha", "Rainfall_mm"))
  expect_equal(b$layout$xaxis$range, c(0.4, 3.6))
})

test_that("matrica: korrelacioni NA mbetet në tekst; kufij të barabartë -> një etiketë", {
  d <- data.frame(Time = 2001:2010, A = c(2, 5, 3, 8, 6, 9, 7, 12, 10, 13),
                  B = c(1, 4, rep(NA, 8)), C = c(NA, NA, 3, 7, rep(NA, 6)))
  b <- plotly::plotly_build(eda_rel_corr_plot(correlation_matrix(d)))$x
  expect_length(b$data[[2]]$text, 9)
  expect_true(anyNA(b$data[[2]]$text))
  expect_equal(as.vector(b$data[[3]]$marker$colorbar$ticktext), "1")
  expect_equal(as.vector(b$data[[3]]$marker$colorbar$tickvals), 0.5)
})

test_that("UI: vetëm grafiku i shpërndarjes animohet; teksti hyrës pa 'bujqësore' (B-07)", {
  html <- as.character(mod_eda_rel_ui("eda_rel"))
  tag_of <- function(id) regmatches(html, regexpr(sprintf('<div[^>]*id="%s"[^>]*>', id), html))
  expect_match(tag_of("eda_rel-scatter"), 'class="[^"]*\\banim-plot\\b')
  expect_no_match(tag_of("eda_rel-corr"), "anim-plot")
  expect_no_match(html, "bujqësore")
  expect_match(html, "marrëdhëniet ndërmjet variablave kryesore, përmes grafikëve")
})

test_that("mod_eda_rel_server: grafikët, titujt dhe çifti i dataset-it tjetër", {
  sv <- reactiveVal(agri_rel())
  testServer(mod_eda_rel_server, args = list(series = sv), {
    session$setInputs(x = "Production_ton", y = "Area_ha")
    expect_match(output$scatter, "Marrëdhënia ndërmjet variablave")
    expect_match(output$corr, "Matrica e korrelacionit")
    expect_equal(output$cap_scatter, "Grafik shpërndarjeje: Production ton kundrejt Area ha.")
    expect_equal(output$cap_corr, "Matrica e korrelacionit (Pearson) për variablat numerike.")
    expect_equal(output$corr_note, "")

    # Seria e zgjedhur nuk është te dataset-i i ri: asnjë error, grafiku pret.
    session$setInputs(y = "Mungon")
    expect_error(output$scatter, class = "shiny.silent.error")
  })
})

test_that("B-06: mesazhet bllokuese -> validate(); 20 kolonat -> shënim nën grafik", {
  one <- list(data = data.frame(Time = 2000:2009, v = 1:10), value_cols = "v", meta = build_meta("v"))
  testServer(mod_eda_rel_server, args = list(series = reactive(one)), {
    session$setInputs(x = "v", y = "v")
    expect_error(output$corr, "Duhet të paktën 2 kolona numerike për korrelacion.")
  })

  const <- list(data = data.frame(Time = 2000:2009, v = 1:10, k = 4), value_cols = c("v", "k"),
                meta = build_meta(c("v", "k")))
  testServer(mod_eda_rel_server, args = list(series = reactive(const)), {
    session$setInputs(x = "k", y = "v")
    expect_error(output$corr, "Pas filtrit \\(sd>0\\) s’mbetën të paktën 2 kolona numerike.")
    expect_error(output$scatter, "Variabla X s’ka mjaft variacion për regresion.")
  })

  set.seed(1)
  wide <- data.frame(Time = 2000:2011, matrix(rnorm(12 * 22), 12, dimnames = list(NULL, paste0("V", 1:22))))
  ws <- list(data = wide, value_cols = paste0("V", 1:22), meta = build_meta(paste0("V", 1:22)))
  testServer(mod_eda_rel_server, args = list(series = reactive(ws)), {
    session$setInputs(x = "V1", y = "V2")
    expect_equal(output$corr_note, "U përdorën vetëm 20 kolonat e para numerike për heatmap.")
    expect_match(output$corr, "V20")
    expect_no_match(output$corr, "V21")
  })
})
