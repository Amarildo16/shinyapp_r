# Analiza eksploruese – Seri kohore: seria, mesatarja lëvizëse dhe shpërndarja.
# Grafikët me plot_ly direkt (V-08); pamja riprodhon atë të ggplotly (plot_theme.R).
# Slider-i i dritares rillogaritet për çdo seri (B-02).

# Grafik i animueshëm: klasa "anim-plot" te div-i i widget-it (plotly-animate.js).
anim_plotly_output <- function(id, height = "360px") {
  out <- plotlyOutput(id, height = height)   # shiny.tag.list me një tag
  out[[1]] <- htmltools::tagAppendAttributes(out[[1]], class = "anim-plot")
  out
}

plot_box <- function(ns, id, caption_id, note_id = NULL) {
  div(
    class = "section-box",
    div(
      class = "plot-container",
      anim_plotly_output(ns(id))
    ),
    tags$small(textOutput(ns(caption_id))),
    if (!is.null(note_id)) tags$small(textOutput(ns(note_id)))
  )
}

mod_eda_ts_ui <- function(id) {
  ns <- NS(id)
  tagList(
    div(class = "glass-divider"),

    div(
      class = "section-box",
      h3(tr("eda_ts.title")),
      p(tr("eda_ts.intro"))
    ),

    sidebarLayout(
      position = "left",

      sidebarPanel(
        selectInput(ns("series"), tr("eda_ts.series"), choices = character(0)),

        sliderInput(
          ns("roll_k"),
          tr("eda_ts.roll_k"),
          min = 3,
          max = 3,
          value = 3,
          step = 1
        )
      ),

      mainPanel(
        plot_box(ns, "raw", "cap_raw"),
        div(class = "glass-divider"),
        plot_box(ns, "roll", "cap_roll", "roll_note"),
        div(class = "glass-divider"),
        plot_box(ns, "dist", "cap_dist")
      )
    )
  )
}

# ---- Grafikët (funksione të pastra: d = series()$data) -------------------------

# Gjurmë vije pa hover-in e plotly (hover-i vjen nga `text`).
line_trace <- function(x, y, text, width_mm, color, hoverinfo = "text") {
  list(
    x = x, y = y, text = text, type = "scatter", mode = "lines",
    line = list(width = width_mm * PX_PER_MM, color = color, dash = "solid"),
    hoveron = "points", showlegend = FALSE, xaxis = "x", yaxis = "y", hoverinfo = hoverinfo
  )
}

eda_ts_raw_plot <- function(d, series, meta) {
  sz <- glass_sizes(11)
  m  <- var_meta(series, meta)
  xlab <- time_axis_label(d$Time)
  y <- d[[series]]

  hover <- paste0(xlab, ": ", fmt_time(d$Time), "<br>", m$label, ": ", fmt_unit(y, series, meta))

  grid <- 11 / 22 * PX_PER_PT
  xaxis <- glass_axis(gg_ticks(d$Time, date = inherits(d$Time, "Date")), xlab, sz, grid)
  yaxis <- glass_axis(gg_ticks(y, labels = function(x) fmt_by_series(x, for_axis = TRUE)),
                      var_display_label(series, meta), sz, grid, anchor = "x")

  glass_figure(
    list(line_trace(as.numeric(d$Time), y, hover, 1, GLASS_WHITE)),
    glass_layout(tr("eda_ts.raw_title", label = m$label), sz, xaxis, yaxis,
                 margin = gg_margin(sz, xaxis, yaxis))
  )
}

# Boshtet e grafikëve me theme_minimal(base_size = 13), pa tituj boshtesh.
eda_ts_axis13 <- function(ticks, sz, anchor) {
  glass_axis(ticks, "", sz, gridwidth = 0.3 * PX_PER_PT, title_color = "rgba(0,0,0,1)",
             tick_color = "white", zerolinecolor = GLASS_GRID, anchor = anchor)
}

EDA_TS_MARGIN13 <- list(t = 60, r = 20, b = 40, l = 40)
TITLE_COLOR13   <- "rgba(255,255,255,0.949)"

# rm: rezultati i rolling_mean().
eda_ts_roll_plot <- function(rm, series, meta) {
  sz <- glass_sizes(13)
  m  <- var_meta(series, meta)
  d  <- rm$data
  xlab <- time_axis_label(d$Time)
  y <- d[[series]]
  when <- paste0(xlab, ": ", fmt_time(d$Time), "<br>")

  hover_raw  <- paste0(when, m$label, ": ", fmt_unit(y, series, meta))
  hover_roll <- ifelse(is.na(d$roll_mean), NA_character_,
                       paste0(when, tr("eda_ts.roll_hover"), ": ", fmt_unit(d$roll_mean, series, meta)))

  yfmt  <- function(x) fmt_by_series(x, for_axis = TRUE)
  xaxis <- eda_ts_axis13(gg_ticks(d$Time, date = inherits(d$Time, "Date")), sz, "y")
  yaxis <- eda_ts_axis13(gg_ticks(c(y, d$roll_mean), labels = yfmt), sz, "x")
  x <- as.numeric(d$Time)

  glass_figure(
    list(
      line_trace(x, y, hover_raw, 0.9, "rgba(255,255,255,0.3451)"),
      line_trace(x, d$roll_mean, hover_roll, 1.6, "rgba(255,59,48,1)")
    ),
    glass_layout(paste0("<b> ", tr("eda_ts.roll_title", k = rm$k), " </b>"), sz, xaxis, yaxis,
                 margin = EDA_TS_MARGIN13, hovermode = "x unified", title_color = TITLE_COLOR13)
  )
}

# Histograma (bins = 18) me dendësinë sipër; pa hover.
eda_ts_dist_plot <- function(d, series, meta) {
  sz <- glass_sizes(13)
  hd <- hist_density(d[[series]], bins = 18L)
  b  <- hd$bars

  traces <- list(list(
    orientation = "v", width = b$width, base = rep(0, nrow(b)), x = b$x, y = b$density,
    text = "", type = "bar", textposition = "none",
    marker = list(autocolorscale = FALSE, color = "rgba(10,132,255,0.3451)",
                  line = list(width = 0.5 * PX_PER_MM, color = "rgba(255,255,255,0.1804)")),
    showlegend = FALSE, xaxis = "x", yaxis = "y", hoverinfo = "skip"
  ))

  # Kontura e dendësisë si poligon i mbyllur: vija bazë, ana e djathtë, kurba, ana e majtë.
  if (!is.null(hd$density)) {
    dx <- hd$density$x
    dens <- line_trace(
      c(dx, dx[length(dx)], rev(dx), dx[1]),
      c(rep(0, length(dx)), 0, rev(hd$density$density), 0),
      "", 1.4, "rgba(255,59,48,1)", hoverinfo = "skip"
    )
    traces[[2]] <- c(dens[setdiff(names(dens), c("hoveron", "showlegend", "xaxis", "yaxis", "hoverinfo"))],
                     list(fill = "toself", fillcolor = "transparent", hoveron = "points",
                          showlegend = FALSE, xaxis = "x", yaxis = "y", hoverinfo = "skip"))
  }

  xfmt  <- function(x) fmt_by_series(x, for_axis = TRUE)
  xaxis <- eda_ts_axis13(gg_ticks(c(b$x - b$width / 2, b$x + b$width / 2), labels = xfmt), sz, "y")
  yaxis <- eda_ts_axis13(gg_ticks(c(0, b$density, hd$density$density)), sz, "x")

  glass_figure(
    traces,
    glass_layout(paste0("<b> ", tr("eda_ts.dist_title"), " </b>"), sz, xaxis, yaxis,
                 margin = EDA_TS_MARGIN13, title_color = TITLE_COLOR13)
  )
}

# ---- Moduli ------------------------------------------------------------------

# Slider-i i dritares për serinë: kufijtë e roll_bounds(), vlera aktuale brenda tyre
# (5 kur s'ka ende vlerë), etiketa me njësinë e hapit.
roll_slider_state <- function(d, series, cur) {
  n_non_na <- sum(!is.na(d[[series]]))
  rb <- roll_bounds(n_non_na, d$Time)
  if (is.null(cur) || is.na(cur)) cur <- min(5L, rb$max)
  list(
    min = rb$min, max = rb$max,
    value = max(rb$min, min(as.integer(cur), rb$max)),
    label = tr("eda_ts.roll_k_unit", unit = time_step_unit(d$Time)),
    enabled = n_non_na >= 3
  )
}

mod_eda_ts_server <- function(id, series) {
  moduleServer(id, function(input, output, session) {
    pick_choice <- function(cur, choices, fallback) {
      if (!is.null(cur) && length(cur) == 1 && nzchar(cur) && cur %in% choices) cur else fallback
    }

    observeEvent(series(), {
      choices <- series()$value_cols
      if (length(choices) == 0) return()
      updateSelectInput(session, "series", choices = choices,
                        selected = pick_choice(isolate(input$series), choices, choices[1]))
    })

    # Seria e zgjedhur, vetëm kur i përket dataset-it aktual.
    sel <- reactive({
      s <- series()
      req(s, input$series, input$series %in% s$value_cols)
      input$series
    })

    # B-02: kufijtë rillogariten për çdo seri dhe çdo dataset; vlera ruhet brenda tyre.
    observeEvent(list(series(), input$series), {
      s <- series()
      req(s, input$series %in% s$value_cols)
      st <- roll_slider_state(s$data, input$series, isolate(input$roll_k))
      updateSliderInput(session, "roll_k", label = st$label, min = st$min, max = st$max,
                        value = st$value, step = 1)
      if (st$enabled) shinyjs::enable("roll_k") else shinyjs::disable("roll_k")
    })

    roll <- reactive({
      req(input$roll_k, requireNamespace("zoo", quietly = TRUE))
      rolling_mean(series()$data, sel(), input$roll_k)
    })

    output$raw  <- renderPlotly(eda_ts_raw_plot(series()$data, sel(), series()$meta))
    output$dist <- renderPlotly(eda_ts_dist_plot(series()$data, sel(), series()$meta))

    # B-06: mesazhet që bllokonin grafikun kalojnë te validate(), me të njëjtin tekst.
    output$roll <- renderPlotly({
      shiny::validate(shiny::need(requireNamespace("zoo", quietly = TRUE), tr("eda_ts.need_zoo")))
      rm <- roll()
      shiny::validate(shiny::need(isTRUE(rm$ok), tr("eda_ts.need_roll_points")))
      eda_ts_roll_plot(rm, sel(), series()$meta)
    })

    # V-17 d: përshtatja e k-së shfaqet nën grafik, jo si njoftim.
    output$roll_note <- renderText({
      rm <- roll()
      if (isTRUE(rm$k_adjusted)) tr("eda_ts.roll_adjusted", k = rm$k, n = rm$n_non_na) else ""
    })

    label_of <- function() var_meta(sel(), series()$meta)$label
    output$cap_raw  <- renderText(tr("eda_ts.cap_raw", label = label_of()))
    output$cap_roll <- renderText({
      req(input$roll_k)
      tr("eda_ts.cap_roll", k = input$roll_k, label = label_of())
    })
    output$cap_dist <- renderText(tr("eda_ts.cap_dist", label = label_of()))
  })
}
