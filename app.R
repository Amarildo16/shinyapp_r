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
    main_tabs = tabsetPanel(
      id = "main_tabs",
      type = "hidden",
      selected = page_tab(DEFAULT_PAGE),

      tabPanel(
        title = tr("page.settings.menu"),
        value = page_tab("settings"),

        div(class="glass-divider"),

        # ===== Dataset section =====
        mod_datasets_ui("datasets"),

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

        mod_overview_ui("overview")
      ),

      tabPanel(
        title = tr("page.eda_ts.menu"),
        value = page_tab("eda_ts"),

        mod_eda_ts_ui("eda_ts")
      ),

      tabPanel(
        title = tr("page.eda_rel.menu"),
        value = page_tab("eda_rel"),

        mod_eda_rel_ui("eda_rel")
      ),

      tabPanel(
        title = tr("page.stationary.menu"),
        value = page_tab("stationary"),

        mod_stationarity_ui("stationary")
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
    ),

    modals = tagList(mod_datasets_modals_ui("datasets"), app_modals())
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

  # =========================================================
  # 2) DATASET-I AKTIV (V-04): një burim i vetëm
  # =========================================================
  active <- mod_datasets_server("datasets")
  series <- reactive(prepare_series(active()))
  fits   <- model_store()   # ETS/ARIMA të përbashkët për Modelimin dhe Parashikimin (P-07)

  pick_choice <- function(cur, choices, fallback) {
    if (!is.null(cur) && length(cur) == 1 && nzchar(cur) && cur %in% choices) cur else fallback
  }

  # Zgjedhësit e serive të faqeve të analizës (kalojnë te modulet në Fazën 5).
  observeEvent(active(), {
    choices <- active()$value_cols
    if (length(choices) == 0) return()

    for (id in c("model_series", "forecast_series")) {
      updateSelectInput(session, id, choices = choices,
                        selected = pick_choice(isolate(input[[id]]), choices, choices[1]))
    }
  })


  # =========================================================
  # 3) BACKGROUND SETTINGS
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

  mod_overview_server("overview", active, series, reactive(input$main_tabs))
  mod_eda_ts_server("eda_ts", series)
  mod_eda_rel_server("eda_rel", series)
  mod_stationarity_server("stationary", series)

  server_plots(input, output, session, series, active, fits)
}

shinyApp(ui, server)
