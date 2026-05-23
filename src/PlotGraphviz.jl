module PlotGraphviz

using Graphs
using SimpleWeightedGraphs
using ParserCombinator
using StructEquality
using DataStructures
using Graphviz_jll


# Write your package code here


export
    # visualization, import, export:
    plot_graphviz, write_dot_file, read_dot_file,

    # modifier:
    set!, val, rm!,

    # utility:
    get_id, read_lines, parse_my_dot, parse_dot_file,

    # graph_new
    GraphvizGraph, GraphvizDigraph, Node, Edge, Subgraph, get_GraphvizGraph_Standard,
    pprint, run_graphviz, preprocessing,

    # data structs:
    GraphvizAttributes, Property, gvNode, gvEdge, gvEdges


include("./dots/attributes_old.jl")
include("./dots/import_dots.jl")
include("./dots/export.jl")
include("./dots/to_dot.jl")
include("./dots/utils.jl")
include("./dots/graphviz.jl")
include("./dots/plot_graphviz.jl")


end
