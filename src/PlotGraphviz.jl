module PlotGraphviz


using SparseArrays
using Graphs
using SimpleWeightedGraphs
using ShowGraphviz

# Write your package code here


export
    # visualization mit Graphviz (for small graphs or use file_export:)
    plot_graphviz, write_dot_file, read_dot_file, AttributeDict, get_attributes


include("./dots/dots.jl")



end
