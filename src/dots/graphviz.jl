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
as_attribute_value(value::Html) = value
as_attribute_value(value) = string(value)
as_attributes(d::OrderedDict) = Attributes(Symbol(k) => as_attribute_value(d[k]) for k in keys(d))
as_attributes(d::AbstractDict) =
    Attributes(Symbol(k) => as_attribute_value(d[k]) for k in sort!(collect(keys(d))))


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

GraphvizGraph(name::String, stmts::Vector{Statement}; strict::Bool=false, kw...) =
    GraphvizGraph(; name=name, strict=strict, directed=false, stmts=stmts, kw...)
GraphvizGraph(name::String, stmts::Vararg{Statement}; strict::Bool=false, kw...) =
    GraphvizGraph(; name=name, strict=strict, directed=false, stmts=collect(stmts), kw...)
GraphvizDigraph(name::String, stmts::Vector{Statement}; strict::Bool=false, kw...) =
    GraphvizGraph(; name=name, strict=strict, directed=true, stmts=stmts, kw...)
GraphvizDigraph(name::String, stmts::Vararg{Statement}; strict::Bool=false, kw...) =
    GraphvizGraph(; name=name, strict=strict, directed=true, stmts=collect(stmts), kw...)


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
        :overlap => "scale",
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
        :arrowhead => "normal",
        :fontsize => edge_label ? "8.0" : "1.0",
    )
end

graph_edge_attrs(::Nothing, from, to) = Attributes()
function graph_edge_attrs(weights, from, to)
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

function quote_dot_identifier(name::AbstractString)
    if occursin(r"^([A-Za-z\x80-\xff_][A-Za-z\x80-\xff_0-9]*|-?(\.[0-9]+|[0-9]+(\.[0-9]*)?))$", name)
        return name
    end
    escaped = replace(name, "\\" => "\\\\", "\"" => "\\\"")
    return "\"$escaped\""
end

function merge_attrs(base::Attributes, overrides::Attributes)
    merged = copy(base)
    for (key, value) in overrides
        merged[key] = value
    end
    return merged
end

function _emit_global_node(node::gvNode, subgraph_node_ids::Set{Int})
    # Nodes declared in subgraphs are emitted there (including merged global
    # overrides), so emitting them again globally is redundant and can perturb
    # layout/ranking due to default re-application.
    return !(node.id in subgraph_node_ids)
end

function _collect_subgraph_node_ids!(acc::Set{Int}, subgraph::gvSubGraph)
    for node in subgraph.nodes
        push!(acc, node.id)
    end
    for nested in subgraph.subgraphs
        _collect_subgraph_node_ids!(acc, nested)
    end
    return acc
end

function _collect_subgraph_edge_pairs!(acc::Set{Tuple{Int,Int}}, subgraph::gvSubGraph)
    for edge in subgraph.edges
        push!(acc, (edge.from, edge.to))
    end
    for nested in subgraph.subgraphs
        _collect_subgraph_edge_pairs!(acc, nested)
    end
    return acc
end

function legacy_subgraph_statement(
    subgraph::gvSubGraph,
    node_names::Dict{Int,String},
    node_attrs::Dict{Int,Attributes},
)
    subgraph_stmts = Statement[]
    subgraph_node_defaults = legacy_attrs(subgraph.node_options)

    for nested in subgraph.subgraphs
        push!(subgraph_stmts, legacy_subgraph_statement(nested, node_names, node_attrs))
    end

    for node in subgraph.nodes
        subgraph_node_attrs = merge_attrs(subgraph_node_defaults, legacy_attrs(node.attributes))
        global_node_overrides = haskey(node_attrs, node.id) ? node_attrs[node.id] : Attributes()
        node_name = get(node_names, node.id, string(node.id))
        push!(subgraph_stmts, Node(node_name, merge_attrs(subgraph_node_attrs, global_node_overrides)))
    end

    for edge in subgraph.edges
        from_name = get(node_names, edge.from, string(edge.from))
        to_name = get(node_names, edge.to, string(edge.to))
        push!(subgraph_stmts, Edge([NodeID(from_name), NodeID(to_name)], legacy_attrs(edge.attributes)))
    end

    return Subgraph(
        subgraph.type,
        subgraph_stmts;
        graph_attrs=legacy_attrs(subgraph.graph_options),
        node_attrs=legacy_attrs(subgraph.node_options),
        edge_attrs=legacy_attrs(subgraph.edge_options),
    )
end

function legacy_graphviz_graph(graph::Graphs.AbstractGraph, attrs::GraphvizAttributes)
    directed = Graphs.is_directed(graph)
    global_node_stmts = Statement[]
    global_edge_stmts = Statement[]
    subgraph_stmts_all = Statement[]

    subgraph_edge_pairs = Set{Tuple{Int,Int}}()
    subgraph_node_ids = Set{Int}()
    node_names = Dict(node.id => node.name for node in attrs.nodes)
    node_attrs = Dict(node.id => legacy_attrs(node.attributes) for node in attrs.nodes)
    edge_attrs = Dict{Tuple{Int,Int},Attributes}()
    for edge in attrs.edges
        key = (edge.from, edge.to)
        haskey(edge_attrs, key) || (edge_attrs[key] = legacy_attrs(edge.attributes))
    end

    for subgraph in attrs.subgraphs
        _collect_subgraph_node_ids!(subgraph_node_ids, subgraph)
        _collect_subgraph_edge_pairs!(subgraph_edge_pairs, subgraph)
    end

    for node in attrs.nodes
        if _emit_global_node(node, subgraph_node_ids)
            push!(global_node_stmts, Node(node.name, node_attrs[node.id]))
        end
    end

    for edge in Graphs.edges(graph)
        from = Graphs.src(edge)
        to = Graphs.dst(edge)
        if (from, to) in subgraph_edge_pairs
            continue
        end
        from_name = get(node_names, from, string(from))
        to_name = get(node_names, to, string(to))
        key = (from, to)
        attributes = haskey(edge_attrs, key) ? edge_attrs[key] : Attributes()
        push!(global_edge_stmts, Edge([NodeID(from_name), NodeID(to_name)], attributes))
    end

    for subgraph in attrs.subgraphs
        push!(subgraph_stmts_all, legacy_subgraph_statement(subgraph, node_names, node_attrs))
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

    edge_weights = edge_label ? Graphs.weights(graph) : nothing
    for edge in Graphs.edges(graph)
        from = Graphs.src(edge)
        to = Graphs.dst(edge)
        push!(stmts, Edge([NodeID("$from"), NodeID("$to")], graph_edge_attrs(edge_weights, from, to)))
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
    gGraph.strict && print(io, "strict ")
    print(io, gGraph.directed ? "digraph " : "graph ")
    print(io, quote_dot_identifier(gGraph.name))
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
        print(io, quote_dot_identifier(subgraph.name))
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
    print(io, quote_dot_identifier(node.name))
    pprint_attrs(io, node.attrs)
    print(io, ";")
end

function pprint(io::IO, node::NodeID, n::Int)
    print(io, quote_dot_identifier(node.name))
    if !isempty(node.port)
        print(io, ":")
        print(io, quote_dot_identifier(node.port))
    end
    if !isempty(node.anchor)
        print(io, ":")
        print(io, quote_dot_identifier(node.anchor))
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
            value isa Html ? print(io, value) : print_dot_string(io, value)
            print(io, value isa Html ? ">" : "\"")
        end
        print(io, "]")
        print(io, post)
    end
end

function pprint(io::IO, lab::Label, n::Int; directed::Bool=false)
    if !isempty(lab.labelloc)
        print(io, "labelloc=\"")
        print_dot_string(io, lab.labelloc)
        print(io, "\";")
    end
    print(io, "label=\"")
    print_dot_string(io, lab.label)
    print(io, "\";")
end

function print_dot_string(io::IO, value::AbstractString)
    escaped = false
    for char in value
        if char == '\n'
            print(io, "\\n")
        elseif char == '\r'
            print(io, "\\r")
        elseif char == '"' && !escaped
            print(io, "\\\"")
        else
            print(io, char)
        end

        escaped = char == '\\' ? !escaped : false
    end
end

indent(io::IO, n::Int) = print(io, " "^n)
