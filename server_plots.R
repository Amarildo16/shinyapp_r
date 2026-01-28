server_plots <- function(input, output, session, df) {

  # =========================================================
  # Ndihmëse: emërtim dhe formatim
  # =========================================================

  `%||%` <- function(a, b) if (is.null(a)) b else a

  var_meta <- function(var) {
    switch(
      var,
      "Production_ton"      = list(label = "Prodhimi bujqësor", unit = "ton"),
      "Yield_ton_per_ha"    = list(label = "Rendimenti bujqësor", unit = "ton/ha"),
      "Rainfall_mm"         = list(label = "Reshjet vjetore", unit = "mm"),
      list(label = var, unit = "")
    )
  }

  fmt_fixed <- function(x, digits = 2) {
    ifelse(
      is.na(x),
      NA_character_,
      format(
        round(x, digits),
        nsmall = digits,
        big.mark = " ",
        decimal.mark = ",",
        scientific = FALSE,
        trim = TRUE
      )
    )
  }

  fmt_compact <- function(x, digits = 1) {
    out <- vapply(x, function(v) {
      if (is.na(v)) return(NA_character_)
      av <- abs(v)

      if (av >= 1e9) {
        val <- v / 1e9; suf <- " mld"
      } else if (av >= 1e6) {
        val <- v / 1e6; suf <- " mln"
      } else if (av >= 1e3) {
        val <- v / 1e3; suf <- " mijë"
      } else {
        val <- v; suf <- ""
      }

      s <- format(
        round(val, digits),
        nsmall = digits,
        big.mark = " ",
        decimal.mark = ",",
        scientific = FALSE,
        trim = TRUE
      )

      s <- sub(",0+$", "", s)
      paste0(s, suf)
    }, character(1))

    out
  }

  fmt_by_var <- function(x, var, for_axis = TRUE) {
    if (var == "Production_ton") {
      return(fmt_compact(x, digits = 1))
    }
    if (var == "Yield_ton_per_ha") {
      return(fmt_fixed(x, digits = 2))
    }
    if (var == "Rainfall_mm") {
      return(fmt_fixed(x, digits = 1))
    }
    if (for_axis) fmt_compact(x, digits = 1) else fmt_fixed(x, digits = 2)
  }

  fmt_unit <- function(x, var) {
    m <- var_meta(var)
    paste0(fmt_by_var(x, var, for_axis = FALSE), " ", m$unit)
  }

  plotly_cfg <- function(p) {
    p %>% plotly::config(displayModeBar = FALSE, responsive = TRUE)
  }

  # Vendos tekstin e hover-it në trace specifike (pa aes(text=...) në ggplot)
  set_trace_text <- function(pl, idx, text_vec) {
    if (length(idx) != 1) return(pl)
    pl$x$data[[idx]]$text <- text_vec
    pl$x$data[[idx]]$hoverinfo <- "text"
    pl
  }

  skip_trace_hover <- function(pl, idx) {
    if (length(idx) == 0) return(pl)
    for (i in idx) pl$x$data[[i]]$hoverinfo <- "skip"
    pl
  }

  find_traces <- function(pl, predicate) {
    which(vapply(pl$x$data, predicate, logical(1)))
  }

  # =========================================================
  # Captions (tekste shpjeguese poshtë grafikëve)
  # =========================================================

  output$cap_eda_ts_raw <- renderText({
    req(input$eda_series)
    m <- var_meta(input$eda_series)
    paste0(
      "Grafiku paraqet evolucionin vjetor të serisë “", m$label,
      "” gjatë periudhës 1998–2024."
    )
  })

  output$cap_eda_ts_roll <- renderText({
    req(input$eda_series, input$roll_k)
    m <- var_meta(input$eda_series)
    paste0(
      "Vija e zbutur (mesatare lëvizëse me dritare k = ", input$roll_k,
      ") thekson prirjen afatmesme duke reduktuar luhatjet afatshkurtra të serisë “",
      m$label, "”."
    )
  })

  output$cap_eda_ts_dist <- renderText({
    req(input$eda_series)
    m <- var_meta(input$eda_series)
    paste0(
      "Histogrami dhe densiteti i vlerësuar ilustrojnë formën e shpërndarjes për serinë “",
      m$label, "” dhe ndihmojnë në vlerësimin e asimetrisë dhe vlerave ekstreme."
    )
  })

  output$cap_eda_rel_scatter <- renderText({
    req(input$rel_x, input$rel_y)
    mx <- var_meta(input$rel_x)
    my <- var_meta(input$rel_y)
    paste0(
      "Pikat përfaqësojnë vrojtimet vjetore; vija e regresionit linear sugjeron drejtimin e lidhjes së mundshme ndërmjet “",
      mx$label, "” dhe “", my$label, "”."
    )
  })

  output$cap_eda_rel_corr <- renderText({
    "Matrica e korrelacionit (Pearson) përmbledh lidhjet lineare ndërmjet variablave; vlerat afër ±1 tregojnë lidhje më të fortë."
  })

  output$cap_stat_diff_plot <- renderText({
    req(input$stat_series)
    m <- var_meta(input$stat_series)
    paste0(
      "Diferencimi i parë aplikohet për të reduktuar trendin dhe për të mbështetur arritjen e stacionaritetit në serinë “",
      m$label, "”."
    )
  })

  output$cap_stat_acf_pacf <- renderText({
    req(input$stat_series)
    "Grafikët ACF dhe PACF përdoren për të orientuar përzgjedhjen e rendit të komponentëve autoregresivë (AR) dhe mesatares lëvizëse (MA) në modelet ARIMA."
  })

  output$cap_model_plot <- renderText({
    req(input$model_series, input$model_h)
    m <- var_meta(input$model_series)
    paste0(
      "Grafiku krahason parashikimet e modeleve ETS dhe ARIMA për serinë “",
      m$label, "” në horizontin h = ", input$model_h, " vite."
    )
  })

  output$cap_forecast_plot <- renderText({
    req(input$forecast_series, input$method)
    m <- var_meta(input$forecast_series)
    paste0(
      "Parashikimi për serinë “", m$label,
      "” shoqërohet me interval besimi 80%, i cili reflekton pasigurinë e parashikimit."
    )
  })

  # =========================
  # Tabela – Përmbledhje (Overview)
  # =========================

  output$data_info_tbl <- renderTable({
    d <- df()

    data.frame(
      Element = c("Viti fillestar", "Viti përfundimtar", "Numri i vrojtimeve", "Burimi i të dhënave"),
      Vlera   = c(
        as.character(min(d$Year)),
        as.character(max(d$Year)),
        as.character(nrow(d)),
        "INSTAT / Our World in Data"
      ),
      check.names = FALSE
    )
  })

  output$variables_tbl <- renderTable({
    data.frame(
      Variabla = c(
        "Prodhimi bujqësor (ton)",
        "Rendimenti bujqësor (ton/ha)",
        "Reshjet vjetore (mm)"
      ),
      Përshkrimi = c(
        "Sasia totale e prodhimit bujqësor në nivel vjetor.",
        "Sasia e prodhimit për njësi sipërfaqeje (ton për hektar).",
        "Sasia totale e reshjeve në nivel vjetor (milimetra)."
      ),
      check.names = FALSE
    )
  })

  output$summary_tbl <- renderTable({
    d <- df() %>% dplyr::select(-Year)

    vars <- names(d)

    stats_num <- data.frame(
      Variabla = vars,
      Mesatarja = sapply(d, mean, na.rm = TRUE),
      `Devijimi standard` = sapply(d, sd, na.rm = TRUE),
      Minimumi = sapply(d, min, na.rm = TRUE),
      Maksimumi = sapply(d, max, na.rm = TRUE),
      check.names = FALSE
    )

    stats_num$Variabla <- vapply(vars, function(v) {
      m <- var_meta(v)
      paste0(m$label, " (", m$unit, ")")
    }, character(1))

    out <- stats_num
    for (i in seq_along(vars)) {
      v <- vars[i]
      out$Mesatarja[i] <- fmt_by_var(stats_num$Mesatarja[i], v, for_axis = FALSE)
      out$`Devijimi standard`[i] <- fmt_by_var(stats_num$`Devijimi standard`[i], v, for_axis = FALSE)
      out$Minimumi[i] <- fmt_by_var(stats_num$Minimumi[i], v, for_axis = FALSE)
      out$Maksimumi[i] <- fmt_by_var(stats_num$Maksimumi[i], v, for_axis = FALSE)
    }

    out
  })

  # =========================
  # EDA – Seri kohore
  # =========================

  output$eda_ts_raw <- renderPlotly({
    req(df(), input$eda_series)

    m <- var_meta(input$eda_series)

    d <- df() %>%
      dplyr::select(Year, value = dplyr::all_of(input$eda_series)) %>%
      dplyr::mutate(
        hover = paste0(
          "Viti: ", Year,
          "<br>", m$label, ": ", fmt_unit(value, input$eda_series)
        )
      )

    p <- ggplot(d, aes(x = Year, y = value)) +
      geom_line(linewidth = 1, color = "white") +
      labs(
        title = paste0("Seria kohore e vëzhguar – ", m$label),
        x = "Viti",
        y = paste0(m$label, " (", m$unit, ")")
      ) +
      scale_y_continuous(labels = function(x) fmt_by_var(x, input$eda_series)) +
      theme_minimal() +
      theme(
        plot.background  = element_blank(),
        panel.background = element_blank(),
        text = element_text(color = "white"),
        axis.text = element_text(color = "white"),
        axis.title = element_text(color = "white")
      )

    pl <- ggplotly(p, tooltip = NULL) %>%
      layout(
        paper_bgcolor = "rgba(0,0,0,0)",
        plot_bgcolor  = "rgba(0,0,0,0)",
        font = list(color = "white"),
        xaxis = list(gridcolor = "rgba(255,255,255,0.15)"),
        yaxis = list(gridcolor = "rgba(255,255,255,0.15)")
      )

    line_idx <- find_traces(pl, function(tr) {
      (tr$type %||% "") == "scatter" && grepl("lines", tr$mode %||% "")
    })[1]

    pl <- set_trace_text(pl, line_idx, d$hover)

    plotly_cfg(pl)
  })

  output$eda_ts_roll <- renderPlotly({
    req(df(), input$eda_series, input$roll_k)

    m <- var_meta(input$eda_series)

    d <- df() %>%
      dplyr::arrange(Year) %>%
      dplyr::mutate(
        roll_mean = zoo::rollmean(
          .data[[input$eda_series]],
          k = input$roll_k,
          fill = NA,
          align = "right"
        )
      ) %>%
      dplyr::mutate(
        hover_raw = paste0("Viti: ", Year, "<br>", m$label, ": ", fmt_unit(.data[[input$eda_series]], input$eda_series)),
        hover_roll = paste0("Viti: ", Year, "<br>Mesatare lëvizëse: ", fmt_unit(roll_mean, input$eda_series))
      )

    p <- ggplot(d, aes(x = Year)) +
      geom_line(
        aes(y = .data[[input$eda_series]]),
        color = scales::alpha("black", 0.35),
        linewidth = 0.9
      ) +
      geom_line(
        aes(y = roll_mean),
        color = "#ff3b30",
        linewidth = 1.6
      ) +
      labs(
        title = paste0("Mesatarja lëvizëse (k = ", input$roll_k, ")"),
        subtitle = paste0(m$label, " (", m$unit, ")"),
        x = NULL,
        y = NULL
      ) +
      scale_y_continuous(labels = function(x) fmt_by_var(x, input$eda_series)) +
      theme_minimal(base_size = 13) +
      theme(
        panel.background = element_rect(fill = "transparent", color = NA),
        plot.background  = element_rect(fill = "transparent", color = NA),
        panel.grid.major = element_line(color = scales::alpha("black", 0.08), linewidth = 0.3),
        panel.grid.minor = element_blank(),
        axis.text        = element_text(color = scales::alpha("black", 0.65)),
        plot.title       = element_text(face = "bold"),
        plot.subtitle    = element_text(color = scales::alpha("black", 0.55))
      )

    pl <- ggplotly(p, tooltip = NULL) %>%
      layout(
        paper_bgcolor = "rgba(0,0,0,0)",
        plot_bgcolor  = "rgba(0,0,0,0)",
        margin = list(t = 60, l = 40, r = 20, b = 40),
        hovermode = "x unified"
      )

    line_idx <- find_traces(pl, function(tr) {
      (tr$type %||% "") == "scatter" && grepl("lines", tr$mode %||% "")
    })

    # Layer 1 = seria origjinale; Layer 2 = mesatarja lëvizëse
    if (length(line_idx) >= 1) {
      pl <- set_trace_text(pl, line_idx[1], d$hover_raw)
    }
    if (length(line_idx) >= 2) {
      roll_hover_full <- ifelse(is.na(d$roll_mean), NA_character_, d$hover_roll)
      pl <- set_trace_text(pl, line_idx[2], roll_hover_full)
    }

    plotly_cfg(pl)
  })

  output$eda_ts_dist <- renderPlotly({
    req(df(), input$eda_series)

    m <- var_meta(input$eda_series)

    d <- df() %>%
      dplyr::mutate(val = .data[[input$eda_series]])

    p <- ggplot(d, aes(x = val)) +
      geom_histogram(
        aes(y = after_stat(density)),
        bins = 18,
        fill = scales::alpha("#0a84ff", 0.35),
        color = scales::alpha("black", 0.15)
      ) +
      geom_density(
        color = "#ff3b30",
        linewidth = 1.4
      ) +
      labs(
        title = "Shpërndarja",
        subtitle = paste0(m$label, " (", m$unit, ")"),
        x = NULL,
        y = NULL
      ) +
      scale_x_continuous(labels = function(x) fmt_by_var(x, input$eda_series)) +
      theme_minimal(base_size = 13) +
      theme(
        panel.background = element_rect(fill = "transparent", color = NA),
        plot.background  = element_rect(fill = "transparent", color = NA),
        panel.grid.major = element_line(color = scales::alpha("black", 0.08), linewidth = 0.3),
        panel.grid.minor = element_blank(),
        axis.text        = element_text(color = scales::alpha("black", 0.65)),
        plot.title       = element_text(face = "bold"),
        plot.subtitle    = element_text(color = scales::alpha("black", 0.55))
      )

    pl <- ggplotly(p, tooltip = NULL) %>%
      layout(
        paper_bgcolor = "rgba(0,0,0,0)",
        plot_bgcolor  = "rgba(0,0,0,0)",
        margin = list(t = 60, l = 40, r = 20, b = 40)
      )

    # Për të shmangur etiketa të panevojshme në hover, e çaktivizojmë hover-in këtu
    pl <- skip_trace_hover(pl, seq_along(pl$x$data))

    plotly_cfg(pl)
  })

  # =========================
  # EDA – Marrëdhënie
  # =========================

  output$eda_rel_scatter <- renderPlotly({
    req(df(), input$rel_x, input$rel_y)

    mx <- var_meta(input$rel_x)
    my <- var_meta(input$rel_y)

    d <- df() %>%
      dplyr::mutate(
        xval = .data[[input$rel_x]],
        yval = .data[[input$rel_y]],
        hover = paste0(
          "Viti: ", Year,
          "<br>", mx$label, ": ", fmt_unit(xval, input$rel_x),
          "<br>", my$label, ": ", fmt_unit(yval, input$rel_y)
        )
      )

    p <- ggplot(d, aes(x = xval, y = yval)) +
      geom_point(
        size = 2.6,
        alpha = 0.55,
        color = scales::alpha("#0a84ff", 0.55)
      ) +
      geom_smooth(
        method = "lm",
        se = FALSE,
        linewidth = 1.4,
        color = "#ff3b30"
      ) +
      labs(
        title = "Marrëdhënia ndërmjet variablave",
        subtitle = paste0(mx$label, " kundrejt ", my$label),
        x = paste0(mx$label, " (", mx$unit, ")"),
        y = paste0(my$label, " (", my$unit, ")")
      ) +
      scale_x_continuous(labels = function(x) fmt_by_var(x, input$rel_x)) +
      scale_y_continuous(labels = function(x) fmt_by_var(x, input$rel_y)) +
      theme_minimal(base_size = 13) +
      theme(
        panel.background = element_rect(fill = "transparent", color = NA),
        plot.background  = element_rect(fill = "transparent", color = NA),
        panel.grid.major = element_line(color = scales::alpha("black", 0.08), linewidth = 0.3),
        panel.grid.minor = element_blank(),
        axis.text        = element_text(color = scales::alpha("black", 0.65)),
        plot.title       = element_text(face = "bold", size = 15),
        plot.subtitle    = element_text(color = scales::alpha("black", 0.55), size = 12)
      )

    pl <- ggplotly(p, tooltip = NULL) %>%
      layout(
        paper_bgcolor = "rgba(0,0,0,0)",
        plot_bgcolor  = "rgba(0,0,0,0)",
        margin = list(t = 60, l = 50, r = 20, b = 60),
        hovermode = "closest"
      )

    marker_idx <- find_traces(pl, function(tr) grepl("markers", tr$mode %||% ""))[1]
    line_idx   <- find_traces(pl, function(tr) grepl("lines", tr$mode %||% ""))

    pl <- set_trace_text(pl, marker_idx, d$hover)
    pl <- skip_trace_hover(pl, setdiff(line_idx, marker_idx))

    plotly_cfg(pl)
  })

  output$eda_rel_corr <- renderPlotly({
    req(df())

    d <- df() %>% dplyr::select(-Year)

    name_map <- c(
      Production_ton   = "Prodhimi",
      Yield_ton_per_ha = "Rendimenti",
      Rainfall_mm      = "Reshjet"
    )

    corr_mat <- cor(d, use = "complete.obs")

    corr_df <- as.data.frame(as.table(corr_mat))
    colnames(corr_df) <- c("Var1", "Var2", "Korrelacioni")

    corr_df$Var1 <- factor(name_map[as.character(corr_df$Var1)], levels = name_map)
    corr_df$Var2 <- factor(name_map[as.character(corr_df$Var2)], levels = name_map)

    p <- ggplot(corr_df, aes(x = Var1, y = Var2, fill = Korrelacioni)) +
      geom_tile(color = scales::alpha("white", 0.35), linewidth = 0.4) +
      scale_fill_gradient2(
        low = "#0a84ff",
        mid = "white",
        high = "#ff3b30",
        midpoint = 0
      ) +
      geom_text(
        aes(label = fmt_fixed(Korrelacioni, digits = 2)),
        color = scales::alpha("black", 0.75),
        size = 4.2
      ) +
      labs(
        title = "Matrica e korrelacionit",
        x = NULL,
        y = NULL
      ) +
      theme_minimal(base_size = 13) +
      theme(
        panel.background = element_rect(fill = "transparent", color = NA),
        plot.background  = element_rect(fill = "transparent", color = NA),
        panel.grid = element_blank(),
        axis.text.x = element_text(color = scales::alpha("white", 0.92), size = 12),
        axis.text.y = element_text(color = scales::alpha("white", 0.92), size = 12),
        plot.title  = element_text(face = "bold", size = 15, color = scales::alpha("white", 0.95))
      )

    ggplotly(p, tooltip = "Korrelacioni") %>%
      layout(
        paper_bgcolor = "rgba(0,0,0,0)",
        plot_bgcolor  = "rgba(0,0,0,0)",
        margin = list(t = 60, l = 80, r = 20, b = 60)
      ) %>%
      plotly_cfg()
  })

  # =========================
  # Stacionariteti
  # =========================

  output$stat_diff_plot <- renderPlotly({
    req(df(), input$stat_series)

    m <- var_meta(input$stat_series)

    y <- ts(
      df()[[input$stat_series]],
      start = min(df()$Year),
      frequency = 1
    )

    dy <- diff(y)

    d <- data.frame(
      Viti = as.numeric(time(dy)),
      Diferenca = as.numeric(dy)
    ) %>%
      dplyr::mutate(
        hover = paste0(
          "Viti: ", Viti,
          "<br>Diferenca: ", fmt_by_var(Diferenca, input$stat_series, for_axis = FALSE), " ", m$unit
        )
      )

    p <- ggplot(d, aes(x = Viti, y = Diferenca)) +
      geom_line(linewidth = 1.2, color = "#0a84ff") +
      labs(
        title = paste0("Diferenca e parë – ", m$label),
        x = "Viti",
        y = "Vlera e diferencuar"
      ) +
      scale_y_continuous(labels = function(x) fmt_by_var(x, input$stat_series)) +
      theme_minimal(base_size = 13) +
      theme(
        panel.background = element_rect(fill = "transparent", color = NA),
        plot.background  = element_rect(fill = "transparent", color = NA),
        panel.grid.major = element_line(color = scales::alpha("white", 0.15)),
        panel.grid.minor = element_blank(),
        axis.text.x = element_text(color = scales::alpha("white", 0.92), size = 12),
        axis.text.y = element_text(color = scales::alpha("white", 0.92), size = 12),
        axis.title.x = element_text(color = scales::alpha("white", 0.85)),
        axis.title.y = element_text(color = scales::alpha("white", 0.85)),
        plot.title   = element_text(face = "bold", size = 15, color = scales::alpha("white", 0.95))
      )

    pl <- ggplotly(p, tooltip = NULL) %>%
      layout(
        paper_bgcolor = "rgba(0,0,0,0)",
        plot_bgcolor  = "rgba(0,0,0,0)",
        margin = list(t = 60, l = 70, r = 20, b = 60)
      )

    line_idx <- find_traces(pl, function(tr) grepl("lines", tr$mode %||% ""))[1]
    pl <- set_trace_text(pl, line_idx, d$hover)

    plotly_cfg(pl)
  })

  output$stat_acf_pacf <- renderPlotly({
    req(df(), input$stat_series)

    m <- var_meta(input$stat_series)

    y <- ts(
      df()[[input$stat_series]],
      start = min(df()$Year),
      frequency = 1
    )

    dy <- diff(y)

    acf_obj  <- acf(dy, plot = FALSE)
    pacf_obj <- pacf(dy, plot = FALSE)

    acf_df <- data.frame(
      Vonesa = as.numeric(acf_obj$lag[-1]),
      Vlera  = as.numeric(acf_obj$acf[-1]),
      Tipi   = "ACF"
    )

    pacf_df <- data.frame(
      Vonesa = as.numeric(pacf_obj$lag),
      Vlera  = as.numeric(pacf_obj$acf),
      Tipi   = "PACF"
    )

    df_plot <- rbind(acf_df, pacf_df)

    conf <- 1.96 / sqrt(length(dy))

    p <- ggplot(df_plot, aes(x = Vonesa, y = Vlera)) +
      geom_col(fill = scales::alpha("#0a84ff", 0.75), width = 0.7) +
      geom_hline(
        yintercept = c(-conf, conf),
        linetype = "dashed",
        color = scales::alpha("white", 0.6)
      ) +
      facet_wrap(~ Tipi, scales = "free_y", ncol = 1) +
      labs(
        title = paste0("ACF dhe PACF – ", m$label),
        x = "Vonesa (lag)",
        y = "Korrelacioni"
      ) +
      theme_minimal(base_size = 13) +
      theme(
        panel.background = element_rect(fill = "transparent", color = NA),
        plot.background  = element_rect(fill = "transparent", color = NA),
        panel.grid.major = element_line(color = scales::alpha("white", 0.15)),
        panel.grid.minor = element_blank(),
        strip.background = element_rect(fill = scales::alpha("white", 0.18), color = NA),
        strip.text       = element_text(color = scales::alpha("white", 0.95), face = "bold"),
        axis.text.x      = element_text(color = scales::alpha("white", 0.92), size = 11),
        axis.text.y      = element_text(color = scales::alpha("white", 0.92), size = 11),
        axis.title.x     = element_text(color = scales::alpha("white", 0.85)),
        axis.title.y     = element_text(color = scales::alpha("white", 0.85)),
        plot.title       = element_text(face = "bold", size = 15, color = scales::alpha("white", 0.95))
      )

    ggplotly(p, tooltip = c("Vonesa", "Vlera", "Tipi")) %>%
      layout(
        paper_bgcolor = "rgba(0,0,0,0)",
        plot_bgcolor  = "rgba(0,0,0,0)",
        margin = list(t = 70, l = 70, r = 20, b = 60)
      ) %>%
      plotly_cfg()
  })

  output$stat_adf_tbl <- renderTable({
    req(df(), input$stat_series)

    y <- ts(
      df()[[input$stat_series]],
      start = min(df()$Year),
      frequency = 1
    )

    dy <- diff(y)

    adf <- tseries::adf.test(dy)

    data.frame(
      Element = c("Statistika ADF", "Vlera p"),
      Vlera   = c(
        fmt_fixed(as.numeric(adf$statistic), digits = 4),
        fmt_fixed(as.numeric(adf$p.value), digits = 4)
      ),
      check.names = FALSE
    )
  })

  # =========================
  # Modelimi – ETS & ARIMA
  # =========================

  output$model_plot <- renderPlotly({
    req(df(), input$model_series, input$model_h)

    m <- var_meta(input$model_series)

    y <- ts(
      df()[[input$model_series]],
      start = min(df()$Year),
      frequency = 1
    )

    fit_ets   <- forecast::ets(y)
    fit_arima <- forecast::auto.arima(
      y,
      seasonal = FALSE,
      stepwise = FALSE,
      approximation = FALSE
    )

    fc_ets   <- forecast::forecast(fit_ets, h = input$model_h)
    fc_arima <- forecast::forecast(fit_arima, h = input$model_h)

    obs_df <- data.frame(
      Viti  = as.numeric(time(y)),
      Vlera = as.numeric(y),
      Tipi  = "Vëzhguar"
    )

    ets_df <- data.frame(
      Viti  = as.numeric(time(fc_ets$mean)),
      Vlera = as.numeric(fc_ets$mean),
      Tipi  = "ETS"
    )

    arima_df <- data.frame(
      Viti  = as.numeric(time(fc_arima$mean)),
      Vlera = as.numeric(fc_arima$mean),
      Tipi  = "ARIMA"
    )

    plot_df <- rbind(obs_df, ets_df, arima_df) %>%
      dplyr::mutate(
        hover = paste0(
          "Viti: ", Viti,
          "<br>", Tipi, ": ", fmt_unit(Vlera, input$model_series)
        )
      )

    p <- ggplot(plot_df, aes(x = Viti, y = Vlera, color = Tipi, group = Tipi)) +
      geom_line(linewidth = 1.1) +
      labs(
        title = paste0("Krahasimi i parashikimeve – ", m$label),
        x = "Viti",
        y = paste0(m$label, " (", m$unit, ")")
      ) +
      scale_y_continuous(labels = function(x) fmt_by_var(x, input$model_series)) +
      theme_minimal(base_size = 13) +
      theme(
        plot.background   = element_rect(fill = "transparent", color = NA),
        panel.background  = element_rect(fill = "transparent", color = NA),
        panel.grid.major  = element_line(color = scales::alpha("white", 0.18)),
        panel.grid.minor  = element_blank(),
        text              = element_text(color = "white"),
        plot.title        = element_text(color = "white", face = "bold"),
        axis.title        = element_text(color = "white"),
        axis.text         = element_text(color = "white"),
        legend.title      = element_blank(),
        legend.text       = element_text(color = "white"),
        legend.background = element_rect(fill = "transparent", color = NA),
        legend.key        = element_rect(fill = "transparent", color = NA)
      )

    pl <- ggplotly(p, tooltip = NULL) %>%
      layout(
        paper_bgcolor = "rgba(0,0,0,0)",
        plot_bgcolor  = "rgba(0,0,0,0)"
      )

    # vendos hover për secilën seri sipas emrit të traces
    by_type <- split(plot_df$hover, plot_df$Tipi)

    for (i in seq_along(pl$x$data)) {
      nm <- pl$x$data[[i]]$name %||% ""
      if (nm %in% names(by_type)) {
        pl$x$data[[i]]$text <- by_type[[nm]]
        pl$x$data[[i]]$hoverinfo <- "text"
      }
    }

    plotly_cfg(pl)
  })

  output$model_acc_tbl <- renderTable({
    req(df(), input$model_series)

    y <- ts(
      df()[[input$model_series]],
      start = min(df()$Year),
      frequency = 1
    )

    fit_ets   <- forecast::ets(y)
    fit_arima <- forecast::auto.arima(
      y,
      seasonal = FALSE,
      stepwise = FALSE,
      approximation = FALSE
    )

    acc_ets   <- forecast::accuracy(fit_ets)
    acc_arima <- forecast::accuracy(fit_arima)

    get_metric <- function(acc, metric) {
      val <- if ("Training set" %in% rownames(acc)) acc["Training set", metric] else acc[1, metric]
      as.numeric(val)
    }

    data.frame(
      Modeli = c("ETS", "ARIMA"),
      RMSE   = fmt_by_var(c(get_metric(acc_ets, "RMSE"), get_metric(acc_arima, "RMSE")), input$model_series, for_axis = FALSE),
      MAE    = fmt_by_var(c(get_metric(acc_ets, "MAE"),  get_metric(acc_arima, "MAE")),  input$model_series, for_axis = FALSE),
      MAPE   = fmt_fixed(c(get_metric(acc_ets, "MAPE"), get_metric(acc_arima, "MAPE")), digits = 2),
      check.names = FALSE
    )
  })

  # =========================================================
  # Parashikimi – Objekte reaktive
  # =========================================================

  series_ts <- reactive({
    req(df(), input$forecast_series)

    ts(
      df()[[input$forecast_series]],
      start = min(df()$Year),
      frequency = 1
    )
  })

  fitted_model <- reactive({
    req(series_ts(), input$method, input$h)

    y <- series_ts()

    if (input$method == "ses") {
      forecast::ses(y, h = input$h)
    } else if (input$method == "holt") {
      forecast::holt(y, h = input$h)
    } else {
      fit <- forecast::auto.arima(
        y,
        seasonal = FALSE,
        stepwise = FALSE,
        approximation = FALSE
      )
      forecast::forecast(fit, h = input$h)
    }
  })

  # =========================================================
  # Grafiku i parashikimit
  # =========================================================

  output$forecast_plot <- renderPlotly({
    req(series_ts(), fitted_model(), input$forecast_series)

    m <- var_meta(input$forecast_series)

    y_ts <- series_ts()
    fc   <- fitted_model()

    obs_df <- data.frame(
      Viti  = as.numeric(time(y_ts)),
      Vlera = as.numeric(y_ts)
    )

    fc_df <- data.frame(
      Viti = as.numeric(time(fc$mean)),
      Mesatarja = as.numeric(fc$mean),
      Poshtë80  = as.numeric(fc$lower[, "80%"]),
      Sipër80   = as.numeric(fc$upper[, "80%"])
    )

    obs_df$hover <- paste0(
      "Viti: ", obs_df$Viti,
      "<br>", m$label, ": ", fmt_unit(obs_df$Vlera, input$forecast_series)
    )

    fc_df$hover <- paste0(
      "Viti: ", fc_df$Viti,
      "<br>Parashikimi: ", fmt_unit(fc_df$Mesatarja, input$forecast_series),
      "<br>Intervali 80%: [", fmt_unit(fc_df$Poshtë80, input$forecast_series), " ; ", fmt_unit(fc_df$Sipër80, input$forecast_series), "]"
    )

    p <- ggplot() +
      geom_line(
        data = obs_df,
        aes(x = Viti, y = Vlera),
        color = "white",
        linewidth = 1
      ) +
      geom_ribbon(
        data = fc_df,
        aes(x = Viti, ymin = Poshtë80, ymax = Sipër80),
        fill = "white",
        alpha = 0.12
      ) +
      geom_line(
        data = fc_df,
        aes(x = Viti, y = Mesatarja),
        color = "white",
        linewidth = 1.2,
        linetype = "solid"
      ) +
      labs(
        title = paste0("Parashikimi – ", m$label, " (", toupper(input$method), ")"),
        x = "Viti",
        y = paste0(m$label, " (", m$unit, ")")
      ) +
      scale_y_continuous(labels = function(x) fmt_by_var(x, input$forecast_series)) +
      theme_minimal(base_size = 13) +
      theme(
        plot.background  = element_rect(fill = "transparent", color = NA),
        panel.background = element_rect(fill = "transparent", color = NA),
        panel.grid.major = element_line(color = scales::alpha("white", 0.12)),
        panel.grid.minor = element_blank(),
        text        = element_text(color = "white"),
        plot.title  = element_text(color = "white", face = "bold"),
        axis.title  = element_text(color = "white"),
        axis.text   = element_text(color = "white")
      )

    pl <- ggplotly(p, tooltip = NULL) %>%
      layout(
        paper_bgcolor = "rgba(0,0,0,0)",
        plot_bgcolor  = "rgba(0,0,0,0)",
        font = list(color = "white")
      )

    # Linjat (pa ribbon) -> vendos hover tekstin shqip
    line_idx <- find_traces(pl, function(tr) {
      (tr$type %||% "") == "scatter" &&
        grepl("lines", tr$mode %||% "") &&
        is.null(tr$fill)
    })

    if (length(line_idx) >= 1) {
      # e dallojmë sipas gjatësisë së serisë
      for (i in line_idx) {
        nx <- length(pl$x$data[[i]]$x %||% numeric(0))
        if (nx == nrow(obs_df)) {
          pl <- set_trace_text(pl, i, obs_df$hover)
        } else if (nx == nrow(fc_df)) {
          pl <- set_trace_text(pl, i, fc_df$hover)
        }
      }
    }

    plotly_cfg(pl)
  })

  # =========================================================
  # Saktësia e parashikimit (seti i trajnimit)
  # =========================================================

  output$forecast_metrics <- renderUI({
    req(fitted_model())

    acc <- tryCatch(
      forecast::accuracy(fitted_model()),
      error = function(e) NULL
    )

    if (is.null(acc)) {
      div(
        class = "section-box",
        p("Saktësia nuk u llogarit. Ju lutemi kontrolloni modelin dhe paketat e instaluara.")
      )
    } else {
      div(
        class = "section-box",
        h4("Saktësia në setin e trajnimit"),
        tableOutput("acc_tbl")
      )
    }
  })

  output$acc_tbl <- renderTable({
    acc <- forecast::accuracy(fitted_model())

    if ("Training set" %in% rownames(acc)) {
      a <- acc["Training set", c("ME", "MAE", "RMSE", "MAPE")]
    } else {
      a <- acc[1, c("ME", "MAE", "RMSE", "MAPE")]
    }

    data.frame(
      Treguesi = c(
        "Gabimi mesatar (ME)",
        "Gabimi mesatar absolut (MAE)",
        "Rrënja e gabimit mesatar katror (RMSE)",
        "Gabimi mesatar absolut përqindor (MAPE)"
      ),
      Vlera = c(
        fmt_by_var(as.numeric(a["ME"]),   input$forecast_series, for_axis = FALSE),
        fmt_by_var(as.numeric(a["MAE"]),  input$forecast_series, for_axis = FALSE),
        fmt_by_var(as.numeric(a["RMSE"]), input$forecast_series, for_axis = FALSE),
        fmt_fixed(as.numeric(a["MAPE"]), digits = 2)
      ),
      check.names = FALSE
    )
  })
}
