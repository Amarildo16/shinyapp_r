source("helpers.R")
source("server_plots.R")

ui <- fluidPage(
  shinyjs::useShinyjs(),

  tags$head(
    tags$meta(name="viewport", content="width=device-width, initial-scale=1"),
    tags$link(rel="stylesheet", href="vendor/filepond/filepond.min.css"),
    tags$link(rel="stylesheet", type="text/css", href="css/custom-style.css"),
    tags$link(rel="icon", type="image/png", href="images/favicon.png"),
    tags$script(src="vendor/filepond/filepond.min.js"),
    tags$script(src="vendor/filepond/filepond-plugin-file-validate-type.min.js"),
    tags$script(src="vendor/filepond/filepond-plugin-file-validate-size.min.js"),
    tags$script(src="js/bg.js"),
    tags$script(src="js/sidebar.js"),
    tags$script(src="js/plotly-animate.js"),
    tags$link(rel = "stylesheet", href = "https://cdn.jsdelivr.net/npm/remixicon@4.9.1/fonts/remixicon.css"),
    tags$link(rel="stylesheet", href="css/icons.css"),
    tags$script(src="js/custom.js")
  ),

  tags$div(
    id = "preloader",
    tags$div(
      id = "status",
      tags$div(
        class = "loading",
        tags$span(), tags$span(), tags$span(), tags$span(), tags$span()
      )
    )
  ),

  div(
    style = "display:none;",
    textInput("data_source", label = NULL, value = ""),
    selectInput("data_time_col", label = NULL, choices = character(0)),
    selectizeInput("data_value_cols", label = NULL, choices = character(0), multiple = TRUE),
    selectInput("data_dup", label = NULL, choices = c("mean","sum","last"), selected = "mean"),
    selectInput("data_freq", label = NULL, choices = c("auto","yearly","quarterly","monthly","daily"), selected = "auto")
  ),

  # Background
  tags$div(
    id = "bg-wrapper",
    tags$div(
      class = "bg-layer current",
      style = "background-image:url('images/image0.jpeg');"
    ),
    tags$div(class = "bg-layer next")
  ),
  tags$div(id = "bg-overlay"),

  div(
    class = "app-shell",

    # Backdrop
    tags$div(
      id = "sidebar_backdrop",
      class = "sidebar-backdrop",
      `aria-hidden` = "true"
    ),

    # Sidebar
    div(
      id = "app_sidebar",
      class = "app-sidebar",

      div(
        class = "sidebar-main",

        div(
          class = "menu-title-row",
          div(class = "menu-title", "Time Series Analysis"),

          actionButton(
            "go_settings",
            label = NULL,
            icon = tags$i(class = "ri-settings-5-line"),
            class = "settings-icon-btn",
            `aria-label` = "Settings"
          )
        ),
        actionButton("go_overview",       "Përmbledhje",                         class = "btn btn-light nav-btn"),
        actionButton("go_eda_ts",         "Analiza eksploruese – Seri kohore",   class = "btn btn-light nav-btn"),
        actionButton("go_eda_rel",        "Analiza eksploruese – Marrëdhënie",   class = "btn btn-light nav-btn"),
        actionButton("go_stationary",     "Stacionariteti",                      class = "btn btn-light nav-btn"),
        actionButton("go_modeling",       "Modelimi",                            class = "btn btn-light nav-btn"),
        actionButton("go_forecast",       "Parashikimi",                         class = "btn btn-light nav-btn"),
        actionButton("go_wrapup",         "Përfundime",                          class = "btn btn-light nav-btn")
      ),

      div(
        class = "sidebar-footer-wrap",
        div(class = "glass-divider"),
        div(
          class = "sidebar-footer",
          tags$small(
            "By ",
            tags$a(
              "Amarildo Alla",
              href = "https://github.com/Amarildo16",
              target = "_blank",
              rel = "noopener noreferrer",
              class = "github-link"
            )
          )
        )
      )
    ),
    # App content
    div(
      class = "app-content",
      div(
        class = "app-content-inner",

        div(
          class = "app-topbar",
          tags$button(
            type = "button",
            class = "hamburger-btn",
            id = "toggle_sidebar",
            tags$span(), tags$span(), tags$span()
          ),
          div(class = "app-title", textOutput("topbar_title"))
        ),

        tabsetPanel(
          id = "main_tabs",
          type = "hidden",
          selected = "tab_overview",
          
          tabPanel(
            title = "Settings",
            value = "tab_settings",

            div(class="glass-divider"),

            # ===== Dataset section =====
            div(
              class = "overview-top",
              h4("Dataset"),
              actionButton(
                "btn_open_upload",
                "Ngarko CSV",
                class = "glass-btn ajax-modal-sm",
                `data-modal` = "upload",
                `data-title` = "Ngarko CSV"
              )
            ),
            uiOutput("saved_datasets_ui"),

            div(class="glass-divider"),

            # ===== Background section =====
            div(
              class = "section-box",
              h4("Background"),

              radioButtons(
                "bg_mode",
                "Zgjidh mënyrën",
                choices = c("Foto" = "image", "Vetëm ngjyrë" = "color", "Pa background" = "none"),
                selected = "image",
                inline = TRUE
              ),

              conditionalPanel(
                condition = "input.bg_mode == 'image'",
                fileInput("bg_image", "Ngarko foto background", accept = c("image/png", "image/jpeg", "image/jpg")),
                checkboxInput("bg_blur_on", "Blur", value = TRUE),
                sliderInput("bg_blur", "Blur strength", min = 0, max = 20, value = 10, step = 1)
              ),

              conditionalPanel(
                condition = "input.bg_mode != 'image'",
                tags$label("Ngjyra e background-it"),
                tags$input(id="bg_color", type="color", value="#0b1c24",
                          style="width:120px;height:42px;border-radius:10px;border:1px solid rgba(255,255,255,.25);background:transparent;")
              ),

              tags$small("Ndryshimet aplikohen menjëherë (live).", style="opacity:.8;display:block;margin-top:10px;")
            )
          ),

          tabPanel(
            title = "Përmbledhje",
            value = "tab_overview",

            div(class = "glass-divider"),

            fluidRow(
              column(
                6,

                div(
                  class = "section-box",
                  h4("Përshkrimi i variablave"),
                  tableOutput("variables_tbl")
                ),

                tags$details(
                  class = "section-box",
                  open = FALSE,
                  tags$summary(tags$strong("Metodologjia")),
                  tags$ul(
                    tags$li("Analizë eksploruese: prirje, variabilitet dhe shpërndarje"),
                    tags$li("Stacionaritet: testi ADF dhe diferencimi kur kërkohet"),
                    tags$li("Parashikim: SES/Holt dhe ARIMA"),
                    tags$li("Opsionale: simulime ARMA, VAR/IRF dhe GARCH")
                  )
                )
              ),

              column(
                6,

                div(
                  class = "section-box",
                  h4("Informacion mbi të dhënat"),
                  tableOutput("data_info_tbl")
                ),

                div(
                  class = "section-box",
                  h4("Statistika përmbledhëse"),
                  tableOutput("summary_tbl")
                )
              )
            )
          ),

          tabPanel(
            title = "Analiza eksploruese – Seri kohore",
            value = "tab_eda_ts",

            div(class = "glass-divider"),

            div(
              class = "section-box",
              h3("Analiza eksploruese e të dhënave – Seri kohore"),
              p("Në këtë seksion shqyrtohen forma e serisë, prirja (trendi), variabiliteti dhe karakteristikat e shpërndarjes.")
            ),

            sidebarLayout(
              position = "left",

              sidebarPanel(
                selectInput("eda_series", "Përzgjidhni serinë", choices = character(0)),

                sliderInput(
                  "roll_k",
                  "Dritarja lëvizëse (vite)",
                  min = 3,
                  max = 10,
                  value = 5,
                  step = 1
                )
              ),

              mainPanel(
                div(
                  class = "section-box",
                  div(
                    class = "plot-container",
                    plotlyOutput("eda_ts_raw", height = "360px")
                  ),
                  tags$small(textOutput("cap_eda_ts_raw"))
                ),

                div(class = "glass-divider"),

                div(
                  class = "section-box",
                  div(
                    class = "plot-container",
                    plotlyOutput("eda_ts_roll", height = "360px")
                  ),
                  tags$small(textOutput("cap_eda_ts_roll"))
                ),

                div(class = "glass-divider"),

                div(
                  class = "section-box",
                  div(
                    class = "plot-container",
                    plotlyOutput("eda_ts_dist", height = "360px")
                  ),
                  tags$small(textOutput("cap_eda_ts_dist"))
                )
              )
            )
          ),

          tabPanel(
            title = "Analiza eksploruese – Marrëdhënie",
            value = "tab_eda_rel",

            div(class = "glass-divider"),

            div(
              class = "section-box",
              h3("Analiza eksploruese e të dhënave – Marrëdhënie"),
              p("Në këtë seksion analizohen marrëdhëniet ndërmjet variablave kryesore bujqësore, përmes grafikëve dhe matricës së korrelacionit.")
            ),

            sidebarLayout(
              position = "left",

              sidebarPanel(
                selectInput("rel_x", "Përzgjidhni variablën X", choices = character(0)),

                selectInput("rel_y", "Përzgjidhni variablën Y", choices = character(0))
              ),

              mainPanel(
                div(
                  class = "section-box",
                  h4("Grafiku i shpërndarjes (Scatter plot)"),
                  div(
                    class = "plot-wrap",
                    plotlyOutput("eda_rel_scatter", height = "420px")
                  ),
                  tags$small(textOutput("cap_eda_rel_scatter"))
                ),

                div(class = "glass-divider"),

                div(
                  class = "section-box",
                  h4("Matrica e korrelacionit"),
                  div(
                    class = "plot-wrap",
                    plotlyOutput("eda_rel_corr", height = "420px")
                  ),
                  tags$small(textOutput("cap_eda_rel_corr"))
                )
              )
            )
          ),

          tabPanel(
            title = "Stacionariteti",
            value = "tab_stationary",

            div(class = "glass-divider"),

            div(
              class = "section-box",
              h3("Stacionariteti dhe transformimet"),
              p("Në këtë seksion vlerësohet stacionariteti i serive kohore dhe paraqiten transformimet e nevojshme për modelim (p.sh. diferencimi).")
            ),

            sidebarLayout(
              position = "left",

              sidebarPanel(
                selectInput("stat_series", "Përzgjidhni serinë", choices = character(0))
              ),

              mainPanel(
                div(
                  class = "section-box",
                  h4("Diferenca e parë (First difference)"),
                  div(
                    class = "plot-wrap",
                    plotlyOutput("stat_diff_plot", height = "360px")
                  ),
                  tags$small(textOutput("cap_stat_diff_plot"))
                ),

                div(class = "glass-divider"),

                div(
                  class = "section-box",
                  h4("ACF dhe PACF"),
                  div(
                    class = "plot-wrap",
                    plotlyOutput("stat_acf_pacf", height = "420px")
                  ),
                  tags$small(textOutput("cap_stat_acf_pacf"))
                ),

                div(class = "glass-divider"),

                div(
                  class = "section-box",
                  h4("Testi ADF"),
                  div(
                    class = "table-wrap",
                    tableOutput("stat_adf_tbl"),
                    uiOutput("stat_adf_note")
                  )
                )
              )
            )
          ),

          tabPanel(
            title = "Modelimi",
            value = "tab_modeling",

            div(class = "glass-divider"),

            div(
              class = "section-box",
              h3("Modelimi i serive kohore"),
              p("Në këtë seksion krahasohen modelet ETS dhe ARIMA për parashikim, si dhe vlerësohet saktësia e tyre në setin e trajnimit.")
            ),

            sidebarLayout(
              position = "left",

              sidebarPanel(
                selectInput("model_series", "Përzgjidhni serinë", choices = character(0)),

                sliderInput(
                  "model_h",
                  "Horizonti i parashikimit (vite)",
                  min = 1,
                  max = 10,
                  value = 5,
                  step = 1
                )
              ),

              mainPanel(
                div(
                  class = "section-box",
                  h4("Krahasimi i parashikimeve"),
                  div(
                    class = "plot-wrap",
                    plotlyOutput("model_plot", height = "480px")
                  ),
                  tags$small(textOutput("cap_model_plot"))
                ),

                div(class = "glass-divider"),

                div(
                  class = "section-box",
                  h4("Saktësia e modelit (seti i trajnimit)"),
                  div(
                    class = "table-wrap",
                    tableOutput("model_acc_tbl")
                  )
                )
              )
            )
          ),

          tabPanel(
            title = "Parashikimi",
            value = "tab_forecast",

            div(class = "glass-divider"),

            sidebarLayout(
              position = "left",

              sidebarPanel(
                h4("Cilësimet e parashikimit"),

                selectInput("forecast_series", "Seria", choices = character(0)),

                selectInput(
                  "method",
                  "Metoda e parashikimit",
                  choices = c(
                    "SES (sheshim eksponencial i thjeshtë)" = "ses",
                    "Holt (trend i zbutur)"                  = "holt",
                    "ARIMA"                                  = "arima"
                  )
                ),

                sliderInput("h", "Horizonti i parashikimit (vite)", 1, 10, 5),

                hr(),
                p("Grafiku paraqet vlerat e vëzhguara dhe parashikimet për vitet pasuese, së bashku me intervalet e pasigurisë.")
              ),

              mainPanel(
                div(
                  class = "section-box",
                  h4("Parashikimi"),
                  div(
                    class = "plot-wrap",
                    plotlyOutput("forecast_plot", height = "520px")
                  ),
                  tags$small(textOutput("cap_forecast_plot"))
                ),

                div(class = "glass-divider"),

                div(
                  class = "section-box",
                  h4("Saktësia e parashikimit"),
                  div(
                    class = "table-wrap",
                    uiOutput("forecast_metrics")
                  )
                )
              )
            )
          ),

          tabPanel(
            title = "Përfundime",
            value = "tab_wrapup",

            div(class = "glass-divider"),

            div(
              class = "section-box",
              h3("Përfundime"),
              tags$ul(
                tags$li("Prodhimi bujqësor në Shqipëri shfaq prirje afatgjatë rritëse, shoqëruar me variabilitet vjetor."),
                tags$li("Testet e stacionaritetit sugjerojnë nevojën për transformime (p.sh. diferencim) përpara modelimit ARIMA, kur seria nuk është stacionare."),
                tags$li("Metodat SES dhe Holt rezultojnë të përshtatshme për parashikime afatshkurtra, sidomos kur struktura e serisë është e qëndrueshme."),
                tags$li("ARIMA ofron fleksibilitet më të lartë për modelim dhe parashikim, veçanërisht kur struktura kërkon përfshirje të komponentëve autoregresivë dhe mesatares lëvizëse."),
                tags$li("Aplikacioni Shiny shërben si mjet eksplorues dhe demonstrues; analiza e plotë dokumentohet në raportin përkatës Rmd.")
              )
            ),

            div(
              class = "section-box",
              tags$details(
                open = FALSE,
                tags$summary(tags$strong("Shënim metodologjik: dekompozimi i serive kohore")),
                p("Dekompozimi sezonal u vlerësua si pjesë e rrjedhës së analizës."),
                p(strong("Përfundim: "), "Nuk është i zbatueshëm për këtë dataset."),
                tags$ul(
                  tags$li("Të dhënat janë vjetore (frequency = 1); rrjedhimisht nuk mund të identifikohet komponent sezonal."),
                  tags$li("Analiza fokusohet në trendin afatgjatë, variabilitetin, stacionaritetin dhe parashikimin.")
                )
              )
            )
          )
        )
      )
    )
  ),
  # ========= MODAL SMALL (Upload) =========
  tags$div(
    class = "modal fade",
    id = "main_modal_sm",
    tabindex = "-1",
    `aria-hidden` = "true",
    tags$div(
      class = "modal-dialog",
      tags$div(
        class = "modal-content",
        tags$div(
          class = "modal-header",
          uiOutput("modal_sm_title"),
          tags$button(
            type = "button",
            class = "close",
            `data-dismiss` = "modal",
            `aria-label` = "Close",
            tags$span(`aria-hidden` = "true", HTML("&times;"))
          )
        ),
        tags$div(class = "modal-body", uiOutput("modal_sm_body")),
        tags$div(
          class = "modal-footer",
          actionButton("btn_cancel_upload", "Cancel", class = "btn btn-light"),
          actionButton("btn_proceed_upload", "Proceed", class = "btn btn-success")
        )
      )
    )
  ),

  # ========= MODAL FULLSCREEN (Config) =========
  tags$div(
    class = "modal fade",
    id = "main_modal_fs",
    tabindex = "-1",
    `aria-hidden` = "true",
    tags$div(
      class = "modal-dialog modal-lg",
      tags$div(
        class = "modal-content",
        tags$div(
          class = "modal-header",
          uiOutput("modal_fs_title"),
          tags$button(
            type = "button",
            class = "close",
            `data-dismiss` = "modal",
            `aria-label` = "Close",
            tags$span(`aria-hidden` = "true", HTML("&times;"))
          )
        ),
        tags$div(class = "modal-body", uiOutput("modal_fs_body")),
        tags$div(
          class = "modal-footer",
          actionButton("btn_cancel_config", "Cancel", class = "btn btn-light"),
          actionButton("btn_save_config", "Save", class = "btn btn-success")
        )
      )
    )
  )
)


server <- function(input, output, session) {
  observeEvent(input$go_settings,       { updateTabsetPanel(session, "main_tabs", "tab_settings") })
  observeEvent(input$go_overview,       { updateTabsetPanel(session, "main_tabs", "tab_overview") })
  observeEvent(input$go_eda_ts,         { updateTabsetPanel(session, "main_tabs", "tab_eda_ts") })
  observeEvent(input$go_eda_rel,        { updateTabsetPanel(session, "main_tabs", "tab_eda_rel") })
  observeEvent(input$go_stationary,     { updateTabsetPanel(session, "main_tabs", "tab_stationary") })
  observeEvent(input$go_modeling,       { updateTabsetPanel(session, "main_tabs", "tab_modeling") })
  observeEvent(input$go_forecast,       { updateTabsetPanel(session, "main_tabs", "tab_forecast") })
  observeEvent(input$go_wrapup,         { updateTabsetPanel(session, "main_tabs", "tab_wrapup") })

  uploaded_tmp_path <- reactiveVal(NULL)
  uploaded_tmp_name <- reactiveVal(NULL)

  TITLE_MAP <- c(
    tab_overview    = "Time Series Analysis",
    tab_eda_ts      = "EDA – Seri kohore",
    tab_eda_rel     = "EDA – Marrëdhënie",
    tab_stationary  = "Stacionariteti",
    tab_modeling    = "Modelimi",
    tab_forecast    = "Parashikimi",
    tab_wrapup      = "Përfundime",
    tab_settings    = "Settings"
  )

  output$topbar_title <- renderText({
    key <- input$main_tabs %||% "tab_overview"
    TITLE_MAP[[key]] %||% "Time Series Analysis"
  })

  # =========================
  # DATA SOURCE (demo + upload)
  # =========================
  df_raw <- reactiveVal(NULL)

  pending_data <- reactiveVal(NULL)
  pending_cfg  <- reactiveVal(NULL)

  observe({
    if (is.null(df_raw())) {
      df_raw(read_data_safe(DATA_PATH))
    }
  })

  df <- reactive(df_raw())

  observeEvent(df(), {
    d <- df()
    if (is.null(d) || nrow(d) == 0) return()

    nm <- names(d)
    if (length(nm) == 0) return()

    cand <- tryCatch(detect_time_candidates(d), error = function(e) {
      data.frame(col = nm, score = 0)
    })

    time_choices <- unique(cand$col)
    if (length(time_choices) == 0) time_choices <- nm

    pick <- function(cur, choices, fallback) {
      if (!is.null(cur) && length(cur) == 1 && cur %in% choices) cur else fallback
    }

    tc_cur <- isolate(input$data_time_col)
    tc_sel <- pick(tc_cur, time_choices, time_choices[1])

    updateSelectInput(session, "data_time_col", choices = time_choices, selected = tc_sel)

    cols <- setdiff(nm, tc_sel)
    num_cols <- cols[vapply(d[cols], function(x) {
      xn <- to_numeric_safe(x)
      mean(!is.na(xn)) >= 0.70
    }, logical(1))]

    if (length(num_cols) == 0) num_cols <- cols

    vc_cur <- isolate(input$data_value_cols)
    vc_sel <- vc_cur[vc_cur %in% num_cols]

    if (length(vc_sel) == 0) {
      vc_sel <- head(num_cols, min(3, length(num_cols)))
    }

    updateSelectizeInput(session, "data_value_cols",
      choices = num_cols,
      selected = vc_sel,
      server = TRUE)

    choices <- num_cols
    if (length(choices) == 0) choices <- cols
    if (length(choices) == 0) return()

    s1 <- choices[1]
    s2 <- if (length(choices) >= 2) choices[2] else choices[1]

    updateSelectInput(session, "eda_series", choices = choices, selected = pick(isolate(input$eda_series), choices, s1))
    updateSelectInput(session, "stat_series", choices = choices, selected = pick(isolate(input$stat_series), choices, s1))
    updateSelectInput(session, "model_series", choices = choices, selected = pick(isolate(input$model_series), choices, s1))
    updateSelectInput(session, "forecast_series", choices = choices, selected = pick(isolate(input$forecast_series), choices, s1))
    updateSelectInput(session, "rel_x", choices = choices, selected = pick(isolate(input$rel_x), choices, s1))
    updateSelectInput(session, "rel_y", choices = choices, selected = pick(isolate(input$rel_y), choices, s2))

  }, ignoreInit = FALSE)

  # =========================
  # MODAL FLOW (sm -> fs)
  # =========================
  observeEvent(input$ajax_modal_open, {
    req(input$ajax_modal_open$modal)

    modal <- input$ajax_modal_open$modal
    title <- input$ajax_modal_open$title

    if (modal == "sm") {
      output$modal_sm_title <- renderUI(tags$h5(class = "modal-title", title))

      output$modal_sm_body <- renderUI({
        tagList(
          tags$div(id = "csv_file_modal_pond_host"),
          fileInput(
            "csv_file_modal",
            label = NULL,
            accept = c(".csv")
          ),
          tags$small("Hidh CSV këtu (drag & drop) ose Browse.")
        )
      })

      session$sendCustomMessage("toggle_modal", list(id = "main_modal_sm", action = "show"))
    }

    if (modal == "fs") {
      output$modal_fs_title <- renderUI(tags$h5(class = "modal-title", title))
      output$modal_fs_body  <- renderUI(div("..."))
      session$sendCustomMessage("toggle_modal", list(id = "main_modal_fs", action = "show"))
    }
  })

  observeEvent(input$csv_file_modal, {
    req(input$csv_file_modal$datapath)
    req(input$csv_file_modal$name)

    ext <- tolower(tools::file_ext(input$csv_file_modal$name))
    if (ext != "csv") {
      showNotification("Ky fajll s'pranohet. Lejohet vetëm: .csv", type = "error", duration = 6)
      return()
    }

    uploaded_tmp_path(input$csv_file_modal$datapath)
    uploaded_tmp_name(input$csv_file_modal$name)

    d <- tryCatch(
      read_data_safe(input$csv_file_modal$datapath, input$csv_file_modal$name),
      error = function(e) {
        showNotification(paste0("Gabim gjatë leximit: ", e$message), type = "error", duration = 8)
        NULL
      }
    )
    if (is.null(d)) return()

    nm <- names(d)

    cand <- tryCatch(detect_time_candidates(d), error = function(e) {
      data.frame(col = nm, score = 0)
    })
    time_choices <- unique(cand$col)
    if (length(time_choices) == 0) time_choices <- nm
    time_default <- time_choices[1]

    cols <- setdiff(nm, time_default)
    num_cols <- cols[vapply(d[cols], function(x) {
      xn <- to_numeric_safe(x)
      mean(!is.na(xn)) >= 0.70
    }, logical(1))]
    if (length(num_cols) == 0) num_cols <- cols
    value_default <- head(num_cols, min(3, length(num_cols)))

    pending_data(d)
    pending_cfg(list(
      nm = nm,
      time_choices = time_choices,
      time_default = time_default,
      value_default = value_default
    ))

    if (nzchar(input$csv_file_modal$name)) {
      if (is.null(isolate(input$data_source)) || !nzchar(isolate(input$data_source))) {
        updateTextInput(session, "data_source", value = input$csv_file_modal$name)
      }
    }

    showNotification("CSV u ngarkua. Tani kliko Proceed për konfigurim.", type = "message", duration = 5)

  }, ignoreInit = TRUE)

  observeEvent(input$btn_cancel_upload, {
    session$sendCustomMessage("toggle_modal", list(id = "main_modal_sm", action = "hide"))
    pending_cfg(NULL)
    pending_data(NULL)
    uploaded_tmp_path(NULL)
    uploaded_tmp_name(NULL)
  })

  observeEvent(input$btn_proceed_upload, {
    req(pending_data())
    req(pending_cfg())

    d   <- pending_data()
    cfg <- pending_cfg()

    output$modal_fs_body <- renderUI(tagList(
      tags$div(class="cfg-top",
        fluidRow(
          column(3,
            selectInput("modal_time_col", "Kolona e kohës",
              choices  = cfg$time_choices,
              selected = cfg$time_default
            )
          ),
          column(5,
            selectizeInput("modal_value_cols", "Seritë numerike",
              choices  = setdiff(cfg$nm, cfg$time_default),
              selected = cfg$value_default,
              multiple = TRUE
            )
          )
        )
      ),
      tags$hr(),
      DT::DTOutput("csv_preview_big")
    ))

    output$csv_preview_big <- DT::renderDT({
      DT::datatable(head(d, 200), rownames = FALSE, options = list(scrollX = TRUE))
    })

    session$sendCustomMessage("toggle_modal", list(id="main_modal_sm", action="hide"))
    session$sendCustomMessage("toggle_modal", list(id="main_modal_fs", action="show"))
  }, ignoreInit = TRUE)

  observeEvent(input$modal_time_col, {
    req(pending_data())
    d <- pending_data()
    nm <- names(d)

    sel <- isolate(input$modal_value_cols)
    sel <- setdiff(sel, input$modal_time_col)

    updateSelectizeInput(
      session, "modal_value_cols",
      choices  = setdiff(nm, input$modal_time_col),
      selected = sel,
      server   = TRUE
    )
  }, ignoreInit = TRUE)

  observeEvent(input$btn_save_config, {
    req(input$modal_time_col)
    req(input$modal_value_cols)

    session$sendCustomMessage("toggle_modal", list(id = "main_modal_fs", action = "hide"))

    d <- pending_data()
    nm <- names(d)

    updateSelectInput(session, "data_time_col",
      choices = nm,
      selected = input$modal_time_col)

    vals <- isolate(input$modal_value_cols)
      tc   <- isolate(input$modal_time_col)
      vals <- setdiff(vals, tc)

      if (length(vals) == 0) vals <- num_cols


    updateSelectizeInput(session, "data_value_cols",
      choices = setdiff(nm, input$modal_time_col),
      selected = input$modal_value_cols,
      server = TRUE)


    dup_sel  <- isolate(input$data_dup)
      freq_sel <- isolate(input$data_freq)

      if (is.null(dup_sel)  || dup_sel  == "") dup_sel  <- "mean"
      if (is.null(freq_sel) || freq_sel == "") freq_sel <- "auto"

      updateSelectInput(session, "data_dup",
        choices  = c("mean", "sum", "first", "last"),
        selected = dup_sel
      )

      updateSelectInput(session, "data_freq",
        choices  = c("auto", "yearly", "quarterly", "monthly", "weekly", "daily"),
        selected = freq_sel
      )

    showNotification("Konfigurimi i dataset-it u ruajt me sukses.", type = "message", duration = 5)

    up_path <- uploaded_tmp_path()
    up_name <- uploaded_tmp_name()

    if (!is.null(up_path) && file.exists(up_path) && !is.null(up_name) && nzchar(up_name)) {

      safe <- sanitize_filename(up_name, default_ext = "csv")
      target <- file.path(DATA_DIR, safe)

      if (file.exists(target)) {
        stem <- tools::file_path_sans_ext(safe)
        ext  <- tools::file_ext(safe)
        safe <- paste0(stem, "_", format(Sys.time(), "%Y%m%d_%H%M%S"), ".", ext)
        target <- file.path(DATA_DIR, safe)
      }

      ok <- file.copy(up_path, target, overwrite = FALSE)

      if (isTRUE(ok)) {
        saved_datasets(list_saved_datasets())
        active_dataset_file(safe)

        try(updateSelectInput(session, "saved_dataset_select", choices = saved_datasets(), selected = safe), silent = TRUE)

        showNotification(paste0("Dataset u ruajt te data/", safe), type="message", duration=6)
      } else {
        showNotification("S’u arrit me ruajt datasetin te /data (permissions).", type="error", duration=8)
      }

      df_raw(d)

      pending_cfg(NULL)
      pending_data(NULL)
      uploaded_tmp_path(NULL)
      uploaded_tmp_name(NULL)
    }
  })

  observeEvent(input$btn_cancel_config, {
    session$sendCustomMessage("toggle_modal", list(id = "main_modal_fs", action = "hide"))
    session$sendCustomMessage("toggle_modal", list(id = "main_modal_sm", action = "show"))
  })

  observeEvent(input$data_time_col, {
    d <- df()
    if (is.null(d) || nrow(d) == 0) return()

    nm <- names(d)
    tc_sel <- input$data_time_col
    if (is.null(tc_sel) || !nzchar(tc_sel) || !(tc_sel %in% nm)) return()

    cols <- setdiff(nm, tc_sel)

    num_cols <- cols[vapply(d[cols], function(x) {
      xn <- to_numeric_safe(x)
      mean(!is.na(xn)) >= 0.70
    }, logical(1))]

    if (length(num_cols) == 0) num_cols <- cols

    vc_cur <- isolate(input$data_value_cols)
    vc_sel <- vc_cur[vc_cur %in% num_cols]
    if (length(vc_sel) == 0) vc_sel <- head(num_cols, min(3, length(num_cols)))

    updateSelectizeInput(session, "data_value_cols", choices = num_cols, selected = vc_sel, server = TRUE)

    choices <- num_cols
    if (length(choices) == 0) return()

    s1 <- choices[1]
    s2 <- if (length(choices) >= 2) choices[2] else choices[1]

    updateSelectInput(session, "eda_series",      choices = choices, selected = pick(isolate(input$eda_series), choices, s1))
    updateSelectInput(session, "stat_series",     choices = choices, selected = pick(isolate(input$stat_series), choices, s1))
    updateSelectInput(session, "model_series",    choices = choices, selected = pick(isolate(input$model_series), choices, s1))
    updateSelectInput(session, "forecast_series", choices = choices, selected = pick(isolate(input$forecast_series), choices, s1))
    updateSelectInput(session, "rel_x",           choices = choices, selected = pick(isolate(input$rel_x), choices, s1))
    updateSelectInput(session, "rel_y",           choices = choices, selected = pick(isolate(input$rel_y), choices, s2))
  })

    list_saved_datasets <- function() {
      sort(list.files(
        DATA_DIR,
        pattern = "\\.(csv|tsv|xlsx|xls)$",
        ignore.case = TRUE,
        full.names = FALSE
      ))
    }

    saved_datasets      <- reactiveVal(list_saved_datasets())
    active_dataset_file <- reactiveVal(NULL)

    output$saved_datasets_ui <- renderUI({
      files <- saved_datasets()

      if (length(files) == 0) {
        return(tags$small("S’ka dataset të ruajtur te folderi data.", style="opacity:.75;"))
      }

      sel <- isolate(input$saved_dataset_select)
      if (is.null(sel) || !nzchar(sel) || !(sel %in% files)) {
        sel <- active_dataset_file() %||% files[1]
        if (!(sel %in% files)) sel <- files[1]
      }

      tagList(
        div(class="section-box",
          h4("Datasetet e ruajtura"),
          selectInput("saved_dataset_select", label = NULL, choices = files, selected = sel),
          div(style="display:flex; gap:10px; align-items:center; margin-top:10px;",
            actionButton("btn_activate_saved", "Aktivo", class="glass-btn"),
            actionButton("btn_refresh_saved", "Rifresko", class="btn btn-light btn-sm")
          ),
          tags$small(
            paste0("Aktiv: ", active_dataset_file() %||% "(asnjë)"),
            style="opacity:.75;display:block;margin-top:10px;"
          )
        )
      )
    })

  observeEvent(input$btn_refresh_saved, {
    saved_datasets(list_saved_datasets())
  })

  observeEvent(input$btn_activate_saved, {
    req(input$saved_dataset_select)

    path <- file.path(DATA_DIR, input$saved_dataset_select)
    if (!file.exists(path)) {
      showNotification("Dataset-i s’u gjet në /data.", type="error", duration=6)
      return()
    }

    d <- tryCatch(
      read_data_safe(path, input$saved_dataset_select),
      error = function(e) {
        showNotification(paste0("Gabim gjatë leximit: ", e$message), type="error", duration=8)
        NULL
      }
    )
    if (is.null(d)) return()

    df_raw(d)
    updateTextInput(session, "data_source", value = input$saved_dataset_select)
    active_dataset_file(input$saved_dataset_select)

    showNotification(paste0("Dataset aktiv: ", input$saved_dataset_select), type="message", duration=4)
  })

  server_plots(input, output, session, df)
}

  #================================
  # Backround settings
  #================================

shinyApp(ui, server)
