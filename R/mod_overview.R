# Përmbledhje: të dhënat e serive të zgjedhura, variablat, informacioni dhe statistikat.
# Tabela e të dhënave lexon active() (kolona e kohës me emrin origjinal); të tjerat
# lexojnë series() nga prepare_series().

mod_overview_ui <- function(id) {
  ns <- NS(id)
  tagList(
    div(
      class = "section-box",
      h4(tr("ov.selected_data")),
      div(class = "table-wrap", DT::DTOutput(ns("ts_selected_tbl")))
    ),

    div(class = "glass-divider"),

    fluidRow(
      column(
        6,

        div(
          class = "section-box",
          h4(tr("ov.variables")),
          tableOutput(ns("variables_tbl"))
        ),

        tags$details(
          class = "section-box",
          open = FALSE,
          tags$summary(tags$strong(tr("ov.methodology"))),
          tags$ul(
            tags$li(tr("ov.methodology.eda")),
            tags$li(tr("ov.methodology.stationarity")),
            tags$li(tr("ov.methodology.forecast"))
          )
        )
      ),

      column(
        6,

        div(
          class = "section-box",
          h4(tr("ov.data_info")),
          tableOutput(ns("data_info_tbl"))
        ),

        div(
          class = "section-box",
          h4(tr("ov.summary")),
          tableOutput(ns("summary_tbl"))
        )
      )
    )
  )
}

# Kolona e kohës (me emrin origjinal) + seritë e zgjedhura, të renditura sipas kohës.
overview_selected_data <- function(a) {
  d0 <- a$data
  tc <- a$time_col
  sel <- a$value_cols[a$value_cols %in% names(d0)]

  d <- make_df_dyn(d0, tc)
  if (tc != "Time" && "Time" %in% names(d)) {
    names(d)[names(d) == "Time"] <- tc
  }

  keep <- intersect(c(tc, sel), names(d))
  dplyr::select(d, dplyr::all_of(keep))
}

overview_info_table <- function(d, n_series, file) {
  tt_ok <- d$Time[!is.na(d$Time)]
  lbl <- time_axis_label(d$Time)

  out <- data.frame(
    c(
      tr("ov.info.first", label = lbl),
      tr("ov.info.last", label = lbl),
      tr("ov.info.n_obs"),
      tr("ov.info.n_series"),
      tr("ov.info.source")
    ),
    c(
      fmt_time(min(tt_ok)),
      fmt_time(max(tt_ok)),
      as.character(nrow(d)),
      as.character(n_series),
      file %||% tr("ov.info.source_user")
    )
  )
  names(out) <- c(tr("ov.col.element"), tr("ov.col.value"))
  out
}

overview_variables_table <- function(vc, meta) {
  out <- data.frame(
    vapply(vc, var_display_label, character(1), meta = meta),
    rep(tr("ov.var_description"), length(vc))
  )
  names(out) <- c(tr("ov.col.variable"), tr("ov.col.description"))
  out
}

# Vlerat e summary_stats(); mesatarja, sd, min dhe max formatohen me fmt_table_value (B-01),
# përqindja e vlerave që mungojnë me 2 decimale dhe presjen e gjuhës (B-24).
overview_summary_table <- function(d, vc, meta) {
  st <- summary_stats(d, vc)
  fmt_safe <- function(x) if (is.na(x)) NA_character_ else fmt_table_value(x)

  out <- data.frame(
    vapply(vc, var_display_label, character(1), meta = meta),
    vapply(st$mean, fmt_safe, character(1)),
    vapply(st$sd, fmt_safe, character(1)),
    vapply(st$min, fmt_safe, character(1)),
    vapply(st$max, fmt_safe, character(1)),
    st$n,
    fmt_fixed(st$missing_pct, digits = 2)
  )
  names(out) <- c(
    tr("ov.col.variable"), tr("ov.col.mean"), tr("ov.col.sd"), tr("ov.col.min"),
    tr("ov.col.max"), tr("ov.col.n"), tr("ov.col.missing")
  )
  out
}

# current_tab: reactive me tab-in aktiv (input$main_tabs), për rregullimin e kolonave të DT.
mod_overview_server <- function(id, active, series, current_tab) {
  moduleServer(id, function(input, output, session) {
    output$ts_selected_tbl <- DT::renderDT({
      a <- active()
      req(a)
      d0 <- a$data

      tc <- a$time_col
      shiny::validate(shiny::need(!is.null(tc) && tc %in% names(d0), tr("ov.need_time_col")))
      shiny::validate(shiny::need(any(a$value_cols %in% names(d0)), tr("ov.need_series")))

      DT::datatable(
        overview_selected_data(a),
        rownames = FALSE,
        class = "display nowrap cell-border compact",
        options = list(
          dom = "lfrtip",
          pageLength = 10,
          lengthMenu = c(5, 10, 20, 50),
          scrollX = TRUE,
          autoWidth = TRUE,
          deferRender = TRUE,
          language = dt_language()
        )
      )
    }, server = TRUE)

    output$data_info_tbl <- renderTable({
      s <- series()
      req(s)
      shiny::validate(shiny::need(sum(!is.na(s$data$Time)) >= 2, tr("ov.need_two_times")))
      overview_info_table(s$data, length(s$value_cols), active()$file)
    })

    output$variables_tbl <- renderTable({
      s <- series()
      req(s, s$value_cols)
      overview_variables_table(s$value_cols, s$meta)
    })

    output$summary_tbl <- renderTable({
      s <- series()
      req(s, s$value_cols)
      overview_summary_table(s$data, s$value_cols, s$meta)
    }, align = "lllllrr")

    adjust_dt <- function() session$sendCustomMessage("dt_adjust", session$ns("ts_selected_tbl"))

    observeEvent(current_tab(), {
      if (identical(current_tab(), page_tab("overview"))) adjust_dt()
    }, ignoreInit = TRUE)

    session$onFlushed(adjust_dt, once = TRUE)
  })
}
