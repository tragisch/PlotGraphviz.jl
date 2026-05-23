# mGraph Evaluation

## Ziel

Nach Stabilisierung der Julia-API soll entschieden werden, ob `mGraph` eine sinnvolle Grundlage fuer PlotGraphviz ist. Dieses Arbeitspaket trifft eine technische Empfehlung; es baut noch kein produktives mGraph-Backend ein.

## Änderungen

- Bewertungskriterien definieren: Nutzen, Wartungskosten, FFI-Komplexitaet, Performance, Layout-Kontrolle und Build-Aufwand.
- Lokale mGraph-Schnittstellen fuer Graphstruktur, Attribute und Graphviz-C-API-Interop inspizieren.
- Einen minimalen Spike planen: Julia-Graph -> mGraph -> Graphviz SVG fuer einen kleinen Graphen.
- Ergebnisse mit dem reinen Julia-/`Graphviz_jll`-Pfad vergleichen.
- Drei Entscheidungsoptionen dokumentieren: mGraph uebernehmen, als optionales Backend fuehren oder getrennt lassen.
- Keine harte C-Abhaengigkeit in PlotGraphviz einfuehren, bevor der Nutzen belegt ist.

## Tests

- Spike rendert denselben einfachen Graphen wie der reine Julia-Pfad.
- Build-Schritte auf macOS sind dokumentiert und reproduzierbar.
- Minimaler FFI-Prototyp gibt Speicher korrekt frei.
- Vergleich misst mindestens Render-Erfolg, benoetigte Abhaengigkeiten und API-Komplexitaet.

## Abnahmekriterien

- Es liegt eine klare Empfehlung vor: uebernehmen, optionales Backend oder getrennt lassen.
- Die Empfehlung nennt konkrete Gruende und Risiken.
- Der Spike veraendert die produktive PlotGraphviz-API nicht.
- Kein produktiver Code haengt von mGraph ab, solange die Entscheidung offen ist.

## Annahmen

- mGraph bleibt ein separates C-Projekt, bis ein messbarer Vorteil nachgewiesen ist.
- Fuer Jupyter-Darstellung ist der reine Julia-/`Graphviz_jll`-Pfad der Referenzpfad.
- mGraph wird vor allem wegen C-Interop, Agraph-Roundtrip oder gemeinsamer Graph-Infrastruktur geprueft.
