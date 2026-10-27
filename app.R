# Funksionet jetojnë te R/: Shiny i ngarkon vetë para app.R.
suppressPackageStartupMessages({
  library(shiny)
  library(shinyjs)
  library(plotly)
  library(ggplot2)
  library(dplyr)
  library(tidyr)
  library(readr)
  library(forecast)
  library(scales)
  library(tseries)
  library(DT)
  library(jsonlite)
  library(zoo)
})
options(scipen = 999)

# Të dhënat e përdoruesit te storage/ (migrim që kopjon) dhe gjuha nga settings.json.
init_storage()
set_lang(read_settings()$lang)

# ui si funksion: lexohet për çdo kërkesë, që pas session$reload() të dalin
# gjuha e re dhe state-i i ruajtur i background-it.
ui <- function(req) {
  BG_STATE <- read_bg_state()

  app_page(
    hidden_inputs = div(
      style = "display:none;",
      textInput("data_source", label = NULL, value = ""),
      selectInput("data_time_col", label = NULL, choices = character(0)),
      selectizeInput("data_value_cols", label = NULL, choices = character(0), multiple = TRUE),
      selectInput("data_dup", label = NULL, choices = c("mean","sum","first","last"), selected = DUP_POLICY),
      selectInput("data_freq", label = NULL, choices = c("auto","yearly","quarterly","monthly","weekly","daily"), selected = FREQ_POLICY)
    ),

    main_tabs = tabsetPanel(
      id = "main_tabs",
      type = "hidden",
      selected = page_tab(DEFAULT_PAGE),

      tabPanel(
        title = tr("page.settings.menu"),
        value = page_tab("settings"),

        div(class="glass-divider"),

        # ===== Dataset section =====
        div(
          class = "overview-top",
          h4(tr("settings.dataset")),
          actionButton(
            "btn_open_upload",
            tr("settings.upload_csv"),
            class = "glass-btn ajax-modal-sm",
            `data-modal` = "upload",
            `data-title` = tr("settings.upload_csv")
          )
        ),
        uiOutput("saved_datasets_ui"),

        div(class="glass-divider"),

        # ===== Background section =====
        section_box(
          h4(tr("settings.background")),

          radioButtons(
            "bg_mode",
            tr("bg.mode_label"),
            choices  = setNames(c("image", "color", "none"),
                                c(tr("bg.mode.image"), tr("bg.mode.color"), tr("bg.mode.none"))),
            selected = BG_STATE$active_mode %||% "image",
            inline   = TRUE
          ),

          conditionalPanel(
            condition = "input.bg_mode == 'image'",

            radioButtons(
              "bg_scope",
              tr("bg.scope_label"),
              choices  = setNames(c("global", "custom"), c(tr("bg.scope.global"), tr("bg.scope.custom"))),
              selected = BG_STATE$modes$image$active_scope %||% "custom",
              inline   = TRUE
            ),

            conditionalPanel(
              condition = "input.bg_scope == 'global'",
              tags$div(class = "bg-tabs-title", tr("bg.global_title")),
              uiOutput("bg_global_card")
            ),

            conditionalPanel(
              condition = "input.bg_scope == 'custom'",
              tags$div(class = "bg-tabs-title", tr("bg.tabs_title")),
              uiOutput("bg_tab_cards")
            ),

            checkboxInput(
              "bg_blur_on",
              tr("bg.blur"),
              value = isTRUE(BG_STATE$modes$image$blur$on)
            ),

            sliderInput(
              "bg_blur",
              tr("bg.blur_strength"),
              min   = 0,
              max   = 20,
              value = as.numeric(BG_STATE$modes$image$blur$amount %||% 10),
              step  = 1
            )
          ),

          conditionalPanel(
            condition = "input.bg_mode == 'color'",

            tags$label(tr("bg.base_color")),

            tags$div(
              id = "bg_color_grid",
              class = "bg-color-grid",
              lapply(c(
                "#0b1c24", "#111827", "#1f2937", "#374151", "#6b7280",
                "#ef4444", "#f97316", "#f59e0b", "#eab308",
                "#22c55e", "#10b981", "#06b6d4", "#3b82f6",
                "#6366f1", "#8b5cf6", "#ec4899"
              ), function(hex) {
                tags$button(
                  type = "button",
                  class = "bg-color-swatch",
                  `data-color` = hex,
                  style = paste0("background:", hex, ";"),
                  title = hex
                )
              })
            ),

            tags$div(
              class = "bg-color-row",
              tags$input(
                id    = "bg_color",
                type  = "color",
                value = BG_STATE$modes$color$value %||% "#0b1c24",
                style = "width:140px;height:46px;border-radius:12px;border:1px solid rgba(255,255,255,.25);background:transparent;"
              ),
              tags$span(id="bg_color_hex_txt", class="bg-color-hex", "")
            )
          ),

          div(
            class = "bg-save-row",
            actionButton("bg_save", tr("common.save"), class = "glass-btn"),
            uiOutput("bg_dirty_badge")
          )
        ),

        div(class = "glass-divider"),

        # ===== Gjuha (V-09) =====
        section_box(
          h4(tr("settings.language")),
          radioButtons(
            "app_lang",
            label    = NULL,
            choices  = setNames(names(LANGS), unname(LANGS)),
            selected = current_lang(),
            inline   = TRUE
          )
        )
      ),

      tabPanel(
        title = tr("page.overview.menu"),
        value = page_tab("overview"),

        div(
          class = "section-box",
          h4("Të dhënat e serive të zgjedhura"),
          div(class = "table-wrap", DT::DTOutput("ts_selected_tbl"))
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
                tags$li("Parashikim: SES/Holt dhe ARIMA")
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
        title = tr("page.eda_ts.menu"),
        value = page_tab("eda_ts"),

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
              "Dritarja lëvizëse",
              min = 3,
              max = 3,
              value = 3,
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
        title = tr("page.eda_rel.menu"),
        value = page_tab("eda_rel"),

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
        title = tr("page.stationary.menu"),
        value = page_tab("stationary"),

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
        title = tr("page.modeling.menu"),
        value = page_tab("modeling"),

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
              "Horizonti i parashikimit",
              min = 1,
              max = 1,
              value = 1,
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
        title = tr("page.forecast.menu"),
        value = page_tab("forecast"),

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

            sliderInput(
              "h",
              "Horizonti i parashikimit", 
              min = 1, 
              max =1, 
              value = 1,
              step = 1
              ),

            hr(),
            p("Grafiku paraqet vlerat e vëzhguara dhe parashikimet për periudhat pasuese, së bashku me intervalet e pasigurisë.")
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
      )
    )
  )
}

server <- function(input, output, session) {
  mod_nav_server(input, output, session)

  # Gjuha (V-09): ruhet te settings.json, pastaj faqja rifreskohet në gjuhën e re.
  observeEvent(input$app_lang, {
    lang <- input$app_lang
    if (!lang %in% names(LANGS) || identical(lang, current_lang())) return()
    write_settings(modifyList(read_settings(), list(lang = lang)))
    set_lang(lang)
    session$reload()
  }, ignoreInit = TRUE)

  uploaded_tmp_path <- reactiveVal(NULL)
  uploaded_tmp_name <- reactiveVal(NULL)

  # =========================================================
  # 2) HELPERS
  # =========================================================
  pick_choice <- function(cur, choices, fallback) {
    if (!is.null(cur) && length(cur) == 1 && nzchar(cur) && cur %in% choices) cur else fallback
  }

  # =========================================================
  # 3) SAVED DATASETS
  # =========================================================

  saved_datasets      <- reactiveVal(list_saved_datasets())
  active_dataset_file <- reactiveVal(NULL)
  pending_delete_file <- reactiveVal(NULL)
  editing_file <- reactiveVal(NULL)

  output$saved_datasets_ui <- renderUI({
    files   <- saved_datasets()
    act_mem <- active_dataset_file()

    if (length(files) == 0) {
      return(
        div(
          class = "section-box",
          h4("Datasetet e ruajtura"),
          tags$small("S’ka dataset të ruajtur te folderi data.", style = "opacity:.75;")
        )
      )
    }

    st <- tryCatch(read_state(), error = function(e) list(active = NULL))

    active <- act_mem %||% st$active %||% files[1]
    if (!(active %in% files)) active <- files[1]

    js_val <- function(x) jsonlite::toJSON(x, auto_unbox = TRUE)

    rows <- split(files, ceiling(seq_along(files) / 2))

    tagList(
      lapply(rows, function(pair) {
        tags$div(
          class = "saved-ds-grid-row",
          lapply(pair, function(f) {
            is_active <- identical(f, active)

            div(
              class = paste("section-box saved-ds-item", if (is_active) "is-active" else ""),

              tags$div(
                class = "saved-ds-row",
                onclick = sprintf(
                  "Shiny.setInputValue('activate_dataset', %s, {priority:'event'});",
                  js_val(f)
                ),

                tags$div(
                  class = "saved-ds-left",
                  tags$span(class = paste("saved-ds-dot", if (is_active) "on" else "")),
                  tags$span(class = "saved-ds-name", f),
                  if (is_active) tags$span(class = "saved-ds-badge", "Aktiv") else NULL
                ),

                tags$div(
                  class = "saved-ds-actions",

                  tags$button(
                    type  = "button",
                    class = "saved-ds-edit",
                    onclick = sprintf(
                      "event.stopPropagation(); Shiny.setInputValue('edit_dataset', %s, {priority:'event'});",
                      js_val(f)
                    ),
                    icon("pen")
                  ),

                  tags$button(
                    type  = "button",
                    class = "saved-ds-trash",
                    onclick = sprintf(
                      "event.stopPropagation(); Shiny.setInputValue('delete_dataset', %s, {priority:'event'});",
                      js_val(f)
                    ),
                    icon("trash")
                  )
                )
              )
            )
          })
        )
      })
    )
  })

  observeEvent(saved_datasets(), {
    files <- saved_datasets() %||% character(0)

    st <- tryCatch(sync_state(files), error = function(e) list(active = NULL))

    if (length(files) == 0) {
      active_dataset_file(NULL)
      return()
    }

    cur <- active_dataset_file() %||% st$active %||% files[1]

    if (is.null(cur) || !nzchar(cur) || !(cur %in% files)) {
      cur <- st$active %||% files[1]
    }

    if (!identical(active_dataset_file(), cur)) {
      active_dataset_file(cur)
    }

  }, ignoreInit = FALSE)

  observeEvent(input$activate_dataset, {
    editing_file(NULL)
    sel <- input$activate_dataset
    req(sel)

    ds <- resolve_saved_dataset_path(sel, DATASETS_DIR)
    if (!isTRUE(ds$ok)) {
      showNotification(ds$msg %||% "Dataset i pavlefshëm.", type = "error", duration = 6)
      return()
    }

    sel <- ds$file
    st <- set_active_dataset(sel)
    active_dataset_file(st$active %||% sel)

    showNotification(paste0("Dataset aktiv u bë: ", sel), type = "message", duration = 4)

  }, ignoreInit = TRUE)

  apply_dataset_cfg_to_main <- function(file, d) {
    req(file, d)

    st  <- tryCatch(read_state(), error = function(e) list())
    cfg <- tryCatch(get_dataset_config(st, file), error = function(e) list(time_col=NULL, value_cols=NULL))

    def <- resolve_dataset_defaults(d, cfg)

    updateSelectInput(session, "data_time_col", choices = def$time_choices, selected = def$time_col)
    updateSelectizeInput(session, "data_value_cols",
      choices  = def$num_cols,
      selected = def$value_cols,
      server   = TRUE
    )
  }

  observeEvent(active_dataset_file(), {
    sel   <- active_dataset_file()
    files <- saved_datasets()

    if (is.null(sel) && length(files)) {
      st2 <- set_active_dataset(files[1])
      active_dataset_file(st2$active %||% files[1])
      return()
    }

    if (is.null(sel) && !length(files)) {
      df_raw(NULL)
      updateTextInput(session, "data_source", value = "")

      updateSelectInput(session, "data_time_col", choices = character(0), selected = character(0))
      updateSelectizeInput(session, "data_value_cols", choices = character(0), selected = character(0), server = TRUE)

      showNotification("S’ka databazë. Ngarko një dataset.", type = "warning", duration = 5)
      updateTabsetPanel(session, "main_tabs", selected = page_tab("settings"))
      return()
    }

    ds <- resolve_saved_dataset_path(sel, DATASETS_DIR)
    if (!isTRUE(ds$ok)) {
      showNotification(ds$msg %||% "Dataset aktiv s’u gjet (mund të jetë fshirë).", type = "warning", duration = 6)
      active_dataset_file(NULL)
      return()
    }

    d <- tryCatch(
      read_data_safe(ds$path, ds$file),
      error = function(e) {
        showNotification(paste0("Gabim gjatë leximit: ", e$message), type = "error", duration = 8)
        NULL
      }
    )

    if (is.null(d)) return()

    df_raw(d)
    updateTextInput(session, "data_source", value = ds$file)
    apply_dataset_cfg_to_main(ds$file, d)

  }, ignoreInit = FALSE)

  observeEvent(input$edit_dataset, {
    f <- input$edit_dataset
    req(f)

    ds <- resolve_saved_dataset_path(f, DATASETS_DIR)
    if (!isTRUE(ds$ok)) {
      showNotification(ds$msg %||% "Dataset i pavlefshëm.", type = "error", duration = 6)
      return()
    }

    f <- ds$file
    showNotification(paste0("Edit: ", f), type = "message", duration = 2)

    d <- tryCatch(
      read_data_safe(ds$path, f),
      error = function(e) {
        showNotification(paste0("Gabim gjatë leximit: ", e$message), type = "error", duration = 8)
        NULL
      }
    )
    if (is.null(d)) return()

    nm <- names(d)

    st  <- read_state()
    cfg <- get_dataset_config(st, f)

    def <- resolve_dataset_defaults(d, cfg)
    time_choices <- def$time_choices
    tc           <- def$time_col
    num_cols     <- def$num_cols
    vals         <- def$value_cols

    uploaded_tmp_path(NULL)
    uploaded_tmp_name(NULL)
    editing_file(f)
    pending_data(d)
    pending_cfg(list(
      nm = nm,
      time_choices  = time_choices,
      time_default  = tc,
      value_default = vals
    ))

    output$modal_fs_title <- renderUI(tags$h5(class="modal-title", paste0("Edit dataset: ", f)))

    output$modal_fs_body <- renderUI(tagList(
      tags$div(class="cfg-top",
        fluidRow(
          column(3,
            selectInput("modal_time_col", "Kolona e kohës",
              choices  = time_choices,
              selected = tc
            )
          ),
          column(5,
            selectizeInput("modal_value_cols", "Seritë numerike",
              choices  = num_cols,
              selected = vals,
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

    session$sendCustomMessage("toggle_modal", list(id="main_modal_fs", action="show"))

    session$onFlushed(function() {
      updateSelectInput(session, "modal_time_col", choices = time_choices, selected = tc)
      updateSelectizeInput(session, "modal_value_cols",
        choices  = num_cols,
        selected = vals,
        server   = TRUE
      )
    }, once = TRUE)

  }, ignoreInit = TRUE)

  observeEvent(input$delete_dataset, {
    sel <- input$delete_dataset
    req(sel)

    pending_delete_file(sel)

    showModal(modalDialog(
      title = "Fshirje dataset",
      p(paste0("Je i sigurt që do ta fshish: ", sel, " ?")),
      footer = tagList(
        modalButton("Anulo"),
        actionButton("confirm_delete_saved", "Po, fshije", class = "btn-danger")
      ),
      easyClose = TRUE
    ))
  }, ignoreInit = TRUE)

  observeEvent(input$confirm_delete_saved, {
    removeModal()

    sel <- pending_delete_file()
    req(sel)

    ds <- resolve_saved_dataset_path(sel, DATASETS_DIR)
    if (!isTRUE(ds$ok)) {
      showNotification(ds$msg %||% "Dataset i pavlefshëm.", type = "error", duration = 5)
      pending_delete_file(NULL)
      return()
    }

    sel <- ds$file
    target <- ds$path
    was_active <- identical(active_dataset_file(), sel)

    ok <- file.remove(target)
    if (!isTRUE(ok)) {
      showNotification("S’u fshi dot file-i. Kontrollo lejet / nëse është i hapur diku.", type = "error", duration = 7)
      pending_delete_file(NULL)
      return()
    }

    files <- list_saved_datasets()
    saved_datasets(files)

    try(sync_state(files), silent = TRUE)

    if (was_active) {
      if (length(files) > 0) {
        st <- set_active_dataset(files[1])
        active_dataset_file(st$active)

        ds_next <- resolve_saved_dataset_path(st$active, DATASETS_DIR)
        d <- tryCatch(
          if (isTRUE(ds_next$ok)) read_data_safe(ds_next$path, ds_next$file) else stop(ds_next$msg %||% "Dataset i pavlefshëm."),
          error = function(e) {
            showNotification(
              paste0("S’u lexu dot dataset-i i ri: ", conditionMessage(e)),
              type = "error", duration = 7
            )
            NULL
          }
        )
        df_raw(d)

        updateTextInput(session, "data_source", value = st$active)

        showNotification("Dataset u fshi. Kalova te dataset-i tjetër.", type = "message", duration = 4)
      } else {
        active_dataset_file(NULL)
        df_raw(NULL)

        updateTextInput(session, "data_source", value = "")
        updateSelectInput(session, "data_time_col", choices = character(0), selected = character(0))
        updateSelectizeInput(session, "data_value_cols", choices = character(0), selected = character(0), server = TRUE)

        showNotification("Dataset u fshi. S’ka dataset tjetër të ruajtur.", type = "message", duration = 5)
      }
    } else {
      st <- tryCatch(read_state(), error = function(e) list(active = NULL))
      if (!is.null(st$active) && !identical(active_dataset_file(), st$active)) {
        active_dataset_file(st$active)
      }

      showNotification("Dataset u fshi me sukses.", type = "message", duration = 4)
    }

    pending_delete_file(NULL)
  }, ignoreInit = TRUE)


  # =========================================================
  # 4) DATA SOURCE
  # =========================================================
  df_raw <- reactiveVal(NULL)
  pending_data <- reactiveVal(NULL)
  pending_cfg  <- reactiveVal(NULL)

  observe({
    if (!is.null(df_raw())) return()

    files <- list_saved_datasets()
    saved_datasets(files)

    st <- tryCatch(sync_state(files), error = function(e) list(active = NULL))
    act <- st$active %||% NULL

    ds_act <- if (!is.null(act) && nzchar(act)) resolve_saved_dataset_path(act, DATASETS_DIR) else list(ok = FALSE)

    if (isTRUE(ds_act$ok)) {
      d <- tryCatch(read_data_safe(ds_act$path, ds_act$file), error = function(e) NULL)
      if (!is.null(d)) {
        df_raw(d)
        active_dataset_file(ds_act$file)
        try(updateTextInput(session, "data_source", value = ds_act$file), silent = TRUE)
        return()
      }
    }

    df_raw(NULL)
  })

  df <- reactive({ df_raw() })

  active_cfg <- reactive({
    df_raw()
    f <- active_dataset_file()
    if (is.null(f) || !nzchar(f)) return(list(time_col = NULL, value_cols = character(0)))
    st <- tryCatch(read_state(), error = function(e) list())
    tryCatch(
      get_dataset_config(st, f),
      error = function(e) list(time_col = NULL, value_cols = character(0))
    )
  })

  # =========================================================
  # 5) UPDATE SELECTORS WHEN df() CHANGES
  # =========================================================
  observeEvent(df(), {
    d <- df()
    if (is.null(d) || nrow(d) == 0) return()

    nm <- names(d)
    if (length(nm) == 0) return()

    f0 <- active_dataset_file()
    st0 <- tryCatch(read_state(), error = function(e) list())
    cfg <- tryCatch(get_dataset_config(st0, f0), error = function(e) list(time_col = NULL, value_cols = character(0)))

    def <- resolve_dataset_defaults(
      d, cfg,
      current_time   = isolate(input$data_time_col),
      current_values = isolate(input$data_value_cols)
    )
    time_choices <- def$time_choices
    tc_sel       <- def$time_col
    num_cols     <- def$num_cols
    vc_sel       <- def$value_cols
    cols         <- setdiff(nm, tc_sel)

    updateSelectInput(session, "data_time_col", choices = time_choices, selected = tc_sel)

    updateSelectizeInput(session, "data_value_cols",
      choices  = num_cols,
      selected = vc_sel,
      server   = TRUE
    )

    choices <- vc_sel
    if (length(choices) == 0) choices <- num_cols
    if (length(choices) == 0) choices <- cols
    if (length(choices) == 0) return()

    s1 <- choices[1]
    s2 <- if (length(choices) >= 2) choices[2] else choices[1]

    updateSelectInput(session, "eda_series",
      choices = choices,
      selected = pick_choice(isolate(input$eda_series), choices, s1)
    )
    updateSelectInput(session, "stat_series",
      choices = choices,
      selected = pick_choice(isolate(input$stat_series), choices, s1)
    )
    updateSelectInput(session, "model_series",
      choices = choices,
      selected = pick_choice(isolate(input$model_series), choices, s1)
    )
    updateSelectInput(session, "forecast_series",
      choices = choices,
      selected = pick_choice(isolate(input$forecast_series), choices, s1)
    )
    updateSelectInput(session, "rel_x",
      choices = choices,
      selected = pick_choice(isolate(input$rel_x), choices, s1)
    )
    updateSelectInput(session, "rel_y",
      choices = choices,
      selected = pick_choice(isolate(input$rel_y), choices, s2)
    )
  }, ignoreInit = FALSE)

  # =========================================================
  # 6) MODAL FLOW
  # =========================================================
  observeEvent(input$ajax_modal_open, {
    req(input$ajax_modal_open$modal)

    modal <- input$ajax_modal_open$modal
    title <- input$ajax_modal_open$title

    if (modal == "sm") {
      output$modal_sm_title <- renderUI(tags$h5(class = "modal-title", title))
      output$modal_sm_body <- renderUI({
        tagList(
          tags$div(id = "csv_file_modal_pond_host"),
          fileInput("csv_file_modal", label = NULL, accept = c(".csv"))
        )
      })
      session$sendCustomMessage("toggle_modal", list(id = "main_modal_sm", action = "show"))
    }
  })

  observeEvent(input$csv_file_modal, {
    req(input$csv_file_modal$datapath, input$csv_file_modal$name)

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

    def <- resolve_dataset_defaults(d)

    pending_data(d)
    pending_cfg(list(
      nm = names(d),
      time_choices = def$time_choices,
      time_default = def$time_col,
      value_default = def$value_cols
    ))

    if (nzchar(input$csv_file_modal$name)) {
      if (is.null(isolate(input$data_source)) || !nzchar(isolate(input$data_source))) {
        updateTextInput(session, "data_source", value = input$csv_file_modal$name)
      }
    }

    showNotification("CSV u ngarkua. Tani kliko Proceed për konfigurim.", type = "message", duration = 5)
  }, ignoreInit = TRUE)

  observeEvent(input$btn_cancel_upload, {
    editing_file(NULL)
    session$sendCustomMessage("toggle_modal", list(id = "main_modal_sm", action = "hide"))
    pending_cfg(NULL); pending_data(NULL)
    uploaded_tmp_path(NULL); uploaded_tmp_name(NULL)
  }, ignoreInit = TRUE)

  observeEvent(input$btn_proceed_upload, {
    req(pending_data(), pending_cfg())

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
    d  <- pending_data()

    tc <- input$modal_time_col

    num_cols <- detect_numeric_cols(d, exclude = tc)
    sel <- pick_value_cols(num_cols, isolate(input$modal_value_cols))

    updateSelectizeInput(session, "modal_value_cols",
      choices  = num_cols,
      selected = sel,
      server   = TRUE
    )
  }, ignoreInit = TRUE)

  observeEvent(input$btn_save_config, {
    if (length(input$modal_value_cols) == 0) {
      showNotification("Zgjidh të paktën 1 seri numerike!", type = "error")
      return()
    }

    req(input$modal_time_col, input$modal_value_cols, pending_data())

    tc_check <- isolate(input$modal_time_col)
    d_check  <- pending_data()
    time_ok <- tryCatch({
      parse_time_safe(d_check[[tc_check]])
      TRUE
    }, error = function(e) e$message)

    if (!isTRUE(time_ok)) {
      showNotification(paste0("Kolona e kohës nuk është e vlefshme: ", time_ok), type = "error", duration = 8)
      return()
    }

    session$sendCustomMessage("toggle_modal", list(id = "main_modal_fs", action = "hide"))

    d_pending <- pending_data()
    nm_pending <- names(d_pending)

    tc_in   <- isolate(input$modal_time_col)
    vals_in <- isolate(input$modal_value_cols)

    final_file <- isolate(editing_file())
    if (is.null(final_file) || !nzchar(final_file)) {
      final_file <- isolate(active_dataset_file())
    }

    up_path <- uploaded_tmp_path()
    up_name <- uploaded_tmp_name()

    is_edit_mode <- !is.null(isolate(editing_file())) && nzchar(isolate(editing_file()))

    if (!is_edit_mode) {
      if (!is.null(up_path) && file.exists(up_path) && !is.null(up_name) && nzchar(up_name)) {

        safe <- sanitize_filename(up_name, default_ext = "csv")
        target <- normalize_app_path(file.path(DATASETS_DIR, safe))

        if (!is_path_inside_dir(target, DATASETS_DIR)) {
          showNotification("Emri i dataset-it nuk lejohet.", type = "error", duration = 8)
          session$sendCustomMessage("toggle_modal", list(id = "main_modal_fs", action = "show"))
          return()
        }

        if (file.exists(target)) {
          stem <- tools::file_path_sans_ext(safe)
          ext  <- tools::file_ext(safe)
          safe <- paste0(stem, "_", format(Sys.time(), "%Y%m%d_%H%M%S"), ".", ext)
          target <- normalize_app_path(file.path(DATASETS_DIR, safe))
        }

        ok <- file.copy(up_path, target, overwrite = FALSE)

        if (isTRUE(ok)) {
          files <- list_saved_datasets()
          saved_datasets(files)

          st <- set_active_dataset(safe)
          active_dataset_file(st$active)
          final_file <- st$active

          showNotification(paste0("Dataset u ruajt te data/", safe), type = "message", duration = 6)
        } else {
          showNotification("S’u arrit me ruajt datasetin te /data (permissions).", type = "error", duration = 8)
          session$sendCustomMessage("toggle_modal", list(id = "main_modal_fs", action = "show"))
          return()
        }
      } else {
        if (!is.null(final_file) && nzchar(final_file)) {
          st <- set_active_dataset(final_file)
          active_dataset_file(st$active)
          final_file <- st$active
        }
      }
    } else {
      if (!is.null(final_file) && nzchar(final_file)) {
        st <- set_active_dataset(final_file)
        active_dataset_file(st$active)
        final_file <- st$active
      }
    }

    d <- d_pending
    if (!is.null(final_file) && nzchar(final_file)) {
      ds_final <- resolve_saved_dataset_path(final_file, DATASETS_DIR)
      if (isTRUE(ds_final$ok)) {
        final_file <- ds_final$file
        d2 <- tryCatch(
          read_data_safe(ds_final$path, final_file),
          error = function(e) {
            showNotification(paste0("S’u rihap dot dataset-i nga disku: ", e$message),
                            type = "error", duration = 8)
            NULL
          }
        )
        if (!is.null(d2)) d <- d2
      }
    }

    def <- resolve_dataset_defaults(d, list(time_col = tc_in, value_cols = vals_in))
    chosen_tc   <- def$time_col
    chosen_vals <- def$value_cols

    if (!is.null(final_file) && nzchar(final_file)) {
      ds_cfg <- resolve_saved_dataset_path(final_file, DATASETS_DIR)
      if (!isTRUE(ds_cfg$ok)) {
        showNotification(ds_cfg$msg %||% "Dataset i pavlefshëm.", type = "error", duration = 8)
        session$sendCustomMessage("toggle_modal", list(id = "main_modal_fs", action = "show"))
        return()
      }
      final_file <- ds_cfg$file

      st2 <- read_state()
      st2 <- update_dataset_config(st2, final_file, chosen_tc, chosen_vals)
      write_state(st2)
    }

    if (!is.null(final_file) && nzchar(final_file)) {
      ds_final <- resolve_saved_dataset_path(final_file, DATASETS_DIR)
      if (isTRUE(ds_final$ok)) {
        d2 <- tryCatch(read_data_safe(ds_final$path, ds_final$file), error = function(e) NULL)
        if (!is.null(d2)) d <- d2
      }
    }

    df_raw(NULL)
    df_raw(d)

    if (!is.null(final_file) && nzchar(final_file)) {
      updateTextInput(session, "data_source", value = final_file)
    }

    pending_cfg(NULL); pending_data(NULL)
    uploaded_tmp_path(NULL); uploaded_tmp_name(NULL)
    editing_file(NULL)

    showNotification("Konfigurimi i dataset-it u ruajt me sukses.", type = "message", duration = 5)
  }, ignoreInit = TRUE)

  observeEvent(input$btn_cancel_config, {
    was_edit_mode <- !is.null(isolate(editing_file())) && nzchar(isolate(editing_file()))
    has_upload_draft <- !is.null(isolate(uploaded_tmp_path())) && nzchar(isolate(uploaded_tmp_path()))

    editing_file(NULL)
    session$sendCustomMessage("toggle_modal", list(id = "main_modal_fs", action = "hide"))
    if (was_edit_mode) {
      pending_cfg(NULL)
      pending_data(NULL)
    }
    if (!was_edit_mode && has_upload_draft) {
      session$sendCustomMessage("toggle_modal", list(id = "main_modal_sm", action = "show"))
    }
  }, ignoreInit = TRUE)

  # =========================================================
  # 7) when time col changes manually -> recompute numeric cols
  # =========================================================
  observeEvent(input$data_time_col, {
    d <- df()
    if (is.null(d) || nrow(d) == 0) return()

    nm <- names(d)
    tc_sel <- input$data_time_col
    if (is.null(tc_sel) || !nzchar(tc_sel) || !(tc_sel %in% nm)) return()

    cfg <- active_cfg()

    num_cols <- detect_numeric_cols(d, exclude = tc_sel)
    vc_sel   <- pick_value_cols(num_cols, cfg$value_cols, isolate(input$data_value_cols))

    updateSelectizeInput(session, "data_value_cols",
      choices  = num_cols,
      selected = vc_sel,
      server   = TRUE
    )
  }, ignoreInit = TRUE)


  # =========================================================
  # 8) BACKGROUND SETTINGS
  # =========================================================

  BG_TABS <- lapply(page_ids(), function(id) {
    list(id = page_tab(id), label = tr(paste0("page.", id, ".menu")))
  })

  BG_STATE <- read_bg_state()

  bg_saved <- reactiveVal(BG_STATE)
  bg_dirty <- reactiveVal(FALSE)

  APP_DIR <- get0("APP_DIR", inherits = TRUE) %||% getwd()

  bg_ver_src <- function(path, st) {
    if (is.null(path) || !nzchar(path)) return(NULL)
    v <- st$version %||% 0
    if (!isTRUE(v > 0)) return(path)
    paste0(path, "?v=", v)
  }

  observeEvent(
    list(input$bg_mode, input$bg_scope, input$bg_blur_on, input$bg_blur, input$bg_color),
    { bg_dirty(TRUE) },
    ignoreInit = TRUE
  )

  output$bg_dirty_badge <- renderUI({
    if (!isTRUE(bg_dirty())) return(NULL)
    tags$span(class="bg-badge", "Ke ndryshime pa Save")
  })

  # --- GLOBAL CARD ---
  output$bg_global_card <- renderUI({
    st <- bg_saved()

    g <- st$modes$image$scopes$global$global %||% NULL
    src <- if (!is.null(g) && nzchar(g)) bg_ver_src(g, st) else NULL
    status <- if (!is.null(g) && nzchar(g)) "Aktive: Custom" else "Aktive: Pa foto (ngjyrë default)"

    div(
      class="bg-tab-card",
      div(
        class = "bg-tab-thumb bg-thumb-empty",
        if (!is.null(src) && nzchar(src)) tags$img(src = src) else HTML(BG_PLACEHOLDER_SVG)
      ),
      div(
        class="bg-tab-meta",
        div(class="bg-tab-name", "Global"),
        div(class="bg-tab-status", status)
      ),
      div(
        class="bg-tab-actions",
        actionButton("bg_edit_global_btn", "Edit", class="glass-btn btn-sm")
      )
    )
  })

  # --- PER TAB CARDS ---
  output$bg_tab_cards <- renderUI({
    st <- bg_saved()

    per_tab <- st$modes$image$scopes$custom$per_tab %||% setNames(list(), character())
    if (is.null(per_tab) || !is.list(per_tab)) per_tab <- setNames(list(), character())

    tags$div(
      class="bg-tabs-grid",
      lapply(BG_TABS, function(t) {
        tabid <- t$id
        custom <- per_tab[[tabid]] %||% NULL
        src <- if (!is.null(custom) && nzchar(custom)) bg_ver_src(custom, st) else NULL
        status <- if (!is.null(custom) && nzchar(custom)) "Aktive: Custom" else "Aktive: Pa foto (ngjyrë default)"

        div(
          class="bg-tab-card",
          div(
            class = "bg-tab-thumb bg-thumb-empty",
            if (!is.null(src) && nzchar(src)) tags$img(src = src) else HTML(BG_PLACEHOLDER_SVG)
          ),
          div(
            class="bg-tab-meta",
            div(class="bg-tab-name", t$label),
            div(class="bg-tab-status", status)
          ),
          div(
            class="bg-tab-actions",
            actionButton(paste0("bg_edit__", tabid), "Edit", class="glass-btn btn-sm")
          )
        )
      })
    )
  })

  BG_PLACEHOLDER_SVG <- '
    <svg viewBox="0 0 120 90" xmlns="http://www.w3.org/2000/svg" role="img" aria-label="Gallery placeholder">
      <defs>
        <filter id="wobble">
          <feTurbulence type="fractalNoise" baseFrequency="0.9" numOctaves="1" seed="2" result="noise"/>
          <feDisplacementMap in="SourceGraphic" in2="noise" scale="1.4" xChannelSelector="R" yChannelSelector="G"/>
        </filter>
      </defs>

      <g filter="url(#wobble)" fill="none" stroke="rgba(255,255,255,0.75)" stroke-width="3"
        stroke-linecap="round" stroke-linejoin="round">
        <rect x="10" y="10" width="100" height="70" rx="10"/>
        <circle cx="38" cy="30" r="6"/>
        <path d="M22 66 L44 44 L58 58 L80 36 L98 54"/>
        <path d="M22 66 H98"/>
      </g>
    </svg>
    '

  # ===========================
  # Drafts for selections
  # ===========================
  draft_global_path <- reactiveVal(NULL)
  draft_per_tab     <- reactiveVal(setNames(list(), character()))

  # ===========================
  # SAVE
  # ===========================
  observeEvent(input$bg_save, {

    BG_CLEAR <- "__CLEAR__"
    st <- bg_saved()

    if (is.null(st$modes) || !is.list(st$modes)) st$modes <- list()
    if (is.null(st$modes$color) || !is.list(st$modes$color)) st$modes$color <- list(value = "#0b1c24")
    if (is.null(st$modes$image) || !is.list(st$modes$image)) st$modes$image <- list()
    if (is.null(st$modes$image$blur) || !is.list(st$modes$image$blur)) st$modes$image$blur <- list(on = TRUE, amount = 10L)
    if (is.null(st$modes$image$scopes) || !is.list(st$modes$image$scopes)) st$modes$image$scopes <- list()

    if (is.null(st$modes$image$scopes$custom) || !is.list(st$modes$image$scopes$custom)) {
      st$modes$image$scopes$custom <- list(per_tab = setNames(list(), character()))
    }
    if (is.null(st$modes$image$scopes$global) || !is.list(st$modes$image$scopes$global)) {
      st$modes$image$scopes$global <- list(global = NULL)
    }
    if (is.null(st$modes$image$scopes$custom$per_tab) || !is.list(st$modes$image$scopes$custom$per_tab)) {
      st$modes$image$scopes$custom$per_tab <- setNames(list(), character())
    }

    st$active_mode <- input$bg_mode %||% st$active_mode %||% "image"
    if (!st$active_mode %in% c("image", "color", "none")) st$active_mode <- "image"

    if (identical(st$active_mode, "color")) {
      if (!is.null(input$bg_color) && nzchar(input$bg_color)) {
        st$modes$color$value <- input$bg_color
      }
    }

    if (identical(st$active_mode, "image")) {

      st$modes$image$blur$on     <- isTRUE(input$bg_blur_on %||% st$modes$image$blur$on)
      st$modes$image$blur$amount <- as.integer(input$bg_blur %||% st$modes$image$blur$amount %||% 10)

      st$modes$image$active_scope <- input$bg_scope %||% st$modes$image$active_scope %||% "custom"
      if (!st$modes$image$active_scope %in% c("custom", "global")) st$modes$image$active_scope <- "custom"

      if (identical(st$modes$image$active_scope, "global")) {
        dp <- draft_global_path()

        if (identical(dp, BG_CLEAR)) {
          st$modes$image$scopes$global$global <- NULL
          draft_global_path(NULL)

        } else if (!is.null(dp) && nzchar(dp)) {
          st$modes$image$scopes$global$global <- dp
          draft_global_path(NULL)
        }
      }

      if (identical(st$modes$image$active_scope, "custom")) {
        dpt <- draft_per_tab()

        if (is.list(dpt) && length(dpt) > 0) {
          for (tb in names(dpt)) {
            v <- dpt[[tb]]

            if (identical(v, BG_CLEAR)) {
              st$modes$image$scopes$custom$per_tab[[tb]] <- NULL

            } else if (!is.null(v) && nzchar(v)) {
              st$modes$image$scopes$custom$per_tab[[tb]] <- v
            }
          }

          pt <- st$modes$image$scopes$custom$per_tab
          if (is.list(pt) && length(pt) > 0) {
            pt <- pt[!vapply(pt, is.null, logical(1))]
            st$modes$image$scopes$custom$per_tab <- pt
          }

          draft_per_tab(setNames(list(), character()))
        }
      }
    }

    write_bg_state(st)
    st <- read_bg_state()

    bg_saved(st)
    bg_dirty(FALSE)

    session$sendCustomMessage("bg_apply", st)
    showNotification("Background u ruajt.", type = "message", duration = 3)

  }, ignoreInit = TRUE)

  session$onFlushed(function() {
    st0 <- isolate(bg_saved())
    session$sendCustomMessage("bg_apply", st0)
  }, once = TRUE)

  # ===========================
  # Media Library
  # ===========================
  bg_fs_ctx <- reactiveVal(NULL)
  bg_media_selected <- reactiveVal(NULL)
  media_refresh <- reactiveVal(0L)

  modal_show_bg <- function() {
    shinyjs::runjs("
      (function(){
        var el = document.getElementById('bg_modal_fs');
        if(!el) return;
        if (window.bootstrap && bootstrap.Modal) {
          bootstrap.Modal.getOrCreateInstance(el).show();
        } else if (window.jQuery && jQuery(el).modal) {
          jQuery(el).modal('show');
        }
      })();
    ")
  }
  modal_hide_bg <- function() {
    shinyjs::runjs("
      (function(){
        var el = document.getElementById('bg_modal_fs');
        if(!el) return;
        if (window.bootstrap && bootstrap.Modal) {
          bootstrap.Modal.getOrCreateInstance(el).hide();
        } else if (window.jQuery && jQuery(el).modal) {
          jQuery(el).modal('hide');
        }
      })();
    ")
  }

  observeEvent(input$bg_edit_global_btn, {
    bg_media_selected(NULL)
    bg_fs_ctx(list(type = "bg_picker", target = "global"))

    updateTabsetPanel(session, "bg_media_tabs", selected = "library")
    modal_show_bg()
  }, ignoreInit = TRUE)

  lapply(BG_TABS, function(t) {
    tabid <- t$id
    observeEvent(input[[paste0("bg_edit__", tabid)]], {
      bg_media_selected(NULL)
      bg_fs_ctx(list(type = "bg_picker", target = "tab", tabid = tabid))

      updateTabsetPanel(session, "bg_media_tabs", selected = "library")
      modal_show_bg()
    }, ignoreInit = TRUE)
  })

  observeEvent(input$bg_btn_close, {
    modal_hide_bg()
    bg_fs_ctx(NULL)
    bg_media_selected(NULL)
  }, ignoreInit = TRUE)

  output$bg_modal_fs_title <- renderUI({
    ctx <- bg_fs_ctx()
    if (is.null(ctx) || !identical(ctx$type, "bg_picker")) return(tags$h5(""))

    if (identical(ctx$target, "global")) {
      return(tags$h5("Media Library – Global"))
    }

    if (identical(ctx$target, "tab")) {
      lab <- NULL
      for (x in BG_TABS) if (identical(x$id, ctx$tabid)) lab <- x$label
      if (is.null(lab)) lab <- ctx$tabid
      return(tags$h5(paste0("Media Library – ", lab)))
    }

    tags$h5("Media Library")
  })

  output$bg_modal_fs_body <- renderUI({
    ctx <- bg_fs_ctx()
    if (is.null(ctx) || !identical(ctx$type, "bg_picker")) return(NULL)

    tabsetPanel(
      id = "bg_media_tabs",

      tabPanel(
        title = "Library",
        value = "library",
        uiOutput("bg_media_gallery")
      ),

      tabPanel(
        title = "Upload",
        value = "upload",

        tags$div(
          class = "bg-upload-fill",
          tags$div(id = "bg_media_upload_pond_host", class="bg-pond-host"),
          fileInput(
            "bg_media_upload",
            label = NULL,
            multiple = TRUE,
            accept = c("image/png","image/jpeg","image/jpg","image/webp")
          )
        )
      )
    )
  })

  output$bg_media_gallery <- renderUI({
    media_refresh()

    BG_CLEAR <- "__CLEAR__"

    st  <- bg_saved()
    ctx <- bg_fs_ctx()

    img_root <- file.path(APP_DIR, "www", "images")
    if (!dir.exists(img_root)) return(tags$div("Nuk gjendet www/images"))

    imgs <- list.files(
      img_root,
      pattern = "\\.(png|jpe?g|webp|gif|svg)$",
      full.names = TRUE,
      recursive = TRUE,
      ignore.case = TRUE
    )

    imgs <- normalizePath(imgs, winslash = "/")
    root_norm <- normalizePath(img_root, winslash = "/")
    imgs <- gsub(paste0("^", root_norm, "/"), "images/", imgs)

    sel <- bg_media_selected()

    active_src <- ""

    if (!is.null(ctx) && identical(ctx$type, "bg_picker")) {

      dp  <- draft_global_path()
      dpt <- draft_per_tab()

      if (identical(ctx$target, "global")) {

        if (identical(dp, BG_CLEAR)) {
          active_src <- ""
        } else if (!is.null(dp) && nzchar(dp)) {
          active_src <- dp
        } else {
          g <- st$modes$image$scopes$global$global %||% ""
          active_src <- if (nzchar(g)) g else ""
        }

      } else if (identical(ctx$target, "tab")) {

        tb <- ctx$tabid
        v  <- NULL
        if (!is.null(tb) && nzchar(tb) && is.list(dpt)) {
          v <- dpt[[tb]] %||% NULL
        }

        if (identical(v, BG_CLEAR)) {
          active_src <- ""
        } else if (!is.null(v) && nzchar(v)) {
          active_src <- v
        } else {
          per_tab <- st$modes$image$scopes$custom$per_tab %||% setNames(list(), character())
          cst <- per_tab[[tb]] %||% ""
          active_src <- if (nzchar(cst)) cst else ""
        }
      }
    }

    if (length(imgs) == 0) {
      return(tags$div(class = "section-box", tags$small("S’ka foto në images/.")))
    }

    tags$div(
      class = "media-grid",
      lapply(imgs, function(src) {

        is_active <- nzchar(active_src) && identical(src, active_src)
        is_sel    <- !is.null(sel) && identical(src, sel)

        cls <- "media-card"
        if (is_active) cls <- paste(cls, "is-active")
        if (is_sel)    cls <- paste(cls, "selected")

        tags$div(
          class = cls,
          onclick = sprintf(
            "Shiny.setInputValue('bg_media_pick','%s',{priority:'event'});",
            src
          ),

          if (is_active) tags$div(class = "media-tick", tags$i(class = "ri-check-line")),

          if (is_active) tags$button(
            type  = "button",
            class = "media-clear-btn",
            onclick = sprintf(
              "event.stopPropagation();Shiny.setInputValue('bg_media_clear_active','%s',{priority:'event'});",
              src
            ),
            tags$i(class = "ri-subtract-line")
          ),

          tags$div(class = "media-thumb", tags$img(src = src)),

          tags$div(
            class = "media-meta",
            tags$div(class = "name", basename(src)),

            tags$button(
              type  = "button",
              class = "media-delete-btn",
              onclick = sprintf(
                "event.stopPropagation();Shiny.setInputValue('bg_media_delete','%s',{priority:'event'});",
                src
              ),
              tags$i(class = "ri-delete-bin-6-line")
            )
          )
        )
      })
    )
  })

  observeEvent(input$bg_media_pick, {
    bg_media_selected(input$bg_media_pick)
  }, ignoreInit = TRUE)

  pending_delete <- reactiveVal(NULL)

  observeEvent(input$bg_media_delete, {
    src <- input$bg_media_delete %||% ""
    if (!nzchar(src)) return()

    pending_delete(src)

    showModal(modalDialog(
      title = "Konfirmo fshirjen",
      paste0("Do ta fshish këtë foto? ", basename(src)),
      footer = tagList(
        modalButton("Anulo"),
        actionButton("bg_delete_confirm", "Fshi", class = "btn btn-danger")
      ),
      easyClose = TRUE
    ))
  }, ignoreInit = TRUE)

  observeEvent(input$bg_media_clear_active, {
    ctx <- bg_fs_ctx()
    if (is.null(ctx) || !identical(ctx$type, "bg_picker")) return()

    BG_CLEAR <- "__CLEAR__"

    if (identical(ctx$target, "global")) {
      draft_global_path(BG_CLEAR)
    } else if (identical(ctx$target, "tab")) {
      if (is.null(ctx$tabid) || !nzchar(ctx$tabid)) return()
      d <- draft_per_tab()
      d[[ctx$tabid]] <- BG_CLEAR
      draft_per_tab(d)
    }

    bg_dirty(TRUE)
    modal_hide_bg()
    bg_fs_ctx(NULL)
    bg_media_selected(NULL)
  }, ignoreInit = TRUE)


  observeEvent(input$bg_delete_confirm, {
    src <- pending_delete() %||% ""
    removeModal()
    pending_delete(NULL)

    if (!nzchar(src)) return()

    ext <- tolower(tools::file_ext(src))
    if (!ext %in% c("png","jpg","jpeg","webp","gif","svg")) {
      showNotification("Ky s’është file foto.", type="error", duration=4)
      return()
    }

    media_path <- resolve_media_image_path(src, APP_DIR)
    if (!isTRUE(media_path$ok)) {
      showNotification(media_path$msg %||% "Shtegu i fotos nuk lejohet.", type="error", duration=4)
      return()
    }
    src <- media_path$src

    st <- bg_saved()

    in_use <- character(0)

    g <- st$modes$image$scopes$global$global %||% ""
    if (nzchar(g)) in_use <- c(in_use, g)

    pt <- st$modes$image$scopes$custom$per_tab %||% list()
    if (is.list(pt) && length(pt) > 0) {
      in_use <- c(in_use, unlist(pt, use.names = FALSE))
    }

    in_use <- unique(in_use[!is.na(in_use) & nzchar(in_use)])

    if (src %in% in_use) {
      showNotification("S’e fshin dot: kjo foto është Default/Active ose përdoret diku.", type="error", duration=4)
      return()
    }

    abs_path <- media_path$path

    if (!file.exists(abs_path)) {
      showNotification("File s’u gjet në disk.", type="error", duration=4)
      return()
    }

    ok <- tryCatch(unlink(abs_path, force = TRUE) == 0, error = function(e) FALSE)

    if (isTRUE(ok)) {
      if (identical(bg_media_selected(), src)) bg_media_selected(NULL)
      if (identical(draft_global_path(), src)) draft_global_path(NULL)

      dpt <- draft_per_tab()
      if (is.list(dpt) && length(dpt) > 0) {
        for (k in names(dpt)) if (identical(dpt[[k]], src)) dpt[[k]] <- NULL
        dpt <- dpt[!vapply(dpt, is.null, logical(1))]
        draft_per_tab(dpt)
      }

      media_refresh(media_refresh() + 1L)
      showNotification("Foto u fshi.", type="message", duration=3)
    } else {
      showNotification("Fshirja dështoi.", type="error", duration=4)
    }
  }, ignoreInit = TRUE)

  safe_name <- function(x) {
    x <- gsub("[^A-Za-z0-9_-]+", "_", x)
    x <- gsub("^_+|_+$", "", x)
    x
  }

  BG_UPLOAD_MAX_BYTES <- 5 * 1024^2

  processed_datapaths <- reactiveVal(character(0))

  observeEvent(input$bg_media_upload, {
    req(input$bg_media_upload)

    up <- input$bg_media_upload
    if (!is.data.frame(up) || nrow(up) == 0) return()

    seen <- processed_datapaths()
    new_count <- 0L

    dest_dir <- file.path(APP_DIR, "www", "images")
    if (!dir.exists(dest_dir)) dir.create(dest_dir, recursive = TRUE)

    for (i in seq_len(nrow(up))) {
      dp <- up$datapath[i]
      if (is.na(dp) || !nzchar(dp) || dp %in% seen) next

      orig_name <- up$name[i] %||% paste0("image_", i)
      mime <- if ("type" %in% names(up)) up$type[i] else NULL
      size <- if ("size" %in% names(up)) up$size[i] else NULL
      chk <- validate_bg_upload_file(
        path = dp,
        filename = orig_name,
        mime = mime,
        size = size,
        max_bytes = BG_UPLOAD_MAX_BYTES
      )

      if (!isTRUE(chk$ok)) {
        showNotification(paste0(basename(orig_name), ": ", chk$msg), type="error", duration=6)
        seen <- c(seen, dp)
        next
      }

      ext <- chk$ext

      base <- safe_name(tools::file_path_sans_ext(orig_name))
      if (is.na(base) || !nzchar(base)) base <- paste0("img_", format(Sys.time(), "%Y%m%d_%H%M%S"))

      out_abs <- normalize_app_path(file.path(dest_dir, paste0(base, ".", ext)))
      suffix <- 0L
      while (file.exists(out_abs)) {
        suffix <- suffix + 1L
        base2 <- paste0(base, "_", format(Sys.time(), "%Y%m%d_%H%M%S"), "_", suffix)
        out_abs <- file.path(dest_dir, paste0(base2, ".", ext))
      }

      out_abs <- normalize_app_path(out_abs)
      if (!is_path_inside_dir(out_abs, dest_dir)) {
        showNotification("Emri i fotos nuk lejohet.", type="error", duration=6)
        seen <- c(seen, dp)
        next
      }

      ok <- file.copy(dp, out_abs, overwrite = FALSE)

      if (isTRUE(ok)) {
        new_count <- new_count + 1L
        seen <- c(seen, dp)
      }
    }

    processed_datapaths(seen)

    if (new_count > 0) {
      media_refresh(media_refresh() + 1L)

      bg_media_selected(NULL)

      session$sendCustomMessage("pond_clear", list(inputId = "bg_media_upload"))
      processed_datapaths(character(0))

      updateTabsetPanel(session, "bg_media_tabs", selected = "library")

      showNotification(paste0("U ngarkuan ", new_count, " foto ✅"), type="message", duration=3)
    }

  }, ignoreInit = TRUE)

  observeEvent(input$bg_btn_use, {
    ctx <- bg_fs_ctx()
    if (is.null(ctx) || !identical(ctx$type, "bg_picker")) return()

    req(bg_media_selected())

    if (identical(ctx$target, "global")) {
      draft_global_path(bg_media_selected())
    } else if (identical(ctx$target, "tab")) {
      d <- draft_per_tab()
      d[[ctx$tabid]] <- bg_media_selected()
      draft_per_tab(d)
    }

    bg_dirty(TRUE)
    modal_hide_bg()

    bg_fs_ctx(NULL)
  }, ignoreInit = TRUE)

  output$ts_selected_tbl <- DT::renderDT({
    d0 <- df()
    req(d0)

    cfg <- active_cfg()

    tc <- cfg$time_col %||% input$data_time_col
    shiny::validate(shiny::need(!is.null(tc) && tc %in% names(d0),
                              "Zgjidh kolonën e kohës te Settings."))

    sel <- cfg$value_cols %||% input$data_value_cols %||% character(0)
    sel <- sel[sel %in% names(d0)]
    shiny::validate(shiny::need(length(sel) > 0,
                              "S’ke zgjedh asnjë seri numerike te Settings."))

    d <- make_df_dyn(d0, tc)

    if (!is.null(tc) && tc != "Time" && "Time" %in% names(d)) {
      names(d)[names(d) == "Time"] <- tc
    }

    keep <- intersect(c(tc, sel), names(d))
    out  <- dplyr::select(d, dplyr::all_of(keep))

    DT::datatable(
      out,
      rownames = FALSE,
      class = "display nowrap cell-border compact",
      options = list(
        dom = "lfrtip",
        pageLength = 10,
        lengthMenu = c(5, 10, 20, 50),
        scrollX = TRUE,
        autoWidth = TRUE,
        deferRender = TRUE
      )
    )
  }, server = TRUE)

  observeEvent(input$main_tabs, {
    if (identical(input$main_tabs, page_tab("overview"))) {
      session$sendCustomMessage("dt_adjust", "ts_selected_tbl")
    }
  }, ignoreInit = TRUE)

  session$onFlushed(function() {
    session$sendCustomMessage("dt_adjust", "ts_selected_tbl")
  }, once = TRUE)

  server_plots(input, output, session, df)
}

shinyApp(ui, server)
