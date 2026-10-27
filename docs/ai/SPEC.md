# Specifikimi i Shiny App (Time Series Analysis)

## Qëllimi dhe realiteti i përdorimit

App Shiny për mësimin e analizës së serive kohore. U ndërtua si projekt shkollor nga Amarildo Alla: fillimisht statik, pastaj dinamik me ngarkim dataset-esh me kërkesë të zyshës. Tani zysha e përdor në leksione në klasa të tjera.

Zysha e hap projektin në RStudio dhe e nis manualisht ("Run App") në kompjuterin e saj. Ngarkon CSV-të e saj, zgjedh seritë dhe kalon nëpër faqet e analizës para studentëve.

Ky version ("ultimate_version") **nuk shton analiza të reja**. Qëllimi është ristrukturimi i plotë: kod modular, i testuar, pa bug-et e njohura, me të njëjtat rezultate statistike dhe të njëjtën përvojë për përdoruesin.

## Kërkesat e konfirmuara

Burimi: **E** = sjellje ekzistuese që duhet ruajtur · **B** = biseda me përdoruesin, 2026-10-27

| ID | Burimi | Kërkesa |
|---|---|---|
| R01 | B | App-i mbetet në **R + Shiny**. Nuk rishkruhet në C, C++, Rust apo gjuhë tjetër (V-01). |
| R02 | B | Përdorim **single-user, lokal**: niset manualisht në RStudio. Pa login, server, databazë apo deploy (V-02). |
| R03 | E | Punon pa internet. Të gjitha asetet (CSS, JS, fonte, ikona, FilePond) janë lokale; asnjë CDN. |
| R04 | E | Ndërfaqja është në shqip (sot e përzier me anglishten). Zëvendësohet nga R26. |
| R05 | E | Ngarkim CSV nga Settings me drag-and-drop (FilePond). Zbulim automatik i delimiter-it (`,` `;` tab) dhe i formatit të numrave (`1.234,5`, `1,234.5`, negativë në kllapa). |
| R06 | E | Për çdo dataset: zgjedhja e kolonës së kohës dhe e një ose më shumë serive numerike, me parapamje të të dhënave. Konfigurimi mund të editohet më vonë. |
| R07 | E | Disa dataset-e të ruajtura, një aktiv. Aktivizim me një klik; fshirje me konfirmim. Ndryshimet pasqyrohen menjëherë në të gjitha faqet. Gjithçka ruhet pas rinisjes. |
| R08 | E | Formatet e kohës: `YYYY`, `YYYY-MM`, `YYYY-MM-DD`, `YYYYQ#`, `dd/mm/YYYY`, `dd-mm-YYYY`, `YYYY/mm/dd`, `mm/dd/YYYY`. Frekuencat: vjetore, tremujore, mujore, javore, ditore. |
| R09 | E | **Përmbledhje:** tabela e serive të zgjedhura (me kërkim dhe faqosje), përshkrimi i variablave, informacioni mbi të dhënat, statistikat përmbledhëse (mesatarja, devijimi standard, min, max, N, % që mungon). |
| R10 | E | **EDA – Seri kohore:** seria origjinale, mesatarja lëvizëse me dritare të rregullueshme, histogram + densitet. |
| R11 | E | **EDA – Marrëdhënie:** scatter X/Y me vijën e regresionit linear; matrica e korrelacionit Pearson. |
| R12 | E | **Stacionariteti:** diferenca e parë, ACF/PACF e diferencës, testi ADF për nivelin dhe diferencën, me interpretim automatik në α = 0.05. |
| R13 | E | **Modelimi:** krahasimi ETS kundrejt ARIMA (auto) me horizont të rregullueshëm; RMSE, MAE, MAPE në setin e trajnimit. |
| R14 | E | **Parashikimi:** SES, Holt ose ARIMA; horizont i rregullueshëm; intervali i pasigurisë; tabela e saktësisë (ME, MAE, RMSE, MAPE). |
| R15 | E | Analizat statistike (Stacionariteti, Modelimi, Parashikimi) kërkojnë seri të rregullt pa boshllëqe, me mesazh të qartë kur nuk plotësohet. EDA punon edhe me boshllëqe. Kufijtë minimalë: diferenca 3, ACF/PACF 6, ADF 20, ETS/ARIMA 20, ARIMA në Parashikim 30. |
| R16 | E | Kufijtë e horizontit dhe të dritares lëvizëse varen nga frekuenca dhe gjatësia e serisë; etiketa tregon njësinë (vite, muaj…). |
| R17 | E | **Background:** pa background, vetëm ngjyrë (paletë + zgjedhës), ose foto (globale ose e veçantë për çdo faqe), me blur të rregullueshëm. Ndryshimet ruhen vetëm me "Save" dhe mbeten pas rinisjes. |
| R18 | E | **Media Library:** galeri fotosh, zgjedhje, ngarkim i shumëfishtë, fshirje me konfirmim (e bllokuar nëse fotoja përdoret), heqje e fotos aktive. |
| R19 | E | Siguria e ngarkimeve: foto vetëm JPG/PNG/WEBP deri 5 MB, të verifikuara nga përmbajtja (magic bytes); emrat pastrohen; asnjë shteg nuk del jashtë folderave të lejuar. |
| R20 | E | Identiteti vizual ruhet: tema e errët "glass", sidebar me hamburger, animacioni i vizatimit të grafikëve, preloader, footer-i "By Amarildo Alla" me lidhjet sociale. Përshtatet për ekrane të vogla. |
| R21 | B | Ristrukturimi **nuk ndryshon asnjë rezultat statistik** pa vendim të regjistruar (V-07). |
| R22 | B | Struktura modulare sipas ARCHITECTURE.md: `R/` + module Shiny, jo 3 file monolitike (V-03). |
| R23 | B | Të dhënat e përdoruesit ndahen nga kodi (`storage/`) dhe nuk humbin kurrë; migrim automatik nga struktura e vjetër (V-05). |
| R24 | B | Versionet e paketave fiksohen me `renv` (V-06). |
| R25 | B | Asnjë pikë e detyrës nuk anashkalohet në heshtje ose shpallet e kryer pa provë. Puna dokumentohet në `docs/ai` dhe Obsidian. |
| R26 | B | **UI dygjuhëshe: shqip (e paracaktuar) dhe anglisht.** Gjuha zgjidhet në Settings, ruhet pas rinisjes dhe përkthen çdo tekst të dukshëm, përfshirë grafikët, tabelat, mesazhet dhe interpretimin e ADF. Formati i numrave ndjek gjuhën. Detajet te V-09. |

## Përvoja e përdorimit (që duhet ruajtur)

### Hapja
App-i hapet te "Përmbledhje" me dataset-in aktiv. Pa asnjë dataset, shfaqet mesazh dhe hapet Settings. Preloader-i shfaqet gjatë llogaritjeve.

### Settings → Dataset
Kartat e dataset-eve në dy kolona, me pikën e aktivit, emrin, shenjën "Aktiv", butonin e editimit dhe të fshirjes. "Ngarko CSV" hap modalin e vogël me FilePond; "Proceed" hap modalin e konfigurimit me parapamje (deri 200 rreshta).

### Faqet e analizës
Çdo faqe ka panel majtas me zgjedhjet (seria, X/Y, dritarja, horizonti, metoda) dhe grafikët/tabelat djathtas, secili me titull dhe shënim poshtë.

### Background
Ndryshimet pa "Save" shënohen me "Ke ndryshime pa Save". Kur ndërrohet faqja, fotoja ndërrohet me crossfade.

## Kufijtë e versionit

**Nuk janë kërkuar:**
- shumë përdorues, login, server, deploy, databazë
- paketim si app desktop
- rishkrim në gjuhë tjetër
- analiza të reja (ARMA, VAR/IRF, GARCH; shih V-10 për tekstin e Metodologjisë)
- eksport i rezultateve
- ngarkim Excel nga UI (leximi i Excel ekziston në kod si opsion, por UI pranon vetëm CSV)
- mbështetje për kolonë kohe numerike që nuk është vit (V-11); vetëm mesazh më i qartë
- gjuhë të tjera përveç shqipes dhe anglishtes
