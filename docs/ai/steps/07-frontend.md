# Faza 07 — Frontend: CSS dhe JS

Statusi: **i pafilluar**. Kërkesat: R03, R20. Problemet: U-05, B-10.

## Qëllimi

CSS dhe JS të ndara sipas përgjegjësisë, pa ndryshuar pamjen.

## Veprimet

1. Ndaj `custom-style.css` në `tokens.css`, `layout.css`, `components.css`, `modals.css`, `datatables.css`, `background.css`. Ruaj radhën e kaskadës.
2. Bashko selektorët e përsëritur (`.bg-tab-card`, `.media-card`, `.bg-tabs-grid` etj.) duke ruajtur rezultatin përfundimtar të kaskadës.
3. Ul `!important` aty ku nuk mbishkruan Bootstrap/DataTables (U-05).
4. Ndaj `custom.js` në `preloader.js`, `filepond-bridge.js`, `modals.js`, `color-picker.js`.
5. Preloader-i shfaqet vetëm pas ~400 ms busy (B-10).
6. Verifiko që asnjë aset nuk kërkohet nga interneti (R03).

7. Tekstet në JS (p.sh. FilePond: "Drop files here…", "Ky fajll s'pranohet") vijnë nga R sipas gjuhës, jo të shkruara direkt (R26).
## Mos bëj

- Mos ndrysho ngjyrat, hapësirat, fontet apo animacionet pa vendim.

## Kriteret e përfundimit

- Q24–Q27 kalojnë, në desktop dhe në mobile (≤ 780 px).
- Smoke test-i kalon.

## Dorëzimi

STATUS.md, TASKS.md, ISSUES.md, Obsidian. Commit i sugjeruar: `refactor(faza-7): ndarja e CSS dhe JS`.
