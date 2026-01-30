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
  "rugarch",
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

PROMPT / SPEC: Shiny Time Series App (Dynamic Engine)
Qëllimi

  Ndërto një Shiny App që punon me çdo dataset time series të ngarkuar nga useri (CSV/Excel), pa asnjë hardcode të emrave të kolonave. App-i duhet të ketë një data engine që normalizon të dhënat në një format standard dhe pastaj ekzekuton module analitike (EDA, stationarity, modeling, forecasting) mbi seritë e zgjedhura.

1) Modulet që duhet të punojnë për çdo dataset
  1) EDA – Seri kohore
    A1. Seria e vëzhguar
      Plot line (ggplot geom_line) me kohën në boshtin X dhe vlerën në boshtin Y.
      Konvertim në plotly (ggplotly) + hover custom (time + value të formatuar).

    A2. Mesatarja lëvizëse (Rolling mean)
      zoo::rollmean(series, k=roll_k, align="right", fill=NA)
      Plot: seria origjinale + rolling mean i theksuar.

    A3. Shpërndarja
      Histogram me densitet (geom_histogram(... density ...))
      geom_density() (KDE)

2) EDA – Marrëdhënie
  B1. Scatter + trend linear
    geom_point() + geom_smooth(method="lm", se=FALSE) për trendin.

  B2. Matrica e korrelacionit
    cor(d, use="complete.obs") (për kolonat numerike të zgjedhura, pa kohën)
    Heatmap: geom_tile() + gradient divergjent + geom_text() për vlerat.
    Note: në versionin dinamik, s’ka name_map hardcode; label-et dalin nga emri i kolonës ose metadata që useri vendos.

3) Stacionariteti
  C1. Diferenca e parë

    y <- ts(series, start=start_time, frequency=freq) (vetëm kur frekuenca është e përshtatshme për ts; shih seksionin F)
    dy <- diff(y)
    Plot i dy.

  C2. ACF & PACF mbi dy
    acf(dy, plot=FALSE), pacf(dy, plot=FALSE)
    conf = 1.96 / sqrt(length(dy))

  C3. ADF Test
    tseries::adf.test(y) në nivel
    tseries::adf.test(diff(y)) në diferencë
    Output tabelor: statistic + p-value + interpretim me alpha = 0.05.

4) Modelimi
  D1. ETS vs ARIMA
    ETS: forecast::ets(y)
    ARIMA: forecast::auto.arima(y, seasonal=FALSE, stepwise=FALSE, approximation=FALSE)
    (me policy performance kur dataset-i është shumë i madh; shih seksionin E)
    Forecast: forecast::forecast(model, h=model_h)
    Plot krahasues: Observed vs ETS vs ARIMA
    Accuracy: forecast::accuracy(fit) → RMSE, MAE, MAPE

5) Parashikimi (Forecast tab)
  E1. Metodat e zgjedhshme

    SES: forecast::ses(y, h=h)
    Holt: forecast::holt(y, h=h)
    ARIMA: auto.arima(...) + forecast(fit, h=h)

  E2. Plot forecast
    Observed + forecast mean
    Interval 80% (ribbon): lower[,"80%"], upper[,"80%"]

  E3. Metrikat
    forecast::accuracy(fitted_model()) → ME, MAE, RMSE, MAPE

2) Kontrata minimale e dataset-it (që app-i të ecë gjithmonë)
  B1. Minimum i detyrueshëm
    Dataset-i duhet të ketë:
    1 kolonë kohe (time column)
    e parse-ueshme qartë si: daily date, YYYY-MM, YYYY, YYYYQ#, etj.
    të paktën 1 kolonë numerike (value series)
    numerike reale ose e konvertueshme (p.sh. 1,23 → 1.23)

  B2. E rekomanduar
    Koha e renditur (ascending)
    Pa duplikate në kohë ose useri zgjedh agregimin: mean/sum/last

3) Validimet kryesore (që t’i kërkosh para se të hapen tab-et)
  C1. Validime për kohën
    Time column ekziston dhe ka NA minimal (ose NA të menaxhueshme)
    Parse success:
      ideal 100%
      nëse 95–99% → warning + listim i rreshtave problematikë
    Pas sort-it: koha është monotonic (ascending)
    Frekuenca:
      useri e zgjedh manualisht OSE auto-detect nga diferencat
    Regularity:
      nëse del irregular:
      propozo resample/aggregate
      ose lejo irregular por çaktivizo modelet që s’kan sens
    Përkufizim i “irregular” (kriter i qartë)
      Engine e konsideron dataset-in irregular nëse:
        hapat kohorë nuk janë uniform në shumicë, ose
        mungojnë shumë periudha.
    Policy e thjeshtë:
      nëse gap-rate > 10% (periudha të munguar kundrejt periudhave të pritshme) → “irregular”.

  C2. Validime për kolonat numerike
    Për çdo seri të zgjedhur:
      Konverto në numeric (presje, space, valuta)
      Mos lejo seri konstante (sd≈0)
      Minimum length (sipër module-specific)
    Missing values (NA policy)
      Engine llogarit missing-rate për çdo seri.
      Nëse missing > 30%:
        warning i fortë dhe sugjerim për cleaning (drop/impute/interpolate/ffill)
        opsional: disable disa analiza (ADF/ARIMA) nëse n_complete bie shumë.
    Duplikate në kohë (duplicate time policy)
      Nëse ka duplikate në time column:
        useri zgjedh agregimin: mean/sum/last
        Default i rekomanduar: mean për numeric (për stabilitet), sum vetëm kur useri e kërkon.

4) Validime “module-specific” (që tab-et të mos prishen)
  Observed TS: n >= 2
  Rolling mean: roll_k >= 2 dhe roll_k < n (ndryshe auto-fix + warning)
  Histogram/density: rekomando n >= 10
  Scatter + lm: 2 seri numerike + n_complete >= 3
  Correlation: ≥ 2 kolona numerike; useri zgjedh subset (max 20)
  Diff + ACF/PACF: minimal n >= 5, rekomando n >= 20
  ADF: rekomando n >= 20 (më mirë 30+), ndryshe disable + mesazh
  ETS: rekomando n >= 20
  ARIMA: rekomando n >= 30, ndryshe sugjero SES/Holt ose warning
  Forecast: h >= 1; nëse h > floor(n/2) → warning

5) Hard validations (bllokon rrjedhën)
  duhet 1 time column + ≥1 numeric value column
  duhet nrow ≥ 2
  për Stationarity/Modeling: n_complete ≥ 20 (ose 30) ndryshe disable module (jo crash)

6) Soft validations / policies (performance & UX)
  Defaults (të fiksuara si policy)
    Downsample threshold (plots): n > 10k
    Correlation hard limit: max 20 kolona
    DT preview max columns: 50
    ARIMA fast threshold: n > 5k

  Policies
    ncol > 200 → warning + UI search + preview limited
    DT preview max 50 columns (user choose)
    correlation max 20 columns (hard limit i modulit)
    n > 10k → downsample vetëm për grafikë (modelimi përdor full)
    n > 5k → “Fast ARIMA” mode (opsional/toggle)

7) UI Behavior (si duhet të sillet app-i)
  Useri zgjedh:
    time column
    frequency (auto/manual)
    value columns (multi-select)
    opsione cleaning: missing handling + duplicate aggregation
  Engine krijon një objekt standard: time index + seri numerike + metadata
  Çdo tab punon vetëm mbi këtë objekt (pa hardcode emrash kolone)
  Në çdo invalidim: app-i jep mesazh të qartë + sugjerim konkret çfarë të bëjë useri

8) Data Engine Output Contract (çfarë prodhon engine-i për tab-et)
  Engine duhet të prodhojë këto objekte standarde (që çdo tab t’i përdorë njësoj):
    data_clean: dataframe i pastruar (pas parse, sort, cleaning)
    time_index: vektor kohe (Date/Year/Period) i renditur
    series_matrix: dataframe/矩 me vetëm kolonat numerike të zgjedhura (pa time)
    meta:
      frequency (auto/manual), regular/irregular, gap-rate
      range (start/end), n, n_complete, missing-rate per seri
      labels/units (nga emri i kolonës ose input i userit)

9) Rregull për ts() dhe frekuencat (që të mos ket keqkuptime)
  Engine duhet të përdorë ts() vetëm kur seria është regular dhe frekuenca është e përshtatshme:
    Yearly → freq=1
    Quarterly → freq=4
    Monthly → freq=12

  Për Daily ose Irregular:
    përdoret Date-index (jo ts klasik), ose propozohet resampling (p.sh. daily→monthly) para përdorimit të ts().

  start_time duhet të jetë i përcaktuar qartë sipas frekuencës:

    Monthly: (year, month)
    Quarterly: (year, quarter)
    Yearly: year