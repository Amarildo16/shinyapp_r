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
  "DT",
  "jsonlite"
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

para se te beni run ne R merrni kodin mesiper dhe vendoseni ne console per te instaluar paketat e nevojshme qe duhen per kete projekt 
Ky kod shikon nese i keni apo jo te instaluara paketat e nevojshme dhe nese ndonje pakete mungon instalon vetem paketen qe mungon

sapo ti keni ber run do perballeni me faqen "Time series analysis"
projekti ka nje dataset fillestar per mos tu dukur bosh por mund ta lini dhe bosh pa asnje problem 

gjeja e pare qe duhet te beni eshte te hapni sidebarin dhe te shkoni ne settings ku do tju jepet mundesia te ngarkoni csv te reja (vetem csv) dhe mund te zgjidhni kolonat qe doni te kryeni perllogaritjet edhe pasi e keni ruajtur nje dataset ju mund ta editoni duke ndryshuar shtuar ose hequr kolonat per serite kohore. Ndryshimet pasqyrohen ne gjith projektin direkt

Me poshte keni backround settings ku mund ta personalizoni projektin sipas deshires suaj duke shtuar foto ne backround duke ndryshuar ngjyre ose duke e len default 

Shpresoj tju ket pelqyer!