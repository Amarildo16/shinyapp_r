# Faza 07 — Frontend: CSS dhe JS

Statusi: **i përfunduar** (2026-10-29, `16c0acb`, V-23, T-27). Kërkesat: R03, R20. Problemet: U-05, B-10, B-16 (V-16).

> [!important] Nga Faza 4
> Rregullo B-16 (FilePond: `404 /[object Object]` dhe warning-u `updatefiles` gjatë Upload-it). Me mbylljen e kësaj faze, përjashtimi V-16 te Q01 bie.

## Qëllimi

CSS dhe JS të ndara sipas përgjegjësisë, pa ndryshuar pamjen.

## Veprimet

1. Ndaj `custom-style.css` në `tokens.css`, `layout.css`, `components.css`, `modals.css`, `datatables.css`, `background.css`. Ruaj radhën e kaskadës. ✅
2. Bashko selektorët e përsëritur (`.bg-tab-card`, `.media-card`, `.bg-tabs-grid` etj.) duke ruajtur rezultatin përfundimtar të kaskadës. ✅ (20 rregulla)
3. Ul `!important` aty ku nuk mbishkruan Bootstrap/DataTables (U-05). ✅ (135 → 68)
4. Ndaj `custom.js` në `preloader.js`, `filepond-bridge.js`, `modals.js`, `color-picker.js`. ✅
5. Preloader-i shfaqet vetëm pas ~400 ms busy (B-10). ✅
6. Verifiko që asnjë aset nuk kërkohet nga interneti (R03). ✅

7. Tekstet në JS (p.sh. FilePond: "Drop files here…", "Ky fajll s'pranohet") vijnë nga R sipas gjuhës, jo të shkruara direkt (R26). ✅ (V-23 b)
## Mos bëj

- Mos ndrysho ngjyrat, hapësirat, fontet apo animacionet pa vendim.

## Kriteret e përfundimit

- Q24–Q27 kalojnë, në desktop dhe në mobile (≤ 780 px).
- Smoke test-i kalon.

## Dorëzimi

STATUS.md, TASKS.md, ISSUES.md, Obsidian. Commit i sugjeruar: `refactor(faza-7): ndarja e CSS dhe JS`.
