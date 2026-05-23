# Legacy API Adaptieren

## Ziel

Die alten PlotGraphviz-APIs sollen weiter lauffaehig bleiben, aber nicht mehr die Architektur bestimmen. Bestehender Code mit `GraphvizAttributes`, `Property`, `gvNode`, `gvEdge`, `plot_graphviz(g, attrs)`, `read_dot_file` und `write_dot_file` soll erhalten bleiben, waehrend neue Entwicklung auf den modernen `GraphvizGraph`-Kern geht.

## Änderungen

- `GraphvizAttributes`, `Property`, `gvNode` und `gvEdge` werden als Legacy-Schicht behandelt.
- Legacy-Attribute werden in `GraphvizGraph`-Attribute uebersetzt, bevor gerendert wird.
- `plot_graphviz(g, attrs)` nutzt intern denselben Graphviz-Renderpfad wie `plot_graphviz(::Graphs.AbstractGraph)`.
- `write_dot_file` erzeugt weiterhin DOT-Dateien, soll aber dieselbe Kantenlogik wie der moderne Kern verwenden.
- `read_dot_file` bleibt zunaechst ParserCombinator-basiert und wird mit Tests gegen vorhandene Testdaten abgesichert.
- Fragile Vorverarbeitungs-Heuristiken fuer DOT werden in einer klar benannten internen Funktion isoliert und kommentiert.
- Keine neuen Features werden in die Legacy-Strukturen eingebaut; neue Features entstehen nur im modernen Kern.

## Tests

- README-Beispiele mit `GraphvizAttributes` laufen ohne MethodErrors.
- `read_dot_file("test/data/directed/clust4.gv")` liefert einen gerichteten gewichteten Graphen und Attribute.
- `write_dot_file` erzeugt DOT, das sich ueber `Graphviz_jll.dot()` als SVG rendern laesst.
- Legacy- und neuer Pfad erzeugen bei einfachen Graphen dieselben Kanten.
- Node-, Edge- und Graph-Attribute aus der Legacy-Schicht erscheinen in der DOT-Ausgabe.

## Abnahmekriterien

- Bestehender Nutzer-Code mit dokumentierter Legacy-API bricht nicht.
- Die Legacy-Schicht ruft keine entfernten oder unexportierten alten ShowGraphviz-Pfade mehr auf.
- Import und Export sind voneinander testbar.
- Der Code trennt klar zwischen Legacy-Datenmodell und modernem Render-Modell.

## Annahmen

- Vollstaendige DOT-Sprachkompatibilitaet ist nicht Ziel dieses Arbeitspakets.
- ParserCombinator bleibt vorerst erhalten, bis ein separater Import-Plan umgesetzt wird.
- Legacy-Kompatibilitaet ist wichtiger als perfekte interne Eleganz.
