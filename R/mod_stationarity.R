# Stacionariteti: diferenca e parë, ACF/PACF e diferencës dhe testi ADF me interpretim.
# Grafikët me plot_ly direkt (V-08); pamja riprodhon atë të ggplotly (plot_theme.R).
# Numrat e ADF ndjekin gjuhën (V-19 a); p-vlera e prerë nga tseries shfaqet "< 0,0100" (V-17 c).

mod_stationarity_ui <- function(id) {
  ns <- NS(id)
  stat_box <- function(title, ...) div(class = "section-box", h4(title), ...)

  tagList(
    div(class = "glass-divider"),

    div(
      class = "section-box",
      h3(tr("stat.title")),
      p(tr("stat.intro"))
    ),

    sidebarLayout(
      position = "left",

      sidebarPanel(
        selectInput(ns("series"), tr("stat.series"), choices = character(0))
      ),

      mainPanel(
        stat_box(tr("stat.diff_box"),
                 div(class = "plot-wrap", anim_plotly_output(ns("diff"), height = "360px")),
                 tags$small(textOutput(ns("cap_diff")))),
        div(class = "glass-divider"),
        stat_box(tr("stat.acf_box"),
                 div(class = "plot-wrap", anim_plotly_output(ns("acf"), height = "420px")),
                 tags$small(textOutput(ns("cap_acf")))),
        div(class = "glass-divider"),
        stat_box(tr("stat.adf_box"),
                 div(class = "table-wrap", tableOutput(ns("adf_tbl")), uiOutput(ns("adf_note"))))
      )
    )
  )
}

# ---- Grafikët (funksione të pastra) ---------------------------------------------

# Boshtet e theme_minimal(13) me tekstin e tick-eve në `tick_pt` pikë dhe grid-in 0.15.
stat_axis <- function(ticks, title, sz, tick_pt, gridcolor, anchor) {
  modifyList(
    glass_axis(ticks, title, sz, gridwidth = 13 / 22 * PX_PER_PT,
               title_color = gg_color("white", 0.85), tick_color = gg_color("white", 0.92), anchor = anchor),
    list(tickfont = list(size = tick_pt * PX_PER_PT), gridcolor = gridcolor,
         tickcolor = NA, linecolor = NA, nticks = NA)
  )
}

# fd: rezultati i first_difference(); time: koha e plotë e serisë (për emrin e boshtit).
stat_diff_plot <- function(fd, series, time, meta) {
  sz <- glass_sizes(13)
  m  <- var_meta(series, meta)
  xlab <- time_axis_label(time)

  hover <- paste0(xlab, ": ", fmt_time(fd$Time), "<br>", tr("stat.diff_hover"), ": ",
                  fmt_unit(fd$diff, series, meta))

  xaxis <- stat_axis(gg_ticks(fd$Time, date = inherits(fd$Time, "Date")), xlab, sz, 12, GLASS_GRID, "y")
  yaxis <- stat_axis(gg_ticks(fd$diff, labels = function(x) fmt_by_series(x, for_axis = TRUE)),
                     tr("stat.diff_y"), sz, 12, GLASS_GRID, "x")

  layout <- glass_layout(paste0("<b> ", tr("stat.diff_title", label = m$label), " </b>"),
                         list(text = sz$text, title = 15 * PX_PER_PT), xaxis, yaxis,
                         margin = list(t = 60, r = 20, b = 60, l = 70),
                         title_color = gg_color("white", 0.95))
  layout$legend <- gg_legend("rgba(0,0,0,1)", sz)
  layout$shapes <- list()
  glass_figure(list(line_trace(as.numeric(fd$Time), fd$diff, hover, 1.2, gg_color("#0a84ff"))), layout)
}

# Hapësira ndërmjet dy paneleve (panel.spacing + shiriti i titullit), në njësi "npc" të
# lartësisë. ggplotly e llogariste mbi device-in e R-së; vlera është ajo e device-it
# 7 × 7 in që hap R kur s'ka tjetër (Rscript, testServer, runApp).
ACF_PANEL_GAP <- 0.035076795350768

# ap: rezultati i acf_pacf_data(). Dy panele (ACF sipër, PACF poshtë), si facet_wrap(ncol = 1).
stat_acf_plot <- function(ap, series, meta) {
  sz <- glass_sizes(13)
  m  <- var_meta(series, meta)
  black <- "rgba(0,0,0,1)"
  grid  <- gg_color("white", 0.15)

  lags <- c(ap$acf$lag, ap$pacf$lag)
  vals <- c(ap$acf$value, ap$pacf$value)
  # Hover-i i ggplotly: format() mbi të gjitha shtyllat bashkë (e njëjta gjerësi dhe shifra).
  hover <- paste0(tr("stat.acf_lag_hover"), ": ", format(lags, justify = "none"), "<br />",
                  tr("stat.acf_value_hover"), ": ", format(vals, justify = "none"))
  n_acf <- nrow(ap$acf)
  part  <- list(acf = seq_len(n_acf), pacf = n_acf + seq_len(nrow(ap$pacf)))

  xt <- gg_ticks(c(lags - 0.35, lags + 0.35))
  yt <- lapply(part, function(i) gg_ticks(c(pmin(0, vals[i]), pmax(0, vals[i]), -ap$conf, ap$conf)))

  bars <- lapply(names(part), function(p) {
    i <- part[[p]]
    list(orientation = "v", width = rep(0.7, length(i)), base = pmin(0, vals[i]), x = lags[i],
         y = abs(vals[i]), text = hover[i], type = "bar", textposition = "none",
         # alpha 0.75 i ggplot-it dilte nga ggplotly si 190/255 (0.7451).
         marker = list(autocolorscale = FALSE, color = gg_color("#0a84ff", 190 / 255),
                       line = list(width = 0.5 * PX_PER_MM, color = "transparent")),
         showlegend = FALSE, xaxis = "x", yaxis = if (p == "acf") "y" else "y2", hoverinfo = "text")
  })
  # Kufijtë ±1,96/√n si geom_hline: dy vija në një gjurmë për çdo panel.
  hlines <- lapply(c("y", "y2"), function(ax) {
    tr_ <- line_trace(c(xt$range[1], xt$range[2], NA, xt$range[1], xt$range[2]),
                      c(-ap$conf, -ap$conf, NA, ap$conf, ap$conf), "", 0.5, gg_color("white", 0.6))
    tr_$line$dash <- "dash"
    tr_$yaxis <- ax
    tr_
  })

  axis <- function(ticks, anchor, domain) {
    a <- stat_axis(ticks, "", sz, 11, grid, anchor)
    a$title <- ""
    a$domain <- domain
    a
  }
  top <- 0.5 - ACF_PANEL_GAP
  xaxis  <- axis(xt, "y2", c(0, 1))
  yaxis  <- axis(yt$acf, "x", c(0.5 + ACF_PANEL_GAP, 1))
  yaxis2 <- axis(yt$pacf, "x", c(0, top))
  yaxis2$automargin <- NULL   # ggplotly e vendoste vetëm te boshti i parë

  # Titujt e boshteve si shënime (ggplotly me facet): zhvendosja = tick-et + gjatësia e
  # tick-ut + margjinat e tekstit dhe të titullit (pt -> px).
  tick_px  <- 11 * PX_PER_PT
  extra_px <- (13 / 4 + 0.8 * 13 / 4 + 13 / 4) * PX_PER_PT
  longest  <- max(nchar(yaxis$ticktext))
  axis_title <- function(text, x, y, angle, xanchor, yanchor, shift) {
    c(list(text = text, x = x, y = y, showarrow = FALSE, ax = 0, ay = 0,
           font = list(color = gg_color("white", 0.85), family = "", size = sz$text),
           xref = "paper", yref = "paper", textangle = angle, xanchor = xanchor, yanchor = yanchor,
           annotationType = "axis"), shift)
  }
  strip <- function(text, y) {
    list(text = text, x = 0.5, y = y, showarrow = FALSE, ax = 0, ay = 0,
         font = list(color = gg_color("white", 0.95), family = "", size = 0.8 * 13 * PX_PER_PT),
         xref = "paper", yref = "paper", textangle = 0, xanchor = "center", yanchor = "bottom")
  }
  strip_px <- (0.8 * 13 + 2 * 0.8 * 13 / 2) * PX_PER_PT
  strip_bg <- function(y) {
    list(type = "rect", fillcolor = gg_color("white", 0.18),
         line = list(color = "transparent", width = 13 / 22 * PX_PER_PT, linetype = "solid"),
         yref = "paper", xref = "paper", layer = "below", x0 = 0, x1 = 1, y0 = 0, y1 = strip_px,
         yanchor = y, ysizemode = "pixel")
  }

  layout <- glass_layout(paste0("<b> ", tr("stat.acf_title", label = m$label), " </b>"),
                         list(text = sz$text, title = 15 * PX_PER_PT), xaxis, yaxis,
                         margin = list(t = 70, r = 20, b = 60, l = 70),
                         title_color = gg_color("white", 0.95))
  layout$yaxis2 <- yaxis2
  layout$font$color <- black
  layout$annotations <- list(
    axis_title(tr("stat.acf_x"), 0.5, 0, 0, "center", "top", list(yshift = -(tick_px + extra_px))),
    axis_title(tr("stat.acf_y"), 0, 0.5, -90, "right", "center",
               list(xshift = -(tick_px * longest / 2 + extra_px))),
    strip("ACF", 1),
    strip("PACF", top)
  )
  layout$shapes <- list(strip_bg(1), strip_bg(top))
  layout$legend <- gg_legend(black, sz)
  glass_figure(c(bars, hlines), layout)
}

# ---- ADF -----------------------------------------------------------------------

# Testi ADF për serinë, si adf_res() i vjetër: ok, reason ("ok" | "invalid_ts"), msg,
# statistikat (të rrumbullakuara në 4 shifra), p-vlerat, kufiri i prerë dhe metoda.
adf_summary <- function(d, series) {
  v <- validate_ts_ready(d, series, FREQ_POLICY, min_n = 20L)
  if (!isTRUE(v$ok)) {
    return(list(ok = FALSE, reason = "invalid_ts", msg = v$message, y_len = v$n %||% 0L,
                statistic = c(NA_real_, NA_real_), p_value = c(NA_real_, NA_real_),
                p_bound = c(NA_character_, NA_character_), method = rep(v$message, 2),
                p_lvl = NA_real_, p_diff = NA_real_))
  }
  y <- suppressWarnings(as.numeric(v$data$y))
  adf <- run_adf(y)
  part <- list(adf$level, adf$diff)
  pick <- function(f, na) vapply(part, function(o) if (is.null(o)) na else o[[f]], na)
  list(
    ok = TRUE, reason = "ok", msg = NULL, y_len = length(y),
    statistic = round(pick("statistic", NA_real_), 4),
    p_value   = pick("p_value", NA_real_),
    p_bound   = pick("p_bound", NA_character_),
    method    = pick("method", "ADF (tseries::adf.test)"),
    p_lvl     = adf$level$p_value %||% NA_real_,
    p_diff    = adf$diff$p_value %||% NA_real_
  )
}

# p-vlera me 4 shifra dhe shenjën dhjetore të gjuhës; "< " / "> " kur tseries e pret.
adf_p_text <- function(p, bound, dec = number_style()$dec) {
  txt <- formatC(p, format = "f", digits = 4, decimal.mark = dec)
  ifelse(is.na(bound), txt, paste(ifelse(bound == "lower", "<", ">"), txt))
}

# Tabela e shfaqur: kolonat dhe tipet si më parë (numerike kur testi s'u bë).
adf_table <- function(a) {
  tbl <- data.frame(
    c(tr("stat.adf_row_level"), tr("stat.adf_row_diff")),
    a$statistic,
    if (isTRUE(a$ok)) adf_p_text(a$p_value, a$p_bound) else a$p_value,
    a$method,
    check.names = FALSE, stringsAsFactors = FALSE
  )
  names(tbl) <- c(tr("stat.adf_col_series"), tr("stat.adf_col_stat"), tr("stat.adf_col_p"), tr("stat.adf_col_method"))
  tbl
}

ADF_NOTE_STYLE <- "<p style='margin-top:10px; font-size: 13px; line-height: 1.45;'>"

adf_note_html <- function(a, series, meta) {
  if (!isTRUE(a$ok)) {
    return(HTML(paste0(ADF_NOTE_STYLE, tr("stat.adf_note_head"), " ", a$msg, "</p>")))
  }
  m <- var_meta(series, meta)
  dec <- number_style()$dec
  p_txt <- function(i) {
    if (is.na(a$p_value[i])) return(paste0("= ", "NA"))
    if (is.na(a$p_bound[i])) paste("=", adf_p_text(a$p_value[i], NA, dec)) else adf_p_text(a$p_value[i], a$p_bound[i], dec)
  }
  concl <- function(p, key) {
    if (!is.na(p) && p < 0.05) tr(paste0(key, "_reject")) else if (!is.na(p)) tr(paste0(key, "_keep")) else tr(paste0(key, "_na"))
  }
  unit_txt <- if (nzchar(m$unit %||% "")) paste0(" (", m$unit, ")") else ""

  HTML(paste0(
    ADF_NOTE_STYLE,
    tr("stat.adf_note_intro", label = m$label, unit = unit_txt,
       alpha = formatC(0.05, format = "f", digits = 2, decimal.mark = dec)),
    tr("stat.adf_note_level", p = p_txt(1), concl = concl(a$p_lvl, "stat.adf_level")),
    tr("stat.adf_note_diff", p = p_txt(2), concl = concl(a$p_diff, "stat.adf_diff")),
    "</p>"
  ))
}

# ---- Moduli ------------------------------------------------------------------

mod_stationarity_server <- function(id, series) {
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

    ready <- function(min_n) {
      v <- validate_ts_ready(series()$data, sel(), FREQ_POLICY, min_n = min_n)
      shiny::validate(shiny::need(isTRUE(v$ok), v$message))
      v$data
    }

    # B-06: mesazhet që bllokonin grafikun kalojnë te validate(), me të njëjtin tekst.
    output$diff <- renderPlotly({
      fd <- first_difference(ready(3L))
      shiny::validate(shiny::need(!is.null(fd), tr("stat.need_diff_points")))
      stat_diff_plot(fd, sel(), series()$data$Time, series()$meta)
    })

    output$acf <- renderPlotly({
      dd <- ready(6L)
      shiny::validate(shiny::need(nrow(dd) >= 6, tr("stat.need_acf_points")))
      ap <- acf_pacf_data(dd)
      shiny::validate(shiny::need(!is.null(ap), tr("stat.need_acf_diff")))
      # V-20: diferenca konstante -> ACF e papërcaktuar (NaN); mesazh në vend të grafikut bosh.
      shiny::validate(shiny::need(any(is.finite(c(ap$acf$value, ap$pacf$value))), tr("stat.acf_constant_diff")))
      stat_acf_plot(ap, sel(), series()$meta)
    })

    adf <- reactive(adf_summary(series()$data, sel()))

    output$adf_tbl <- renderTable(adf_table(adf()), striped = FALSE, bordered = TRUE, spacing = "s",
                                  format.args = list(decimal.mark = number_style()$dec))
    output$adf_note <- renderUI(adf_note_html(adf(), sel(), series()$meta))

    label_of <- function() var_meta(sel(), series()$meta)$label
    output$cap_diff <- renderText(tr("stat.cap_diff", label = label_of()))
    output$cap_acf  <- renderText(tr("stat.cap_acf", label = label_of()))
  })
}
