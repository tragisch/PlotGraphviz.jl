function _meta_parse_scalar(value)
    if value isa String
        unquoted = unquote_dot_value(value)
        parsed_int = tryparse(Int, unquoted)
        if !isnothing(parsed_int)
            return parsed_int
        end
        parsed_float = tryparse(Float64, unquoted)
        if !isnothing(parsed_float)
            return parsed_float
        end
        lowered = lowercase(unquoted)
        if lowered == "true"
            return true
        elseif lowered == "false"
            return false
        end
        return unquoted
    end

    return value
end

function _meta_dict_from_properties(properties::Properties)
    out = Dict{String,Any}()
    for prop in properties
        out[prop.key] = _meta_parse_scalar(prop.value)
    end
    return out
end

function _meta_dict_from_properties(properties::AbstractDict)
    out = Dict{String,Any}()
    for (k, v) in properties
        out[string(k)] = _meta_parse_scalar(v)
    end
    return out
end

function _properties_from_meta_dict(data)
    props = Properties()
    if data isa AbstractDict
        for (k, v) in data
            set!(props, string(k), v)
        end
    end
    return props
end

function _edge_weight_from_data(data, weight_key::String, fallback_weight::Real)
    if data isa AbstractDict && haskey(data, weight_key)
        weight = data[weight_key]
        if weight isa Real
            return float(weight)
        end
        parsed = tryparse(Float64, string(weight))
        if !isnothing(parsed)
            return parsed
        end
    end

    return float(fallback_weight)
end

"""
    to_metagraph(g::AbstractSimpleWeightedGraph, attrs::GraphvizAttributes;
        weight_key="weight", default_weight=1.0)

Convert a weighted PlotGraphviz graph + attributes to `MetaGraphsNext.MetaGraph`.
Node/edge/graph attributes are mapped into `Dict{String,Any}` metadata.
"""
function to_metagraph(g::AbstractSimpleWeightedGraph, attrs::GraphvizAttributes;
    weight_key::String="weight", default_weight=1.0)

    vertex_descriptions = Pair{String,Dict{String,Any}}[]
    for node in attrs.nodes
        data = _meta_dict_from_properties(node.attributes)
        if !haskey(data, "label")
            data["label"] = node.name
        end
        push!(vertex_descriptions, string(node.name) => data)
    end

    edge_descriptions = Pair{Tuple{String,String},Dict{String,Any}}[]
    for e in Graphs.edges(g)
        from = Graphs.src(e)
        to = Graphs.dst(e)
        from_label = string(legacy_node_name(attrs, from))
        to_label = string(legacy_node_name(attrs, to))

        data = _meta_dict_from_properties(legacy_edge_attrs(attrs, from, to))
        if !haskey(data, weight_key)
            data[weight_key] = float(Graphs.weights(g)[from, to])
        end
        push!(edge_descriptions, (from_label, to_label) => data)
    end

    graph_data = _meta_dict_from_properties(attrs.graph_options)
    weight_function = data -> _edge_weight_from_data(data, weight_key, default_weight)

    return MetaGraph(g, vertex_descriptions, edge_descriptions, graph_data, weight_function, float(default_weight))
end

"""
    from_metagraph(mg::MetaGraphsNext.MetaGraph;
        weight_key="weight", default_weight=1.0)

Convert a `MetaGraphsNext.MetaGraph` into `(weighted_graph, attrs::GraphvizAttributes)`.
Graph/vertex/edge metadata is transferred to DOT-compatible properties.
"""
function from_metagraph(mg::MetaGraphsNext.MetaGraph;
    weight_key::String="weight", default_weight=1.0)

    base_graph = mg.graph
    T = Graphs.is_directed(base_graph) ? SimpleWeightedDiGraph : SimpleWeightedGraph
    weighted_graph = T(Graphs.nv(base_graph))
    attrs = GraphvizAttributes(weighted_graph)

    empty!(attrs.nodes)
    for v in 1:Graphs.nv(base_graph)
        raw_label = label_for(mg, v)
        label = string(raw_label)
        node_data = _properties_from_meta_dict(mg[raw_label])
        if isempty(val(node_data, "label"))
            set!(node_data, "label", label)
        end
        push!(attrs.nodes, gvNode(v, label, node_data))
    end

    empty!(attrs.edges)
    for e in Graphs.edges(base_graph)
        from = Graphs.src(e)
        to = Graphs.dst(e)
        from_label = label_for(mg, from)
        to_label = label_for(mg, to)

        edge_data_dict = mg[from_label, to_label]
        edge_weight = _edge_weight_from_data(edge_data_dict, weight_key, default_weight)
        SimpleWeightedGraphs.add_edge!(weighted_graph, from, to, edge_weight)

        edge_props = _properties_from_meta_dict(edge_data_dict)
        if isempty(val(edge_props, weight_key))
            set!(edge_props, weight_key, edge_weight)
        end
        push!(attrs.edges, gvEdge(from, to, edge_props))
    end

    empty!(attrs.graph_options)
    for prop in _properties_from_meta_dict(mg[])
        set!(attrs.graph_options, prop)
    end

    return weighted_graph, attrs
end
