module PlotGraphviz

using Graphs
using SimpleWeightedGraphs
using Tokenize
using ShowGraphviz


# Write your package code here


export
    # visualization mit Graphviz (for small graphs or use file_export:)
    plot_graphviz, write_dot_file, read_dot_file, AttributeDict, set!, val, rm!


include("./dots/attributes.jl")
include("./dots/import_dots.jl")
include("./dots/export_dots.jl")
include("./dots/plot_graphviz.jl")
include("./dots/to_dot.jl")


end
