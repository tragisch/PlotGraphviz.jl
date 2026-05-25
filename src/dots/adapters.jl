"""
    to_weighted_graph(g::Graphs.AbstractGraph; default_weight=1.0)

Convert a `Graphs.jl` graph to a `SimpleWeightedGraph` / `SimpleWeightedDiGraph`.
For already weighted graphs, the input is returned unchanged.
"""
to_weighted_graph(g::AbstractSimpleWeightedGraph; default_weight=1.0) = g

function to_weighted_graph(g::Graphs.AbstractGraph; default_weight=1.0)
    T = Graphs.is_directed(g) ? SimpleWeightedDiGraph : SimpleWeightedGraph
    wg = T(Graphs.nv(g))
    for e in Graphs.edges(g)
        SimpleWeightedGraphs.add_edge!(wg, Graphs.src(e), Graphs.dst(e), float(default_weight))
    end
    return wg
end

function _read_edge_weight(attrs::GraphvizAttributes, from::Int, to::Int, weight_keys::Tuple, default_weight::Real)
    for key in weight_keys
        raw = val(attrs.edges, from, to, key)
        if isempty(raw)
            continue
        end

        parsed = tryparse(Float64, raw)
        if !isnothing(parsed)
            return parsed
        end

        unquoted = strip(raw, '"')
        parsed = tryparse(Float64, unquoted)
        if !isnothing(parsed)
            return parsed
        end
    end

    return float(default_weight)
end

"""
    apply_edge_weights(g::Graphs.AbstractGraph, attrs::GraphvizAttributes;
        weight_keys=("weight", "xlabel"), default_weight=1.0)

Create a weighted graph from `g` and assign edge weights from DOT attributes in `attrs`.
The first existing key in `weight_keys` wins; if none match, `default_weight` is used.
"""
function apply_edge_weights(g::Graphs.AbstractGraph, attrs::GraphvizAttributes;
    weight_keys=("weight", "xlabel"), default_weight=1.0)

    T = Graphs.is_directed(g) ? SimpleWeightedDiGraph : SimpleWeightedGraph
    weighted = T(Graphs.nv(g))

    for e in Graphs.edges(g)
        from = Graphs.src(e)
        to = Graphs.dst(e)
        w = _read_edge_weight(attrs, from, to, Tuple(weight_keys), default_weight)
        SimpleWeightedGraphs.add_edge!(weighted, from, to, w)
    end

    return weighted
end

"""
    read_dot_file_weighted(filename::AbstractString;
        weight_keys=("weight", "xlabel"), default_weight=1.0)

Read a DOT file via `read_dot_file` and return a weighted graph where edge weights are
mapped from DOT attributes (preferring `weight`, then `xlabel` by default).
Returns `(weighted_graph, attrs)`.
"""
function read_dot_file_weighted(filename::AbstractString;
    weight_keys=("weight", "xlabel"), default_weight=1.0)

    g, attrs = read_dot_file(filename)
    weighted = apply_edge_weights(g, attrs; weight_keys=weight_keys, default_weight=default_weight)
    return weighted, attrs
end
