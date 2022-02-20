


#typealias
const AttributeDict = Dict{Any,Array{Tuple{String,Any}}}

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
        "P" => [
            ("weights", (edge_label) ? "true" : "false"),
            ("largenet", "200")],
        "G" => [
            ("center", "1"),
            ("overlap", "scale"),
            ("concentrate", "true"),
            ("layout", (directed) ? "dot" : "neato"),
            ("size", (n < 20) ? "3.0" : ((n < 100) ? "7.0" : "10.0"))],
        "N" => [
            ("color", "Turquoise"),
            ("fontsize", (node_label) ? ((n < 100) ? "7.0" : "5.0") : "1.0"),
            ("width", (node_label) ? "0.25" : "0.20"),
            ("height", (node_label) ? "0.25" : "0.20"),
            ("fixedsize", "true"), ("shape", (node_label) ? "circle" : "point")],
        "E" => [
            ("arrowsize", "0.5"),
            ("arrowtype", "normal"),
            ("fontsize", (edge_label) ? "8.0" : "1.0")
        ])
    if n > parse(Int64, val(attr["P"], "largenet"))
        attr = _mod_attr_large_network!(attr)
    end

    return attr
end

# internal function to modify `GraphViz` plot-paramter for large graphs
function _mod_attr_large_network!(attrs::AttributeDict)
    set!(attrs["N"], "shape", "point")
    set!(attrs["N"], "color", "black")
    set!(attrs["G"], "fontsize", "1")
    set!(attrs["G"], "concetrate", "true")
    set!(attrs["G"], "layout", "sfdp")
    set!(attrs["P"], "weights", "false")
    set!(attrs["N"], "shape", "point")
end

# return val of attribute:
function val(attributes::Array{Tuple{String,Any}}, attribute::String)
    if !isempty(attributes)
        for a in attributes
            if a[1] == attribute
                return a[2]
            end
        end
    end
    return []
end

# set val to attributeDict
function set!(attrs::AttributeDict, key, attribute::Tuple{String,Any})
    if haskey(attrs, key)
        set!(attrs[key], attribute[1], attribute[2])
    else
        attrs[key] = [attribute]
    end
end

# set val of attribute:
function set!(attributes::Array{Tuple{String,Any}}, attribute::String, val)
    if isempty(attributes)
        push!(attributes, (attribute, val))
    else
        for i = 1:length(attributes)
            if (attributes[i][1] == attribute) && !(attributes[i][2] == val)
                attributes[i] = (attribute, val)
                return attributes
            elseif (attributes[i][1] == attribute) && (attributes[i][2] == val)
                return attributes
            end
        end
        push!(attributes, (attribute, val))
    end
    return attributes
end

# remove attribute of attributes
function rm!(attributes::Array{Tuple{String,Any}}, attribute::String)
    if !isempty(attributes)
        for i = 1:length(attributes)
            if attributes[i] == attribute
                attributes = deleteat!(attributes, i)
                return attributes
            end
        end
    end
    return attributes
end



