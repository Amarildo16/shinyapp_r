server_plots <- function(input, output, session, df) {
  # =========================================================
  # 0) Dynamic selectors
  # =========================================================

  time_col <- reactive({
    req(df())
    nm <- names(df())

    tc <- input$data_time_col %||% input$time_col %||% NULL
    if (!is.null(tc) && tc %in% nm) return(tc)

    if ("Year" %in% nm) return("Year")

    cand <- detect_time_candidates(df())
    best <- cand$col[1]
    best
  })

  value_cols <- reactive({
    req(df())
    nm <- names(df())

    vc <- input$data_value_cols %||% input$value_cols %||% NULL
    if (!is.null(vc)) {
      vc <- vc[vc %in% nm]
      if (length(vc) > 0) return(vc)
    }

    d <- df()
    tc <- time_col()

    cols <- setdiff(names(d), tc)

    num_candidates <- cols[vapply(d[cols], function(x) {
      xn <- to_numeric_safe(x)
      mean(!is.na(xn)) >= 0.70
    }, logical(1))]

    num_candidates
  })

  meta <- reactive({
    build_meta(value_cols())
  })

  df_dyn <- reactive({
    req(df(), time_col())
    d <- df()

    vc <- value_cols()
    req(length(vc) > 0)

    for (v in vc) d[[v]] <- to_numeric_safe(d[[v]])

    d <- make_df_dyn(d, time_col())
    d <- d[, c("Time", vc), drop = FALSE]
    dup <- input$data_dup %||% "mean"
    d <- apply_dup_policy(d, vc = vc, method = dup)
    fr <- input$data_freq %||% "auto"
    d <- apply_freq_policy(d, freq = fr, vc = vc)

    d
  })

  time_range_txt <- reactive({
    req(df_dyn())
    tt <- df_dyn()$Time
    rng <- range(tt, na.rm = TRUE)
    paste0(fmt_time(rng[1]), " – ", fmt_time(rng[2]))
  })

  n_series_txt <- reactive({
    paste0(length(value_cols()))
  })

  # =========================================================
  # 1) Tabela – Përmbledhje
  # =========================================================

  output$data_info_tbl <- renderTable({
    req(df_dyn())

    d  <- df_dyn()
    tt <- d$Time

    data.frame(
      Element = c(
        paste0(time_axis_label(tt), " fillestare"),
        paste0(time_axis_label(tt), " përfundimtare"),
        "Numri i vrojtimeve",
        "Numri i serive numerike",
        "Burimi i të dhënave"
      ),
      Vlera = c(
        fmt_time(min(tt, na.rm = TRUE)),
        fmt_time(max(tt, na.rm = TRUE)),
        as.character(nrow(d)),
        n_series_txt(),
        input$data_source %||% "Përdoruesi (dataset i ngarkuar)"
      ),
      check.names = FALSE
    )
  })

  # =========================================================
  # 2) Lista e variablave
  # =========================================================

  output$variables_tbl <- renderTable({
    req(value_cols())

    vc <- value_cols()

    data.frame(
      Variabla = vapply(vc, function(v) {
        m <- var_meta(v, meta())
        if (nzchar(m$unit)) paste0(m$label, " (", m$unit, ")")
        else m$label
      }, character(1)),
      Përshkrimi = rep("Seri numerike e ngarkuar nga përdoruesi.", length(vc)),
      check.names = FALSE
    )
  })

  # =========================================================
  # 3) Tabela statistikore
  # =========================================================

  output$summary_tbl <- renderTable({
    req(df_dyn(), value_cols())

    d  <- df_dyn()
    vc <- value_cols()

    if (is.null(vc) || length(vc) == 0) {
      return(data.frame(Mesazh = "Zgjidh të paktën 1 seri numerike.", check.names = FALSE))
    }

    X <- setNames(lapply(vc, function(v) to_numeric_safe(d[[v]])), vc)

    safe_stat <- function(x, fun) {
      x <- x[!is.na(x)]
      if (length(x) == 0) return(NA_real_)
      fun(x)
    }

    safe_sd <- function(x) {
      x <- x[!is.na(x)]
      if (length(x) < 2) return(NA_real_)
      stats::sd(x)
    }

    out <- data.frame(
      Variabla = vc,
      Mesatarja = vapply(vc, function(v) safe_stat(X[[v]], base::mean), numeric(1)),
      `Devijimi standard` = vapply(vc, function(v) safe_sd(X[[v]]), numeric(1)),
      Minimumi = vapply(vc, function(v) safe_stat(X[[v]], base::min), numeric(1)),
      Maksimumi = vapply(vc, function(v) safe_stat(X[[v]], base::max), numeric(1)),
      `N (jo-NA)` = vapply(vc, function(v) sum(!is.na(X[[v]])), integer(1)),
      `Missing %` = vapply(vc, function(v) round(100 * mean(is.na(X[[v]])), 2), numeric(1)),
      check.names = FALSE
    )

    out$Variabla <- vapply(vc, function(v) {
      m <- var_meta(v, meta())
      if (!is.null(m$unit) && nzchar(m$unit)) paste0(m$label, " (", m$unit, ")")
      else m$label
    }, character(1))

    mean_num <- out$Mesatarja
    sd_num   <- out$`Devijimi standard`
    min_num  <- out$Minimumi
    max_num  <- out$Maksimumi

    fmt_safe <- function(x) {
      if (is.na(x)) return(NA_character_)
      fmt_by_series(as.numeric(x), for_axis = FALSE)
    }

    out$Mesatarja <- vapply(mean_num, fmt_safe, character(1))
    out$`Devijimi standard` <- vapply(sd_num, fmt_safe, character(1))
    out$Minimumi  <- vapply(min_num, fmt_safe, character(1))
    out$Maksimumi <- vapply(max_num, fmt_safe, character(1))

    out
  })

  # =========================================================
  # 4) fmt_pct
  # =========================================================
  fmt_pct <- function(x) {
    if (is.na(x)) return("N/A")
    if (x > 0)  return(paste0("+", sprintf("%.2f", x), "% / vit"))
    if (x < 0)  return(paste0(sprintf("%.2f", x), "% / vit"))
    "0.00% / vit"
  }
  
  # ========================= 
  # EDA – Seri kohore 
  # =========================

  output$eda_ts_raw <- renderPlotly({
    req(df_dyn(), input$eda_series)

    m <- var_meta(input$eda_series, meta())
    d0 <- df_dyn()

    xlab <- time_axis_label(d0$Time)

    d <- d0 %>%
      dplyr::select(Time, value = dplyr::all_of(input$eda_series)) %>%
      dplyr::mutate(
        hover = paste0(
          xlab, ": ", fmt_time(Time),
          "<br>", m$label, ": ", fmt_unit(value, input$eda_series, meta())
        )
      )

    p <- ggplot(d, aes(x = Time, y = value)) +
      geom_line(linewidth = 1, color = "white") +
      labs(
        title = paste0("Seria kohore e vëzhguar – ", m$label),
        x = xlab,
        y = if (nzchar(m$unit)) paste0(m$label, " (", m$unit, ")") else m$label
      ) +
      scale_y_continuous(labels = function(x) fmt_by_series(x, for_axis = TRUE)) +
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
    req(df_dyn(), input$eda_series, input$roll_k)

    if (!requireNamespace("zoo", quietly = TRUE)) {
      showNotification("Paketa 'zoo' mungon. Instalo: install.packages('zoo')", type = "error")
      return(NULL)
    }

    m <- var_meta(input$eda_series, meta())
    d0 <- df_dyn()
    xlab <- time_axis_label(d0$Time)

    # -------------------------
    # roll_k
    # -------------------------
    y <- d0[[input$eda_series]]
    n_non_na <- sum(!is.na(y))

    k <- input$roll_k
    if (is.null(k) || is.na(k)) k <- 5
    k <- as.integer(k)
    k <- max(2L, k)

    if (n_non_na < 3) {
      showNotification("Seria ka shumë pak vlera reale (jo-NA) për rolling mean.", type = "warning")
      return(NULL)
    }

    k_max <- max(2L, n_non_na - 1L)
    if (k > k_max) {
      k <- k_max
      showNotification(
        paste0("roll_k u përshtat automatikisht në k=", k,
              " (seri ka ", n_non_na, " vlera jo-NA)."),
        type = "message"
      )
    }

    # -------------------------
    # Rolling mean NA-friendly
    # -------------------------
    d <- d0 %>%
      dplyr::arrange(Time) %>%
      dplyr::mutate(
        roll_mean = zoo::rollapply(
          .data[[input$eda_series]],
          width = k,
          FUN = function(z) {
            if (all(is.na(z))) NA_real_
            else mean(z, na.rm = TRUE)
          },
          fill = NA,
          align = "right",
          partial = FALSE
        )
      ) %>%
      dplyr::mutate(
        hover_raw = paste0(
          xlab, ": ", fmt_time(Time),
          "<br>", m$label, ": ", fmt_unit(.data[[input$eda_series]], input$eda_series, meta())
        ),
        hover_roll = ifelse(
          is.na(roll_mean),
          NA_character_,
          paste0(
            xlab, ": ", fmt_time(Time),
            "<br>Mesatare lëvizëse: ", fmt_unit(roll_mean, input$eda_series, meta())
          )
        )
      )

    p <- ggplot(d, aes(x = Time)) +
      geom_line(
        aes(y = .data[[input$eda_series]]),
        color = scales::alpha("white", 0.35),
        linewidth = 0.9
      ) +
      geom_line(
        aes(y = roll_mean),
        color = "#ff3b30",
        linewidth = 1.6
      ) +
      labs(
        title = paste0("Mesatarja lëvizëse (k = ", k, ")"),
        subtitle = if (nzchar(m$unit)) paste0(m$label, " (", m$unit, ")") else m$label,
        x = NULL,
        y = NULL
      ) +
      scale_y_continuous(labels = function(x) fmt_by_series(x, for_axis = TRUE)) +
      theme_minimal(base_size = 13) +
      theme(
        panel.background = element_rect(fill = "transparent", color = NA),
        plot.background  = element_rect(fill = "transparent", color = NA),
        panel.grid.major = element_line(color = scales::alpha("white", 0.12), linewidth = 0.3),
        panel.grid.minor = element_blank(),
        axis.text     = element_text(color = scales::alpha("white", 0.92)),
        plot.title    = element_text(face = "bold", color = scales::alpha("white", 0.95)),
        plot.subtitle = element_text(color = scales::alpha("white", 0.75))
      )

    pl <- ggplotly(p, tooltip = NULL) %>%
      layout(
        paper_bgcolor = "rgba(0,0,0,0)",
        plot_bgcolor  = "rgba(0,0,0,0)",
        margin = list(t = 60, l = 40, r = 20, b = 40),
        hovermode = "x unified",
        font  = list(color = "white"),
        xaxis = list(
          gridcolor     = "rgba(255,255,255,0.15)",
          zerolinecolor = "rgba(255,255,255,0.15)",
          tickfont      = list(color = "white")
        ),
        yaxis = list(
          gridcolor     = "rgba(255,255,255,0.15)",
          zerolinecolor = "rgba(255,255,255,0.15)",
          tickfont      = list(color = "white")
        )
      )

    line_idx <- find_traces(pl, function(tr) {
      (tr$type %||% "") == "scatter" && grepl("lines", tr$mode %||% "")
    })

    if (length(line_idx) >= 1) pl <- set_trace_text(pl, line_idx[1], d$hover_raw)
    if (length(line_idx) >= 2) pl <- set_trace_text(pl, line_idx[2], d$hover_roll)

    plotly_cfg(pl)
  })

  output$eda_ts_dist <- renderPlotly({
    req(df_dyn(), input$eda_series)

    m <- var_meta(input$eda_series, meta())

    d <- df_dyn() %>%
      dplyr::mutate(val = .data[[input$eda_series]])

    p <- ggplot(d, aes(x = val)) +
      geom_histogram(
        aes(y = after_stat(density)),
        bins = 18,
        fill  = scales::alpha("#0a84ff", 0.35),
        color = scales::alpha("white", 0.18)
      ) +
      geom_density(
        color = "#ff3b30",
        linewidth = 1.4
      ) +
      labs(
        title = "Shpërndarja",
        subtitle = if (nzchar(m$unit)) paste0(m$label, " (", m$unit, ")") else m$label,
        x = NULL,
        y = NULL
      ) +
      scale_x_continuous(labels = function(x) fmt_by_series(x, for_axis = TRUE)) +
      theme_minimal(base_size = 13) +
      theme(
        panel.background = element_rect(fill = "transparent", color = NA),
        plot.background  = element_rect(fill = "transparent", color = NA),

        panel.grid.major = element_line(color = scales::alpha("white", 0.12), linewidth = 0.3),
        panel.grid.minor = element_blank(),

        axis.text     = element_text(color = scales::alpha("white", 0.92)),
        plot.title    = element_text(face = "bold", color = scales::alpha("white", 0.95)),
        plot.subtitle = element_text(color = scales::alpha("white", 0.75))
      )

    pl <- ggplotly(p, tooltip = NULL) %>%
      layout(
        paper_bgcolor = "rgba(0,0,0,0)",
        plot_bgcolor  = "rgba(0,0,0,0)",
        margin = list(t = 60, l = 40, r = 20, b = 40),

        font  = list(color = "white"),
        xaxis = list(
          gridcolor     = "rgba(255,255,255,0.15)",
          zerolinecolor = "rgba(255,255,255,0.15)",
          tickfont      = list(color = "white")
        ),
        yaxis = list(
          gridcolor     = "rgba(255,255,255,0.15)",
          zerolinecolor = "rgba(255,255,255,0.15)",
          tickfont      = list(color = "white")
        )
      )

    pl <- skip_trace_hover(pl, seq_along(pl$x$data))

    plotly_cfg(pl)
  })

  # =========================
  # EDA – Marrëdhënie
  # =========================

  output$eda_rel_scatter <- renderPlotly({
    req(df_dyn(), input$rel_x, input$rel_y)

    mx <- var_meta(input$rel_x, meta())
    my <- var_meta(input$rel_y, meta())

    d0 <- df_dyn()
    xlab_time <- time_axis_label(d0$Time)

    d <- d0 %>%
      dplyr::mutate(
        xval = .data[[input$rel_x]],
        yval = .data[[input$rel_y]],
        hover = paste0(
          xlab_time, ": ", fmt_time(Time),
          "<br>", mx$label, ": ", fmt_unit(xval, input$rel_x, meta()),
          "<br>", my$label, ": ", fmt_unit(yval, input$rel_y, meta())
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
        x = if (nzchar(mx$unit)) paste0(mx$label, " (", mx$unit, ")") else mx$label,
        y = if (nzchar(my$unit)) paste0(my$label, " (", my$unit, ")") else my$label
      ) +
      scale_x_continuous(labels = function(x) fmt_by_series(x, for_axis = TRUE)) +
      scale_y_continuous(labels = function(x) fmt_by_series(x, for_axis = TRUE)) +
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
    req(df_dyn())

    d0 <- df_dyn()

    tc <- NULL
    if (exists("time_col")) {
      tc <- tryCatch(time_col(), error = function(e) NULL)
    }

    num_df <- d0 %>%
      dplyr::select(where(is.numeric)) %>%
      dplyr::select(-dplyr::any_of(c("Time", tc)))

    if (ncol(num_df) < 2) {
      showNotification("Duhet të paktën 2 kolona numerike për korrelacion.", type = "warning")
      return(NULL)
    }

    if (ncol(num_df) > 20) {
      num_df <- num_df[, 1:20, drop = FALSE]
      showNotification("U përdorën vetëm 20 kolonat e para numerike për heatmap.", type = "message")
    }

    corr_mat <- cor(num_df, use = "complete.obs")

    corr_df <- as.data.frame(as.table(corr_mat))
    colnames(corr_df) <- c("Var1", "Var2", "Korrelacioni")

    vars <- colnames(num_df)
    corr_df$Var1 <- factor(as.character(corr_df$Var1), levels = vars)
    corr_df$Var2 <- factor(as.character(corr_df$Var2), levels = vars)

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
  # Stacionariteti (DINAMIK)
  # =========================

  output$stat_diff_plot <- renderPlotly({
    req(df_dyn(), input$stat_series)

    m  <- var_meta(input$stat_series, meta())
    d0 <- df_dyn()
    xlab <- time_axis_label(d0$Time)

    dd <- d0 %>%
      dplyr::select(Time, y = dplyr::all_of(input$stat_series)) %>%
      dplyr::arrange(Time) %>%
      dplyr::filter(!is.na(y))

    if (nrow(dd) < 3) {
      showNotification("Seria ka shumë pak vlera reale (jo-NA) për diferencë të parë.", type = "warning")
      return(NULL)
    }

    dy <- diff(dd$y)
    tt <- dd$Time[-1]

    d <- data.frame(
      Time = tt,
      Diferenca = as.numeric(dy),
      stringsAsFactors = FALSE
    ) %>%
      dplyr::mutate(
        hover = paste0(
          xlab, ": ", fmt_time(Time),
          "<br>Diferenca: ", fmt_unit(Diferenca, input$stat_series, meta())
        )
      )

    p <- ggplot(d, aes(x = Time, y = Diferenca)) +
      geom_line(linewidth = 1.2, color = "#0a84ff") +
      labs(
        title = paste0("Diferenca e parë – ", m$label),
        x = xlab,
        y = "Vlera e diferencuar"
      ) +
      scale_y_continuous(labels = function(x) fmt_by_series(x, for_axis = TRUE)) +
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
        margin = list(t = 60, l = 70, r = 20, b = 60),
        font  = list(color = "white"),
        xaxis = list(gridcolor = "rgba(255,255,255,0.15)"),
        yaxis = list(gridcolor = "rgba(255,255,255,0.15)")
      )

    line_idx <- find_traces(pl, function(tr) grepl("lines", tr$mode %||% ""))[1]
    pl <- set_trace_text(pl, line_idx, d$hover)

    plotly_cfg(pl)
  })

  output$stat_acf_pacf <- renderPlotly({
    req(df_dyn(), input$stat_series)

    m  <- var_meta(input$stat_series, meta())
    d0 <- df_dyn()

    dd <- d0 %>%
      dplyr::select(Time, y = dplyr::all_of(input$stat_series)) %>%
      dplyr::arrange(Time) %>%
      dplyr::filter(!is.na(y))

    if (nrow(dd) < 6) {
      showNotification("Duhet të paktën ~6 vlera reale për ACF/PACF (pas diferencës humbet 1).", type="warning")
      return(NULL)
    }

    dy <- diff(dd$y)
    n  <- length(dy)

    if (n < 5) {
      showNotification("Seria e diferencuar ka shumë pak pika për ACF/PACF.", type="warning")
      return(NULL)
    }

    acf_obj  <- acf(dy, plot = FALSE)
    pacf_obj <- pacf(dy, plot = FALSE)

    acf_df <- data.frame(
      Vonesa = as.numeric(acf_obj$lag[-1]),
      Vlera  = as.numeric(acf_obj$acf[-1]),
      Tipi   = "ACF",
      stringsAsFactors = FALSE
    )

    pacf_df <- data.frame(
      Vonesa = as.numeric(pacf_obj$lag),
      Vlera  = as.numeric(pacf_obj$acf),
      Tipi   = "PACF",
      stringsAsFactors = FALSE
    )

    df_plot <- rbind(acf_df, pacf_df)
    conf <- 1.96 / sqrt(n)

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
    req(df_dyn(), input$stat_series)

    d0 <- df_dyn()
    y  <- d0[[input$stat_series]]
    y  <- as.numeric(y)
    y  <- y[!is.na(y)]

    if (length(y) < 20) {
      return(data.frame(
        Serie = c("Original (niveli)", "First difference (Δ)"),
        Statistic = NA_real_,
        `p-value` = NA_real_,
        Method = "ADF (tseries::adf.test) — kërkon ≥ 20 pika",
        check.names = FALSE
      ))
    }

    adf_lvl  <- try(tseries::adf.test(y), silent = TRUE)
    dy <- diff(y)
    adf_diff <- if (length(dy) >= 20) try(tseries::adf.test(dy), silent = TRUE) else "try-error"

    extract_adf <- function(obj, label) {
      if (inherits(obj, "try-error")) {
        return(data.frame(
          Serie = label,
          Statistic = NA_real_,
          `p-value` = NA_real_,
          Method = "ADF (tseries::adf.test)",
          stringsAsFactors = FALSE,
          check.names = FALSE
        ))
      }
      data.frame(
        Serie = label,
        Statistic = as.numeric(obj$statistic),
        `p-value` = as.numeric(obj$p.value),
        Method = obj$method,
        stringsAsFactors = FALSE,
        check.names = FALSE
      )
    }

    out <- rbind(
      extract_adf(adf_lvl,  "Original (niveli)"),
      extract_adf(adf_diff, "First difference (Δ)")
    )

    out$Statistic <- round(out$Statistic, 4)
    out$`p-value` <- formatC(out$`p-value`, format = "f", digits = 4)

    out
  }, striped = FALSE, bordered = TRUE, spacing = "s")

  output$stat_adf_note <- renderUI({
    req(df_dyn(), input$stat_series)

    m <- var_meta(input$stat_series, meta())
    d0 <- df_dyn()

    y <- as.numeric(d0[[input$stat_series]])
    y <- y[!is.na(y)]

    alpha <- 0.05

    if (length(y) < 20) {
      return(HTML(
        "<p style='margin-top:10px; font-size: 13px; line-height: 1.45;'>
          <b>Interpretim (ADF):</b> Seria ka shumë pak pika (duhen ≥ 20) për test të besueshëm.
        </p>"
      ))
    }

    adf_lvl  <- try(tseries::adf.test(y), silent = TRUE)
    adf_diff <- if (length(diff(y)) >= 20) try(tseries::adf.test(diff(y)), silent = TRUE) else "try-error"

    get_p <- function(obj) {
      if (inherits(obj, "try-error")) return(NA_real_)
      as.numeric(obj$p.value)
    }

    p_lvl  <- get_p(adf_lvl)
    p_diff <- get_p(adf_diff)

    concl_lvl <- if (!is.na(p_lvl) && p_lvl < alpha) {
      "refuzohet hipoteza zero dhe seria në nivel vlerësohet stacionare"
    } else if (!is.na(p_lvl)) {
      "nuk refuzohet hipoteza zero dhe seria në nivel sugjeron jo-stacionaritet"
    } else {
      "testi për serinë në nivel nuk u llogarit (gabim gjatë ekzekutimit)"
    }

    concl_diff <- if (!is.na(p_diff) && p_diff < alpha) {
      "pas diferencës së parë refuzohet hipoteza zero dhe seria e diferencuar vlerësohet stacionare"
    } else if (!is.na(p_diff)) {
      "edhe pas diferencës së parë nuk refuzohet hipoteza zero"
    } else {
      "testi për serinë e diferencuar nuk u llogarit (gabim gjatë ekzekutimit)"
    }

    p_txt_lvl  <- ifelse(is.na(p_lvl),  "NA", formatC(p_lvl,  format = "f", digits = 4))
    p_txt_diff <- ifelse(is.na(p_diff), "NA", formatC(p_diff, format = "f", digits = 4))

    unit_txt <- if (nzchar(m$unit %||% "")) paste0(" (", m$unit, ")") else ""

    HTML(paste0(
      "<p style='margin-top:10px; font-size: 13px; line-height: 1.45;'>",
      "<b>Interpretim (ADF):</b> Për serinë <i>", m$label, "</i>", unit_txt, ", ",
      "hipoteza zero e testit ADF është se seria ka rrënjë njësi (pra është jo-stacionare). ",
      "Me nivel rëndësie &alpha; = 0.05: ",
      "<br>• <b>Niveli</b> (p = ", p_txt_lvl, "): ", concl_lvl, ".",
      "<br>• <b>Diferenca e parë</b> (p = ", p_txt_diff, "): ", concl_diff, ".",
      "</p>"
    ))
  })

  # =========================
  # Modelimi – ETS & ARIMA
  # =========================

  output$model_plot <- renderPlotly({
    req(df_dyn(), input$model_series, input$model_h)

    m  <- var_meta(input$model_series, meta())
    d0 <- df_dyn()
    xlab <- time_axis_label(d0$Time)

    dd <- d0 %>%
      dplyr::select(Time, y = dplyr::all_of(input$model_series)) %>%
      dplyr::arrange(Time) %>%
      dplyr::filter(!is.na(y))

    n <- nrow(dd)
    if (n < 20) {
      showNotification("Për ETS/ARIMA rekomandohen ≥ 20 pika reale (jo-NA).", type = "warning")
      return(NULL)
    }

    h <- as.integer(input$model_h)
    if (is.na(h) || h < 1) h <- 1
    if (h > floor(n/2)) {
      showNotification("Kujdes: h është i madh krahasuar me të dhënat (h > n/2).", type = "message")
    }

    y <- as.numeric(dd$y)

    fast_arima <- n > 5000
    arima_stepwise <- if (fast_arima) TRUE else FALSE
    arima_approx   <- if (fast_arima) TRUE else FALSE

    fit_ets <- try(forecast::ets(y), silent = TRUE)
    seasonal_flag <- frequency(y) %in% c(4, 12)
    fit_arima <- try(
      forecast::auto.arima(
        y,
        seasonal = seasonal_flag,
        stepwise = arima_stepwise,
        approximation = arima_approx
      ),
      silent = TRUE
    )

    if (inherits(fit_ets, "try-error") || inherits(fit_arima, "try-error")) {
      showNotification("Modelimi dështoi për ETS ose ARIMA (kontrollo të dhënat / NA / seri konstante).", type="error")
      return(NULL)
    }

    fc_ets   <- forecast::forecast(fit_ets,   h = h)
    fc_arima <- forecast::forecast(fit_arima, h = h)

    future_time <- make_future_time(dd$Time, h)

    obs_df <- data.frame(
      Time  = dd$Time,
      Vlera = y,
      Tipi  = "Vëzhguar",
      stringsAsFactors = FALSE
    )

    ets_df <- data.frame(
      Time  = future_time,
      Vlera = as.numeric(fc_ets$mean),
      Tipi  = "ETS",
      stringsAsFactors = FALSE
    )

    arima_df <- data.frame(
      Time  = future_time,
      Vlera = as.numeric(fc_arima$mean),
      Tipi  = "ARIMA",
      stringsAsFactors = FALSE
    )

    plot_df <- rbind(obs_df, ets_df, arima_df) %>%
      dplyr::mutate(
        hover = paste0(
          xlab, ": ", fmt_time(Time),
          "<br>", Tipi, ": ", fmt_unit(Vlera, input$model_series, meta())
        )
      )

    p <- ggplot(plot_df, aes(x = Time, y = Vlera, color = Tipi, group = Tipi)) +
      geom_line(linewidth = 1.1) +
      scale_color_manual(values = c(
        "Vëzhguar" = "white",
        "ETS"      = "#0a84ff",
        "ARIMA"    = "#ff3b30"
      )) +
      labs(
        title = paste0("Krahasimi i parashikimeve – ", m$label),
        x = xlab,
        y = if (nzchar(m$unit)) paste0(m$label, " (", m$unit, ")") else m$label
      ) +
      scale_y_continuous(labels = function(x) fmt_by_series(x, for_axis = TRUE)) +
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
        plot_bgcolor  = "rgba(0,0,0,0)",
        font  = list(color = "white"),
        xaxis = list(gridcolor = "rgba(255,255,255,0.15)"),
        yaxis = list(gridcolor = "rgba(255,255,255,0.15)")
      )

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
    req(df_dyn(), input$model_series)

    m  <- var_meta(input$model_series, meta())
    d0 <- df_dyn()

    dd <- d0 %>%
      dplyr::select(Time, y = dplyr::all_of(input$model_series)) %>%
      dplyr::arrange(Time) %>%
      dplyr::filter(!is.na(y))

    n <- nrow(dd)
    if (n < 20) {
      return(data.frame(
        Modeli = c("ETS", "ARIMA"),
        RMSE = NA_character_,
        MAE  = NA_character_,
        MAPE = NA_character_,
        check.names = FALSE
      ))
    }

    y <- as.numeric(dd$y)

    fit_ets <- try(forecast::ets(y), silent = TRUE)

    fast_arima <- n > 5000
    fit_arima <- try(
      forecast::auto.arima(
        y,
        seasonal = FALSE,
        stepwise = if (fast_arima) TRUE else FALSE,
        approximation = if (fast_arima) TRUE else FALSE
      ),
      silent = TRUE
    )

    if (inherits(fit_ets, "try-error") || inherits(fit_arima, "try-error")) {
      return(data.frame(
        Modeli = c("ETS", "ARIMA"),
        RMSE = NA_character_,
        MAE  = NA_character_,
        MAPE = NA_character_,
        check.names = FALSE
      ))
    }

    acc_ets   <- forecast::accuracy(fit_ets)
    acc_arima <- forecast::accuracy(fit_arima)

    get_metric <- function(acc, metric) {
      val <- if ("Training set" %in% rownames(acc)) acc["Training set", metric] else acc[1, metric]
      as.numeric(val)
    }

    add_unit <- function(txt) {
      u <- m$unit %||% ""
      if (nzchar(u)) paste0(txt, " ", u) else txt
    }

    rmse_vals <- c(get_metric(acc_ets, "RMSE"), get_metric(acc_arima, "RMSE"))
    mae_vals  <- c(get_metric(acc_ets, "MAE"),  get_metric(acc_arima, "MAE"))
    mape_vals <- c(get_metric(acc_ets, "MAPE"), get_metric(acc_arima, "MAPE"))

    data.frame(
      Modeli = c("ETS", "ARIMA"),
      RMSE   = vapply(rmse_vals, function(v) add_unit(fmt_by_series(v, for_axis = FALSE)), character(1)),
      MAE    = vapply(mae_vals,  function(v) add_unit(fmt_by_series(v, for_axis = FALSE)), character(1)),
      MAPE   = fmt_fixed(mape_vals, digits = 2),
      check.names = FALSE
    )
  })

  # =========================================================
  # Parashikimi – Objekte reaktive (DINAMIK)
  # =========================================================

  series_dat <- reactive({
    req(df_dyn(), input$forecast_series)

    d0 <- df_dyn()

    if (!(input$forecast_series %in% names(d0))) {
      showNotification("Seria e zgjedhur s’gjendet në dataset.", type = "error")
      return(NULL)
    }

    if (any(duplicated(dd$Time))) {
      dd <- dd %>%
        dplyr::group_by(Time) %>%
        dplyr::summarise(y = mean(y, na.rm = TRUE), .groups = "drop") %>%
        dplyr::arrange(Time)

      dd$y[is.nan(dd$y)] <- NA_real_

      showNotification("U gjetën duplikate në kohë; u agreguan me mesatare (mean).", type = "message")
    }

    if (sum(!is.na(dd$y)) < 2) {
      showNotification("Duhet të paktën 2 pika reale (jo-NA) për parashikim.", type = "warning")
      return(NULL)
    }

    if (any(duplicated(dd$Time))) {
      dd <- dd %>%
        dplyr::group_by(Time) %>%
        dplyr::summarise(y = mean(y, na.rm = TRUE), .groups = "drop") %>%
        dd$y[is.nan(dd$y)] <- NA_real_
        dplyr::arrange(Time)

      showNotification("U gjetën duplikate në kohë; u agreguan me mesatare (mean).", type = "message")
    }

    if (stats::sd(dd$y, na.rm = TRUE) < 1e-12) {
      showNotification("Seria është (pothuaj) konstante — parashikimi s’ka kuptim.", type = "warning")
      return(NULL)
    }

    dd
  })

  series_ts <- reactive({
    req(series_dat())
    dd <- series_dat()

    spec <- ts_spec_from_time(dd$Time, input$data_freq %||% "auto")
    yts  <- ts(as.numeric(dd$y), frequency = spec$freq, start = spec$start)

    # nëse apply_freq_policy futi boshllëqe (NA), i plotësojmë vetëm për modelim
    if (anyNA(yts)) {
      yts <- forecast::na.interp(yts)
    }

    yts
  })

  fitted_model <- reactive({
    req(series_ts(), input$method, input$h)

    y <- series_ts()
    n <- length(y)

    h <- as.integer(input$h)
    if (is.na(h) || h < 1) h <- 1

    if (h > floor(n / 2)) {
      showNotification("Kujdes: h është i madh krahasuar me të dhënat (h > n/2).", type = "message")
    }

    if (input$method %in% c("ses", "holt") && n < 2) {
      showNotification("SES/Holt kërkojnë ≥ 2 pika.", type = "warning")
      return(NULL)
    }

    if (!(input$method %in% c("ses", "holt", "arima"))) {
      showNotification("Metodë e panjohur. Lejohen: ses, holt, arima.", type = "error")
      return(NULL)
    }

    if (input$method == "ses") {
      return(forecast::ses(y, h = h))
    }

    if (input$method == "holt") {
      return(forecast::holt(y, h = h))
    }

    if (n < 30) {
      showNotification("Për ARIMA rekomandohen ≥ 30 pika reale. Zgjidh SES/Holt ose shto të dhëna.", type = "warning")
      return(NULL)
    }

    fast_arima <- n > 5000

    seasonal_flag <- frequency(y) %in% c(4, 12)
    fit <- try(
      forecast::auto.arima(
        y,
        seasonal = seasonal_flag,
        stepwise = if (fast_arima) TRUE else FALSE,
        approximation = if (fast_arima) TRUE else FALSE
      ),
      silent = TRUE
    )

    if (inherits(fit, "try-error")) {
      showNotification("ARIMA dështoi (kontrollo të dhënat / missing / seri konstante).", type = "error")
      return(NULL)
    }

    forecast::forecast(fit, h = h)
  })

  # =========================================================
  # Grafiku i parashikimit (DINAMIK me Time)
  # =========================================================

  output$forecast_plot <- renderPlotly({
    req(series_dat(), fitted_model(), input$forecast_series, input$h, input$method)

    m  <- var_meta(input$forecast_series, meta())
    dd <- series_dat()
    fc <- fitted_model()

    xlab <- time_axis_label(dd$Time)

    obs_df <- data.frame(
      Time  = dd$Time,
      Vlera = as.numeric(dd$y),
      stringsAsFactors = FALSE
    )

    h <- as.integer(input$h); if (is.na(h) || h < 1) h <- 1
    fut_time <- make_future_time(obs_df$Time, h)

    fc_mean  <- as.numeric(fc$mean)

    low80 <- up80 <- rep(NA_real_, length(fc_mean))
    if (!is.null(fc$lower) && "80%" %in% colnames(fc$lower)) low80 <- as.numeric(fc$lower[, "80%"])
    if (!is.null(fc$upper) && "80%" %in% colnames(fc$upper)) up80  <- as.numeric(fc$upper[, "80%"])

    fc_df <- data.frame(
      Time      = fut_time,
      Mesatarja = fc_mean,
      Poshtë80  = low80,
      Sipër80   = up80,
      stringsAsFactors = FALSE
    )

    obs_df$hover <- paste0(
      xlab, ": ", fmt_time(obs_df$Time),
      "<br>", m$label, ": ", fmt_unit(obs_df$Vlera, input$forecast_series, meta())
    )

    fc_df$hover <- paste0(
      xlab, ": ", fmt_time(fc_df$Time),
      "<br>Parashikimi: ", fmt_unit(fc_df$Mesatarja, input$forecast_series, meta()),
      "<br>Intervali 80%: [",
      fmt_unit(fc_df$Poshtë80, input$forecast_series, meta()),
      " ; ",
      fmt_unit(fc_df$Sipër80, input$forecast_series, meta()),
      "]"
    )

    p <- ggplot() +
      geom_line(
        data = obs_df,
        aes(x = Time, y = Vlera),
        color = "white",
        linewidth = 1
      ) +
      geom_ribbon(
        data = fc_df,
        aes(x = Time, ymin = Poshtë80, ymax = Sipër80),
        fill = "white",
        alpha = 0.12
      ) +
      geom_line(
        data = fc_df,
        aes(x = Time, y = Mesatarja),
        color = "white",
        linewidth = 1.2,
        linetype = "solid"
      ) +
      labs(
        title = paste0("Parashikimi – ", m$label, " (", toupper(input$method), ")"),
        x = xlab,
        y = if (nzchar(m$unit)) paste0(m$label, " (", m$unit, ")") else m$label
      ) +
      scale_y_continuous(labels = function(x) fmt_by_series(x, for_axis = TRUE)) +
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

    line_idx <- find_traces(pl, function(tr) {
      (tr$type %||% "") == "scatter" && grepl("lines", tr$mode %||% "") && is.null(tr$fill)
    })

    if (length(line_idx) > 0) {
      for (i in line_idx) {
        nx <- length(pl$x$data[[i]]$x %||% list())
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
  # Saktësia e parashikimit (seti i trajnimit) — DINAMIK
  # =========================================================

  output$forecast_metrics <- renderUI({
    req(fitted_model(), input$forecast_series)

    acc <- tryCatch(
      forecast::accuracy(fitted_model()),
      error = function(e) NULL
    )

    if (is.null(acc)) {
      div(
        class = "section-box",
        h4("Saktësia në setin e trajnimit"),
        p("Saktësia nuk u llogarit. Shkak i mundshëm: seri shumë e shkurtër, shumë NA, seri konstante, ose model i dështuar.")
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
    req(fitted_model(), input$forecast_series)

    acc <- tryCatch(
      forecast::accuracy(fitted_model()),
      error = function(e) NULL
    )

    if (is.null(acc) || nrow(acc) == 0) {
      return(data.frame(
        Treguesi = c(
          "Gabimi mesatar (ME)",
          "Gabimi mesatar absolut (MAE)",
          "Rrënja e gabimit mesatar katror (RMSE)",
          "Gabimi mesatar absolut përqindor (MAPE)"
        ),
        Vlera = rep("NA", 4),
        check.names = FALSE
      ))
    }

    row_name <- if ("Training set" %in% rownames(acc)) "Training set" else rownames(acc)[1]

    metrics <- c("ME", "MAE", "RMSE", "MAPE")
    vals <- setNames(rep(NA_real_, length(metrics)), metrics)

    for (mt in metrics) {
      if (mt %in% colnames(acc)) {
        vals[mt] <- suppressWarnings(as.numeric(acc[row_name, mt]))
      }
    }

    m  <- var_meta(input$forecast_series, meta())
    u  <- m$unit %||% ""
    add_unit <- function(x_chr) if (nzchar(u)) paste0(x_chr, " ", u) else x_chr

    data.frame(
      Treguesi = c(
        "Gabimi mesatar (ME)",
        "Gabimi mesatar absolut (MAE)",
        "Rrënja e gabimit mesatar katror (RMSE)",
        "Gabimi mesatar absolut përqindor (MAPE)"
      ),
      Vlera = c(
        add_unit(fmt_by_series(vals["ME"],   for_axis = FALSE)),
        add_unit(fmt_by_series(vals["MAE"],  for_axis = FALSE)),
        add_unit(fmt_by_series(vals["RMSE"], for_axis = FALSE)),
        if (is.na(vals["MAPE"])) "NA" else paste0(fmt_fixed(vals["MAPE"], digits = 2), " %")
      ),
      check.names = FALSE
    )
  }, striped = FALSE, bordered = TRUE, spacing = "s")
}
