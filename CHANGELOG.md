# Changelog

All notable changes to this project will be documented in this file.

## [Unreleased]

### Added
- Interoperability adapters between DOT/PlotGraphviz attributes and Julia graph ecosystems:
  - `to_weighted_graph`
  - `apply_edge_weights`
  - `read_dot_file_weighted`
  - `to_metagraph`
  - `from_metagraph`
- `MetaGraphsNext.jl` integration support for metadata roundtrips (graph/node/edge attributes).
- New automated tests for:
  - weighted graph mapping from DOT attributes
  - `MetaGraphsNext` conversion roundtrips

### Changed
- README updates:
  - clarified support for `Graphs.jl` and `SimpleWeightedGraphs.jl`
  - documented `MetaGraphsNext.jl` interoperability
  - added API know-how section for interop workflows
  - installation examples updated to modern Julia (`1.10+`)
  - prominent support line in header: `Supported Julia: 1.10+`
- Dependency compatibility and resolution:
  - expanded `DataStructures` compat to `"0.18, 0.19"`
  - upgraded `DataStructures` to `0.19.4`
  - upgraded `Graphs` to `1.14.0`
  - transitive updates include `ImageMorphology` and `ImageSegmentation`

### Verified
- Full test suite passes after upgrades (`208/208`).
