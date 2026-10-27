# Plani i verifikimit

## Rregullat

- Verifiko **sjelljen dhe rezultatet**, jo vetëm strukturën e kodit. Një test që thjesht përsërit kodin nuk është provë.
- **Mos raporto si të kaluar një kontroll që nuk u ekzekutua.** Nëse mjeti mungon, regjistro çfarë nuk u verifikua; mos e zëvendëso rezultatin me supozim.
- Në raport dallo gjithmonë:
  - **"Kodi u shkrua"**: pa ekzekutim.
  - **"Testet kaluan"**: thuaj ku u ekzekutuan dhe nga kush.
  - **"U provua në browser"**: app-i u nis dhe u klikua.
  - **"U provua nga përdoruesi në RStudio"**: rezultati i raportuar nga përdoruesi.
- Mos përsërit kontrolle të kaluara pa ndryshim ose shqetësim të ri.
- Dokumentimi pa ndryshim kodi nuk kërkon nisjen e app-it.

## Mjedisi i verifikimit

Gjendja e verifikuar më 2026-10-27:
- **Rruga 0 funksionon.** Claude Code në Windows-in e përdoruesit ekzekuton R 4.6.1 me rrugë të plotë: `"C:\Program Files\R\R-4.6.1\bin\Rscript.exe"` (`Rscript` nuk është në PATH). Nga rrënja e projektit, `.Rprofile` aktivizon `renv`, pra përdoren paketat e `renv.lock`.
- R **nuk** është i instalueshëm në workspace-in cloud të Claude-it (`apt` pa `r-base-core`, CRAN 403) as në VM-në e kompjuterit të përdoruesit (Ubuntu pa R, CRAN 403). Rrugët 2 dhe conda-forge nuk nevojiten më.
- R dhe RStudio janë në Windows-in e përdoruesit, ku zysha e nis app-in.
- Për prova me browser, Claude e nis app-in nga një kopje e projektit (T-04) dhe përdor Playwright. Playwright shkruan vetëm brenda projektit (`.playwright-mcp/`); artefaktet zhvendosen jashtë repo-s pas provës.

Rrugët, sipas radhës së preferencës:
0. **Claude Code lokalisht në Windows-in e përdoruesit.** Nëse `Rscript` është i arritshëm nga terminali, Claude Code ekzekuton vetë testet, referencën dhe nisjen e app-it, me paketat e `renv.lock`. Kjo është rruga më e mirë; kontrollohet në fillim të çdo sesioni (`Rscript --version`). Instalimet globale në kompjuterin e përdoruesit nuk bëhen pa leje.
1. **Përdoruesi në RStudio** ekzekuton komandat më poshtë dhe ngjit rezultatin në bisedë. Kjo është e vetmja rrugë që përdor saktësisht paketat e `renv.lock`.
2. **R nga conda-forge në workspace-in cloud** (nëse funksionon në Fazën 0), vetëm për testet e funksioneve të pastra. Versionet e paketave mund të ndryshojnë nga `renv.lock`: krahasimi me referencën vlen vetëm nga rruga 1.
3. **Browser-i i integruar** mbi app-in që përdoruesi e ka nisur (`http://127.0.0.1:<port>`), për kontroll vizual dhe klikime. Kërkon që përdoruesi të nisë app-in.

Pa asnjë nga këto, Claude kontrollon vetëm statikisht (lexim, balancim kllapash, kërkim referencash) dhe e thotë qartë.

### Testet (që nga Faza 2)

- `tests/testthat/helper-app.R` ngarkon `R/` me `shiny::loadSupport()` dhe e drejton `APP_DIR` te një sandbox i përkohshëm. `fixture("emri.csv")` jep rrugën e një fixture-i.
- Kur dështon një test, `testthat` 3.3 krijon `tests/testthat/_problems/` (në `.gitignore`).
- Nga Claude Code: `"C:\Program Files\R\R-4.6.1\bin\Rscript.exe" -e "testthat::test_dir('tests/testthat')"` nga rrënja e projektit.

### Komandat (nga rrënja e projektit, në RStudio)

```r
renv::restore()                                   # paketat sipas renv.lock
testthat::test_dir("tests/testthat")              # testet e funksioneve
source("tests/reference/compare_reference.R")     # krahasimi me referencën
shiny::runApp()                                   # nisja e app-it
```

## Referenca dhe tolerancat (V-07)

- Referenca krijohet **një herë**, në Fazën 0, nga kodi i `main` (`976dce0`), në kompjuterin e përdoruesit me paketat e `renv.lock`. Ruhet te `tests/reference/*.rds` dhe nuk rigjenerohet për ta bërë një test të kalojë.
- **Tolerancat:**
  - Statistikat deterministe (mesatare, sd, min/max, korrelacion, regresion, diferencë, ACF/PACF, ADF): `all.equal(..., tolerance = 1e-10)`.
  - Modelet: forma identike (rendi ARIMA, lloji ETS). Koeficientët, parashikimet, intervalet dhe saktësia: `tolerance = 1e-8`.
- Një ndryshim i qëllimshëm (p.sh. rregullim bug-u që prek vlerat) bëhet vetëm me vendim te DECISIONS.md, me vlerat para/pas. Vetëm atëherë përditësohet referenca, me shënim në STATUS.md.
- Formatimi (B-01) ndryshon **paraqitjen**, jo vlerat. Testet e formatimit janë të ndara nga testet e vlerave.
- **Struktura** (Faza 0): `compute_results.R` kthen `deterministic` (1e-10), `models$forms` (`identical`) dhe `models$values` (1e-8). `compare_reference.R` raporton OK/FAIL për çdo pjesë dhe ndalon me error nëse një pjesë del jashtë tolerancës. Referenca u krijua më 2026-10-27 nga `976dce0`, me R 4.6.1 dhe paketat e `renv.lock`.
- `all.equal` mat diferencën mesatare relative të çdo vektori. Kjo është toleranca e kërkuar; mos e zëvendëso me krahasim element pas elementi pa vendim.

## Dataset-et e testeve (`tests/fixtures/`)

Vjetor i plotë · mujor i plotë · tremujor `2020Q1` · mujor me një muaj që mungon · data të dyfishta · `;` + presje dhjetore · seri konstante · seri e shkurtër (< 20) · kolona tekst jo-numerike · file bosh / vetëm header.

Asnjë test nuk përdor të dhënat reale të përdoruesit te `storage/`.

## Skenarët

| ID | Skenari | Rezultati i kërkuar |
|---|---|---|
| Q01 | Nisja me "Run App" | Pa errore dhe pa warning në console. **Fazat 0–4 (V-13):** pa errore R; lejohen vetëm B-11 (warning-et `ggplot2 aes(text)` dhe `adf.test` "p-value smaller…") dhe B-12 (erroret e progresit te `model_plot` në browser). Çdo tjetër = dështim. Nga Faza 5: pa përjashtime, përveç **B-16** (FilePond gjatë Upload-it: `404 /[object Object]` + warning-u `updatefiles`), i lejuar deri në mbylljen e Fazës 7 (V-16). |
| Q02 | `storage/` bosh (klon i ri) | Shembujt kopjohen; app-i hapet me dataset aktiv. |
| Q03 | Migrim nga struktura e vjetër (`data/*.csv` + JSON) | Dataset-et dhe konfigurimet ruhen; ka kopje rezervë; origjinalet mbeten të paprekura. |
| Q04 | Aktivizim i një dataset-i tjetër | Të gjitha faqet përditësohen **një herë** (pa render të dyfishtë). Mënyra (V-15 d): numërohen ngjarjet `shiny:value`/`shiny:error` për çdo output në browser, pas aktivizimit nga Settings dhe vizitës së çdo faqeje. |
| Q05 | Edit: ndryshim serish / kolone kohe | Pasqyrohet kudo; ruhet pas rinisjes. |
| Q06 | Upload CSV `,` dhe CSV `;` me presje dhjetore; emër ekzistues | Lexohen saktë; emri merr timestamp; asgjë nuk mbishkruhet. |
| Q07 | Upload i pavlefshëm (jo-CSV, bosh, vetëm header) | Mesazh i qartë; asgjë nuk ruhet. |
| Q08 | Fshirje e dataset-it aktiv; fshirje e të fundit | Kalon te tjetri; pa dataset → mesazh + Settings. |
| Q09 | Përmbledhje | 4 tabelat të mbushura; numrat me format të saktë (B-01); kërkimi/faqosja e tabelës punojnë. |
| Q10 | EDA – Seri kohore, ndërrim serie | Kufijtë e slider-it rillogariten (B-02); mesatarja lëvizëse = referenca. |
| Q11 | EDA – Marrëdhënie | Regresioni dhe korrelacioni = referenca; < 2 seri → mesazh. |
| Q12 | Stacionariteti | Diferenca, ACF/PACF, ADF = referenca; interpretimi i saktë; < 20 pika → mesazh. |
| Q13 | Modelimi | ETS/ARIMA = referenca; ndryshimi i horizontit nuk e rillogarit modelin. |
| Q14 | Parashikimi SES/Holt/ARIMA | = referenca; intervali i shfaqur; ngjyra të dallueshme (B-04); hover i saktë edhe kur h = n (B-05). |
| Q15 | Seri me periudhë që mungon | EDA punon; analizat statistike japin mesazh të qartë. |
| Q16 | Data të dyfishta | Mesatarja sipas politikës; asnjë crash. |
| Q17 | Tremujor `2020Q1`, vjetor numerik | Frekuenca e saktë; njësia e saktë në etiketat e slider-ave. |
| Q18 | Seri konstante | Mesazh i qartë; asnjë crash. |
| Q19 | Lëvizje e shpejtë e slider-ave dhe ndërrim faqesh | Asnjë njoftim i përsëritur (B-06); asnjë error. |
| Q20 | Background: ngjyrë → Save → rinisje | Ngjyra ruhet. |
| Q21 | Foto globale dhe për faqe, blur, Save, rinisje | Crossfade kur ndërrohet faqja; gjithçka ruhet. |
| Q22 | Media Library: ngarkim JPG/PNG/WEBP; > 5 MB; file i rremë; emër me `'` | Të vlefshmet ngarkohen; të pavlefshmet refuzohen me mesazh; emri me `'` punon (B-08). |
| Q23 | Fshirje e fotos në përdorim / të lirë | E para bllokohet; e dyta fshihet. |
| Q24 | Sidebar dhe mobile (≤ 780 px) | Hap/mbyll, Escape, butoni aktiv; layout pa tejkalime. |
| Q25 | Pa internet | App-i punon plotësisht; asnjë kërkesë rrjeti. |
| Q26 | Ndryshime të shpejta | Preloader-i nuk shfaqet për to (B-10); shfaqet për llogaritje të gjata. |
| Q27 | Krahasim me screenshot-et "para" | Pa regresione vizuale të pavendosura. |
| Q28 | `renv::restore()` në mjedis të pastër | App-i niset. |
| Q29 | `testthat::test_dir("tests/testthat")` | Të gjitha kalojnë. |
| Q30 | `compare_reference.R` për të dy dataset-et shembull | Të gjitha brenda tolerancave. |
| Q31 | Ndërrim gjuhe shqip ↔ anglisht në Settings; rinisje | Çdo tekst i dukshëm (menyja, faqet, grafikët, tabelat, modalet, mesazhet, ADF) del në gjuhën e zgjedhur; numrat sipas gjuhës; zgjedhja ruhet; dataset-i aktiv dhe background-i nuk ndryshojnë. |
| Q32 | `test-i18n.R` | `sq.json` dhe `en.json` kanë të njëjtët çelësa, asnjë vlerë bosh; nuk ka tekst të dukshëm jashtë `tr()` (kontroll me kërkim). |

## Smoke test pas çdo faze

Minimumi: Q01, Q04, Q09–Q14 (me të dy dataset-et), Q20, Q24, Q29, Q30 kur preket logjika llogaritëse, dhe Q31/Q32 nga Faza 03 e tutje. Nëse një skenar nuk mund të ekzekutohet, shënohet si "i paprovuar" me shkakun.

## Prova e pranimit

Për çdo fazë regjistro te STATUS.md:
- mjedisin dhe datën
- commit-in bazë, nëse ekziston
- skenarët e ekzekutuar dhe kush i ekzekutoi
- rezultatet dhe mangësitë

Një provë e dështuar mbetet e hapur deri në zgjidhje ose ndryshim të shprehur të fushës nga përdoruesi.
