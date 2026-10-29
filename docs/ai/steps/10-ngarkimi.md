# Faza 10 — Ngarkimi i CSV-ve të mëdha (FilePond dhe kufijtë)

Statusi: **gati, pa commit** (2026-10-29, V-28; provat te STATUS "Faza 10 — rezultati"). Problemet: B-25, B-26, B-27. Vendimet: V-28. Varet nga: 09.

Kërkesa e përdoruesit (2026-10-29): CSV-të sintetike me 200 000 dhe 2 000 000 rreshta (12,2 MB dhe 122,1 MB) nuk ngarkohen dhe nuk del asnjë mesazh. Zbulimi (Claude, në një kopje): kufiri 5 MB i Shiny-t me gabimin te një element i fshehur, kufiri 25 MB i FilePond-it, FilePond-i që e shënon çdo CSV si të papranuar (B-25) dhe gjetja e kolonave që zgjat 12 s / 130 s pas "Vazhdo" (B-27).

## Veprimet

1. `UPLOAD_MAX_MB <- 150` te `R/config.R`; `options(shiny.maxRequestSize = ...)` dhe `maxFileSize` i FilePond-it nga e njëjta vlerë (V-28 a).
2. B-25: FilePond-i pranon CSV-të (tipi i pritur dhe `accept` i proxy-t përputhen); Shiny-t i kalohen vetëm skedarët që FilePond-i i pranon; mesazhi për skedarin shumë të madh në shqip/anglisht (`pond.too_large`).
3. B-26: gabimi i ngarkimit të Shiny-t ("Maximum upload size exceeded" etj.) del si njoftim.
4. B-27: kolona e kohës dhe seritë propozohen nga 5 000 rreshtat e parë (`DETECT_SAMPLE_ROWS`, V-28 d: zgjedhja e përdoruesit); për dataset-et me më pak rreshta, rezultati është i njëjtë me sot.
5. Treguesi "Duke lexuar…" gjatë leximit dhe gjetjes së kolonave (`withProgress`).
6. Testet: kufiri, mostra (e njëjtë me të gjithë dataset-in kur ka pak rreshta), tekstet e reja.

## Mos bëj

- Mos ndrysho llogaritjet e serive (`prepare_series`, `parse_time_safe`, `to_numeric_safe`): shpejtësia e tyre është pjesa e performancës (P-13).
- Mos shto kohë me orë/minuta (U-11) dhe mos ndrysho pamjen e modalit përtej treguesit (pamja e shkurtër e CSV-së vjen më vonë).
- Mos prek skedarët e përdoruesit te `Downloads`: provat bëhen me kopje jashtë repo-s.
- Asnjë ndryshim te rezultatet statistike. Mos bëj merge, tag apo push.

## Kriteret e përfundimit

- Q29 dhe Q30 kalojnë.
- Në browser, në një kopje: të dy CSV-të ngarkohen, FilePond-i nuk i shënon me të kuqe, "Vazhdo" hapet shpejt, "Ruaj" i ruan; një skedar mbi kufirin jep mesazhin në shqip; console 0.

## Dorëzimi

STATUS.md, TASKS.md, ISSUES.md, DECISIONS.md, HANDOFF.md, Obsidian.
