# Hapat dhe gjurmimi i kërkesave

Më 2026-10-27 u krye analiza, u hartua plani dhe u mbyllën të gjitha vendimet (V-01 – V-12). Faza 0 u autorizua ("vazhdo") dhe u zbatua më 2026-10-27. Çdo fazë tjetër nis vetëm pas "vazhdo" të përdoruesit.

| Faza | Dokumenti | Varet nga | Kërkesat | Problemet | Statusi |
|---|---|---|---|---|---|
| 00 | [Përgatitja](steps/00-pergatitja.md) | — | R21, R24, R25 | U-03, U-06 | I përfunduar (2026-10-27) |
| 01 | [Pastrimi](steps/01-pastrimi.md) | 00 | R03, R20 | D-01–D-04 | I përfunduar (2026-10-27) |
| 02 | [Logjika e pastër → `R/` + testet](steps/02-logjika-ne-R.md) | 01 | R05, R08, R15, R21, R22 | P-01, P-02, P-03, B-01, D-05 | I përfunduar (2026-10-27); kopja e 6-të e P-03 → Faza 4 (V-14) |
| 03 | [Config, layout, storage, i18n](steps/03-config-layout-storage.md) | 02 | R07, R20, R22, R23, R26 | P-11, P-12, U-04 | I pafilluar |
| 04 | [Moduli i dataset-eve](steps/04-moduli-datasets.md) | 03 | R05–R07, R22 | P-05, P-06, P-08, B-03 | I pafilluar |
| 05 | [Faqet e analizës si module](steps/05-faqet-e-analizes.md) | 04 | R09–R16, R21, R26 | P-04, P-07, B-02, B-04–B-07, B-09 | I pafilluar |
| 06 | [Moduli i background-it](steps/06-moduli-background.md) | 03 | R17–R19, R23 | P-08, P-09, P-10, B-08 | I pafilluar |
| 07 | [Frontend: CSS dhe JS](steps/07-frontend.md) | 05, 06 | R03, R20 | U-05, B-10 | I pafilluar |
| 08 | [Finalizimi](steps/08-finalizimi.md) | 01–07 | R25, R26 (të gjitha) | U-01, U-02, D-04 | I pafilluar |

Statuset: **I pafilluar** · **Në punë** · **I përfunduar** (vetëm me provë) · **I bllokuar** (me shkak konkret)

Fazat ndjekin radhën e tabelës. Faza 06 varet vetëm nga 03 dhe mund të bëhet para 05 nëse përdoruesi e kërkon. Testimi bëhet gjatë çdo faze, jo vetëm në fund.

## Gjendja e zbatimit

| Faza | Statusi | Skedarët kryesorë | Provat |
|---|---|---|---|
| 00 | I përfunduar | `.gitattributes`, `.gitignore`, `install_packages.R`, `renv.lock`, `.Rprofile`, `renv/activate.R`, `renv/settings.json`, `tests/reference/compute_results.R`, `make_reference.R`, `compare_reference.R`, `tests/reference/*.rds` | Claude, 2026-10-27, R 4.6.1 lokal: `renv::status()` pastër; `make_reference.R` OK nga `976dce0`; Q30 `compare_reference.R` 24/24 OK; prova negative të krahasuesit OK; UI = referenca (browser); 15 screenshot-e "para" në Obsidian; R03 pa kërkesa jashtë localhost. Q01 kalon sipas V-13 (vetëm B-11/B-12 të njohura). Commit `531bc0c` (përdoruesi). |
| 01 | I përfunduar | `app.R`, `helpers.R`, `server_plots.R`, `README.md`, `.gitignore`, `www/vendor/remixicon/` (zhvendosur nga `www/css` + `www/fonts`); `icons.css` + 42 fonte → `_to_delete/` | Claude, 2026-10-27: parse OK; `grep` pa referenca të mbetura; Q30 24/24; browser (kopje): Q01 (V-13), Q04, Q09–Q14 me të dy dataset-et = vlerat e referencës, Q13 (h = 5 = referenca), Q14 (Holt h = 5 = referenca; ARIMA < 30 → mesazh), Q20 (ngjyrë → Save → rinisje: ruhet), Q24 (Escape; 390 px pa tejkalim), 8/8 ikonat Remix, asnjë 404/kërkesë e jashtme. Commit `069c8fc` (përdoruesi). |
| 02 | Në punë (pret vendimin për P-03 kopja 6) | `R/` (13 skedarë nga `helpers.R` + `legacy_server_plots.R`), `app.R`, `tests/testthat/` (helper + 8 skedarë testesh), `tests/fixtures/` (10 CSV), `tests/reference/compute_results.R`, `renv.lock`, `.gitignore` | Claude, 2026-10-27: 62/62 objekte identike pas lëvizjes; Q29 43 teste / 226 pritje, 0 dështime, 1 skip (B-13); Q30 24/24; P-03 10 010 kombinime dhe D-05 308 raste identike me kodin e vjetër; testi B-01 dështon mbi formatin e vjetër; browser: Q01 (V-13), Q04, Q05, Q09–Q14, Q20, Q24; `get_app_dir()` i saktë kur niset nga një folder tjetër. Pa commit. |

Kur mbaron një fazë, shto një rresht këtu me skedarët dhe provat (ID-të e testeve, skenarët Qxx, kush i ekzekutoi).

## Lista e mbylljes së një faze

- [ ] Kërkesa dhe kufijtë janë kuptuar dhe regjistruar.
- [ ] Dokumentet relevante janë lexuar; vendimet e nevojshme janë marrë dhe regjistruar.
- [ ] Çdo pikë e dokumentit të fazës është zbatuar ose shënuar si pengesë konkrete.
- [ ] Rezultatet statistike përputhen me referencën (kur preket logjika llogaritëse).
- [ ] Të dhënat e përdoruesit janë të paprekura; migrimet kanë kopje rezervë.
- [ ] Janë kryer kontrollet e QUALITY.md dhe është ruajtur evidenca (kush, ku, me çfarë rezultati).
- [ ] App-i niset dhe smoke test-i kalon.
- [ ] STATUS.md, TASKS.md, ISSUES.md janë të sakta.
- [ ] Obsidian është pasqyruar, ose pengesa është regjistruar.
- [ ] Dorëzimi nuk pretendon funksione apo prova që mungojnë; ndryshimet nuk janë bërë commit.

## Evidenca për çdo hap

Shto: statusin, skedarët që e realizojnë, ID-të e testeve ose skenarët Qxx, rezultatin, kush e ekzekutoi verifikimin (Claude / përdoruesi) dhe pikat e pambyllura. Një checkbox pa provë nuk mjafton.
