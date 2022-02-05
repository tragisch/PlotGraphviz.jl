# Functions for representing graphs in GraphViz's dot format
# http://www.graphviz.org/
# http://www.graphviz.org/Documentation/dotguide.pdf
# http://www.graphviz.org/pub/scm/graphviz2/doc/info/lang.html

# orientated and based more or less on :
# https://github.com/JuliaAttic/OldGraphs.jl/blob/master/src/dot.jl
# https://github.com/tkf/ShowGraphviz.jl
# and only simply modified (Roettgermann, 12/21)


#typealias
const AttributeDict = Dict{Symbol,Vector{String}}

"""
    default_attributes(g)

Return `attrs::AttributeDict default` as plotting paramter for `GraphViz` Plot.

See attributes on http://www.graphviz.org/. The AttributeDict is of `Dict{Symbol,Vector{String}}` with Symbols `P` (Plot), `G` (Graph), `N` (Node) and `E` (Edges).
For example the following dict-Entry set the layout engine to `dot`.

    attr[:layout] = ["G", "dot"]

#### Arguments
- `g::AbstractSimpleWeightedGraph`: a graph representation to export 
"""
function get_attributes(graph::AbstractSimpleWeightedGraph; node_label::Bool = true, edge_label::Bool = false)::AttributeDict
    directed = Graphs.is_directed(graph)
    n = nv(graph)
    #size_graph=minimum(5.0 +*/sqrt, 15.0)  # ToDo: automated scaler
    attr = AttributeDict(
        :weights => ["P", (edge_label) ? "true" : "false"],
        :largenet => ["P", "200"],
        :arrowsize => ["E", "0.5"],
        :arrowtype => ["E", "normal"],
        :center => ["G", "1"],
        :overlap => ["G", "scale"],
        :color => ["N", "Turquoise"],
        :concentrate => ["G", "true"],
        :fontsize => ["N", (node_label) ? ((n < 100) ? "7.0" : "5") : "1.0"],
        :width => ["N", (node_label) ? "0.25" : "0.20"],
        :height => ["N", (node_label) ? "0.25" : "0.20"],
        :fixedsize => ["N", "true"],
        :fontsize => ["E", (edge_label) ? "8.0" : "1.0"],
        :layout => ["G", (directed) ? "dot" : "neato"], # dot or neato
        :size => ["G", (n < 20) ? "3.0" : ((n < 100) ? "7.0" : "10")],
        :shape => ["N", (node_label) ? "circle" : "point"]
    )

    # modify attr_ if it is a large network:
    if n > parse(Int64, attr[:largenet][2])
        attr = _mod_attr_large_network!(attr)
    end

    return attr
end

# internal function to modify `GraphViz` plot-paramter for large graphs
function _mod_attr_large_network!(attrs::AttributeDict)
    attrs[:shape] = ["N", "point"]
    attrs[:color] = ["N", "black"]
    attrs[:fontsize] = ["G", "1"]
    attrs[:concetrate] = ["G", "true"]
    attrs[:layout] = ["G", "sfdp"]
    attrs[:weights] = ["P", "false"]
    return attrs
end

# internal function to get `G`raph, `E`dge and `N`ode relateted attributes:
function _get_GNE_attributes(attrs::AttributeDict, gne::String)
    if !isempty(attrs)
        GNE_attrs = Dict()
        for key in keys(attrs)
            if contains(attrs[key][1], gne)
                GNE_attrs[key] = attrs[key]
            end
        end
        return GNE_attrs
    else
        return ""
    end

end

# internal function to get a suitable string out of the attribute dictionary:
function _parse_attributes(mat::AbstractSimpleWeightedGraph, attrs::AttributeDict, gne::String)

    gne_attrs = _get_GNE_attributes(attrs, gne)
    str_attr::String = ""

    if gne == "N" # node attributes
        str_attr = string("[", join(map(a -> _to_dot(a[1], a[2][2]), collect(gne_attrs)), ","))
    elseif gne == "G" # graph attributes
        for key in keys(attrs)
            if contains(attrs[key][1], "G")
                str_attr = str_attr * string(_to_dot(key, attrs[key][2]), ";\n ")
            end
        end
    elseif gne == "E" # edge attributes
        str_attr = string("[", join(map(a -> _to_dot(a[1], a[2][2]), collect(gne_attrs)), ","))
    end
    return str_attr
end


# helper function to identify all_zero Array
_is_all_zero(arr) = length(arr) == 0 || all(==(0), arr)

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
    attributes[:size] = ["G", string(scale)]
    (edge_label) ? attributes[:forcelabels] = ["G", "true"] : nothing
    (landscape) ? attributes[:orientation] = ["G", "LR"] : nothing

    gv_dot = _to_dot(g; attributes = attributes, path = path, colors = colors)
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
"""
function plot_graphviz(g::AbstractSimpleWeightedGraph, attributes::AttributeDict;
    path = [],
    colors = zeros(Int, nv(g))
)

    gv_dot = _to_dot(g; attributes = attributes, path = path, colors = colors)
    plot_graphviz(gv_dot)
end



function plot_graphviz(str::AbstractString)
    ShowGraphviz.CONFIG.dot_option = `-q` # do not warn in iJulia!
    ShowGraphviz.DOT(str)
end


"""
    write_dot_file(g, file; attributes, path)


Export graph `g` to DOT-Format and store it in file `file`.

#### Arguments
- `g::AbstractSimpleWeightedGraph`: a graph representation to export 
- `filename::AbstractString`: the filename to store (i.e. "graph.dot")
- (optional) `attributes::AttributeDict`: Dot-Attributes like node color stored in a dictionary
- (optional) `path = zeros(Int, nv(mat))`: Int-Array of nodes. Nodes and their edges are drawn in red color (i.e. shortest path)
"""
function write_dot_file(graph::AbstractSimpleWeightedGraph, filename::AbstractString;
    attributes::AttributeDict = get_attributes(graph), path = [], colors = zeros(Int, nv(graph)))
    open(filename, "w") do f
        _to_dot(graph, f, attributes; path = path, colors = colors)
    end
end

"""
    read_dot_file(file)

Import graph from DOT-Format and store it in file `SimpleWeightedGraph` or `SimpleWeightedDiGraph``.
ToDo: ERROR-Handling if not a suitable DOT-File is not implemented

#### Arguments
- `file::AbstractString`: the filename of dot-file (i.e. "graph.dot")
"""
function read_dot_file(filename::AbstractString)
    # to count total lines in the file
    node_count = 0

    directed = false


    # get size of graph
    f = open(filename, "r")
    for line in readlines(f)
        (line_type, nodes, weight) = _read_dotline(line)
        if line_type == "digraph"
            directed = true
        elseif line_type == "node"
            node_count += 1
        end
    end
    close(f)

    adj = zeros(node_count - 1, node_count - 1)

    # get edges
    f = open(filename, "r")
    for line in readlines(f)
        (line_type, nodes, weight) = _read_dotline(line)
        if line_type == "edge"
            adj[nodes[1], nodes[2]] = weight
            if directed == false
                adj[nodes[2], nodes[1]] = weight
            end
        end
    end
    # close file
    close(f)

    if directed
        adj = adj'
        return SimpleWeightedDiGraph(adj)
    else
        return SimpleWeightedGraph(adj)
    end

end


function _read_dotline(str::String)

    tokens = collect(tokenize(str))
    start_options = false
    weight_identifier = false
    weight = 1.0
    nodes = (Int)[]
    line_type = "node"
    idx_LSQARE = 0

    # handle input and identify edge, node or graph_line
    for token in tokens

        if token.val == "digraph"
            line_type = "digraph"
            break
        elseif token.val == "graph"
            line_type = "graph"
            break
        elseif token.kind == Tokenize.Tokens.INTEGER
            if weight_identifier == true
                weight = parse(Float64, token.val)
                weight_identifier = false
            else
                push!(nodes, parse(Int64, token.val))
            end
        elseif (Tokenize.Tokens.exactkind(token) == Tokenize.Tokens.ANON_FUNC) || Tokenize.Tokens.exactkind(token) == Tokenize.Tokens.ERROR
            line_type = "edge"
        elseif token.kind == Tokenize.Tokens.IDENTIFIER
            (token.val == "xlabel") ? weight_identifier = true : weight_identifier = false
        elseif token.kind == Tokenize.Tokens.FLOAT && (weight_identifier == true)
            weight = parse(Float64, token.val)
            weight_identifier = false
        elseif token.kind == Tokenize.Tokens.LSQUARE
            start_options = true
            idx_LSQARE = token.startpos[2]
        elseif token.kind == Tokenize.Tokens.EQ && (start_options == false)
            line_type = "graph"
        end
    end



    return (line_type, nodes, weight)

end

