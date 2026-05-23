# mGraph Evaluation

## Kurzfazit

PlotGraphviz sollte mGraph aktuell nicht als Grundlage oder harte Abhaengigkeit
uebernehmen. Der reine Julia-Pfad ueber `Graphs.jl`, `GraphvizGraph`, DOT und
`Graphviz_jll` ist bereits lauffaehig und deutlich einfacher in CI, Packaging
und Notebook-Nutzung abzusichern.

mGraph bleibt interessant als separates C-Projekt und spaeter eventuell als
optionales Backend. Dafuer muesste aber zuerst ein reproduzierbarer Build, eine
schmale C-ABI und ein belastbarer Nutzen gegenueber dem bestehenden
Graphviz_jll-Pfad nachgewiesen werden.

## Bewertete Optionen

### Option 1: mGraph als neue Grundlage

Nicht empfohlen.

Gruende:

- PlotGraphviz hat bereits ein internes Render-Modell mit `GraphvizGraph`.
- `Graphviz_jll` vermeidet lokale Homebrew- oder System-Graphviz-Abhaengigkeiten.
- Ein C-Backend wuerde Ownership, Speicherfreigabe, Build und CI deutlich
  komplexer machen.
- mGraph bildet aktuell nicht alle PlotGraphviz-Beduerfnisse verlustfrei ab.

### Option 2: mGraph als optionales Backend

Moeglich, aber erst spaeter.

Voraussetzungen:

- mGraph baut reproduzierbar auf macOS und Linux.
- Es gibt eine stabile C-ABI fuer Julia-`ccall`.
- Speicherbesitz ist eindeutig dokumentiert.
- Node-Namen, Edge-Attribute, Graph-Attribute und Gewichtungen bleiben erhalten.
- Ein Spike zeigt messbaren Vorteil bei Performance, Layout-Kontrolle oder
  Interop.

### Option 3: mGraph getrennt lassen

Aktuell empfohlen.

PlotGraphviz kann so den modernen Julia-Pfad fertig stabilisieren. mGraph kann
parallel reifen, ohne PlotGraphviz-API, CI und Paketinstallation zu belasten.

## Beobachtungen zu mGraph

Die lokale mGraph-Implementierung bietet bereits:

- C-Strukturen fuer `Graph`, `Node` und `Edge`.
- Property-Listen fuer Graph-, Node- und Edge-Metadaten.
- Konvertierung nach Graphviz-C-API (`Agraph_t`).
- DOT-Lesen und DOT-Schreiben.
- Rendern nach SVG und PNG ueber Graphviz.

Wichtige Einschraenkungen:

- Der Build ist aktuell nicht reproduzierbar durchgelaufen.
- Das Bazel-Setup referenziert lokal `/opt/homebrew/opt/graphviz`.
- Der Build zieht zusaetzlich `raylib`, obwohl PlotGraphviz fuer Rendering nur
  Graphviz benoetigt.
- Der Testlauf von mGraph scheiterte an einem Registry-Checksum-Problem fuer
  `raylib`.
- Node-Namen werden in der Graphviz-Konvertierung auf `n<ID>` normalisiert.
- Die Rueckkonvertierung liest numerische IDs heuristisch aus Namen.
- Subgraphen sind im C-Code noch als TODO markiert.
- Die Property-Verwaltung ist global und braucht klare Lifecycle-Regeln fuer
  eine sichere Julia-Anbindung.

## Referenzpfad in PlotGraphviz

Der aktuelle PlotGraphviz-Pfad ist:

```text
Graphs.AbstractGraph -> GraphvizGraph -> DOT -> Graphviz_jll -> SVG/PNG
```

Dieser Pfad ist fuer PlotGraphviz naheliegend, weil:

- er direkt an `Graphs.jl` anschliesst,
- er ohne C-FFI im Public API auskommt,
- er in Julia-Paketen einfacher testbar ist,
- er Notebook-Ausgabe ueber `show(::MIME"image/svg+xml", ...)` unterstuetzt,
- er keine lokale Graphviz-Installation voraussetzt.

Ein lokaler Smoke-Test mit `savefig(..., g)` fuer einen kleinen
`SimpleDiGraph` konnte SVG erfolgreich erzeugen.

## Minimaler Spike fuer spaeter

Wenn mGraph spaeter erneut bewertet wird, sollte der Spike bewusst klein
bleiben:

1. In mGraph eine schmale C-ABI bereitstellen:
   - Graph erzeugen und freigeben.
   - Nodes und Edges hinzufuegen.
   - Attribute setzen.
   - SVG in Datei oder Speicher rendern.
2. mGraph als Shared Library reproduzierbar bauen.
3. In PlotGraphviz nur einen nicht exportierten Julia-Prototyp mit `ccall`
   anlegen.
4. Einen Graphen mit drei Knoten und zwei Kanten rendern.
5. Ergebnis mit `to_dot` und `savefig` des reinen Julia-Pfads vergleichen.
6. Build-Aufwand, Laufzeit, Attribute-Treue und Wartungskosten dokumentieren.

## Akzeptanzkriterien

Diese Evaluation ist abgeschlossen, wenn:

- keine produktive PlotGraphviz-API auf mGraph umgestellt wurde,
- keine neue harte C-Abhaengigkeit eingefuehrt wurde,
- die Entscheidung dokumentiert ist,
- die Risiken fuer FFI, Build und CI benannt sind,
- die Bedingungen fuer einen spaeteren optionalen Backend-Spike klar sind.

## Empfehlung

mGraph sollte derzeit nicht die Grundlage fuer PlotGraphviz werden.

Der naechste sinnvolle Schritt bleibt, PlotGraphviz auf dem bestehenden
Julia/Graphviz_jll-Kern weiter zu verbessern. mGraph kann parallel als separates
Projekt stabilisiert werden. Erst wenn mGraph reproduzierbar baut und ein
kleiner FFI-Spike einen konkreten Vorteil zeigt, lohnt sich eine optionale
Backend-Schicht in PlotGraphviz.
