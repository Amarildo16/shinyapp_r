# Settings → Dataset: lista e dataset-eve, ngarkimi, konfigurimi, fshirja (V-04).
# mod_datasets_server() kthen active(), burimin e vetëm të së vërtetës:
#   list(file, data = <tekst>, time_col, value_cols)  ose NULL kur s'ka dataset.

mod_datasets_ui <- function(id) {
  ns <- NS(id)
  tagList(
    div(
      class = "overview-top",
      h4(tr("settings.dataset")),
      actionButton(ns("btn_open_upload"), tr("settings.upload_csv"), class = "glass-btn")
    ),
    uiOutput(ns("saved_datasets_ui"))
  )
}

# Modalet jetojnë në fund të faqes (app_page), jashtë tab-eve.
mod_datasets_modals_ui <- function(id) {
  ns <- NS(id)
  tagList(
    glass_modal(
      ns("main_modal_sm"), ns("modal_sm_title"), ns("modal_sm_body"),
      tagList(
        actionButton(ns("btn_cancel_upload"), tr("common.cancel"), class = "btn btn-light"),
        actionButton(ns("btn_proceed_upload"), tr("common.proceed"), class = "btn btn-success")
      ),
      size = "lg"
    ),
    glass_modal(
      ns("main_modal_fs"), ns("modal_fs_title"), ns("modal_fs_body"),
      tagList(
        actionButton(ns("btn_cancel_config"), tr("common.cancel"), class = "btn btn-light"),
        actionButton(ns("btn_save_config"), tr("common.save"), class = "btn btn-success")
      ),
      size = "fs"
    ),
    glass_modal(
      ns("delete_modal"), ns("delete_modal_title"), ns("delete_modal_body"),
      tagList(
        tags$button(type = "button", class = "btn btn-default", `data-dismiss` = "modal",
                    tr("ds.delete_cancel")),
        actionButton(ns("confirm_delete_saved"), tr("ds.delete_confirm"), class = "btn-danger")
      ),
      size = "sm"
    )
  )
}

mod_datasets_server <- function(id) {
  moduleServer(id, function(input, output, session) {
    ns <- session$ns
    notify <- function(msg, type = "message", duration = 5) {
      showNotification(msg, type = type, duration = duration)
    }

    files       <- reactiveVal(list_saved_datasets())
    st0         <- tryCatch(sync_state(isolate(files())), error = function(e) list(active = NULL))
    active_file <- reactiveVal(st0$active)
    reload      <- reactiveVal(0L)   # rilexim pas ruajtjes së konfigurimit
    active_rv   <- reactiveVal(NULL)

    pending_data      <- reactiveVal(NULL)   # dataset-i në modalin e konfigurimit
    editing_file      <- reactiveVal(NULL)
    uploaded_tmp_path <- reactiveVal(NULL)
    uploaded_tmp_name <- reactiveVal(NULL)
    pending_delete    <- reactiveVal(NULL)

    read_dataset <- function(file) {
      ds <- resolve_saved_dataset_path(file, DATASETS_DIR)
      if (!isTRUE(ds$ok)) return(ds)
      ds$data <- read_data_safe(ds$path, ds$file)
      ds
    }

    clear_pending <- function() {
      pending_data(NULL); editing_file(NULL)
      uploaded_tmp_path(NULL); uploaded_tmp_name(NULL)
    }

    # ---- Ngarkimi: rruga e vetme (P-06) ----------------------------------------
    # Kolona e kohës dhe seritë: konfigurimi i ruajtur, pastaj zgjedhja e dataset-it
    # të mëparshëm (si inputet e fshehura të vjetra), pastaj default-et.
    observeEvent(list(active_file(), reload()), {
      f <- active_file()
      if (is.null(f) || !nzchar(f)) {
        active_rv(NULL)
        return()
      }

      ds <- tryCatch(read_dataset(f), error = function(e) {
        notify(tr("ds.read_error", msg = conditionMessage(e)), "error", 8)
        NULL
      })
      if (is.null(ds)) {
        active_rv(NULL)
        return()
      }
      if (!isTRUE(ds$ok)) {
        notify(ds$msg %||% tr("ds.active_missing"), "warning", 6)
        active_file(NULL)
        return()
      }

      cfg  <- tryCatch(get_dataset_config(read_state(), ds$file),
                       error = function(e) list(time_col = NULL, value_cols = character(0)))
      prev <- isolate(active_rv())
      def  <- resolve_dataset_defaults(ds$data, cfg,
                                       current_time   = prev$time_col,
                                       current_values = prev$value_cols)

      active_rv(list(file = ds$file, data = ds$data,
                     time_col = def$time_col, value_cols = def$value_cols))
    }, ignoreInit = FALSE)

    # ---- Lista e dataset-eve ---------------------------------------------------
    output$saved_datasets_ui <- renderUI({
      fl <- files()

      if (length(fl) == 0) {
        return(div(
          class = "section-box",
          h4(tr("ds.saved_title")),
          tags$small(tr("ds.none_saved"), style = "opacity:.75;")
        ))
      }

      active <- active_file() %||% fl[1]
      if (!(active %in% fl)) active <- fl[1]

      js_event <- function(input_id, f, stop = FALSE) {
        sprintf("%sShiny.setInputValue(%s, %s, {priority:'event'});",
                if (stop) "event.stopPropagation(); " else "",
                jsonlite::toJSON(ns(input_id), auto_unbox = TRUE),
                jsonlite::toJSON(f, auto_unbox = TRUE))
      }

      rows <- split(fl, ceiling(seq_along(fl) / 2))
      tagList(lapply(rows, function(pair) {
        tags$div(
          class = "saved-ds-grid-row",
          lapply(pair, function(f) {
            is_active <- identical(f, active)
            div(
              class = paste("section-box saved-ds-item", if (is_active) "is-active" else ""),
              tags$div(
                class = "saved-ds-row",
                onclick = js_event("activate_dataset", f),
                tags$div(
                  class = "saved-ds-left",
                  tags$span(class = paste("saved-ds-dot", if (is_active) "on" else "")),
                  tags$span(class = "saved-ds-name", f),
                  if (is_active) tags$span(class = "saved-ds-badge", tr("ds.active_badge")) else NULL
                ),
                tags$div(
                  class = "saved-ds-actions",
                  tags$button(type = "button", class = "saved-ds-edit",
                              onclick = js_event("edit_dataset", f, stop = TRUE), icon("pen")),
                  tags$button(type = "button", class = "saved-ds-trash",
                              onclick = js_event("delete_dataset", f, stop = TRUE), icon("trash"))
                )
              )
            )
          })
        )
      }))
    })

    # ---- Aktivizimi ------------------------------------------------------------
    observeEvent(input$activate_dataset, {
      editing_file(NULL)
      ds <- resolve_saved_dataset_path(input$activate_dataset, DATASETS_DIR)
      if (!isTRUE(ds$ok)) {
        notify(ds$msg %||% tr("ds.invalid"), "error", 6)
        return()
      }
      st <- set_active_dataset(ds$file)
      active_file(st$active %||% ds$file)
      notify(tr("ds.activated", file = ds$file), duration = 4)
    }, ignoreInit = TRUE)

    # ---- Modali i konfigurimit: i njëjti për Upload dhe Edit (B-03) ------------
    open_config_modal <- function(d, title, def) {
      pending_data(d)
      output$modal_fs_title <- renderUI(tags$h5(class = "modal-title", title))
      output$modal_fs_body <- renderUI(tagList(
        tags$div(class = "cfg-top",
          fluidRow(
            column(3, selectInput(ns("modal_time_col"), tr("ds.time_col"),
                                  choices = def$time_choices, selected = def$time_col)),
            column(5, selectizeInput(ns("modal_value_cols"), tr("ds.value_cols"),
                                     choices = def$num_cols, selected = def$value_cols,
                                     multiple = TRUE))
          )
        ),
        tags$hr(),
        DT::DTOutput(ns("csv_preview_big"))
      ))
      output$csv_preview_big <- DT::renderDT({
        DT::datatable(head(d, 200), rownames = FALSE, options = list(scrollX = TRUE, language = dt_language()))
      })
      toggle_glass_modal(session, "main_modal_fs", "show")

      # Kur modali rivizatohet me të njëjtat ID, serveri merr zgjedhjet e reja vetëm kështu.
      session$onFlushed(function() {
        updateSelectInput(session, "modal_time_col", choices = def$time_choices, selected = def$time_col)
        updateSelectizeInput(session, "modal_value_cols", choices = def$num_cols,
                             selected = def$value_cols, server = TRUE)
      }, once = TRUE)
    }

    observeEvent(input$edit_dataset, {
      ds <- resolve_saved_dataset_path(input$edit_dataset, DATASETS_DIR)
      if (!isTRUE(ds$ok)) {
        notify(ds$msg %||% tr("ds.invalid"), "error", 6)
        return()
      }
      f <- ds$file
      notify(tr("ds.edit_notice", file = f), duration = 2)

      d <- tryCatch(read_data_safe(ds$path, f), error = function(e) {
        notify(tr("ds.read_error", msg = conditionMessage(e)), "error", 8)
        NULL
      })
      if (is.null(d)) return()

      def <- resolve_dataset_defaults(d, get_dataset_config(read_state(), f))
      uploaded_tmp_path(NULL)
      uploaded_tmp_name(NULL)
      editing_file(f)
      open_config_modal(d, tr("ds.edit_title", file = f), def)
    }, ignoreInit = TRUE)

    observeEvent(input$modal_time_col, {
      d <- pending_data()
      req(d)
      num_cols <- detect_numeric_cols(d, exclude = input$modal_time_col)
      sel <- pick_value_cols(num_cols, isolate(input$modal_value_cols))
      updateSelectizeInput(session, "modal_value_cols", choices = num_cols, selected = sel, server = TRUE)
    }, ignoreInit = TRUE)

    # ---- Ngarkimi i CSV-së -----------------------------------------------------
    observeEvent(input$btn_open_upload, {
      output$modal_sm_title <- renderUI(tags$h5(class = "modal-title", tr("settings.upload_csv")))
      output$modal_sm_body <- renderUI(tagList(
        tags$div(id = ns("csv_file_modal_pond_host")),
        fileInput(ns("csv_file_modal"), label = NULL, accept = c(".csv"))
      ))
      toggle_glass_modal(session, "main_modal_sm", "show")
    }, ignoreInit = TRUE)

    observeEvent(input$csv_file_modal, {
      up <- input$csv_file_modal
      req(up$datapath, up$name)

      if (tolower(tools::file_ext(up$name)) != "csv") {
        notify(tr("ds.only_csv"), "error", 6)
        return()
      }

      uploaded_tmp_path(up$datapath)
      uploaded_tmp_name(up$name)

      d <- tryCatch(read_data_safe(up$datapath, up$name), error = function(e) {
        notify(tr("ds.read_error", msg = conditionMessage(e)), "error", 8)
        NULL
      })
      if (is.null(d)) return()

      pending_data(d)
      notify(tr("ds.csv_loaded"))
    }, ignoreInit = TRUE)

    observeEvent(input$btn_cancel_upload, {
      toggle_glass_modal(session, "main_modal_sm", "hide")
      clear_pending()
    }, ignoreInit = TRUE)

    observeEvent(input$btn_proceed_upload, {
      d <- pending_data()
      req(d)
      toggle_glass_modal(session, "main_modal_sm", "hide")
      # Titulli bosh, si në ngarkimin e parë të versionit të vjetër.
      open_config_modal(d, "", resolve_dataset_defaults(d))
    }, ignoreInit = TRUE)

    observeEvent(input$btn_cancel_config, {
      was_edit  <- !is.null(editing_file())
      has_draft <- !is.null(uploaded_tmp_path()) && nzchar(uploaded_tmp_path())

      editing_file(NULL)
      toggle_glass_modal(session, "main_modal_fs", "hide")
      if (was_edit) pending_data(NULL)
      if (!was_edit && has_draft) toggle_glass_modal(session, "main_modal_sm", "show")
    }, ignoreInit = TRUE)

    # ---- Ruajtja: e njëjta për Upload dhe Edit ---------------------------------
    # Upload kopjon CSV-në te storage/datasets (pa mbishkrim: emri merr timestamp);
    # Edit ruan vetëm konfigurimin. Në të dyja rastet dataset-i bëhet aktiv.
    save_uploaded_file <- function(path, name) {
      safe   <- sanitize_filename(name, default_ext = "csv")
      target <- normalize_app_path(file.path(DATASETS_DIR, safe))
      if (!is_path_inside_dir(target, DATASETS_DIR)) {
        notify(tr("ds.name_not_allowed"), "error", 8)
        return(NULL)
      }
      if (file.exists(target)) {
        safe   <- paste0(tools::file_path_sans_ext(safe), "_",
                         format(Sys.time(), "%Y%m%d_%H%M%S"), ".", tools::file_ext(safe))
        target <- normalize_app_path(file.path(DATASETS_DIR, safe))
      }
      if (!isTRUE(file.copy(path, target, overwrite = FALSE))) {
        notify(tr("ds.save_failed"), "error", 8)
        return(NULL)
      }
      files(list_saved_datasets())
      notify(tr("ds.saved_to", file = safe), duration = 6)
      safe
    }

    observeEvent(input$btn_save_config, {
      if (length(input$modal_value_cols) == 0) {
        notify(tr("ds.pick_series"), "error")
        return()
      }
      d_pending <- pending_data()
      req(input$modal_time_col, d_pending)

      tc_in   <- input$modal_time_col
      vals_in <- input$modal_value_cols

      # B-19: kolona e zgjedhur pranon edhe numrat 1, 2, 3… (EDA punon; analizat japin mesazhin e B-09).
      time_ok <- tryCatch({ parse_time_safe(d_pending[[tc_in]], allow_index = TRUE); TRUE },
                          error = function(e) conditionMessage(e))
      if (!isTRUE(time_ok)) {
        notify(tr("ds.bad_time_col", msg = time_ok), "error", 8)
        return()
      }

      toggle_glass_modal(session, "main_modal_fs", "hide")

      up_path <- uploaded_tmp_path()
      up_name <- uploaded_tmp_name()
      final_file <- editing_file() %||% active_file()

      if (is.null(editing_file()) && !is.null(up_path) && file.exists(up_path) &&
          !is.null(up_name) && nzchar(up_name)) {
        final_file <- save_uploaded_file(up_path, up_name)
        if (is.null(final_file)) {
          toggle_glass_modal(session, "main_modal_fs", "show")
          return()
        }
      }

      if (!is.null(final_file) && nzchar(final_file)) {
        final_file <- set_active_dataset(final_file)$active %||% final_file

        ds <- resolve_saved_dataset_path(final_file, DATASETS_DIR)
        if (!isTRUE(ds$ok)) {
          notify(ds$msg %||% tr("ds.invalid"), "error", 8)
          toggle_glass_modal(session, "main_modal_fs", "show")
          return()
        }
        d <- tryCatch(read_data_safe(ds$path, ds$file), error = function(e) {
          notify(tr("ds.reopen_error", msg = conditionMessage(e)), "error", 8)
          d_pending
        })

        def <- resolve_dataset_defaults(d, list(time_col = tc_in, value_cols = vals_in))
        write_state(update_dataset_config(read_state(), ds$file, def$time_col, def$value_cols))

        active_file(ds$file)
        reload(reload() + 1L)
      }

      clear_pending()
      notify(tr("ds.config_saved"))
    }, ignoreInit = TRUE)

    # ---- Fshirja me konfirmim --------------------------------------------------
    observeEvent(input$delete_dataset, {
      sel <- input$delete_dataset
      req(sel)
      pending_delete(sel)
      output$delete_modal_title <- renderUI(tags$h4(class = "modal-title", tr("ds.delete_title")))
      output$delete_modal_body  <- renderUI(p(tr("ds.delete_question", file = sel)))
      toggle_glass_modal(session, "delete_modal", "show")
    }, ignoreInit = TRUE)

    observeEvent(input$confirm_delete_saved, {
      toggle_glass_modal(session, "delete_modal", "hide")
      sel <- pending_delete()
      pending_delete(NULL)
      req(sel)

      ds <- resolve_saved_dataset_path(sel, DATASETS_DIR)
      if (!isTRUE(ds$ok)) {
        notify(ds$msg %||% tr("ds.invalid"), "error", 5)
        return()
      }

      was_active <- identical(active_file(), ds$file)
      if (!isTRUE(file.remove(ds$path))) {
        notify(tr("ds.delete_failed"), "error", 7)
        return()
      }

      fl <- list_saved_datasets()
      files(fl)
      try(sync_state(fl), silent = TRUE)

      if (!was_active) {
        notify(tr("ds.deleted"), duration = 4)
      } else if (length(fl) > 0) {
        active_file(set_active_dataset(fl[1])$active)
        notify(tr("ds.deleted_switched"), duration = 4)
      } else {
        active_file(NULL)
        notify(tr("ds.deleted_none_left"))
      }
    }, ignoreInit = TRUE)

    reactive(active_rv())
  })
}
