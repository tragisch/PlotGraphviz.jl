
"""
    plot_graphviz(g, node_label= true, edge_label=false; path = zeros(Int, nv(mat))


Render graph `g` in iJulia using `Graphviz` engines.

#### Arguments
- `g::AbstractSimpleWeightedGraph`: a graph representation to export 
- (optional) `edge_label::Bool`: if true all edges are labeled with their weights (default = false)
- (optional) `path = []`: Int-Array of nodes. Nodes and their edges are drawn in red color (i.e. shortest path)
- (optional) `colors = zeros(Int, nv(mat))`: Color nodes using Brewer Color Scheme (max 9 colors).
- (optional) `scale = 3.0`: Scale your plot
- (optional) `landscape = false`: render landscape, but node-labes are not rotated as well.
"""
function plot_graphviz(g::AbstractSimpleWeightedGraph;
    edge_label::Bool = false,
    colors = zeros(Int, SimpleWeightedGraphs.nv(g)),
    path = [],
    scale = 3.0,
    landscape = false)

    attrs = GraphvizAttributes(g; node_label = true, edge_label = edge_label)
    set!(attrs.graph_options, "size", string(scale))

    (edge_label) ? set!(attrs.graph_options, "forcelabels", "true") : nothing
    (landscape) ? set!(attrs.graph_options, "rankdir", "LR") : nothing

    gv_dot = string_dot(g, attrs, path, colors)
    plot_graphviz(gv_dot)
end

function plot_graphviz(tup::Tuple{SimpleWeightedDiGraph{Int64,Float64},GraphvizAttributes};
    edge_label::Bool = false,
    colors = zeros(Int, SimpleWeightedGraphs.nv(tup[1])),
    path = [],
    scale = 3.0,
    landscape = false)

    g = tup[1]
    attrs = tup[2]

    (edge_label) ? set!(attrs.graph_options, "forcelabels", "true") : set!(attrs.graph_options, "forcelabels", "false")
    (landscape) ? set!(attrs.graph_options, "rankdir", "LR") : set!(attrs.graph_options, "rankdir", "TB")

    plot_graphviz(g, attrs; path, colors, scale)

end


"""
    plot_graphviz(g, attributes; path = zeros(Int, nv(mat)))


Render graph `g` in **iJulia** using `Graphviz` engines.

#### Arguments
- `g::AbstractSimpleWeightedGraph`: a graph representation to export 
- `attributes::AttributeDict`: Render with own set of plotting attributes (see http://www.graphviz.org/ for details)
- (optional) `path = []`: Int-Array of nodes. Nodes and their edges are drawn in red color (i.e. shortest path)
- (optional) `colors = zeros(Int, nv(mat))`: Color nodes using Brewer Color Scheme (max 9 colors).
- (optional) `scale = 3.0`: Scale your plot
"""
function plot_graphviz(g::AbstractSimpleWeightedGraph, attributes::GraphvizAttributes;
    path = [],
    colors = zeros(Int, nv(g)),
    scale = 3.0
)
    if !isempty(val(attributes.plot_options, "weights"))
        (val(attributes.plot_options, "weights") == "true") ? set!(attributes.graph_options, "forcelabels", "true") : nothing
    end
    set!(attributes.graph_options, "size", string(scale))
    gv_dot = string_dot(g, attributes, path, colors)
    plot_graphviz(gv_dot)
end

# call ShowGraphviz
function plot_graphviz(str::AbstractString)
    ShowGraphviz.CONFIG.dot_option = `-q` # do not warn in iJulia!
    ShowGraphviz.DOT(str)
end


