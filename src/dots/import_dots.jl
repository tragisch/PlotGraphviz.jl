"""
    read_dot_file(file)

Import graph from DOT-Format and store it in file `SimpleWeightedGraph` or `SimpleWeightedDiGraph``.
Return AttributeDict for graph layouts.
ToDo: ERROR-Handling if not a suitable DOT-File is not implemented

#### Arguments
- `file::AbstractString`: the filename of dot-file (i.e. "graph.dot")
"""
function read_dot_file(filename::AbstractString)

    # read_file
    my_graph = read_graph(filename)

    # use ParserCombinator.Parsers.DOT to convert to attributes
    graphs_parser_combinator = ParserCombinator.Parsers.DOT.parse_dot(my_graph)

    # use first graph (toDo for more graphs)  !!! PROBLEM
    if length(graphs_parser_combinator) == 1
        # @show length(graphs_parser_combinator)
        graph_parser_combinator = graphs_parser_combinator[1]
    else
        graph_parser_combinator = graphs_parser_combinator[1]
    end

    attrs = init_Attributes!(graph_parser_combinator)

    # set! attributes
    set_attributes!(attrs, graph_parser_combinator)

    # get AbstractSimpleWeightedGraph
    g = get_AbstractSimpleWeightedGraph(attrs)

    return g, attrs
end


function read_graph(filename)
    f = open(filename, "r")
    s = read(f, String)
    close(f)
    return s
end


function init_Attributes!(g)
    if isdefined(g, :directed)
        node_options = [PlotGraphviz.Property("directed", g.directed)]
    end

    # nodes:
    nd = ParserCombinator.Parsers.DOT.nodes(g)
    nodes = []
    count = 1
    for key in nd.dict
        push!(nodes, PlotGraphviz.gvNode(count, String(key[1]),
            [Property("label", check_value(String(key[1])))]))
        count += 1
    end

    # edges:
    eg = ParserCombinator.Parsers.DOT.edges(g)
    edges = []
    for tup in eg.dict
        to = get_id(nodes, String(tup[1][1]))
        from = get_id(nodes, String(tup[1][2]))
        push!(edges, PlotGraphviz.gvEdge(to, from, Properties()))
        if g.directed == false
            push!(edges, PlotGraphviz.gvEdge(from, to, Properties()))
        end
    end
    subgraphs = (gvSubGraph)[]

    return GraphvizAttributes(node_options, Properties(), Properties(), Properties(), subgraphs, nodes, edges)

end

function set_attributes!(attrs, g)

    for stm in g.stmts

        if stm isa ParserCombinator.Parsers.DOT.Attribute
            set!(attrs.graph_options, String(stm.name.id), check_value(String(stm.value.id)))
        elseif stm isa ParserCombinator.Parsers.DOT.GraphAttributes
            for attr in stm.attrs
                set!(attrs.graph_options, String(attr.name.id), check_value(String(attr.value.id)))
            end
        elseif stm isa ParserCombinator.Parsers.DOT.NodeAttributes
            for attr in stm.attrs
                set!(attrs.node_options, String(attr.name.id), check_value(String(attr.value.id)))
            end
        elseif stm isa ParserCombinator.Parsers.DOT.EdgeAttributes
            for attr in stm.attrs
                set!(attrs.edge_options, String(attr.name.id), check_value(String(attr.value.id)))
            end
        elseif stm isa ParserCombinator.Parsers.DOT.Edge
            if !(isempty(stm.attrs))
                for attr in stm.attrs
                    set_edge!(attrs.edges, get_id(attrs.nodes, String(stm.nodes[1].id.id)), get_id(attrs.nodes, String(stm.nodes[2].id.id)),
                        Property(String(attr.name.id), check_value(String(attr.value.id))))
                    if (g.directed == false)
                        set_edge!(attrs.edges, get_id(attrs.nodes, String(stm.nodes[2].id.id)), get_id(attrs.nodes, String(stm.nodes[1].id.id)),
                            Property(String(attr.name.id), check_value(String(attr.value.id))))
                    end
                end
            end
        elseif stm isa ParserCombinator.Parsers.DOT.Node
            if !(isempty(stm.attrs))
                for attr in stm.attrs
                    set_node!(attrs.nodes, get_id(attrs.nodes, String(stm.id.id.id)),
                        Property(String(attr.name.id), check_value(String(attr.value.id))))
                end
            end
        elseif stm isa ParserCombinator.Parsers.DOT.SubGraph
            if !isnothing(stm.id)
                push!(attrs.subgraphs, gvSubGraph(String(stm.id.id)))
            else
                push!(attrs.subgraphs, gvSubGraph(""))
            end

            set_subgraph!(attrs.subgraphs[end], stm, attrs.nodes, g.directed)
        end
    end

end


function set_subgraph!(subs::gvSubGraph, g::ParserCombinator.Parsers.DOT.SubGraph, nodes::gvNodes, directed::Bool)
    # @show subs
    for stm in g.stmts
        if stm isa ParserCombinator.Parsers.DOT.Node
            push!(subs.nodes, gvNode(get_id(nodes, String(stm.id.id.id)), String(stm.id.id.id), Properties()))
            for attr in stm.attrs
                set_node!(subs.nodes, get_id(nodes, String(stm.id.id.id)),
                    Property(String(attr.name.id), check_value(String(attr.value.id))))
            end
        elseif stm isa ParserCombinator.Parsers.DOT.Attribute
            set!(subs.graph_options, String(stm.name.id), check_value(String(stm.value.id)))
        elseif stm isa ParserCombinator.Parsers.DOT.NodeAttributes
            for attr in stm.attrs
                set!(subs.node_options, String(attr.name.id), check_value(String(attr.value.id)))
            end
        elseif stm isa ParserCombinator.Parsers.DOT.Edge
            push!(subs.edges, gvEdge(get_id(nodes, String(stm.nodes[1].id.id)), get_id(nodes, String(stm.nodes[2].id.id)), Properties()))
            if (directed == false)
                push!(subs.edges, gvEdge(get_id(nodes, String(stm.nodes[2].id.id)), get_id(nodes, String(stm.nodes[1].id.id)), Properties()))
            end

            if !(isempty(stm.attrs))
                for attr in stm.attrs
                    set_edge!(subs.edges, get_id(nodes, String(stm.nodes[1].id.id)), get_id(nodes, String(stm.nodes[2].id.id)),
                        Property(String(attr.name.id), check_value(String(attr.value.id))))
                    if (directed == false)
                        set_edge!(subs.edges, get_id(nodes, String(stm.nodes[2].id.id)), get_id(nodes, String(stm.nodes[1].id.id)),
                            Property(String(attr.name.id), check_value(String(attr.value.id))))
                    end
                end
            end
        end

    end

end

function get_AbstractSimpleWeightedGraph(attrs::GraphvizAttributes)
    nodes = attrs.nodes
    ndim = length(nodes)
    adj = zeros(ndim, ndim)

    directed = val(attrs.plot_options, "directed")

    for e in attrs.edges
        weight = val_edge(attrs.edges, e.from, e.to, "xlabel")
        if !(isempty(weight))
            adj[e.from, e.to] = parse(Float64, weight)
            (directed == false) ? adj[e.to, e.from] = parse(Float64, weight) : nothing
        else
            adj[e.from, e.to] = 1
            (directed == false) ? adj[e.to, e.from] = 1 : nothing
        end
    end

    if directed
        return SimpleWeightedDiGraph(adj)
    else
        return SimpleWeightedGraph(adj)
    end
end

const special_characters = ["+", "-", "&", " "]
function check_value(value::T) where {T}
    if value isa String
        if isempty(value)
            value = "\" " * "\""
        else
            for e in special_characters
                if (contains(value, e) == true)
                    value = "\"" * value * "\""
                    break
                end
            end
        end
    end
    return value
end


