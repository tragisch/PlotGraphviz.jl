module PlotGraphviz

using Graphs
using SimpleWeightedGraphs
using ParserCombinator
using ShowGraphviz


# Write your package code here


export
    # visualization mit Graphviz (for small graphs or use file_export:)
    plot_graphviz, write_dot_file, read_dot_file, GraphvizAttributes,
    set!, val, rm!,
    set_edge!, set_node!, val_edge, val_node, get_id, get_node,
    Property, Attributes, gvNode, Nodes, gvEdge, gvEdges


include("./dots/attributes.jl")
include("./dots/graph_attributes.jl")
include("./dots/import_dots.jl")
include("./dots/export_dots.jl")
include("./dots/plot_graphviz.jl")
include("./dots/to_dot.jl")

end
