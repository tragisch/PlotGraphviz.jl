module PlotGraphviz

using Graphs
using SimpleWeightedGraphs
using ParserCombinator
using ShowGraphviz


# Write your package code here


export
    # visualization, import, export:
    plot_graphviz, write_dot_file, read_dot_file,

    # modifier:
    set!, val, rm!,

    # utility:
    get_id,

    # data structs:
    GraphvizAttributes, Property, gvNode, gvEdge, gvEdges


include("./dots/attributes.jl")
include("./dots/graph_attributes.jl")
include("./dots/import_dots.jl")
include("./dots/export_dots.jl")
include("./dots/plot_graphviz.jl")
include("./dots/to_dot.jl")

end
