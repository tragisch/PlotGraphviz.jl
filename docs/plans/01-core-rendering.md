# Core Rendering Stabilisieren

## Ziel

Der moderne Kern von PlotGraphviz soll stabil und klein sein: ein `Graphs.AbstractGraph` wird in ein `GraphvizGraph`-Objekt uebersetzt, daraus wird DOT erzeugt, und Graphviz rendert ueber `Graphviz_jll` SVG oder PNG. Dieser Pfad ist die Grundlage fuer Jupyter, VS Code, Pluto und normale Julia-Displays.

## Änderungen

- `GraphvizGraph` bleibt das primaere interne Render-Modell fuer neue Funktionen.
- `Base.show(io, MIME("image/svg+xml"), graph::GraphvizGraph)` ist der Standardpfad fuer Notebook- und Rich-Display-Ausgabe.
- `Base.show(io, MIME("image/png"), graph::GraphvizGraph)` wird als optionaler Dateiformatpfad abgesichert.
- `plot_graphviz(::Graphs.AbstractGraph)` bleibt nur ein Convenience-Wrapper, der intern `GraphvizGraph` erzeugt und dann `display` nutzt.
- Knoten und Kanten werden ausschliesslich ueber `Graphs.nv`, `Graphs.edges`, `Graphs.src` und `Graphs.dst` ausgelesen.
- Gewichtete Graphen beziehen Labels aus `Graphs.weights(g)` oder aus den bekannten `SimpleWeightedGraphs`-Feldern, ohne Phantom-Kanten bei Gewicht `0` zu erzeugen.
- `run_graphviz` nutzt die `Graphviz_jll`-Wrapper als `Cmd` mit gesetzter Umgebung, nicht nur den rohen Binary-Pfad.

## Tests

- Einfacher ungerichteter Graph mit zwei Kanten: DOT enthaelt nur diese zwei Kanten.
- Einfacher gerichteter Graph: DOT nutzt `->` und erhaelt die Richtung.
- Gewichteter Graph: DOT enthaelt `xlabel` fuer vorhandene Kanten.
- Gewicht `0` erzeugt keine Kante.
- `sprint(show, MIME("image/svg+xml"), graphviz_graph)` enthaelt `<svg`.
- PNG-Show-Methode schreibt nicht-leere Bytes.

## Abnahmekriterien

- `Pkg.test()` laeuft lokal durch.
- Ein `SimpleGraph`, `SimpleDiGraph`, `SimpleWeightedGraph` und `SimpleWeightedDiGraph` kann ohne Legacy-Attribute gerendert werden.
- Der neue Kern benoetigt keine direkte Abhaengigkeit zu `ShowGraphviz`.
- Fehler von `dot`, `neato` oder anderen Graphviz-Programmen werden als Julia-Prozessfehler sichtbar und nicht still verschluckt.

## Annahmen

- `Graphviz_jll` ist die Standard-Graphviz-Quelle.
- Systemweit installiertes Graphviz ist kein notwendiger Fallback fuer den Kern.
- Vertex-IDs aus `Graphs.jl` werden zunaechst als String-Repräsentation in DOT geschrieben.
