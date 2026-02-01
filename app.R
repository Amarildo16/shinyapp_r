source("helpers.R")
source("server_plots.R")

ui <- fluidPage(
  shinyjs::useShinyjs(),

  tags$head(
    tags$meta(name = "viewport", content = "width=device-width, initial-scale=1"),

    tags$link(rel = "stylesheet", type = "text/css", href = "css/custom-style.css"),

    tags$style(HTML("
      html, body { height: 100%; margin: 0 !important; }
      body > .container-fluid{
        padding-left: 0 !important;
        padding-right: 0 !important;
        margin: 0 !important;
        width: 100% !important;
      }
      ")),

    tags$script(src = "js/bg.js"),
    tags$script(src = "js/sidebar.js"),
    tags$script(src = "js/plotly-animate.js"),
    tags$link(rel = "stylesheet", href = "vendor/filepond/filepond.min.css"),
    tags$script(src = "vendor/filepond/filepond.min.js"),
    tags$script(src = "vendor/filepond/filepond-plugin-file-validate-type.min.js"),
    tags$script(src = "vendor/filepond/filepond-plugin-file-validate-size.min.js"),
    tags$link(rel = "stylesheet", href = "https://cdn.jsdelivr.net/npm/remixicon/fonts/remixicon.css"),
    tags$script(src = "js/custom.js")
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

    # Content
    div(
      class = "app-content",
      div(
        class = "app-content-inner",

        # Hamburger (scrolls away with content)
        tags$button(
          id = "toggle_sidebar",
          type = "button",
          class = "hamburger-btn",
          `aria-label` = "Hap menunë",
          tags$span(),
          tags$span(),
          tags$span()
        ),

        tabsetPanel(
          id = "main_tabs",
          type = "hidden",
          selected = "tab_overview",
          
          tabPanel(
            title = "Settings",
            value = "tab_settings",

            div(
              class = "section-box",
              h3("Settings"),
              p("Këtu konfiguron dataset-in dhe background-in.")
            ),

            div(class="glass-divider"),

            # ===== Dataset section =====
            div(
              class = "section-box",
              h4("Dataset"),
              actionButton(
                "btn_open_upload_settings",
                "Ngarko CSV",
                class = "glass-btn ajax-modal-sm",
                `data-modal` = "upload",
                `data-title` = "Ngarko CSV"
              ),
              tags$small("Hap modali i upload-it, pastaj del preview/config si fullscreen.", style="opacity:.8;display:block;margin-top:8px;")
            ),

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

            div(
              class = "overview-top",
              h3("Time Series Analysis", class = "overview-title"),
              actionButton(
                "btn_open_upload",
                "Ngarko CSV",
                class = "glass-btn ajax-modal-sm",
                `data-modal` = "upload",
                `data-title` = "Ngarko CSV"
              )
            ),

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
      class = "modal-dialog modal-dialog-centered",
      tags$div(
        class = "modal-content",
        tags$div(
          class = "modal-header",
          uiOutput("modal_sm_title"),
          tags$button(type = "button", class = "btn-close", `data-bs-dismiss` = "modal")
        ),
        tags$div(class = "modal-body", uiOutput("modal_sm_body"))
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
      class = "modal-dialog modal-fullscreen modal-dialog-scrollable",
      tags$div(
        class = "modal-content",
        tags$div(
          class = "modal-header",
          uiOutput("modal_fs_title"),
          tags$button(type = "button", class = "btn-close", `data-bs-dismiss` = "modal")
        ),
        tags$div(class = "modal-body", uiOutput("modal_fs_body")),
        tags$div(
          class = "modal-footer",
          actionButton("btn_save_config", "Save", class = "btn btn-success")
        )
      )
    )
  )
)


server <- function(input, output, session) {
  observeEvent(input$go_settings_click, { updateTabsetPanel(session, "main_tabs", "tab_settings") })
  observeEvent(input$go_overview,       { updateTabsetPanel(session, "main_tabs", "tab_overview") })
  observeEvent(input$go_eda_ts,         { updateTabsetPanel(session, "main_tabs", "tab_eda_ts") })
  observeEvent(input$go_eda_rel,        { updateTabsetPanel(session, "main_tabs", "tab_eda_rel") })
  observeEvent(input$go_stationary,     { updateTabsetPanel(session, "main_tabs", "tab_stationary") })
  observeEvent(input$go_modeling,       { updateTabsetPanel(session, "main_tabs", "tab_modeling") })
  observeEvent(input$go_forecast,       { updateTabsetPanel(session, "main_tabs", "tab_forecast") })
  observeEvent(input$go_wrapup,         { updateTabsetPanel(session, "main_tabs", "tab_wrapup") })

  # =========================
  # DATA SOURCE (demo + upload)
  # =========================
  df_raw <- reactiveVal(NULL)

  observe({
    if (is.null(df_raw())) {
      df_raw(read_data_safe(DATA_PATH))
    }
  })

  observeEvent(input$data_file, {
    in_file <- input$data_file
    if (is.null(in_file) || is.null(in_file$datapath) || !nzchar(in_file$datapath)) return()

    out <- tryCatch(
      read_data_safe(in_file$datapath, in_file$name),
      error = function(e) {
        showNotification(
          paste0("Gabim gjatë leximit të skedarit: ", e$message, ". U përdor dataset-i demo."),
          type = "error",
          duration = 8
        )
        read_data_safe(DATA_PATH)
      }
    )

    df_raw(out)

    # burimi i të dhënave (opsionale)
    if (!is.null(in_file$name) && nzchar(in_file$name)) {
      if (is.null(isolate(input$data_source)) || !nzchar(isolate(input$data_source))) {
        updateTextInput(session, "data_source", value = in_file$name)
      }
    }
  }, ignoreInit = TRUE)

  # Dataset aktiv për gjithë app-in
  df <- reactive(df_raw())

  # =========================
  # 0.1) Mbush dropdown-at dinamikë sapo ndryshon dataset-i
  # =========================
  observeEvent(df(), {
    d <- df()
    if (is.null(d) || nrow(d) == 0) return()

    nm <- names(d)
    if (length(nm) == 0) return()

    # (A) Kandidatë për kolonën e kohës
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

    # (B) Kandidatë numerikë
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

    # (C) Mbush selector-at e analizës me kolonat numerike
    choices <- num_cols
    if (length(choices) == 0) choices <- cols
    if (length(choices) == 0) return()

    s1 <- choices[1]
    s2 <- if (length(choices) >= 2) choices[2] else choices[1]

    updateSelectInput(session, "eda_series",
                      choices = choices,
                      selected = pick(isolate(input$eda_series), choices, s1))

    updateSelectInput(session, "stat_series",
                      choices = choices,
                      selected = pick(isolate(input$stat_series), choices, s1))

    updateSelectInput(session, "model_series",
                      choices = choices,
                      selected = pick(isolate(input$model_series), choices, s1))

    updateSelectInput(session, "forecast_series",
                      choices = choices,
                      selected = pick(isolate(input$forecast_series), choices, s1))

    updateSelectInput(session, "rel_x",
                      choices = choices,
                      selected = pick(isolate(input$rel_x), choices, s1))

    updateSelectInput(session, "rel_y",
                      choices = choices,
                      selected = pick(isolate(input$rel_y), choices, s2))

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

      output$modal_sm_body <- renderUI(tagList(
        fileInput("csv_file_modal", label = NULL, accept = ".csv"),
        tags$small("Hidh CSV këtu (drag & drop) ose Browse.", style = "opacity:.8;")
      ))

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

    # 1) Lexo datasetin dhe bëje aktiv për gjithë app-in
    d <- read_data_safe(input$csv_file_modal$datapath, input$csv_file_modal$name)
    df_raw(d)

    # 2) Mbyll modalin e vogël
    session$sendCustomMessage("toggle_modal", list(id = "main_modal_sm", action = "hide"))

    nm <- names(d)

    # Sugjero time col (nga detect_time_candidates)
    cand <- tryCatch(detect_time_candidates(d), error = function(e) {
      data.frame(col = nm, score = 0)
    })
    time_choices <- unique(cand$col)
    if (length(time_choices) == 0) time_choices <- nm
    time_default <- time_choices[1]

    # Sugjero numeric cols (jo time)
    cols <- setdiff(nm, time_default)
    num_cols <- cols[vapply(d[cols], function(x) {
      xn <- to_numeric_safe(x)
      mean(!is.na(xn)) >= 0.70
    }, logical(1))]
    if (length(num_cols) == 0) num_cols <- cols
    value_default <- head(num_cols, min(3, length(num_cols)))

    # 3) Mbush modalin e madh (preview + konfigurime)
    output$modal_fs_title <- renderUI(tags$h5(class = "modal-title", "Konfigurimi i dataset-it"))

    output$modal_fs_body <- renderUI(tagList(
      fluidRow(
        column(8, DT::DTOutput("csv_preview_big")),
        column(4,
          selectInput("modal_time_col", "Kolona e kohës",
                      choices = time_choices, selected = time_default),

          selectizeInput("modal_value_cols", "Seritë numerike",
                         choices = setdiff(nm, time_default),
                         selected = value_default,
                         multiple = TRUE),

          selectInput("modal_dup", "Duplikate në kohë", c("mean","sum","last"), "mean"),
          selectInput("modal_freq", "Frekuenca", c("auto","yearly","quarterly","monthly","daily"), "auto")
        )
      )
    ))

    output$csv_preview_big <- DT::renderDT({
      DT::datatable(head(d, 200), options = list(scrollX = TRUE, pageLength = 15))
    })

    # 4) Hape modalin fullscreen
    session$sendCustomMessage("toggle_modal", list(id = "main_modal_fs", action = "show"))

    # 5) Përditëso burimin e të dhënave (opsionale)
    if (!is.null(input$csv_file_modal$name) && nzchar(input$csv_file_modal$name)) {
      if (is.null(isolate(input$data_source)) || !nzchar(isolate(input$data_source))) {
        updateTextInput(session, "data_source", value = input$csv_file_modal$name)
      }
    }
  })

  # Kur useri ndryshon time col në modal fs → rifresko choices për value cols (live)
  observeEvent(input$modal_time_col, {
    req(df())
    d <- df()
    nm <- names(d)

    updateSelectizeInput(
      session, "modal_value_cols",
      choices = setdiff(nm, input$modal_time_col),
      selected = isolate(input$modal_value_cols),
      server = TRUE
    )
  }, ignoreInit = TRUE)

  observeEvent(input$btn_save_config, {
    req(input$modal_time_col)
    req(input$modal_value_cols)

    # Mbyll modalin
    session$sendCustomMessage("toggle_modal", list(id = "main_modal_fs", action = "hide"))

    # Përditëso input-et kryesore me choices + selected
    d <- df()
    nm <- names(d)

    # time
    updateSelectInput(session, "data_time_col",
                      choices = nm,
                      selected = input$modal_time_col)

    # values (jo time)
    updateSelectizeInput(session, "data_value_cols",
                         choices = setdiff(nm, input$modal_time_col),
                         selected = input$modal_value_cols,
                         server = TRUE)

    showNotification("Konfigurimi i dataset-it u ruajt me sukses.", type = "message", duration = 5)
  })

  # =========================
  # MAIN MODULES
  # =========================

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

    # ruaj sa të mundesh selections aktuale
    vc_cur <- isolate(input$data_value_cols)
    vc_sel <- vc_cur[vc_cur %in% num_cols]
    if (length(vc_sel) == 0) vc_sel <- head(num_cols, min(3, length(num_cols)))

    updateSelectizeInput(session, "data_value_cols",
                        choices = num_cols,
                        selected = vc_sel,
                        server = TRUE)

    # rifresko edhe selector-at e analizës (që mos mbeten me vlera që s’janë më valid)
    choices <- num_cols
    if (length(choices) == 0) return()

    s1 <- choices[1]
    s2 <- if (length(choices) >= 2) choices[2] else choices[1]

    pick <- function(cur, choices, fallback) {
      if (!is.null(cur) && length(cur) == 1 && cur %in% choices) cur else fallback
    }

    updateSelectInput(session, "eda_series",      choices = choices, selected = pick(isolate(input$eda_series), choices, s1))
    updateSelectInput(session, "stat_series",     choices = choices, selected = pick(isolate(input$stat_series), choices, s1))
    updateSelectInput(session, "model_series",    choices = choices, selected = pick(isolate(input$model_series), choices, s1))
    updateSelectInput(session, "forecast_series", choices = choices, selected = pick(isolate(input$forecast_series), choices, s1))
    updateSelectInput(session, "rel_x",           choices = choices, selected = pick(isolate(input$rel_x), choices, s1))
    updateSelectInput(session, "rel_y",           choices = choices, selected = pick(isolate(input$rel_y), choices, s2))
  })

  server_plots(input, output, session, df)
}

shinyApp(ui, server)
