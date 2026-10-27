# Ponytail në Shiny App

## Burimi

- Projekti: [DietrichGebert/ponytail](https://github.com/DietrichGebert/ponytail).
- Kopja lokale: [references/ponytail/SKILL.md](references/ponytail/SKILL.md), me [licencën MIT](references/ponytail/LICENSE).
- Versioni: commit `e3ba2aa6f1e6f0bc4d69eb09c9f0d0a93af56156` (kopjuar nga projekti beach_works, ku u mor më 2026-09-28).

Përfshihet vetëm dokumenti i skill-it dhe licenca. Nuk janë instaluar hooks, komanda slash apo plugin-e. Mos pretendo se ekziston komanda `/ponytail` vetëm nga prania e kësaj kopjeje.

## Zbatimi në këtë projekt

Për kodimin përdor Ponytail me nivelin **full**, me përparësi të kërkesave të përdoruesit. Shkallët e "ladder"-it përkthehen kështu:

1. **A duhet të ekzistojë?** Nëse nuk e kërkon SPEC.md, ISSUES.md ose një vendim, nuk shtohet.
2. **Ekziston tashmë në projekt?** Ripërdor funksionet ekzistuese (`parse_time_safe`, `to_numeric_safe`, `validate_ts_ready`…) para se të shkruash të reja.
3. **R bazë / `stats`?** Përdore.
4. **Shiny e ka?** `bindCache`, `bindEvent`, `validate(need())`, `moduleServer`, `addResourcePath` para kodit të shkruar me dorë.
5. **Paketë e instaluar tashmë?** `forecast`, `tseries`, `plotly`, `DT`, `jsonlite`, `zoo`, `cachem` (vjen me Shiny). Asnjë paketë e re pa vendim.
6. **Një rresht?** Një rresht.
7. **Vetëm atëherë:** minimumi që punon.

**Bug = shkaku rrënjë.** Para se të ndryshosh një funksion, kërko çdo vend ku thirret. P-02 dhe P-03 janë pikërisht rasti i kundërt: e njëjta logjikë e kopjuar 8 dhe 6 herë.

## Çfarë Ponytail NUK lejon këtu

- Mos thjeshto validimin e serive kohore, kufijtë minimalë apo mesazhet e gabimit.
- Mos hiq validimin e ngarkimeve (ext, MIME, magic bytes, madhësia, shtigjet).
- Mos hiq testet që mbrojnë rezultatet statistike apo krahasimin me referencën.
- Mos hiq kopjet rezervë dhe migrimin e të dhënave të përdoruesit.
- Mos shkurto dokumentimin që përdoruesi e ka kërkuar.
- Mos hiq një veçori ekzistuese (SPEC.md, "E") me arsyen që "është e thjeshtë".

## Raste konkrete

- Mos shto golem, rhino, `box` apo framework tjetër (V-03).
- Mos shto server, databazë apo sistem përdoruesish (V-02).
- Mos shkruaj cache me dorë kur `bindCache` / `cachem` e bëjnë.
- Mos krijo abstraksione për "faqe të ardhshme". Një modul për faqe, aq sa duhet.
- Mos shto paketë për gjëra që R bazë i bën në pak rreshta.

Një kompromis i qëllimshëm regjistrohet me koment `# ponytail:` që tregon kufirin dhe kur rishikohet. Ai nuk mund të cenojë një kërkesë të konfirmuar.
