# Vendimet dhe pyetjet e hapura

Gjendja fillestare: 2026-10-27. Përditësuar: 2026-10-27 18:57 — Faza 0: vendimet teknike T-01 – T-04 dhe pyetja e hapur për Q01. Më herët (18:33): V-08 – V-12 u mbyllën; V-09 u ndryshua nga përdoruesi në UI dygjuhëshe. Përditëso datën dhe regjistro arsyen kur ndryshon një vendim. **Mos ripyet një vendim që përdoruesi e ka dhënë.**

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

## Pyetje të hapura

- **Q01 në Fazat 0–4** (2026-10-27): kodi ekzistues jep warning-e në R (B-11) dhe errore në console të browser-it (B-12), që rregullohen në Fazën 5. Propozimi: deri në Fazën 5, Q01 = "pa errore R; lejohen vetëm warning-et/erroret e njohura B-11/B-12"; Q01 i plotë nga Faza 5. Pret përgjigjen e përdoruesit.

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
