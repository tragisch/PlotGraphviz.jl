# using Catlab.jl version of Graphviz
# src/graphics/Graphviz.jl
# small adaptions to fit for own package.

# TODO: Vorteil Modul ermitteln
# derived from

abstract type Graphviz end
abstract type Statement <: Graphviz end

struct Html
    content::String
end
Base.print(io::IO, html::Html) = print(io, html.content)

const AttributeValue = Union{String,Html}
const Attributes = OrderedDict{Symbol,AttributeValue}

as_attributes(attrs::Attributes) = attrs
as_attributes(d::OrderedDict) = Attributes(Symbol(k) => d[k] for k in keys(d))
as_attributes(d::AbstractDict) =
    Attributes(Symbol(k) => d[k] for k in sort!(collect(keys(d))))


### main struct GraphvizGraph

Base.@kwdef struct GraphvizGraph <: Graphviz
    name::String
    strict::Bool
    directed::Bool
    stmts::Vector{Statement} = Statement[]
    graph_attrs::Attributes = Attributes()
    node_attrs::Attributes = Attributes()
    edge_attrs::Attributes = Attributes()
end

GraphvizGraph(name::String, stmts::Vector{Statement}; kw...) =
    GraphvizGraph(; name=name, strict=false, directed=false, stmts=stmts, kw...)
GraphvizGraph(name::String, stmts::Vararg{Statement}; kw...) =
    GraphvizGraph(; name=name, strict=false, directed=false, stmts=collect(stmts), kw...)
GraphvizDigraph(name::String, stmts::Vector{Statement}; kw...) =
    GraphvizGraph(; name=name, strict=false, directed=true, stmts=stmts, kw...)
GraphvizDigraph(name::String, stmts::Vararg{Statement}; kw...) =
    GraphvizGraph(; name=name, strict=false, directed=true, stmts=collect(stmts), kw...)


### Statement Subgraph:
Base.@kwdef struct Subgraph <: Statement
    name::String = ""
    stmts::Vector{Statement} = Statement[]
    graph_attrs::Attributes = Attributes()
    node_attrs::Attributes = Attributes()
    edge_attrs::Attributes = Attributes()
end

Subgraph(stmts::Vector{Statement}; kw...) = Subgraph(; stmts=stmts, kw...)
Subgraph(stmts::Vararg{Statement}; kw...) = Subgraph(; stmts=collect(stmts), kw...)
Subgraph(name::String, stmts::Vector{Statement}; kw...) =
    Subgraph(; name=name, stmts=stmts, kw...)
Subgraph(name::String, stmts::Vararg{Statement}; kw...) =
    Subgraph(; name=name, stmts=collect(stmts), kw...)

### Statement Node:
struct Node <: Statement
    name::String
    attrs::Attributes
end
Node(name::String, attrs::AbstractDict) = Node(name, as_attributes(attrs))
Node(name::String; attrs...) = Node(name, attrs)

@struct_hash_equal struct NodeID <: Graphviz
    name::String
    port::String
    anchor::String
    NodeID(name::String, port::String="", anchor::String="") = new(name, port, anchor)
end

@struct_hash_equal struct Edge <: Statement
    path::Vector{NodeID}
    attrs::Attributes
end
Edge(path::Vector{NodeID}, attrs::AbstractDict) = Edge(path, as_attributes(attrs))
Edge(path::Vector{NodeID}; attrs...) = Edge(path, attrs)
Edge(path::Vararg{NodeID}; attrs...) = Edge(collect(path), attrs)
Edge(path::Vector{String}, attrs::AbstractDict) = Edge(map(NodeID, path), attrs)
Edge(path::Vector{String}; attrs...) = Edge(map(NodeID, path), attrs)
Edge(path::Vararg{String}; attrs...) = Edge(map(NodeID, collect(path)), attrs)

Base.@kwdef struct Label <: Statement
    labelloc::String = ""
    label::String = ""
end

function filter_statements(gGraph::GraphvizGraph, type::Type)
    [stmt for stmt in gGraph.stmts if stmt isa type]
end
function filter_statements(gGraph::GraphvizGraph, type::Type, attr::Symbol)
    [stmt.attrs[attr] for stmt in gGraph.stmts
     if stmt isa type && haskey(stmt.attrs, attr)]
end

function default_graph_attrs(directed::Bool, n::Integer)
    Attributes(
        :center => "1,1",
        :overlay => "scale",
        :concentrate => "true",
        :layout => directed ? "dot" : "neato",
        :size => n < 20 ? "3.0" : (n < 100 ? "7.0" : "10.0"),
    )
end

function default_node_attrs(node_label::Bool, n::Integer)
    Attributes(
        :color => "Turquoise",
        :fontsize => node_label ? (n < 100 ? "7.0" : "5.0") : "1.0",
        :width => node_label ? "0.25" : "0.20",
        :height => node_label ? "0.25" : "0.20",
        :fixedsize => "true",
        :shape => node_label ? "circle" : "point",
    )
end

function default_edge_attrs(edge_label::Bool)
    Attributes(
        :arrowsize => "0.5",
        :arrowtype => "normal",
        :fontsize => edge_label ? "8.0" : "1.0",
    )
end

function graph_edge_attrs(graph::Graphs.AbstractGraph, from, to, edge_label::Bool)
    edge_label || return Attributes()

    weights = Graphs.weights(graph)
    return Attributes(:xlabel => string(weights[from, to]))
end

function unquote_dot_value(value)
    if value isa String && length(value) >= 2 && startswith(value, "\"") && endswith(value, "\"")
        m = match(r"^\"(.*)\"$"s, value)
        if !isnothing(m)
            return string(m.captures[1])
        end
    end
    return string(value)
end

function legacy_attrs(properties::Properties)
    attrs = Attributes()
    for prop in properties
        key = Symbol(prop.key)
        value = unquote_dot_value(prop.value)

        # Legacy compatibility: users often set `filled=true/false` as a node
        # property. DOT expects this through `style="filled"` instead.
        if key == :filled
            v = lowercase(string(value))
            if v in ("true", "1", "yes")
                attrs[:style] = "filled"
            elseif v in ("false", "0", "no")
                # ignore `filled=false` so explicit fillcolor or inherited
                # subgraph style can still control the rendering.
                continue
            else
                attrs[key] = value
            end
            continue
        end

        attrs[key] = value
    end
    return attrs
end

function legacy_edge_attrs(attrs::GraphvizAttributes, from::Int, to::Int)
    for edge in attrs.edges
        if edge.from == from && edge.to == to
            return legacy_attrs(edge.attributes)
        end
    end
    return Attributes()
end

function legacy_node_name(attrs::GraphvizAttributes, id::Int)
    name = get_name(attrs.nodes, id)
    return name == 0 ? string(id) : string(name)
end

function quote_dot_identifier(name::AbstractString)
    if occursin(r"^([A-Za-z\x80-\xff_][A-Za-z\x80-\xff_0-9]*|-?(\.[0-9]+|[0-9]+(\.[0-9]*)?))$", name)
        return name
    end
    escaped = replace(name, "\\" => "\\\\", "\"" => "\\\"")
    return "\"$escaped\""
end

legacy_node_id(attrs::GraphvizAttributes, id::Int) = quote_dot_identifier(legacy_node_name(attrs, id))

function legacy_node_attrs(attrs::GraphvizAttributes, id::Int)
    for node in attrs.nodes
        if node.id == id
            return legacy_attrs(node.attributes)
        end
    end
    return Attributes()
end

function merge_attrs(base::Attributes, overrides::Attributes)
    merged = copy(base)
    for (key, value) in overrides
        merged[key] = value
    end
    return merged
end

function _is_default_label_only(node::gvNode, attrs::GraphvizAttributes)
    if length(node.attributes) != 1
        return false
    end
    prop = node.attributes[1]
    if prop.key != "label"
        return false
    end
    return string(prop.value) == check_value(legacy_node_name(attrs, node.id))
end

function _emit_global_node(node::gvNode, attrs::GraphvizAttributes, subgraph_node_ids::Set{Int})
    if !(node.id in subgraph_node_ids)
        return true
    end
    # If a node is already present in a subgraph and only carries the synthetic
    # default label, skip redundant global emission to preserve cluster ranking.
    return !_is_default_label_only(node, attrs)
end

function legacy_graphviz_graph(graph::Graphs.AbstractGraph, attrs::GraphvizAttributes)
    directed = Graphs.is_directed(graph)
    global_node_stmts = Statement[]
    global_edge_stmts = Statement[]
    subgraph_stmts_all = Statement[]

    subgraph_edge_pairs = Set{Tuple{Int,Int}}()
    subgraph_node_ids = Set{Int}()
    for subgraph in attrs.subgraphs
        for node in subgraph.nodes
            push!(subgraph_node_ids, node.id)
        end
        for edge in subgraph.edges
            push!(subgraph_edge_pairs, (edge.from, edge.to))
        end
    end

    for node in attrs.nodes
        if _emit_global_node(node, attrs, subgraph_node_ids)
            push!(global_node_stmts, Node(legacy_node_id(attrs, node.id), legacy_attrs(node.attributes)))
        end
    end

    for edge in Graphs.edges(graph)
        from = Graphs.src(edge)
        to = Graphs.dst(edge)
        if (from, to) in subgraph_edge_pairs
            continue
        end
        from_name = legacy_node_id(attrs, from)
        to_name = legacy_node_id(attrs, to)
        push!(global_edge_stmts, Edge([NodeID(from_name), NodeID(to_name)], legacy_edge_attrs(attrs, from, to)))
    end

    for subgraph in attrs.subgraphs
        subgraph_stmts = Statement[]
        subgraph_node_defaults = legacy_attrs(subgraph.node_options)
        for node in subgraph.nodes
            subgraph_node_attrs = merge_attrs(subgraph_node_defaults, legacy_attrs(node.attributes))
            global_node_overrides = legacy_node_attrs(attrs, node.id)
            push!(subgraph_stmts, Node(legacy_node_id(attrs, node.id), merge_attrs(subgraph_node_attrs, global_node_overrides)))
        end
        for edge in subgraph.edges
            from_name = legacy_node_id(attrs, edge.from)
            to_name = legacy_node_id(attrs, edge.to)
            push!(subgraph_stmts, Edge([NodeID(from_name), NodeID(to_name)], legacy_attrs(edge.attributes)))
        end
        push!(
            subgraph_stmts_all,
            Subgraph(
                subgraph.type,
                subgraph_stmts;
                graph_attrs=legacy_attrs(subgraph.graph_options),
                node_attrs=legacy_attrs(subgraph.node_options),
                edge_attrs=legacy_attrs(subgraph.edge_options),
            ),
        )
    end

    stmts = Statement[]
    append!(stmts, subgraph_stmts_all)
    append!(stmts, global_node_stmts)
    append!(stmts, global_edge_stmts)

    return GraphvizGraph(;
        name="G",
        strict=false,
        directed=directed,
        stmts=stmts,
        graph_attrs=legacy_attrs(attrs.graph_options),
        node_attrs=legacy_attrs(attrs.node_options),
        edge_attrs=legacy_attrs(attrs.edge_options),
    )
end

# derived from Graphs.jl graph types
function get_GraphvizGraph_Standard(graph::Graphs.AbstractGraph; node_label::Bool=true, edge_label::Bool=false)
    directed = Graphs.is_directed(graph)
    n = nv(graph)

    stmts = Statement[]
    for i in 1:n
        push!(stmts, Node("$i"))
    end

    for edge in Graphs.edges(graph)
        from = Graphs.src(edge)
        to = Graphs.dst(edge)
        push!(stmts, Edge([NodeID("$from"), NodeID("$to")], graph_edge_attrs(graph, from, to, edge_label)))
    end

    graph_attrs = default_graph_attrs(directed, n)
    node_attrs = default_node_attrs(node_label, n)
    edge_attrs = default_edge_attrs(edge_label)

    if directed
        return GraphvizDigraph("G", stmts; graph_attrs=graph_attrs, edge_attrs=edge_attrs, node_attrs=node_attrs)
    end

    return GraphvizGraph("G", stmts; graph_attrs=graph_attrs, edge_attrs=edge_attrs, node_attrs=node_attrs)
end


### pprint
pprint(expr::Graphviz) = pprint(stdout, expr)
pprint(io::IO, expr::GraphvizGraph) = pprint(io, expr, 0)

function pprint(io::IO, gGraph::GraphvizGraph, n::Int)
    indent(io, n)
    print(io, gGraph.directed ? "digraph " : "graph ")
    print(io, gGraph.name)
    println(io, " {")
    pprint_attrs(io, gGraph.graph_attrs, n + 2; pre="graph", post=";\n")
    pprint_attrs(io, gGraph.node_attrs, n + 2; pre="node", post=";\n")
    pprint_attrs(io, gGraph.edge_attrs, n + 2; pre="edge", post=";\n")
    for stmt in gGraph.stmts
        pprint(io, stmt, n + 2, directed=gGraph.directed)
        println(io)
    end
    indent(io, n)
    println(io, "}")
end

function pprint(io::IO, subgraph::Subgraph, n::Int; directed::Bool=false)
    indent(io, n)
    if isempty(subgraph.name)
        println(io, "{")
    else
        print(io, "subgraph ")
        print(io, subgraph.name)
        println(io, " {")
    end
    pprint_attrs(io, subgraph.graph_attrs, n + 2; pre="graph", post=";\n")
    pprint_attrs(io, subgraph.node_attrs, n + 2; pre="node", post=";\n")
    pprint_attrs(io, subgraph.edge_attrs, n + 2; pre="edge", post=";\n")
    for stmt in subgraph.stmts
        pprint(io, stmt, n + 2, directed=directed)
        println(io)
    end
    indent(io, n)
    print(io, "}")
end

function pprint(io::IO, node::Node, n::Int; directed::Bool=false)
    indent(io, n)
    print(io, node.name)
    pprint_attrs(io, node.attrs)
    print(io, ";")
end

function pprint(io::IO, node::NodeID, n::Int)
    print(io, node.name)
    if !isempty(node.port)
        print(io, ":")
        print(io, node.port)
    end
    if !isempty(node.anchor)
        print(io, ":")
        print(io, node.anchor)
    end
end

function pprint(io::IO, edge::Edge, n::Int; directed::Bool=false)
    indent(io, n)
    for (i, node) in enumerate(edge.path)
        if i > 1
            print(io, directed ? " -> " : " -- ")
        end
        pprint(io, node, n)
    end
    pprint_attrs(io, edge.attrs)
    print(io, ";")
end

function pprint_attrs(io::IO, attrs::Attributes, n::Int=0;
    pre::String="", post::String="")
    if !isempty(attrs)
        indent(io, n)
        print(io, pre)
        print(io, " [")
        for (i, (key, value)) in enumerate(attrs)
            if (i > 1)
                print(io, ",")
            end
            print(io, key)
            print(io, "=")
            print(io, value isa Html ? "<" : "\"")
            print(io, value)
            print(io, value isa Html ? ">" : "\"")
        end
        print(io, "]")
        print(io, post)
    end
end

function pprint(io::IO, lab::Label, n::Int; directed::Bool=false)
    if !isempty(lab.labelloc)
        print(io, "labelloc=\"$(lab.labelloc)\";")
    end
    print(io, "label=\"$(lab.label)\";")
end

indent(io::IO, n::Int) = print(io, " "^n)
