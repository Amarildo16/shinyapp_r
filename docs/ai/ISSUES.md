# Problemet e gjetura (ISSUES)

> [!info] Si përdoret
> Çdo problem ka një ID që përmendet te [TASKS.md](TASKS.md), te `steps/` dhe në ditarin e Obsidian. Kur rregullohet, shëno kutinë **vetëm me provë** (testi ose skenari Qxx) dhe pasqyroje te `02 - Problemet e gjetura.md` në Obsidian.
> Rreshtat i referohen commit-it `976dce0`.

**Kategoritë:** `P` = strukturë, `B` = bug, `D` = kod / asete të vdekura, `U` = konsistencë / UX

## P — Struktura

- [ ] **P-01 — Tre file monolitike.** `app.R` ka UI + server (2 365 rreshta); `helpers.R` përzien librari, globale, I/O, matematikë dhe background; `server_plots.R` është një funksion i vetëm 1 867 rreshta.
  - Zgjidhja: folderi `R/` + module Shiny ([ARCHITECTURE.md](ARCHITECTURE.md)). · Faza: 2–5
  - Faza 2 (2026-10-27): `helpers.R` u nda në 13 skedarë te `R/` (62 objekte, identike me origjinalin); `server_plots.R` → `R/legacy_server_plots.R`. Mbetet `app.R` (Fazat 3–6) dhe `legacy_server_plots.R` (Faza 5).
- [x] **P-02 — Zbulimi i kolonave numerike është kopjuar 8 herë.** Kontrolli `mean(!is.na(to_numeric_safe(x))) >= 0.70`.
  - `app.R`: 893, 992, 1221, 1333, 1410, 1548, 1622
  - `server_plots.R`: 41
  - Zgjidhja: një funksion `detect_numeric_cols(d, exclude)`. · Faza: 2
  - Mbyllur 2026-10-27: `detect_numeric_cols(d, exclude, threshold = 0.70, fallback_all = TRUE)` te `R/data_parse.R` zëvendëson të 8 kopjet (te `legacy_server_plots.R` me `fallback_all = FALSE`, siç ishte). Prova: `grep "0.70"` nuk gjen kopje; `test-data_parse.R`; 10 010 kombinime të njëjta me kodin e vjetër (Claude).
- [x] **P-03 — Zbulimi i kolonës së kohës + vlerat default janë kopjuar 6 herë.**
  - `app.R`: 882, 982, 1202, 1325, 1533
  - `server_plots.R`: 18
  - Zgjidhja: `resolve_dataset_defaults(d, cfg)` që kthen `time_choices`, `time_col`, `num_cols`, `value_cols`. · Faza: 2
  - Faza 2 (2026-10-27): `resolve_dataset_defaults(d, cfg, current_time, current_values)` + `pick_value_cols()` te `R/data_prepare.R` zëvendësojnë 5 kopjet e `app.R`, si edhe pjesën e serive te observer-at `modal_time_col` dhe `data_time_col`. Prova: `test-data_prepare.R`; 10 010 kombinime (kopja 1 dhe 3) identike me kodin e vjetër.
  - **Mbetet:** `time_col()` te `R/legacy_server_plots.R` ka rregulla të tjera (inputi → "Year" → kandidati i parë). Zëvendësimi do ndryshonte default-et; propozohet ta mbyllë Faza 4 (P-05). Shtyrë te Faza 4 me V-14.
  - Mbyllur 2026-10-27 (Faza 4): `time_col()` u hoq nga `legacy_server_plots.R`; koha dhe seritë vijnë nga `active()` / `prepare_series()`. Prova: `grep` pa `time_col <-`; vlerat e të 6 faqeve identike para/pas në browser (16 fusha × 2 dataset-e); Q30 24/24 (Claude).
- [ ] **P-04 — Tema e grafikëve është kopjuar 9 herë.** Sfondi transparent, teksti i bardhë dhe `layout()` i njëjtë përsëriten në çdo grafik.
  - Zgjidhja: `plot_theme.R` me `glass_layout()`. · Faza: 5
- [x] **P-05 — Dy burime të së vërtetës për konfigurimin.** JSON-i (`active_cfg()`) dhe inputet e fshehura (`data_time_col`, `data_value_cols`). Përmbledhja preferon JSON-in, grafikët preferojnë inputet. Kjo shkakton render të dyfishtë kur ndryshon dataset-i.
  - Zgjidhja: `mod_datasets` kthen një `active()` të vetëm. · Faza: 4
  - Mbyllur 2026-10-27: `active()` + `series()`; inputet e fshehura dhe `active_cfg()` u hoqën; edhe Përmbledhja lexon `active()`. Prova (Claude, browser, numërim `shiny:value`, V-15 d): aktivizimi nga Settings → 27 output-e, secili 1 herë, 0 errore (edhe para). Aktivizim me faqen e dukshme: Përmbledhja 5 → 1 render, faqet e analizës 5 → 2. Kalimi i dytë vjen nga zgjedhësit globalë të serive (`eda_series`…), që përditësohen me një vajtje-ardhje te browser-i; mbyllet në Fazën 5, kur zgjedhësi kalon brenda modulit.
- [x] **P-06 — Dataset-i aktiv ngarkohet dy herë në startup.** `observe()` (`app.R:1151`) dhe `observeEvent(active_dataset_file())` (`app.R:910`) ngarkojnë të dy.
  - Faza: 4
  - Mbyllur 2026-10-27: një observer i vetëm ngarkimi te `mod_datasets_server()` (T-15). Prova: `test-mod_datasets.R` (nisja me/pa konfigurim).
- [x] **P-07 — ARIMA llogaritet dy herë, me dy cache manuale.** Modelimi (`.model_cache_*`) dhe Parashikimi (`.arima_cache_*`) llogaritin të njëjtin `auto.arima`.
  - Zgjidhja: `model_store` i përbashkët me `bindCache`. · Faza: 5
  - Mbyllur 2026-10-28 (Faza 5, bazat): `model_store()` me `cachem` (T-19); dy cache-t manuale u hoqën. Prova: `test-model_store.R` (një llogaritje për seri, lloji në çelës, NULL ruhet); Q30 24/24 (modelet dhe parashikimet = referenca) (Claude).
- [ ] **P-08 — Modalet hapen me tre mënyra.** Mesazhi `toggle_modal`, `shinyjs::runjs` me Bootstrap (`modal_show_bg`) dhe `showModal`.
  - Zgjidhja: një mënyrë e vetme + `glass_modal()` në `ui_components.R`. · Faza: 3–6
  - Faza 4 (2026-10-27, V-15 a): modalet e dataset-eve (Upload, konfigurimi, fshirja) hapen e mbyllen vetëm me `toggle_glass_modal()`; `showModal` dhe `ajax_modal_open` u hoqën për dataset-et. **Mbetet:** background-i (`modal_show_bg`, `showModal` i fshirjes së fotos), Faza 6.
- [ ] **P-09 — `BG_STATE` lexohet dy herë** (`app.R:4` dhe `app.R:1657`). · Faza: 6
- [ ] **P-10 — `BG_PLACEHOLDER_SVG` definohet pasi përdoret** (`app.R:1743`). Punon vetëm falë vlerësimit të vonuar. · Faza: 6
- [x] **P-11 — Inputet `data_dup` dhe `data_freq` janë të fshehura.** Janë gjithmonë `mean` / `auto`, pra kod që nuk zgjidhet kurrë nga përdoruesi.
  - Zgjidhja: konstante në `config.R`, ose opsion në konfigurimin e dataset-it. · Faza: 4
  - Faza 3 (2026-10-27): `DUP_POLICY`/`FREQ_POLICY` te `config.R` (vlerat default të inputeve të fshehura). Inputet hiqen në Fazën 4.
  - Mbyllur 2026-10-27: inputet u hoqën; `prepare_series()` dhe `legacy_server_plots.R` përdorin `DUP_POLICY`/`FREQ_POLICY`. Prova: `grep` pa `data_dup`/`data_freq`; Q30 24/24.
- [ ] **P-12 — Lista e faqeve përsëritet në 5 vende.** Butonat në UI, `TITLE_MAP`, `BG_TABS`, `MAP` te `sidebar.js` dhe `AFFECTS` te `plotly-animate.js`.
  - Zgjidhja: `PAGES` në `config.R`, ku UI dhe JS gjenerohen prej saj. · Faza: 3
  - Faza 3 (2026-10-27): butonat e sidebar-it, tab-et, `TITLE_MAP` (→ `page_title()`), `BG_TABS` dhe harta e `sidebar.js` gjenerohen nga `PAGES`; `bg.js` nuk ka më ID. Prova: diff i HTML-së, `grep`, browser. **Mbetet:** `AFFECTS` te `plotly-animate.js` (Faza 7).

## B — Bug-e

- [x] **B-01 — Tabelat tregojnë gjithmonë 4 decimale.** `fmt_by_series()` thirret për një vlerë të vetme, kështu që hapësira e vlerave është 0 dhe zgjidhet formati me 4 decimale.
  - Vendet: `server_plots.R` 372–380 (statistikat përmbledhëse), 1495–1497 (saktësia e modelimit), 1859–1861 (saktësia e parashikimit)
  - Zgjidhja: formatimi i gjithë kolonës njëherësh, ose një funksion i dedikuar për vlera të vetme. · Faza: 2
  - Mbyllur 2026-10-27: `fmt_table_value()` (T-05) në të tre tabelat. Prova: testi B-01 te `test-utils_format.R` kalon mbi kodin e ri dhe dështon mbi formatimin e vjetër; në browser "63,5000" → "63,50" (Claude). Shembujt para/pas te STATUS.md.
  - Shënim: hover-at e Parashikimit thërrasin ende `fmt_unit()` për çdo vlerë veç e veç (4 decimale); rishkruhen në Fazën 5 (B-05, V-08).
- [ ] **B-02 — Slider-at përditësohen vetëm një herë për dataset.** Për shkak të `.slider_once` (`server_plots.R:141`), kur ndërron serinë, maksimumi mbetet ai i serisë së vjetër.
  - Faza: 5
- [x] **B-03 — Upload dhe Edit ofrojnë seri të ndryshme.** Te upload, "Proceed" ofron çdo kolonë që nuk është koha (`app.R:1381`), ndërsa Edit ofron vetëm kolonat numerike.
  - Faza: 4
  - Mbyllur 2026-10-27: një funksion i vetëm `open_config_modal()` me `resolve_dataset_defaults()$num_cols`. Prova: testi B-03 te `test-mod_datasets.R` (HTML-ja e zgjedhësit të serive pa kolonat tekst); browser: `text_cols.csv` ofron vetëm `Value`. Shënim: në browser, kodi i vjetër e korrigjonte listën kur ndryshonte `modal_time_col`, ndaj gabimi dukej vetëm kur modali rivizatohej me të njëjtën kolonë kohe.
- [ ] **B-04 — Te Parashikimi, vija e vëzhguar dhe parashikimi janë të dyja të bardha.** Nuk dallohen. · Faza: 5
- [ ] **B-05 — Hover-i i Parashikimit lidhet me vijat sipas gjatësisë.** `nx == nrow(...)` (`server_plots.R:1760`) prishet kur h = n.
  - Zgjidhja: `plot_ly` direkt me `text` për çdo trace. · Faza: 5
- [ ] **B-06 — `showNotification` brenda render-ave.** Njoftimet përsëriten në çdo rifreskim.
  - Vendet: `server_plots.R` 514, 534, 541, 838, 844, 854, 951, 1030, 1040, 1373, 1512, 1522, 1616, 1620, 1630
  - Zgjidhja: `validate(need(...))` ose mesazh në kartë. · Faza: 5
- [ ] **B-07 — Teksti i vjetër "variablave kryesore bujqësore"** te EDA – Marrëdhënie (`app.R:397`). · Faza: 5
- [ ] **B-08 — Emri i fotos futet në JS pa escape.** `sprintf("...'%s'...")` (`app.R:2053`). Një emër me `'` e prish klikimin.
  - Zgjidhja: `jsonlite::toJSON()` si te dataset-et. · Faza: 6
- [ ] **B-09 — Kolona e kohës numerike që nuk është vit refuzohet.** Vendimi: vetëm mesazh më i qartë (V-11). Klasifikohet si `index`, kështu që Stacionariteti, Modelimi dhe Parashikimi nuk punojnë.
  - Vendim: ose mbështetje me frekuencë 1, ose mesazh më i qartë. · Faza: 5
- [ ] **B-10 — Preloader-i errëson gjithë ekranin në çdo `shiny:busy`** (`custom.js:14`), edhe për një lëvizje slider-i.
  - Zgjidhja: shfaqet vetëm pas ~400 ms, ose vetëm për llogaritje të gjata. · Faza: 7
- [ ] **B-11 — Warning-e në console të R-së gjatë përdorimit** (gjetur në Fazën 0, 2026-10-27, Q01).
  - `ggplot2::geom_point(aes(text = hover))` → "Ignoring unknown aesthetics: text" (`server_plots.R:752`, EDA – Marrëdhënie). Zhduket me `plot_ly` (V-08).
  - `tseries::adf.test()` → "p-value smaller than printed p-value" kur p < 0,01 (`server_plots.R:1163–1165`). Është sjellje normale e testit; vlera e shfaqur (0,0100) është ajo e `tseries`. Zgjidhja duhet të mos ndryshojë vlerën (R21), p.sh. kapja e këtij warning-u specifik.
  - Faza: 5
  - Faza 5, bazat (2026-10-28): warning-u i `adf.test` u hoq te `run_adf()` dhe p-vlera e prerë ruhet si `p_bound` (V-17 c). Prova: `test-ts_models.R` (`expect_no_warning`, vlera = `tseries`); Q30 pa warning; log-u i app-it pa warning ADF. **Mbetet:** `aes(text)` (me `plot_ly`, moduli EDA – Marrëdhënie).
- [ ] **B-12 — Errore në console të browser-it te Modelimi** (gjetur në Fazën 0, 2026-10-27).
  - "Shiny server has sent a progress message for model_plot, but the output is in an unexpected state" (+ "recalculating"/"recalculated" … "idle"). Vjen nga `shiny::withProgress()` brenda reaktivit `.model_fits()` (`server_plots.R:1316`); i njëjti model te `arima_fit()` (`server_plots.R:1572`). Grafiku dhe tabela shfaqen saktë.
  - Zgjidhja: llogaritja e modeleve jashtë render-it (`model_store`, P-07), progres pa `withProgress` brenda `reactive()`. · Faza: 5
- [x] **B-13 — Formati dd-mm-YYYY lexohet gabim** (mbyllur 2026-10-27 me V-14: formati pranohet vetëm kur teksti ka formën e plotë; prova: 300/300 raste dd-mm-YYYY të sakta, 2 100 raste të formateve të tjera identike me kodin e vjetër, Q29 0 dështime, Q30 24/24, në app dataset-i dd-mm-YYYY lexohet saktë — Claude) (gjetur në Fazën 2, 2026-10-27). `parse_time_safe(c("15-03-2021", "16-03-2021"))` → `0015-03-20`, `0016-03-20`: formati `%Y-%m-%d` provohet i pari dhe `as.Date` injoron karakteret e tepërta. R08 e liston dd-mm-YYYY si të mbështetur.
  - Zgjidhja (V-14, `c1c7048`): një format pranohet vetëm kur teksti ka formën e plotë të formatit. Testi te `test-data_parse.R` ekzekutohet dhe kalon. · Faza: 2
- [ ] **B-14 — `to_numeric_safe()` lexon tekstin me shifra si numër** (gjetur në Fazën 2). Shkronjat hiqen, kështu që "shenim 2015" → 2015, dhe një kolonë shënimesh mund të dalë "numerike" (pragu 0.70). Sjellje ekzistuese, e dokumentuar në test; ndryshimi do prekte zbulimin e kolonave (R05). Diskutohet para çdo ndryshimi. · Faza: e pacaktuar

- [ ] **B-15 — Dialogu i konfirmimit të fshirjes nuk lexohej** (gjetur në Fazën 4, 2026-10-27). `showModal(modalDialog())` delte me sfond të bardhë dhe tekst të bardhë: titulli dhe pyetja nuk shiheshin, vetëm butonat. Screenshot-i "para" në Obsidian `screenshots/faza-4/`.
  - Dataset-et: rregulluar në Fazën 4 (V-15 a): `glass_modal` me pamjen e modalit Upload; teksti lexohet (screenshot "pas"). **Mbetet:** konfirmimi i fshirjes së fotos te Background përdor po `showModal` (e paverifikuar nëse ka të njëjtin problem), Faza 6.
- [ ] **B-16 — Console e browser-it gjatë Upload-it me FilePond** (gjetur në Fazën 4, 2026-10-27). Pas zgjedhjes së skedarit: `404 /[object Object]` dhe warning-u "Pond -> Shiny updatefiles sync failed: … parameter 1 is not of type 'File'" (`custom.js:193`). Dalin njësoj edhe me kodin e commit-it `5daa8fc` (para Fazës 4), pra nuk janë regresion. Ngarkimi punon: CSV-ja lexohet dhe ruhet md5-identike. Provuar vetëm me file chooser-in e Playwright; mbetet të shihet nëse ndodh edhe me klikim/drag-and-drop real. Përjashtuar përkohësisht nga Q01 me V-16. · Faza: 7 (FilePond bridge)

- [x] **B-17 — ADF jepte error me saktësisht 20 pika** (gjetur në Fazën 5, 2026-10-28). Te `adf_res()`, kur diferenca kishte < 20 pika, në vend të testit vendosej teksti `"try-error"`, pastaj `obj$statistic` jepte "$ operator is invalid for atomic vectors". Prova: rikrijimi i shprehjes në R. `run_adf()` e llogarit nivelin dhe e lë diferencën bosh; testi te `test-ts_models.R`. ✅ Pranuar si rregullim bug-u me V-18 (2026-10-28). · Faza: 5

## D — Kod dhe asete të vdekura

- [x] **D-01 — `www/css/icons.css` (750 KB) ngarkohet por nuk përdoret.** · Faza: 1
  - Mbyllur 2026-10-27: `tags$link` u hoq; skedari u zhvendos te `_to_delete/` (pa leje fshirjeje). Përmbante edhe një kopje të vjetër të Remix që mbishkruante `remixicon.css`. Kodet e 8 ikonave të përdorura u krahasuan: identike, me të njëjtat fonte, pra pamja nuk ndryshon. Prova: kërkim me `grep`; në browser, të 8 ikonat shfaqen me fontin `remixicon` (Claude).
- [x] **D-02 — ~16 MB fonte të papërdorura.** `boxicons.*`, `la-*`, `materialdesignicons-*`, `hkgrotesk-*`, `summernote.*`. Mbahen vetëm `remixicon.*`. · Faza: 1
  - Mbyllur 2026-10-27: 42 skedarë (10,3 MB, jo 16 MB siç ishte vlerësuar) u zhvendosën te `_to_delete/`. Remix kaloi te `www/vendor/remixicon/` dhe `url(...)` u rregulluan. `www/` ra nga 20 MB në 8,8 MB. Prova: asnjë kërkesë 404 në browser; `woff2` ngarkohet nga rruga e re (Claude).
- [x] **D-03 — Funksione dhe output-e të papërdorura:** (Faza 1: të gjitha përveç `context`. Faza 2, 2026-10-27: `context` u hoq nga `validate_ts_ready` dhe nga 5 thirrjet; u hoqën edhe `has_zoo`/`has_readxl` globale, të papërdorura. Prova: `grep` pa mbetje; Q29, Q30.)
  - `pick()` (`helpers.R:1065`)
  - `fmt_pct` (`server_plots.R:388`)
  - `time_range_txt` (`server_plots.R:257`)
  - `output$bg_media_selected_txt` (`app.R:2094`)
  - `has_vars`, `has_rugarch` (`helpers.R:367`)
  - `tab_wrapup` (`app.R:722`)
  - dega `fs` te `ajax_modal_open`
  - variabla `title` te `csv_file_modal`
  - parametri `context` te `validate_ts_ready`
  - Faza: 1–2
- [ ] **D-04 — README dhe Metodologjia premtojnë gjëra që nuk ekzistojnë.** (Faza 1, 2026-10-27: rreshti ARMA/VAR/GARCH u hoq nga Metodologjia; `vars`/`rugarch` u hoqën nga README. Mbetet kontrolli i Metodologjisë kundrejt app-it në Fazën 8.) Vendimi: hiqen (V-10). README instalon `vars` dhe `rugarch`; Metodologjia përmend ARMA, VAR/IRF dhe GARCH, që nuk janë implementuar. · Faza: 1 dhe 8
- [x] **D-05 — Dega numerike e `parse_time_safe` ka kod të tepërt.** Kontrolli i hapit kthen `xn` në të dyja rastet. · Faza: 2
  - Mbyllur 2026-10-27: blloku `xu`/`steps` u hoq. Prova: 308 raste numerike me dalje identike me kodin e vjetër; `test-data_parse.R` (Claude).

## U — Konsistencë dhe UX

- [ ] **U-01 — Gjuha e përzier.** Vendimi: UI dygjuhëshe sq/en me `tr()` (V-09, R26). Etiketa në anglisht: Settings, Save, Proceed, Cancel, Library, Upload, Blur strength, Edit. · Faza: 8
  - Faza 3 (2026-10-27): infrastruktura `tr()` + `i18n/`; layout-i, sidebar-i, topbar-i, Settings dhe modalet kalojnë nga `tr()`. Vlerat shqip janë tekstet e sotme (T-12), ndaj përzierja rregullohet te `sq.json` në Fazën 8.
- [ ] **U-02 — Gabime drejtshkrimi.** "ndërtu", "u lexu", "Backround" (në koment). · Faza: 8
- [x] **U-03 — `.gitignore` ka `.Rproj`.** Duhet `*.Rproj`. · Faza: 0
  - Mbyllur 2026-10-27: `.Rproj` → `*.Rproj`; u shtuan `storage/` dhe `renv/library|staging|local/`. Prova: `git diff .gitignore` (Claude).
- [ ] **U-04 — Ngarkimet e përdoruesit shkruhen brenda kodit** (`data/`, `www/images/`).
  - Zgjidhja: folderi `storage/`. · Faza: 3
  - Faza 3 (2026-10-27): CSV-të dhe state-i shkojnë te `storage/` me migrim që kopjon (T-08); `data/` nuk shkruhet më. Prova: `test-storage.R` (Q02, Q03), browser mbi kopje me `data/` të vjetër. **Mbetet:** fotot e ngarkuara (`www/images/` → `storage/images/`, Faza 6).
- [ ] **U-05 — CSS ka 135 `!important` dhe selektorë të përsëritur.** P.sh. `.bg-tab-card`, `.media-card` dhe `.bg-tabs-grid` janë definuar 2–3 herë. · Faza: 7
- [x] **U-06 — Line endings ndryshojnë vetvetiu.** Vendimi: discard i ndryshimit aktual (V-12) + `.gitattributes`. Windows i kthen në CRLF, kështu që `datasets_state.json` del si i ndryshuar edhe pa ndryshim real.
  - Zgjidhja: `.gitattributes`. · Faza: 0
  - Mbyllur 2026-10-27: në kompjuterin e përdoruesit `core.autocrlf=input`, prandaj git nuk shfaqte më ndryshim (s'kishte çfarë të hidhej poshtë). U shtua `.gitattributes` (`* text=auto eol=lf`, binare për foto/fonte/`.rds`/`.xlsx`/`.ico`…). Prova: `git status` pa ndryshime te `data/`, `git ls-files --eol` (index LF), `git check-attr` (Claude).
- [ ] **U-07 — "Ke ndryshime pa Save" mbetet pasi kthehet zgjedhja fillestare** (gjetur në Fazën 0, 2026-10-27). Te Background, Foto → Pa background (pa Save) e lë mesazhin edhe pse gjendja është sërish ajo e ruajtur. E vogël; vetëm UX. · Faza: 6
