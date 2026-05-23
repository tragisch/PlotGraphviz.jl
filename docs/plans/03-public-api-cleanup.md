# Public API Aufraeumen

## Ziel

PlotGraphviz soll eine klare, kleine und moderne oeffentliche API bekommen. Die wichtigsten Nutzeraktionen sind: Graph in internes Graphviz-Modell uebersetzen, DOT erzeugen, anzeigen und in eine Datei schreiben.

## Änderungen

- Neue Hauptfunktionen festlegen: `to_graphviz`, `to_dot`, `plot_graphviz` und `savefig`.
- `to_graphviz(graph)` liefert ein `GraphvizGraph`.
- `to_dot(x)` liefert einen DOT-String fuer `Graphs.AbstractGraph` oder `GraphvizGraph`.
- `plot_graphviz(x)` bleibt Notebook-freundlich und zeigt das reichste verfuegbare Format an.
- `savefig(filename, x; format=nothing, prog="dot")` rendert in eine Datei; das Format wird aus der Endung abgeleitet, wenn nicht explizit gesetzt.
- Die Exportliste in `src/PlotGraphviz.jl` wird auf stabile API-Symbole reduziert.
- Interne Typen werden nur exportiert, wenn sie bewusst Teil der Erweiterungs-API sind.
- Alte oder uneindeutige Namen bekommen Deprecation-Warnungen, bevor sie entfernt werden.

## Tests

- Smoke-Tests fuer `to_graphviz`, `to_dot`, `plot_graphviz` und `savefig`.
- `@test isdefined(PlotGraphviz, Symbol(...))` nur fuer gewuenschte Exporte.
- `to_dot` enthaelt erwartete Knoten, Kanten und Attribute.
- `savefig` schreibt SVG und PNG in temporaere Dateien.
- Kein Test laedt oder benoetigt `ShowGraphviz`.

## Abnahmekriterien

- README kann mit der neuen API erklaert werden, ohne Legacy-Beispiele als Einstieg zu brauchen.
- Oeffentliche Namen sind konsistent und dokumentierbar.
- Alte Namen funktionieren noch oder geben klare Deprecation-Hinweise.
- Die API ist klein genug, dass ein Nutzer sie in wenigen Beispielen versteht.

## Annahmen

- `plot_graphviz` bleibt aus Kompatibilitaetsgruenden erhalten.
- `savefig` darf denselben Namen wie bekannte Julia-Plotting-Konventionen verwenden, ohne von Plots.jl abzuhaengen.
- Deprecations werden erst nach Tests eingefuehrt, nicht gleichzeitig mit groesseren Verhaltensaenderungen.
