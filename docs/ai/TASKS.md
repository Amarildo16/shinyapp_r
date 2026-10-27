# Hapat dhe gjurmimi i kërkesave

Më 2026-10-27 u krye analiza, u hartua plani dhe u mbyllën të gjitha vendimet (V-01 – V-12). Faza 0 u autorizua ("vazhdo") dhe u zbatua më 2026-10-27. Çdo fazë tjetër nis vetëm pas "vazhdo" të përdoruesit.

| Faza | Dokumenti | Varet nga | Kërkesat | Problemet | Statusi |
|---|---|---|---|---|---|
| 00 | [Përgatitja](steps/00-pergatitja.md) | — | R21, R24, R25 | U-03, U-06 | Në punë (mbetet vetëm Q01: pret vendimin e përdoruesit) |
| 01 | [Pastrimi](steps/01-pastrimi.md) | 00 | R03, R20 | D-01–D-04 | I pafilluar |
| 02 | [Logjika e pastër → `R/` + testet](steps/02-logjika-ne-R.md) | 01 | R05, R08, R15, R21, R22 | P-01, P-02, P-03, B-01, D-05 | I pafilluar |
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
| 00 | Në punë (Q01) | `.gitattributes`, `.gitignore`, `install_packages.R`, `renv.lock`, `.Rprofile`, `renv/activate.R`, `renv/settings.json`, `tests/reference/compute_results.R`, `make_reference.R`, `compare_reference.R`, `tests/reference/*.rds` | Claude, 2026-10-27, R 4.6.1 lokal: `renv::status()` pastër; `make_reference.R` OK nga `976dce0`; Q30 `compare_reference.R` 24/24 OK; prova negative të krahasuesit OK; UI = referenca (browser); 15 screenshot-e "para" në Obsidian; R03 pa kërkesa jashtë localhost. **Q01 jo plotësisht:** warning-e B-11 dhe errore në browser B-12, nga kodi ekzistues. |

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
