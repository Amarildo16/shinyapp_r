# =========================
# SAFE INSTALL 
# =========================

core_pkgs <- c(
  "shiny", "shinyjs",
  "plotly",
  "ggplot2",
  "dplyr", "tidyr",
  "readr",
  "forecast",
  "scales",
  "tseries",
  "zoo",
  "vars",
  "rugarch"
  "DT"
)

safe_install <- function(pkgs) {
  installed <- rownames(installed.packages())
  to_install <- setdiff(pkgs, installed)

  if (length(to_install) == 0) {
    message("Të gjitha paketat janë të instaluara.")
    return(invisible(TRUE))
  }

  message("Po instalohen paketat që mungojnë: ", paste(to_install, collapse = ", "))
  install.packages(to_install, dependencies = TRUE)
  invisible(TRUE)
}

safe_install(core_pkgs)
