


#typealias
const AttributeDict = Dict{Tuple{String,String},String}

"""
    default_attributes(g)

Return `attrs::AttributeDict default` as plotting paramter for `GraphViz` Plot.

See attributes on http://www.graphviz.org/. The AttributeDict is of `Dict{Symbol,Vector{String}}` with Symbols `P` (Plot), `G` (Graph), `N` (Node) and `E` (Edges).
For example the following dict-Entry set the layout engine to `dot`.

    attr[:layout] = ["G", "dot"]

#### Arguments
- `g::AbstractSimpleWeightedGraph`: a graph representation to export 
"""
function get_attributes(graph::AbstractSimpleWeightedGraph; node_label::Bool = true, edge_label::Bool = false)
    directed = Graphs.is_directed(graph)
    n = nv(graph)
    #size_graph=minimum(5.0 +*/sqrt, 15.0)  # ToDo: automated scaler
    attr = AttributeDict(
        ("weights", "P") => (edge_label) ? "true" : "false",
        ("largenet", "P") => "200",
        ("arrowsize", "E") => "0.5",
        ("arrowtype", "E") => "normal",
        ("center", "G") => "1",
        ("overlap", "G") => "scale",
        ("color", "N") => "Turquoise",
        ("concentrate", "G") => "true",
        ("fontsize", "N") => (node_label) ? ((n < 100) ? "7.0" : "5.0") : "1.0",
        ("width", "N") => (node_label) ? "0.25" : "0.20",
        ("height", "N") => (node_label) ? "0.25" : "0.20",
        ("fixedsize", "N") => "true",
        ("fontsize", "E") => (edge_label) ? "8.0" : "1.0",
        ("layout", "G") => (directed) ? "dot" : "neato", # dot or neato
        ("size", "G") => (n < 20) ? "3.0" : ((n < 100) ? "7.0" : "10.0"),
        ("shape", "N") => (node_label) ? "circle" : "point"
    )

    if n > parse(Int64, attr[("largenet", "P")])
        attr = _mod_attr_large_network!(attr)
    end

    return attr
end

# internal function to modify `GraphViz` plot-paramter for large graphs
function _mod_attr_large_network!(attrs::AttributeDict)
    attrs[("shape", "N")] = "point"
    attrs[("color", "N")] = "black"
    attrs[("fontsize", "G")] = "1"
    attrs[("concetrate", "G")] = "true"
    attrs[("layout", "G")] = "sfdp"
    attrs[("weights", "P")] = "false"
    return attrs
end

# internal function to return bool if key = symb or "GEN"=node, edge or Graph identifier.
function has_attribute(dict::AttributeDict, symb::String; idx = 1)
    for key in dict
        if contains(key[1][idx], symb) # key[1][idx] == symb
            return true
        end
    end
    return false
end



