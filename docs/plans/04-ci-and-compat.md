# CI Und Compat Modernisieren

## Ziel

PlotGraphviz soll gegen aktuelle Julia-Versionen und frische Dependency-Aufloesungen getestet werden. Lokale Artefakte und historische Notebook-Daten duerfen CI und Pakettests nicht beeinflussen.

## Änderungen

- GitHub Actions fuer Julia `1.10` LTS und aktuelle stable `1.12` einrichten.
- CI auf macOS und Linux ausfuehren, weil Graphviz-JLL-Rendering plattformrelevant ist.
- `Project.toml` compat-Eintraege pruefen und nur benoetigte direkte Abhaengigkeiten behalten.
- `Manifest.toml` bleibt fuer Paketentwicklung unversioniert; die vorhandene `.gitignore`-Regel bleibt bestehen.
- Lokale Artefakte wie `.bgai-db`, Notebooks, generierte Bilder und grosse Testdaten werden nicht Teil des Testpfads.
- Optional einen README-Smoke-Test ergaenzen, aber keine Notebook-Ausfuehrung als Pflicht-CI.

## Tests

- `Pkg.test()` aus einer frischen Registry-Aufloesung.
- CI rendert mindestens ein SVG mit `Graphviz_jll`.
- CI prueft, dass keine lokalen Cache-Verzeichnisse getrackt werden.
- Tests laufen ohne Netzwerkzugriff nach Dependency-Installation.
- `Project.toml` enthaelt keine unbenutzten direkten Dependencies.

## Abnahmekriterien

- Alle CI-Jobs laufen gruen auf Julia `1.10` und `1.12`.
- Tests bestehen lokal und in CI mit frisch erzeugtem Manifest.
- `Graphviz_jll` funktioniert in CI fuer SVG-Ausgabe.
- Neue Abhaengigkeiten werden nur eingefuehrt, wenn sie direkt im Code verwendet werden.

## Annahmen

- Julia `1.10` bleibt die unterstuetzte LTS-Untergrenze fuer moderne Arbeit.
- Julia `1.12` ist die aktuelle Stable-Zielversion.
- Eine vollstaendige Notebook-Regeneration ist ein separates Dokumentationspaket.
