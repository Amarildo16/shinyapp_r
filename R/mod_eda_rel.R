# Analiza eksploruese – Marrëdhënie: grafiku i shpërndarjes X–Y me vijën e regresionit
# dhe matrica e korrelacionit. Grafikët me plot_ly direkt (V-08); pamja riprodhon atë
# të ggplotly (plot_theme.R).

mod_eda_rel_ui <- function(id) {
  ns <- NS(id)
  rel_box <- function(title, plot, caption_id, note_id = NULL) {
    div(
      class = "section-box",
      h4(title),
      div(class = "plot-wrap", plot),
      tags$small(textOutput(ns(caption_id))),
      if (!is.null(note_id)) tags$small(textOutput(ns(note_id)))
    )
  }

  tagList(
    div(class = "glass-divider"),

    div(
      class = "section-box",
      h3(tr("eda_rel.title")),
      p(tr("eda_rel.intro"))
    ),

    sidebarLayout(
      position = "left",

      sidebarPanel(
        selectInput(ns("x"), tr("eda_rel.x"), choices = character(0)),

        selectInput(ns("y"), tr("eda_rel.y"), choices = character(0))
      ),

      mainPanel(
        # Vetëm grafiku i shpërndarjes animohej (plotly-animate.js); matrica jo.
        rel_box(tr("eda_rel.scatter_box"), anim_plotly_output(ns("scatter"), height = "420px"), "cap_scatter"),
        div(class = "glass-divider"),
        rel_box(tr("eda_rel.corr_box"), plotlyOutput(ns("corr"), height = "420px"), "cap_corr", "corr_note")
      )
    )
  )
}

# ---- Grafikët (funksione të pastra) ---------------------------------------------

# Boshtet e grafikut të shpërndarjes: theme_minimal(13) + layout()-i i vjetër mbi të.
eda_rel_axis <- function(ticks, title, sz, anchor) {
  modifyList(
    glass_axis(ticks, title, sz, gridwidth = 0.3 * PX_PER_PT,
               title_color = gg_color("white", 0.90), tick_color = "rgba(255,255,255,0.75)",
               zerolinecolor = "rgba(255,255,255,0.10)", anchor = anchor),
    list(ticks = "outside", tickcolor = gg_color("white", 0.35), tickwidth = 13 / 22 * PX_PER_PT,
         gridcolor = "rgba(255,255,255,0.10)", titlefont = list(color = "rgba(255,255,255,0.90)"),
         linecolor = NA, nticks = NA)
  )
}

# rel: rezultati i relation_fit() (ok = TRUE).
eda_rel_scatter_plot <- function(rel, x, y, time, meta) {
  sz <- glass_sizes(13)
  mx <- var_meta(x, meta)
  my <- var_meta(y, meta)
  d  <- rel$data
  ln <- rel$line

  hover <- paste0(
    time_axis_label(time), ": ", fmt_time(d$Time),
    "<br>", mx$label, ": ", fmt_unit(d$xval, x, meta),
    "<br>", my$label, ": ", fmt_unit(d$yval, y, meta)
  )

  traces <- list(list(
    x = d$xval, y = d$yval, text = hover, type = "scatter", mode = "markers",
    marker = list(autocolorscale = FALSE, color = gg_color("#2E86FF"), opacity = 0.7,
                  size = 2.6 * PX_PER_MM, symbol = "circle",
                  line = list(width = 0.5 * PX_PER_MM, color = gg_color("#2E86FF"))),
    hoveron = "points", showlegend = FALSE, xaxis = "x", yaxis = "y", hoverinfo = "text"
  ))
  if (!is.null(ln)) traces[[2]] <- line_trace(ln$xval, ln$yhat, "", 0.9, gg_color("#FF3B30"))

  xaxis <- eda_rel_axis(gg_ticks(c(d$xval, ln$xval), labels = fmt_by_series),
                        var_display_label(x, meta), sz, "y")
  yaxis <- eda_rel_axis(gg_ticks(c(d$yval, ln$yhat), labels = fmt_by_series),
                        var_display_label(y, meta), sz, "x")

  # Nëntitulli i ggplot-it ("X kundrejt Y") nuk shfaqej nga ggplotly; mbetet jashtë.
  layout <- glass_layout(paste0("<b> ", tr("eda_rel.scatter_title"), " </b>"),
                         list(text = sz$text, title = 15 * PX_PER_PT), xaxis, yaxis,
                         margin = list(t = 60, r = 20, b = 60, l = 50),
                         title_color = gg_color("white", 0.95))
  layout$font$color <- "rgba(255,255,255,0.85)"
  layout$legend <- gg_legend(gg_color("white", 0.85), sz)
  layout$shapes <- list()
  glass_figure(traces, layout)
}

# Ngjyrat e scale_fill_gradient2(blu, e bardhë, e kuqe; mesi 0) brenda kufijve `lim`.
corr_fill <- function(v, lim) {
  pal <- scales::pal_div_gradient("#0a84ff", "white", "#ff3b30", "Lab")
  col <- pal(scales::rescale_mid(v, from = lim, mid = 0))
  ifelse(is.na(col), "grey50", col)
}

# Boshtet diskrete të matricës (emrat e kolonave).
corr_axis <- function(vars, sz, anchor) {
  n <- length(vars)
  ticks <- list(range = c(0.4, n + 0.6), tickvals = seq_len(n), ticktext = vars)
  modifyList(
    glass_axis(ticks, "", sz, gridwidth = 0, title_color = "rgba(0,0,0,1)",
               tick_color = gg_color("white", 0.92), anchor = anchor),
    list(tickfont = list(size = 12 * PX_PER_PT), tickcolor = NA, showgrid = FALSE, gridcolor = NA,
         linecolor = NA, nticks = NA)
  )
}

# cm: rezultati i correlation_matrix() (ok = TRUE).
eda_rel_corr_plot <- function(cm) {
  sz   <- glass_sizes(13)
  corr <- cm$corr
  vars <- colnames(corr)
  n    <- length(vars)
  lab  <- tr("eda_rel.corr_label")

  # Qelizat si te as.table(): Var1 (x) ndryshon më shpejt se Var2 (y).
  cells <- data.frame(i = rep(seq_len(n), n), j = rep(seq_len(n), each = n))
  cells$r     <- corr[cbind(cells$i, cells$j)]
  cells$label <- fmt_fixed(cells$r, digits = 2)
  cells$hover <- paste0(vars[cells$i], " × ", vars[cells$j], "<br>", lab, ": ", cells$label)

  lim  <- range(cells$r, na.rm = TRUE)
  z    <- scales::rescale(cells$r)
  fill <- corr_fill(cells$r, lim)
  cs   <- unique(data.frame(z = z, fill = fill))
  cs   <- cs[stats::complete.cases(cs), ]
  cs   <- cs[order(cs$z), ]

  heat <- list(
    x = seq_len(n), y = seq_len(n),
    z = matrix(z, nrow = n, ncol = n, byrow = TRUE),
    text = matrix(cells$hover, nrow = n, ncol = n, byrow = TRUE),
    colorscale = setNames(cs, NULL), type = "heatmap", showscale = FALSE, autocolorscale = FALSE,
    showlegend = FALSE, xaxis = "x", yaxis = "y", hoverinfo = "text"
  )

  text <- list(
    x = cells$i, y = cells$j, text = cells$label, hovertext = cells$hover,
    textfont = list(size = 4.2 * PX_PER_MM, color = "black"),
    type = "scatter", mode = "text", hoveron = "points", showlegend = FALSE,
    xaxis = "x", yaxis = "y", hoverinfo = "text"
  )

  # Shkalla e ngjyrave (colourbar i guide_colourbar: 300 ngjyra; thyerjet brenda kufijve,
  # te qendrat e ngjyrave të para dhe të fundit: 0.5/300 … 299.5/300).
  bar <- seq(lim[1], lim[2], length.out = 300)
  br  <- if (scales::zero_range(lim)) lim[1] else scales::transform_identity()$breaks(lim)
  br[!is.na(br) & (br < lim[1] | br > lim[2])] <- NA
  br_lab <- scales::transform_identity()$format(br)
  keep <- !is.na(br)
  black <- "rgba(0,0,0,1)"
  scale_trace <- list(
    x = 1L, y = 1L, name = "corr_scale", type = "scatter", mode = "markers", opacity = 0,
    hoverinfo = "skip", showlegend = FALSE,
    marker = list(
      color = c(0, 1),
      colorscale = setNames(data.frame(scales::rescale(bar, from = lim), corr_fill(bar, lim)), NULL),
      colorbar = list(
        bgcolor = NA, bordercolor = NA, borderwidth = 0, thickness = 23.04, title = lab,
        titlefont = list(color = black, family = "", size = sz$text),
        tickmode = "array", ticktext = br_lab[keep], tickvals = scales::rescale(br[keep], to = c(0.5, 299.5) / 300, from = lim),
        tickfont = list(color = black, family = "", size = sz$tick), ticklen = 2, len = 0.5
      )
    ),
    xaxis = "x", yaxis = "y"
  )

  layout <- glass_layout(paste0("<b> ", tr("eda_rel.corr_title"), " </b>"),
                         list(text = sz$text, title = 15 * PX_PER_PT),
                         corr_axis(vars, sz, "y"), corr_axis(vars, sz, "x"),
                         margin = list(t = 60, r = 20, b = 60, l = 80),
                         title_color = gg_color("white", 0.95))
  layout$font$color <- black
  layout$legend <- gg_legend(black, sz, title = lab)
  layout$shapes <- list()
  glass_figure(list(heat, text, scale_trace), layout)
}

# ---- Moduli ------------------------------------------------------------------

mod_eda_rel_server <- function(id, series) {
  moduleServer(id, function(input, output, session) {
    pick_choice <- function(cur, choices, fallback) {
      if (!is.null(cur) && length(cur) == 1 && nzchar(cur) && cur %in% choices) cur else fallback
    }

    # X merr serinë e parë, Y të dytën (kur ka vetëm një, të njëjtën).
    observeEvent(series(), {
      choices <- series()$value_cols
      if (length(choices) == 0) return()
      s2 <- if (length(choices) >= 2) choices[2] else choices[1]
      updateSelectInput(session, "x", choices = choices,
                        selected = pick_choice(isolate(input$x), choices, choices[1]))
      updateSelectInput(session, "y", choices = choices,
                        selected = pick_choice(isolate(input$y), choices, s2))
    })

    # Çifti i zgjedhur, vetëm kur të dyja seritë i përkasin dataset-it aktual.
    pair <- reactive({
      s <- series()
      req(s, input$x, input$y, input$x %in% s$value_cols, input$y %in% s$value_cols)
      c(input$x, input$y)
    })

    output$scatter <- renderPlotly({
      p <- pair()
      d <- series()$data
      rel <- relation_fit(d, p[1], p[2])
      shiny::validate(shiny::need(rel$reason != "few_points", tr("eda_rel.need_points")))
      shiny::validate(shiny::need(rel$reason != "no_x_variation", tr("eda_rel.need_x_variation")))
      eda_rel_scatter_plot(rel, p[1], p[2], d$Time, series()$meta)
    })

    cm <- reactive({
      req(series())
      correlation_matrix(series()$data)
    })

    # B-06: mesazhet që bllokonin grafikun kalojnë te validate(), me të njëjtin tekst.
    output$corr <- renderPlotly({
      m <- cm()
      shiny::validate(shiny::need(!identical(m$reason, "few_cols"), tr("eda_rel.need_cols")))
      shiny::validate(shiny::need(!identical(m$reason, "few_cols_after_sd"), tr("eda_rel.need_cols_sd")))
      eda_rel_corr_plot(m)
    })

    # V-17 d: kufiri i 20 kolonave shfaqet nën grafik, jo si njoftim.
    output$corr_note <- renderText({
      if (isTRUE(cm()$truncated)) tr("eda_rel.corr_truncated") else ""
    })

    output$cap_scatter <- renderText({
      p <- pair()
      tr("eda_rel.cap_scatter", x = var_meta(p[1], series()$meta)$label,
         y = var_meta(p[2], series()$meta)$label)
    })
    output$cap_corr <- renderText(tr("eda_rel.cap_corr"))
  })
}
