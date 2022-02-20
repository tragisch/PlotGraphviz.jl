


"""
    plot_graphviz(g, node_label= true, edge_label=false; path = zeros(Int, nv(mat))


Render graph `g` in iJulia using `Graphviz` engines.

#### Arguments
- `g::AbstractSimpleWeightedGraph`: a graph representation to export 
- `node_label::Bool`: if true all nodes are numberd fom 1:N (default = true)
- `edge_label::Bool`: if true all edges are labeled with their weights (default = false)
- (optional) `path = []`: Int-Array of nodes. Nodes and their edges are drawn in red color (i.e. shortest path)
- (optional) `colors = zeros(Int, nv(mat))`: Color nodes using Brewer Color Scheme (max 9 colors).
- (optional) `scale = 3.0`: Scale your plot
- (optional) `landscape = false`: render landscape, but node-labes are not rotated as well.
"""
function plot_graphviz(g::AbstractSimpleWeightedGraph;
    node_label::Bool = true,
    edge_label::Bool = false,
    colors = zeros(Int, SimpleWeightedGraphs.nv(g)),
    path = [],
    scale = 3.0,
    landscape = false)

    attributes = get_attributes(g; node_label = node_label, edge_label = edge_label)
    set!(attributes["G"], "size", string(scale))
    (edge_label) ? set!(attributes["G"], "forcelabels", "true") : nothing
    (landscape) ? set!(attributes["G"], "orientation", "LR") : nothing


    gv_dot = _to_dot(g, attributes, path, colors)
    plot_graphviz(gv_dot)
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
function plot_graphviz(g::AbstractSimpleWeightedGraph, attributes::AttributeDict;
    path = [],
    colors = zeros(Int, nv(g)),
    scale = 3.0
)
    if !isempty(val(attributes["P"], "weights"))
        (val(attributes["P"], "weights") == "true") ? set!(attributes["G"], "forcelabels", "true") : nothing
    end
    set!(attributes["G"], "size", string(scale))
    gv_dot = _to_dot(g, attributes, path, colors)
    plot_graphviz(gv_dot)
end

function plot_graphviz(str::AbstractString)
    ShowGraphviz.CONFIG.dot_option = `-q` # do not warn in iJulia!
    ShowGraphviz.DOT(str)
end


