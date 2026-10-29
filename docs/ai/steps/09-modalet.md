# Faza 09 — Modalet

Statusi: **commit `31611de`** (2026-10-29, V-26); V-27 (U-10) gati, pa commit (provat te STATUS "Faza 9 — rezultati"). Problemet: U-09, U-10. Vendimet: V-26, V-27. Varet nga: 07, 08.

Kërkesa e përdoruesit (2026-10-29): modalet e projektit të rregullohen si sistemi i përdoruesit në Laravel (`main_modal_sm/md/lg/xl/fs`): një madhësi për çdo rast, header-i i rreshtuar, pa ndarjet që nuk i pëlqejnë. Pikat 2 (FilePond dhe CSV-të e mëdha) dhe 3 (pamja e shkurtër e CSV-së) vijnë më pas, si faza më vete.

## Veprimet

1. `glass_modal(..., size = c("sm", "md", "lg", "xl", "fs"))` te `R/ui_components.R`: klasa `glass-modal glass-modal-<size>` te `.modal`; ID-të dhe rrjedha e serverit nuk ndryshojnë (P-08).
2. CSS e përbashkët te `www/css/modals.css`, sipas klasës:
   - stili glass një herë për të gjitha;
   - header: titulli (~18 px) dhe X-i në një rresht, pa vijë poshtë;
   - footer: butonat djathtas, pa vijë sipër (V-26 b);
   - gjerësitë: `sm` 400 px, `md` 560 px, `lg` 800 px, `xl` 1140 px, `fs` ekrani i plotë me 10 px anash (si sot);
   - `sm`–`xl` në qendër të ekranit; në < 576 px çdo modal zë pothuajse gjithë ekranin, përmbajtja rrëshqet brenda, header-i dhe butonat mbeten të dukshëm;
   - hiqen selektorët pa efekt (`#csv_upload_modal`, `modal-lg`).
3. Caktimi: konfirmimet e fshirjes `sm`, ngarkimi i CSV-së `lg`, konfigurimi i dataset-it dhe Galeria `fs` (V-26 c).
4. Testet te `test-ui_components.R`.

## Mos bëj

- Mos ndrysho FilePond-in, kufijtë e ngarkimit apo rrjedhën e ngarkimit (pikat 2 dhe 3).
- Mos ndrysho mesazhet: njoftimet mbeten si sot (V-26 b).
- Asnjë ndryshim te rezultatet statistike apo te të dhënat.
- Mos bëj merge, tag apo push.

## Kriteret e përfundimit

- Q29 dhe Q30 kalojnë.
- Në browser (1440, 768, 375 px): të 5 modalet me titullin dhe X-in në një rresht, pa vijat e vjetra; rrjedhat ngarkim → Vazhdo → Ruaj, Edit, fshirja, Galeria me ngarkim; console 0.
- Krahasimi i stileve: ndryshojnë vetëm modalet.

## Dorëzimi

STATUS.md, TASKS.md, ISSUES.md, DECISIONS.md, HANDOFF.md, Obsidian (ditari, vendimet, problemet, plani, screenshot-et para/pas).
