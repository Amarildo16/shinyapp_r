# Vendimet dhe pyetjet e hapura

Gjendja fillestare: 2026-10-27. Përditësuar: 2026-10-27 (Faza 4: V-15, T-14 – T-17). Më herët: Faza 3 (T-08 – T-13) — T-05 – T-07 dhe dy pyetje nga Faza 2 (B-13, P-03 kopja 6). Më herët (19:10): V-13 (Q01 në Fazat 0–4). Më herët (18:57): vendimet teknike T-01 – T-04. Më herët (18:33): V-08 – V-12 u mbyllën; V-09 u ndryshua nga përdoruesi në UI dygjuhëshe. Përditëso datën dhe regjistro arsyen kur ndryshon një vendim. **Mos ripyet një vendim që përdoruesi e ka dhënë.**

ID-të janë të njëjta me shënimin `05 - Vendimet.md` në Obsidian.

## Të pranuara

| ID | Data | Vendimi | Alternativa e refuzuar | Arsyeja / pasoja |
|---|---|---|---|---|
| V-01 | 2026-10-27 | App-i mbetet **R + Shiny**. | Rishkrim në C/C++/Rust; app desktop native. | Llogaritjet e rënda në R janë tashmë kod i kompiluar. C/C++ nuk kanë ekuivalent të `forecast`. Saktësia statistike ka përparësi. Përdoruesi: "mbajmë kështu si e kemi". |
| V-02 | 2026-10-27 | **Single-user, lokal**, niset në RStudio. | Multi-user / deploy. | Zysha e nis vetë. State-i mbetet në JSON lokale; pa izolim sesionesh. |
| V-03 | 2026-10-27 | **Shiny i thjeshtë me `R/` + module Shiny.** | golem, rhino. | "Run App" në RStudio mbetet. Pa varësi dhe kompleksitet shtesë. |
| V-04 | 2026-10-27 | **Një burim i vetëm i së vërtetës:** `mod_datasets_server()` kthen `active()`; `prepare_series()` llogaritet një herë. | JSON + inpute të fshehura (gjendja aktuale). | Zgjidh P-05, P-06. |
| V-05 | 2026-10-27 | **`storage/`** për të dhënat e përdoruesit, `data/samples/` për shembujt, migrim që **kopjon**. | Ngarkime brenda kodit. | Zgjidh U-04. Asnjë humbje të dhënash. |
| V-06 | 2026-10-27 | **`renv`** për versionet e paketave. | Instalim i lirë. | E njëjta sjellje në çdo kompjuter dhe pas kohësh. |
| V-07 | 2026-10-27 | **Testet me referencë** nga versioni aktual (`tests/reference/`). | Krahasim me sy. | Ristrukturimi nuk ndryshon rezultate statistike pa dashje. |
| V-08 | 2026-10-27 | **Grafikët me `plot_ly()` direkt**, pa `ggplot()` + `ggplotly()`. | Mbajtja e `ggplotly`. | Përdoruesi: "bëj versionin më të mirë". Më i shpejtë, hover pa truka (zgjidh B-05), kontroll i plotë i pamjes. Pamja riprodhohet dhe krahasohet me screenshot-et "para" (Q27). Vlerat e llogaritura nuk ndryshojnë: ndryshon vetëm vizatimi. |
| V-09 | 2026-10-27 | **UI dygjuhëshe: shqip + anglisht**, me zgjedhje gjuhe në Settings. Shqipja e paracaktuar. Detajet te "V-09 — si zbatohet". | Vetëm shqip (propozimi fillestar). | Kërkesë e përdoruesit: "do ta doja edhe shqip edhe anglisht, si përkthime". Kërkesa e re R26. |
| V-10 | 2026-10-27 | Rreshti "Opsionale: simulime ARMA, VAR/IRF dhe GARCH" **hiqet** nga Metodologjia. | Mbajtja si "planifikuar". | Përdoruesi i la zgjedhjen AI-së. App-i përdoret në mësim dhe nuk duhet të premtojë analiza që nuk ekzistojnë. Bashkë me të hiqen `vars`/`rugarch` nga instalimi (D-04). Nëse një ditë shtohen, bëhen kërkesë e re. |
| V-11 | 2026-10-27 | Kolona e kohës numerike që nuk është vit: **vetëm mesazh më i qartë**, pa ndryshim sjelljeje. | Mbështetje me frekuencë 1. | Përdoruesi i la zgjedhjen AI-së. Mbështetja do ndryshonte sjelljen dhe rezultatet (kundër R21). Mesazhi i ri i thotë përdoruesit pse dhe çfarë formati kohe të përdorë. Nëse kërkohet më vonë, bëhet kërkesë e re. |
| V-12 | 2026-10-27 | Ndryshimi i line endings te `data/datasets_state.json` **hidhet poshtë (discard)** në Fazën 0, para `.gitattributes`. | Commit. | Përdoruesi i la zgjedhjen AI-së. Përmbajtja është identike (`git diff --ignore-cr-at-eol` bosh); një commit do shtonte vetëm zhurmë. `.gitattributes` e parandalon herët e tjera. |
| V-13 | 2026-10-27 | **Q01 në Fazat 0–4:** pa errore në R; lejohen vetëm warning-et/erroret e njohura **B-11** dhe **B-12**. **Nga Faza 5**, Q01 i plotë (pa errore dhe pa warning). | Rregullim i B-11/B-12 para Fazës 5. | Përdoruesi: "Prano propozimin … Q01 i plotë nga Faza 5". B-11/B-12 vijnë nga kodi ekzistues dhe zhduken natyrshëm në Fazën 5 (`plot_ly`, `model_store`). Çdo warning/error tjetër i ri mbetet dështim i Q01. |
| V-14 | 2026-10-27 | **(a)** Kopja e 6-të e P-03 (`time_col()` te `R/legacy_server_plots.R`) **shtyhet te Faza 4** (zhduket me P-05). **(b) B-13 rregullohet në Fazën 2:** te `parse_time_safe`, një format i provuar pranohet vetëm kur teksti ka formën e plotë të formatit. | (a) Zëvendësim tani me ndryshim të default-eve. (b) Lënia e bug-ut. | Përdoruesi: "Po: kopja e 6-të e P-03 shtyhet te Faza 4, dhe B-13 rregullohet tani në Fazën 2." (b) ndryshon rezultatin vetëm kur teksti nuk përputhet plotësisht me formatin, p.sh. dd-mm-YYYY që lexohej si viti 15. |
| V-15 | 2026-10-27 | **Faza 4, katër zgjedhje:** (a) modalet e dataset-eve hapen e mbyllen në një mënyrë të vetme (`toggle_modal` me një helper); konfirmimi i fshirjes bëhet `glass_modal` me të njëjtin tekst dhe butona. (b) `ns()` i plotë te `mod_datasets`; selektorët në CSS/JS riemërtohen mekanikisht. (c) Tekstet që thonë "data/" korrigjohen në `storage/datasets`. (d) Q04 provohet duke numëruar ngjarjet `shiny:value` për çdo output në browser, pa `reactlog`. | (a) `showModal` për konfirmimin; (b) ID globale për modalet, si te T-10; (c) tekstet mbeten deri në Fazën 8; (d) `reactlog` te renv (paketë e re). | Përdoruesi: "Vazhdo me rekomandimet". (a) mbyll P-08 për dataset-et; pamja e dialogut të fshirjes mund të ndryshojë pak (krahasohet me screenshot). (b) zbaton rregullin e moduleve. (c) nga Faza 3 dataset-et ruhen te `storage/datasets`, ndaj teksti ishte i pasaktë. (d) pa paketë të re dhe pa prekur kodin e app-it. Me "vazhdo" pranohet edhe B-03: Upload ofron vetëm kolonat numerike, si Edit. |

## V-09 — si zbatohet (vendim teknik i AI-së, brenda V-09)

- **Pa paketë të re** (Ponytail): `R/i18n.R` me funksionin `tr(key, ...)` dhe dy file përkthimesh `i18n/sq.json` dhe `i18n/en.json`, me të njëjtët çelësa.
- **Gjuha e paracaktuar: shqip.** Zysha e përdor në shqip; anglishtja zgjidhet në Settings.
- **Ruajtja:** gjuha ruhet te `storage/state/settings.json` dhe mbetet pas rinisjes.
- **Ndërrimi:** ruan zgjedhjen dhe rifreskon sesionin (`session$reload()`). Është rruga më e thjeshtë e saktë: çdo tekst, edhe në UI statike, del në gjuhën e re. Dataset-i aktiv dhe background-i ruhen, sepse janë në `storage/`.
- **Çfarë përkthehet:**
  - menyja, titujt, etiketat, butonat, modalet
  - njoftimet dhe mesazhet e validimit
  - titujt dhe boshtet e grafikëve, kokat e tabelave
  - interpretimi i ADF, Metodologjia, etiketat e njësive (vite/years, muaj/months…)
- **Çfarë NUK përkthehet:** emrat e kolonave dhe të file-ve të përdoruesit, emri "Time Series Analysis", "By Amarildo Alla".
- **Formati i numrave ndjek gjuhën:**
  - shqip: `1 234,56` dhe "mijë / mln / mld"
  - anglisht: `1,234.56` dhe "K / M / B"
  
  Ndryshon vetëm paraqitja, jo vlerat (R21).
- **Rregulli:** asnjë tekst i dukshëm i shkruar direkt në kod. Çdo tekst kalon nga `tr()`. Një test kontrollon që `sq.json` dhe `en.json` kanë saktësisht të njëjtët çelësa dhe asnjë vlerë bosh.
- **Fazat:** infrastruktura në Fazën 03; çelësat shtohen ndërsa ndërtohet çdo modul (04–07); kontrolli i plotësisë në Fazën 08.

## Vendime teknike të regjistruara (AI, brenda detyrës)

| ID | Data | Vendimi | Arsyeja |
|---|---|---|---|
| T-01 | 2026-10-27 | `renv` u instalua në librarinë e përdoruesit. | Leje e shprehur e përdoruesit: "instalo renv në librarinë time të përdoruesit të R". |
| T-02 | 2026-10-27 | `renv` me `ignored.packages = vars, rugarch, readxl`. | `vars`/`rugarch` hiqen me V-10/D-04; `readxl` nuk është i instaluar dhe UI pranon vetëm CSV (SPEC "Kufijtë"). Pa këtë, `renv::status()` nuk do ishte i pastër, ose lock-u do kishte paketa që po hiqen. Rishikohet nëse shtohet ngarkim Excel. |
| T-03 | 2026-10-27 | Referenca: `tests/reference/compute_results.R` është përshtatësi i vetëm. Pjesët reaktive merren nga vetë `server_plots()` me `shiny::testServer` (mbështjellë si modul i hollë); llogaritjet brenda render-ave kopjohen me të njëjtat thirrje. `make_reference.R` punon vetëm kur kodi = `976dce0` dhe nuk mbishkruan `.rds`. | Referenca vjen nga kodi real, jo nga një rishkrim. Në Fazat 2–5 ndryshon vetëm `compute_results.R`; referenca mbetet e fiksuar (V-07). |
| T-04 | 2026-10-27 | Provat me app-in bëhen mbi një kopje të projektit (scratchpad) me paketat e `renv`. | App-i shkruan state te `data/`; kopja mbron të dhënat (SKILL "Të dhënat e përdoruesit"). |
| T-05 | 2026-10-27 | **B-01:** vlerat e veçanta në tabela formatohen me `fmt_table_value()`: \|x\| < 1 → 4 decimale, përndryshe 2 (pragjet e `fmt_by_series(for_axis = FALSE)`, me madhësinë e vlerës si shkallë). | Nga dy zgjidhjet e ISSUES, kjo nuk varet nga seritë e tjera në të njëjtën kolonë. Ndryshon vetëm paraqitja; vlerat jo (shembujt para/pas te STATUS.md). |
| T-06 | 2026-10-27 | `get_app_dir()`: pas `shiny.appdir`, `getwd()` ka përparësi kur aty ndodhet `app.R`; pastaj RStudio, pastaj `getwd()`. | Shiny bën `setwd(appDir)` para se të ngarkojë `R/`. Me kodin te `R/`, dokumenti aktiv i RStudio-s mund të ishte `R/x.R` dhe `DATA_DIR` do dilte `R/data`. Në çdo rast ku kodi i vjetër jepte rezultatin e saktë, rezultati mbetet i njëjtë. |
| T-07 | 2026-10-27 | `testthat` (dhe 11 varësitë e tij) te `renv.lock`, nga libraria e përdoruesit me `renv::hydrate()`; `library(testthat)` te `tests/testthat/helper-app.R`. | QUALITY.md kërkon `testthat::test_dir()`; pa `library()`, `renv` nuk e regjistronte. Asnjë version ekzistues nuk ndryshoi. |
| T-08 | 2026-10-27 | **Migrimi te `storage/` bëhet një herë** (shënuesi `storage/state/storage.json`). Dataset-et e listuara në `datasets_state.json` e vjetër që mungojnë te `data/` merren nga `data/samples/`. Çdo kopje verifikohet me md5; kopja rezervë e JSON-eve shkon te `storage/state/backup-<data>/`; `data/` nuk preket. Shembujt kopjohen vetëm kur `storage/datasets` mbetet bosh në nisjen e parë. | Pa shënues, një dataset i fshirë do rikthehej nga `data/` në çdo nisje dhe shembujt do riktheheshin pas fshirjes së të fundit (Q08). Pa rezervën nga `data/samples/`, zysha do humbiste nga lista shembujt që kalojnë te `data/samples/` me `git pull`. |
| T-09 | 2026-10-27 | `CODE_DIR` (asetet e kodit: `i18n/`, `data/samples/`) ndahet nga `APP_DIR` (të dhënat). Në app janë i njëjti folder; testet përdorin `options(app.code_dir = ...)`. | Testet dhe referenca punojnë mbi sandbox, por duhet të lexojnë përkthimet e projektit. |
| T-10 | 2026-10-27 | `mod_nav_server(input, output, session)` pa `moduleServer()`. | `main_tabs` dhe `go_<id>` janë ID globale që i përdorin `sidebar.js`, `bg.js` dhe çelësat e `background_state.json`; namespace-i do i prishte. |
| T-11 | 2026-10-27 | `ui` bëhet `function(req)`: gjuha dhe state-i i background-it lexohen për çdo kërkesë. | Pas `session$reload()` UI-ja del në gjuhën e re. Edhe zgjedhjet fillestare të Background-it pasqyrojnë tani state-in e ruajtur pas rifreskimit (më parë lexoheshin vetëm në nisje). |
| T-12 | 2026-10-27 | `i18n/sq.json` mban saktësisht tekstet e sotme (p.sh. "Settings", "Save", "Background"). | "Mos ndrysho pamjen" (hapi 03): HTML-ja shqip është identike me të vjetrën, përveç `data-nav-tab` dhe seksionit "Gjuha". Përzierja e gjuhës (U-01) rregullohet te `sq.json` në Fazën 8. |
| T-13 | 2026-10-27 | `data/datasets_state.json` dhe `data/background_state.json` mbeten në repo pa ndryshim; shembujt kalojnë te `data/samples/` me `git mv`. App-i nuk shkruan më te `data/`. | Te zysha, `git pull` nuk ka konflikt me kopjet e saj lokale të JSON-eve; migrimi i kopjon ato. Në një klon të ri, këto JSON shërbejnë si state fillestar. |
| T-14 | 2026-10-27 | `prepare_series(active)` kthen në Fazën 4 vetëm `data`, `value_cols` dhe `meta`, me të njëjtat hapa si `df_dyn()` (numrat, koha, `DUP_POLICY`, `FREQ_POLICY`). `time_label`, `freq_key` dhe `step_unit` të kontratës shtohen në Fazën 5, kur i përdorin modulet. | Ponytail: asnjë fushë pa përdorues. Kontrata e ARCHITECTURE.md mbetet synimi; `legacy_server_plots.R` llogarit ende vetë hapin dhe njësinë. |
| T-15 | 2026-10-27 | `mod_datasets_server()` lexon dataset-in në një observer të vetëm (`active_file` + `reload`). Kolona e kohës dhe seritë: konfigurimi i ruajtur, pastaj zgjedhja e dataset-it të mëparshëm, pastaj default-et (`resolve_dataset_defaults(d, cfg, prev$time_col, prev$value_cols)`). | Riprodhon gjendjen përfundimtare të inputeve të fshehura të vjetra (observer-i `df()` dërgonte i fundit përditësimin me inputet e mëparshme). Në rastin e zakonshëm (dataset me konfigurim) fiton konfigurimi. |
| T-16 | 2026-10-27 | Rrugët e gabimit të leximit njësohen: kur dataset-i aktiv nuk lexohet ose mungon në disk, shfaqet mesazhi dhe faqet zbrazen (`active()` = NULL), në vend që të mbeten me të dhënat e dataset-it të mëparshëm. Mesazhi i dytë "S’u lexu dot dataset-i i ri" pas fshirjes hiqet; mbetet "Gabim gjatë leximit". Dega "S’ka databazë. Ngarko një dataset." hiqet: nuk ekzekutohej kurrë (`observeEvent` me `ignoreNULL`). | Vetëm rrugë gabimi; V-04 kërkon që karta aktive dhe të dhënat të mos ndryshojnë nga njëra-tjetra. Rrjedhat normale (aktivizim, fshirje, ngarkim) nuk ndryshojnë. |
| T-17 | 2026-10-27 | Te Upload, modali i konfigurimit ka titull bosh (si në ngarkimin e parë të versionit të vjetër). | Më parë titulli mbetej "Edit dataset: …" nëse ishte bërë një Edit më herët në të njëjtin sesion. |

## Pyetje të hapura

- **B-16 dhe Q01 (Faza 4, 2026-10-27).** Gjatë Upload-it me FilePond, console e browser-it tregon një 404 (`/[object Object]`) dhe një warning. Të dyja dalin edhe me kodin para Fazës 4 (`5daa8fc`), pra janë të trashëguara, jo regresion. V-13 lejon në browser vetëm B-12. Propozimi: (a) **rekomanduar:** B-16 shtohet përkohësisht te përjashtimet e V-13 dhe rregullohet në Fazën 7 (FilePond bridge), si B-11/B-12 në Fazën 5; (b) rregullohet tani, para mbylljes së Fazës 4. Pret përgjigjen e përdoruesit.

Më herët: asnjë më 2026-10-27 20:00. Q01 u mbyll me V-13; pyetjet e Fazës 2 (B-13, kopja e 6-të e P-03) u mbyllën me V-14.

## Vendime teknike që AI mund t'i marrë brenda detyrës

Pa pyetur, por duke i regjistruar këtu me arsye: emrat e funksioneve dhe file-ve brenda strukturës së ARCHITECTURE.md, organizimi i testeve, refaktorimet që nuk ndryshojnë sjelljen, rregullimet e bug-eve të listuara te ISSUES.md kur zgjidhja është e qartë.

**Pyet gjithmonë për:**
- çdo gjë që ndryshon një rezultat statistik
- sjelljen e dukshme të app-it
- të dhënat e përdoruesit
- paketat e reja
- kufijtë minimalë dhe parametrat e modeleve

## Si mbyllet një vendim

Regjistro: ID, datën, burimin (cili mesazh i përdoruesit), alternativat, zgjedhjen, arsyen, dokumentet dhe provat e prekura. Lëvize nga "Të propozuara" / "Pyetje të hapura" te "Të pranuara". Pasqyroje në Obsidian `05 - Vendimet.md`.

Mos blloko gjithë projektin nga një pyetje që prek vetëm një hap të mëvonshëm. Mos krijo rezultate të supozuara testesh ndërsa një vendim mbetet i hapur.
