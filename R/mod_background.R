# Settings → Background dhe Media Library (Faza 6). State-i te storage/state/
# (background_state.json), fotot e ngarkuara te storage/images/ ("user-images/..."),
# 12 fotot default te www/images/ ("images/...", nuk fshihen, V-22 a). bg.js e zbaton
# state-in me mesazhin "bg_apply". Ndryshimet ruhen vetëm me Save (R17).

BG_CLEAR <- "__CLEAR__"
BG_COLORS <- c(
  "#0b1c24", "#111827", "#1f2937", "#374151", "#6b7280",
  "#ef4444", "#f97316", "#f59e0b", "#eab308",
  "#22c55e", "#10b981", "#06b6d4", "#3b82f6",
  "#6366f1", "#8b5cf6", "#ec4899"
)

# st: state-i i ruajtur, lexuar për çdo kërkesë (ui është funksion, T-11).
mod_background_ui <- function(id, st = read_bg_state()) {
  ns <- NS(id)
  section_box(
    h4(tr("settings.background")),

    radioButtons(
      ns("mode"),
      tr("bg.mode_label"),
      choices  = setNames(c("image", "color", "none"),
                          c(tr("bg.mode.image"), tr("bg.mode.color"), tr("bg.mode.none"))),
      selected = st$active_mode %||% "image",
      inline   = TRUE
    ),

    conditionalPanel(
      condition = "input.mode == 'image'", ns = ns,

      radioButtons(
        ns("scope"),
        tr("bg.scope_label"),
        choices  = setNames(c("global", "custom"), c(tr("bg.scope.global"), tr("bg.scope.custom"))),
        selected = st$modes$image$active_scope %||% "custom",
        inline   = TRUE
      ),

      conditionalPanel(
        condition = "input.scope == 'global'", ns = ns,
        tags$div(class = "bg-tabs-title", tr("bg.global_title")),
        uiOutput(ns("global_card"))
      ),

      conditionalPanel(
        condition = "input.scope == 'custom'", ns = ns,
        tags$div(class = "bg-tabs-title", tr("bg.tabs_title")),
        uiOutput(ns("tab_cards"))
      ),

      checkboxInput(ns("blur_on"), tr("bg.blur"), value = isTRUE(st$modes$image$blur$on)),

      sliderInput(
        ns("blur"),
        tr("bg.blur_strength"),
        min   = 0,
        max   = 20,
        value = as.numeric(st$modes$image$blur$amount %||% 10),
        step  = 1
      )
    ),

    conditionalPanel(
      condition = "input.mode == 'color'", ns = ns,

      tags$label(tr("bg.base_color")),

      tags$div(
        id = ns("color_grid"),
        class = "bg-color-grid",
        lapply(BG_COLORS, function(hex) {
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
          id    = ns("color"),
          type  = "color",
          value = st$modes$color$value %||% "#0b1c24",
          style = "width:140px;height:46px;border-radius:12px;border:1px solid rgba(255,255,255,.25);background:transparent;"
        ),
        tags$span(id = ns("color_hex_txt"), class = "bg-color-hex", "")
      )
    ),

    div(
      class = "bg-save-row",
      actionButton(ns("save"), tr("common.save"), class = "glass-btn"),
      uiOutput(ns("dirty_badge"))
    )
  )
}

# Modalet jetojnë në fund të faqes (app_page), jashtë tab-eve.
mod_background_modals_ui <- function(id) {
  ns <- NS(id)
  tagList(
    glass_modal(
      ns("modal_fs"), ns("modal_fs_title"), ns("modal_fs_body"),
      tagList(
        actionButton(ns("btn_close"), tr("common.close"), class = "btn btn-light"),
        actionButton(ns("btn_use"), tr("bg.use_photo"), class = "btn btn-success")
      ),
      size = "fs"
    ),
    # B-15 (V-15 a): konfirmimi i fshirjes me pamjen glass, si te dataset-et.
    glass_modal(
      ns("delete_modal"), ns("delete_modal_title"), ns("delete_modal_body"),
      tagList(
        tags$button(type = "button", class = "btn btn-default", `data-dismiss` = "modal",
                    tr("bg.delete_cancel")),
        actionButton(ns("delete_confirm"), tr("bg.delete_confirm"), class = "btn btn-danger")
      ),
      size = "sm"
    )
  )
}

# Shteg me versionin e state-it (cache i browser-it pas Save).
bg_ver_src <- function(path, st) {
  if (is.null(path) || !nzchar(path)) return(NULL)
  v <- st$version %||% 0
  if (!isTRUE(v > 0)) return(path)
  paste0(path, "?v=", v)
}

# State-i i ri pas Save: mënyra, ngjyra, blur-i dhe fotot (draft-et e Media Library).
bg_apply_save <- function(st, mode, color, blur_on, blur, scope, draft_global, draft_per_tab) {
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

  st$active_mode <- mode %||% st$active_mode %||% "image"
  if (!st$active_mode %in% c("image", "color", "none")) st$active_mode <- "image"

  if (identical(st$active_mode, "color") && !is.null(color) && nzchar(color)) {
    st$modes$color$value <- color
  }

  if (identical(st$active_mode, "image")) {
    st$modes$image$blur$on     <- isTRUE(blur_on %||% st$modes$image$blur$on)
    st$modes$image$blur$amount <- as.integer(blur %||% st$modes$image$blur$amount %||% 10)

    st$modes$image$active_scope <- scope %||% st$modes$image$active_scope %||% "custom"
    if (!st$modes$image$active_scope %in% c("custom", "global")) st$modes$image$active_scope <- "custom"

    if (identical(st$modes$image$active_scope, "global")) {
      if (identical(draft_global, BG_CLEAR)) {
        st$modes$image$scopes$global$global <- NULL
      } else if (!is.null(draft_global) && nzchar(draft_global)) {
        st$modes$image$scopes$global$global <- draft_global
      }
    }

    if (identical(st$modes$image$active_scope, "custom") && is.list(draft_per_tab) && length(draft_per_tab) > 0) {
      for (tb in names(draft_per_tab)) {
        v <- draft_per_tab[[tb]]
        if (identical(v, BG_CLEAR)) {
          st$modes$image$scopes$custom$per_tab[[tb]] <- NULL
        } else if (!is.null(v) && nzchar(v)) {
          st$modes$image$scopes$custom$per_tab[[tb]] <- v
        }
      }
      pt <- st$modes$image$scopes$custom$per_tab
      if (is.list(pt) && length(pt) > 0) {
        st$modes$image$scopes$custom$per_tab <- pt[!vapply(pt, is.null, logical(1))]
      }
    }
  }
  st
}

# Çelësi i krahasimit të dy state-ve: pa versionin, ngjyra pa dallim shkronjash.
bg_state_key <- function(st) {
  st$version <- NULL
  if (!is.null(st$modes$color$value)) st$modes$color$value <- tolower(st$modes$color$value)
  as.character(jsonlite::toJSON(st, auto_unbox = TRUE, null = "null"))
}

mod_background_server <- function(id) {
  moduleServer(id, function(input, output, session) {
    ns <- session$ns
    notify <- function(msg, type = "message", duration = 3) showNotification(msg, type = type, duration = duration)

    # B-08: emrat e fotove kalojnë te JS si JSON, jo brenda thonjëzave.
    js_event <- function(input_id, value, stop = FALSE) {
      sprintf("%sShiny.setInputValue(%s, %s, {priority:'event'});",
              if (stop) "event.stopPropagation();" else "",
              jsonlite::toJSON(ns(input_id), auto_unbox = TRUE),
              jsonlite::toJSON(value, auto_unbox = TRUE))
    }

    tabs <- lapply(page_ids(), function(id) list(id = page_tab(id), label = tr(paste0("page.", id, ".menu"))))

    # P-09: state-i lexohet një herë për sesion.
    bg_saved <- reactiveVal(read_bg_state())

    draft_global_path <- reactiveVal(NULL)
    draft_per_tab     <- reactiveVal(setNames(list(), character()))

    # U-07: ka ndryshime vetëm kur Save do ta ndryshonte state-in e ruajtur; kthimi te
    # zgjedhja e ruajtur e heq shenjën.
    bg_dirty <- reactive({
      st <- bg_saved()
      cand <- bg_apply_save(st, input$mode, input$color, input$blur_on, input$blur,
                            input$scope, draft_global_path(), draft_per_tab())
      !identical(bg_state_key(cand), bg_state_key(st))
    })

    output$dirty_badge <- renderUI({
      if (!isTRUE(bg_dirty())) return(NULL)
      tags$span(class = "bg-badge", tr("bg.dirty"))
    })

    bg_card <- function(name, path, st, button_id) {
      src <- if (!is.null(path) && nzchar(path)) bg_ver_src(path, st) else NULL
      div(
        class = "bg-tab-card",
        div(
          class = "bg-tab-thumb bg-thumb-empty",
          if (!is.null(src) && nzchar(src)) tags$img(src = src) else HTML(BG_PLACEHOLDER_SVG)
        ),
        div(
          class = "bg-tab-meta",
          div(class = "bg-tab-name", name),
          div(class = "bg-tab-status", if (!is.null(src)) tr("bg.status_custom") else tr("bg.status_none"))
        ),
        div(
          class = "bg-tab-actions",
          actionButton(ns(button_id), tr("bg.edit"), class = "glass-btn btn-sm")
        )
      )
    }

    output$global_card <- renderUI({
      st <- bg_saved()
      bg_card(tr("bg.card_global"), st$modes$image$scopes$global$global %||% NULL, st, "edit_global_btn")
    })

    output$tab_cards <- renderUI({
      st <- bg_saved()
      per_tab <- st$modes$image$scopes$custom$per_tab %||% setNames(list(), character())
      if (is.null(per_tab) || !is.list(per_tab)) per_tab <- setNames(list(), character())
      tags$div(
        class = "bg-tabs-grid",
        lapply(tabs, function(t) bg_card(t$label, per_tab[[t$id]] %||% NULL, st, paste0("edit__", t$id)))
      )
    })

    # ---- Save ----------------------------------------------------------------------
    observeEvent(input$save, {
      st <- bg_apply_save(bg_saved(), input$mode, input$color, input$blur_on, input$blur,
                          input$scope, draft_global_path(), draft_per_tab())
      scope <- st$modes$image$active_scope
      if (identical(st$active_mode, "image") && identical(scope, "global")) draft_global_path(NULL)
      if (identical(st$active_mode, "image") && identical(scope, "custom") && length(draft_per_tab()) > 0) {
        draft_per_tab(setNames(list(), character()))
      }

      write_bg_state(st)
      st <- read_bg_state()
      bg_saved(st)

      session$sendCustomMessage("bg_apply", st)
      notify(tr("bg.saved"))
    }, ignoreInit = TRUE)

    session$onFlushed(function() {
      session$sendCustomMessage("bg_apply", isolate(bg_saved()))
    }, once = TRUE)

    # ---- Media Library -------------------------------------------------------------
    ctx               <- reactiveVal(NULL)
    media_selected    <- reactiveVal(NULL)
    media_refresh     <- reactiveVal(0L)
    pending_delete    <- reactiveVal(NULL)
    processed_uploads <- reactiveVal(character(0))

    # P-08: modalet hapen e mbyllen vetëm me toggle_glass_modal().
    open_library <- function(target, tabid = NULL) {
      media_selected(NULL)
      ctx(list(type = "bg_picker", target = target, tabid = tabid))
      updateTabsetPanel(session, "media_tabs", selected = "library")
      toggle_glass_modal(session, "modal_fs", "show")
    }
    close_library <- function() {
      toggle_glass_modal(session, "modal_fs", "hide")
      ctx(NULL)
    }

    observeEvent(input$edit_global_btn, open_library("global"), ignoreInit = TRUE)
    lapply(tabs, function(t) {
      observeEvent(input[[paste0("edit__", t$id)]], open_library("tab", t$id), ignoreInit = TRUE)
    })

    observeEvent(input$btn_close, {
      close_library()
      media_selected(NULL)
    }, ignoreInit = TRUE)

    output$modal_fs_title <- renderUI({
      x <- ctx()
      if (is.null(x) || !identical(x$type, "bg_picker")) return(tags$h5(""))
      if (identical(x$target, "global")) return(tags$h5(tr("bg.library_global")))
      if (identical(x$target, "tab")) {
        lab <- NULL
        for (t in tabs) if (identical(t$id, x$tabid)) lab <- t$label
        return(tags$h5(tr("bg.library_tab", label = lab %||% x$tabid)))
      }
      tags$h5(tr("bg.library"))
    })

    output$modal_fs_body <- renderUI({
      x <- ctx()
      if (is.null(x) || !identical(x$type, "bg_picker")) return(NULL)

      tabsetPanel(
        id = ns("media_tabs"),
        tabPanel(title = tr("bg.tab_library"), value = "library", uiOutput(ns("media_gallery"))),
        tabPanel(
          title = tr("bg.tab_upload"),
          value = "upload",
          tags$div(
            class = "bg-upload-fill",
            tags$div(id = ns("media_upload_pond_host"), class = "bg-pond-host"),
            fileInput(
              ns("media_upload"),
              label = NULL,
              multiple = TRUE,
              accept = c("image/png", "image/jpeg", "image/jpg", "image/webp")
            )
          )
        )
      )
    })

    # Fotoja aktive për kontekstin: draft-i i pa ruajtur ose state-i i ruajtur.
    active_src <- function(x, st) {
      if (is.null(x) || !identical(x$type, "bg_picker")) return("")
      if (identical(x$target, "global")) {
        dp <- draft_global_path()
        if (identical(dp, BG_CLEAR)) return("")
        if (!is.null(dp) && nzchar(dp)) return(dp)
        return(st$modes$image$scopes$global$global %||% "")
      }
      if (identical(x$target, "tab")) {
        tb <- x$tabid
        dpt <- draft_per_tab()
        v <- if (!is.null(tb) && nzchar(tb) && is.list(dpt)) dpt[[tb]] %||% NULL else NULL
        if (identical(v, BG_CLEAR)) return("")
        if (!is.null(v) && nzchar(v)) return(v)
        per_tab <- st$modes$image$scopes$custom$per_tab %||% setNames(list(), character())
        return(per_tab[[tb]] %||% "")
      }
      ""
    }

    output$media_gallery <- renderUI({
      media_refresh()
      imgs <- bg_image_list()
      if (length(imgs) == 0) return(tags$div(class = "section-box", tags$small(tr("bg.no_photos"))))

      act <- active_src(ctx(), bg_saved())
      sel <- media_selected()

      tags$div(
        class = "media-grid",
        lapply(imgs, function(src) {
          is_active <- nzchar(act) && identical(src, act)
          is_sel    <- !is.null(sel) && identical(src, sel)
          cls <- paste(c("media-card", if (is_active) "is-active", if (is_sel) "selected"), collapse = " ")

          tags$div(
            class = cls,
            onclick = js_event("media_pick", src),
            if (is_active) tags$div(class = "media-tick", tags$i(class = "ri-check-line")),
            if (is_active) tags$button(
              type = "button", class = "media-clear-btn",
              onclick = js_event("media_clear_active", src, stop = TRUE),
              tags$i(class = "ri-subtract-line")
            ),
            tags$div(class = "media-thumb", tags$img(src = src)),
            tags$div(
              class = "media-meta",
              tags$div(class = "name", basename(src)),
              # V-22 a: fotot default nuk fshihen.
              if (!bg_is_default(src)) tags$button(
                type = "button", class = "media-delete-btn",
                onclick = js_event("media_delete", src, stop = TRUE),
                tags$i(class = "ri-delete-bin-6-line")
              )
            )
          )
        })
      )
    })

    observeEvent(input$media_pick, media_selected(input$media_pick), ignoreInit = TRUE)

    observeEvent(input$media_clear_active, {
      x <- ctx()
      if (is.null(x) || !identical(x$type, "bg_picker")) return()
      if (identical(x$target, "global")) {
        draft_global_path(BG_CLEAR)
      } else if (identical(x$target, "tab")) {
        if (is.null(x$tabid) || !nzchar(x$tabid)) return()
        d <- draft_per_tab()
        d[[x$tabid]] <- BG_CLEAR
        draft_per_tab(d)
      }
      close_library()
      media_selected(NULL)
    }, ignoreInit = TRUE)

    # ---- Fshirja me konfirmim (Q23) -------------------------------------------------
    observeEvent(input$media_delete, {
      src <- input$media_delete %||% ""
      if (!nzchar(src)) return()
      pending_delete(src)
      output$delete_modal_title <- renderUI(tags$h4(class = "modal-title", tr("bg.delete_title")))
      output$delete_modal_body  <- renderUI(p(tr("bg.delete_question", name = basename(src))))
      toggle_glass_modal(session, "delete_modal", "show")
    }, ignoreInit = TRUE)

    observeEvent(input$delete_confirm, {
      src <- pending_delete() %||% ""
      toggle_glass_modal(session, "delete_modal", "hide")
      pending_delete(NULL)
      if (!nzchar(src)) return()

      if (!tolower(tools::file_ext(src)) %in% c("png", "jpg", "jpeg", "webp", "gif", "svg")) {
        notify(tr("bg.err_not_photo"), "error", 4)
        return()
      }
      media_path <- resolve_user_image_path(src)
      if (!isTRUE(media_path$ok)) {
        notify(media_path$msg %||% tr("bg.err_path"), "error", 4)
        return()
      }
      src <- media_path$src

      if (src %in% bg_images_in_use(bg_saved())) {
        notify(tr("bg.err_in_use"), "error", 4)
        return()
      }
      if (!file.exists(media_path$path)) {
        notify(tr("bg.err_not_found"), "error", 4)
        return()
      }

      ok <- tryCatch(unlink(media_path$path, force = TRUE) == 0, error = function(e) FALSE)
      if (!isTRUE(ok)) {
        notify(tr("bg.delete_failed"), "error", 4)
        return()
      }

      if (identical(media_selected(), src)) media_selected(NULL)
      if (identical(draft_global_path(), src)) draft_global_path(NULL)
      dpt <- draft_per_tab()
      if (is.list(dpt) && length(dpt) > 0) {
        for (k in names(dpt)) if (identical(dpt[[k]], src)) dpt[[k]] <- NULL
        draft_per_tab(dpt[!vapply(dpt, is.null, logical(1))])
      }
      media_refresh(media_refresh() + 1L)
      notify(tr("bg.deleted"))
    }, ignoreInit = TRUE)

    # ---- Ngarkimi (Q22, R19) ---------------------------------------------------------
    observeEvent(input$media_upload, {
      up <- input$media_upload
      req(up)
      if (!is.data.frame(up) || nrow(up) == 0) return()

      seen <- processed_uploads()
      new_count <- 0L
      for (i in seq_len(nrow(up))) {
        dp <- up$datapath[i]
        if (is.na(dp) || !nzchar(dp) || dp %in% seen) next
        seen <- c(seen, dp)

        orig_name <- up$name[i] %||% paste0("image_", i)
        r <- bg_store_upload(dp, orig_name,
                             mime = if ("type" %in% names(up)) up$type[i] else NULL,
                             size = if ("size" %in% names(up)) up$size[i] else NULL)
        if (isTRUE(r$ok)) {
          new_count <- new_count + 1L
        } else if (!is.null(r$msg)) {
          notify(r$msg, "error", 6)
        }
      }
      processed_uploads(seen)

      if (new_count > 0) {
        media_refresh(media_refresh() + 1L)
        media_selected(NULL)
        session$sendCustomMessage("pond_clear", list(inputId = ns("media_upload")))
        processed_uploads(character(0))
        updateTabsetPanel(session, "media_tabs", selected = "library")
        notify(tr("bg.uploaded", n = new_count))
      }
    }, ignoreInit = TRUE)

    observeEvent(input$btn_use, {
      x <- ctx()
      if (is.null(x) || !identical(x$type, "bg_picker")) return()
      req(media_selected())
      if (identical(x$target, "global")) {
        draft_global_path(media_selected())
      } else if (identical(x$target, "tab")) {
        d <- draft_per_tab()
        d[[x$tabid]] <- media_selected()
        draft_per_tab(d)
      }
      close_library()
    }, ignoreInit = TRUE)
  })
}
