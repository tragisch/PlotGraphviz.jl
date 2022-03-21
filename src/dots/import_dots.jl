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
    #my_graph = read_graph(filename)

    # open, read & preprocessing
    my_graph = preprocessing(filename)

    # use ParserCombinator.Parsers.DOT to convert to attributes
    graphs_parser_combinator = ParserCombinator.Parsers.DOT.parse_dot(my_graph)

    # use first graph (toDo for more graphs)  !!! PROBLEM
    if length(graphs_parser_combinator) == 1
        graph_parser_combinator = graphs_parser_combinator[1]
    else
        graph_parser_combinator = graphs_parser_combinator[1]
    end

    attrs = init_Attributes!(graph_parser_combinator)

    # set! attributes
    set_attributes!(attrs, graph_parser_combinator)

    # get AbstractSimpleWeightedGraph
    g = get_AbstractSimpleWeightedGraph(attrs)

    n = nv(g)
    large_graph = 200
    if n > large_graph
        attrs = mod_attr_large_network!(attrs)
    end

    return g, attrs
end

function openfile(filename)
    f = open(filename, "r")
    lines = readlines(f)
    close(f)
    lines
end

function preprocessing(filename)
    lines = openfile(filename)
    new_lines = []
    temp = ""
    multi_line_option = false
    subgraph = false
    for line in lines

        # some small corrections:
        line = replace(line, "\t" => "")
        line = replace(line, " ]" => "]")
        line = replace(line, "[ " => "[")

        # delete comments and empty lines:
        if !isnothing(findfirst("//", lstrip(line))) || !isnothing(findfirst("/*", lstrip(line))) || !isnothing(findfirst("*", lstrip(line))) || isempty(line)
            continue
        end

        if !(multi_line_option)

            # multi subgraph lines:
            if !isnothing(findfirst("{", lstrip(line)))
                idx = findfirst("{", lstrip(line))
                if idx.stop < 2
                    subgraph = true
                    multi_line_option = true
                end
            end

            # in case of edge line: 
            # if !(isnothing(findfirst("--", line))) || !(isnothing(findfirst("->", line)))
            #     push!(new_lines, line)
            #     continue
            # end

            optionend = findfirst("]", line)

            # if multi-line syntax:
            if !isnothing(findfirst("[", line)) && isnothing(optionend)
                temp = temp * line
                multi_line_option = true
                continue
            end

            # one-line sub-graph "node"
            if !isnothing(optionend)

                if isnothing(findfirst("{", line[1:optionend.start]))

                    if (isnothing(findfirst("--", line))) && (isnothing(findfirst("->", line)))

                        if !(isempty(lstrip(line[optionend.stop+1:end])))

                            if isnothing(findfirst("{", line[optionend.stop:end]))

                                if !(lstrip(line[(optionend.stop+1):end]) == ";") || (isempty(lstrip(line[(optionend.stop+1):end])))
                                    str = "subgraph {\n " * line * " \n}"
                                    push!(new_lines, str)
                                    continue
                                end
                            else
                                idx = findfirst("{", line[optionend.stop:end])
                                str = insert_at!(line, "\n", (optionend.stop + idx.start - 1))
                                push!(new_lines, str)
                                continue
                            end
                        end
                    end
                end
            end

            # add line to new_lines
            push!(new_lines, line)
        else

            if (subgraph == false)
                temp = temp * " " * line
                if !isnothing(findfirst("]", line))
                    temp = replace(temp, "\t" => "")
                    temp = replace(temp, " ]" => "]")
                    temp = replace(temp, "[ " => "[")
                    push!(new_lines, temp)
                    multi_line_option = false
                    temp = ""
                end
            else
                push!(new_lines, line)
                if !isnothing(findfirst("}", lstrip(line)))
                    subgraph = false
                    multi_line_option = false
                end
            end
        end
    end

    # #DEBUG:
    # for line in new_lines
    #     @show line
    # end


    return Base.join(new_lines, "\n")
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

    # subgraphs
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
                    set!(attrs.edges, get_id(attrs.nodes, String(stm.nodes[1].id.id)), get_id(attrs.nodes, String(stm.nodes[2].id.id)),
                        Property(String(attr.name.id), check_value(String(attr.value.id))); override=true)

                    if (g.directed == false)
                        set!(attrs.edges, get_id(attrs.nodes, String(stm.nodes[2].id.id)), get_id(attrs.nodes, String(stm.nodes[1].id.id)),
                            Property(String(attr.name.id), check_value(String(attr.value.id))); override=true)
                    end

                end
            end
        elseif stm isa ParserCombinator.Parsers.DOT.Node
            if !(isempty(stm.attrs))
                for attr in stm.attrs
                    set!(attrs.nodes, get_id(attrs.nodes, String(stm.id.id.id)),
                        Property(String(attr.name.id), check_value(String(attr.value.id))))
                end
            end
        elseif stm isa ParserCombinator.Parsers.DOT.SubGraph
            if !isnothing(stm.id) # use only cluster as subgraphs.
                push!(attrs.subgraphs, gvSubGraph(String(stm.id.id)))
                set_subgraph!(attrs.subgraphs[end], stm, attrs.nodes, g.directed)
            else
                # all other subgraphs are lazy syntax
                attributes = Properties()
                for attr_sub in stm.stmts
                    if attr_sub isa ParserCombinator.Parsers.DOT.NodeAttributes
                        for attr in attr_sub.attrs
                            set!(attributes, String(attr.name.id), check_value(String(attr.value.id)))
                        end
                    end
                end

                # for all node in subgraph
                for attr_sub in stm.stmts
                    if attr_sub isa ParserCombinator.Parsers.DOT.Node
                        for single_attr in attributes
                            set!(attrs.nodes, get_id(attrs.nodes, String(attr_sub.id.id.id)), single_attr)
                        end
                    end

                end
            end


        end
    end

end


function set_subgraph!(subs::gvSubGraph, g::ParserCombinator.Parsers.DOT.SubGraph, nodes::gvNodes, directed::Bool)
    for stm in g.stmts
        if stm isa ParserCombinator.Parsers.DOT.SubGraph
            attrs3 = []
            for attr_sub in stm.stmts

                if attr_sub isa ParserCombinator.Parsers.DOT.NodeAttributes
                    for attr3 in attr_sub.attrs
                        set!(subs.node_options, String(attr3.name.id), check_value(String(attr3.value.id)))
                        push!(attrs3, attr3)
                    end

                elseif attr_sub isa ParserCombinator.Parsers.DOT.Node
                    push!(subs.nodes, gvNode(get_id(nodes, String(attr_sub.id.id.id)), String(attr_sub.id.id.id), Properties()))
                    for attr in attrs3
                        set!(subs.nodes, get_id(nodes, String(attr_sub.id.id.id)),
                            Property(String(attr.name.id), check_value(String(attr.value.id))))
                    end
                end
            end
        elseif stm isa ParserCombinator.Parsers.DOT.Node
            push!(subs.nodes, gvNode(get_id(nodes, String(stm.id.id.id)), String(stm.id.id.id), Properties()))
            for attr in stm.attrs
                set!(subs.nodes, get_id(nodes, String(stm.id.id.id)),
                    Property(String(attr.name.id), check_value(String(attr.value.id))))
                set!(subs.node_options, String(attr.name.id), check_value(String(attr.value.id)))
            end
        elseif stm isa ParserCombinator.Parsers.DOT.Attribute
            set!(subs.graph_options, String(stm.name.id), check_value(String(stm.value.id)))
        elseif stm isa ParserCombinator.Parsers.DOT.NodeAttributes
            for attr in stm.attrs
                set!(subs.node_options, String(attr.name.id), check_value(String(attr.value.id)))
            end
        elseif stm isa ParserCombinator.Parsers.DOT.EdgeAttributes
            for attr in stm.attrs
                set!(subs.edge_options, String(attr.name.id), check_value(String(attr.value.id)))
            end
        elseif stm isa ParserCombinator.Parsers.DOT.Edge
            for i = 1:(length(stm.nodes)-1)
                push!(subs.edges, gvEdge(get_id(nodes, String(stm.nodes[i].id.id)), get_id(nodes, String(stm.nodes[i+1].id.id)), Properties()))

                if (directed == false)
                    push!(subs.edges, gvEdge(get_id(nodes, String(stm.nodes[i+1].id.id)), get_id(nodes, String(stm.nodes[i].id.id)), Properties()))
                end

                if !(isempty(stm.attrs))
                    for attr in stm.attrs
                        set!(subs.edges, get_id(nodes, String(stm.nodes[i].id.id)), get_id(nodes, String(stm.nodes[i+1].id.id)),
                            Property(String(attr.name.id), check_value(String(attr.value.id))))
                        if (directed == false)
                            set!(subs.edges, get_id(nodes, String(stm.nodes[i+1].id.id)), get_id(nodes, String(stm.nodes[i].id.id)),
                                Property(String(attr.name.id), check_value(String(attr.value.id))))
                        end
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

        weight = val(attrs.edges, e.from, e.to, "xlabel")
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
        if (contains(value, "\"") == false)
            value = "\"" * value * "\""
        end
        # if isempty(value)
        #     value = "\" " * "\""
        # else
        #     for e in special_characters
        #         if (contains(value, e) == true)
        #             value = "\"" * value * "\""
        #             break
        #         end
        #     end
        # end
    end
    return value
end

function insert_at!(str::String, insert::String, at::Int)
    len = length(str)
    str_f = ""
    str_e = ""
    new_string = ""

    if (at > 0) && (at <= len)
        str_f = str[1:at-1]
        str_e = str[at:end]
        new_string = str_f * insert * str_e
    end

    return new_string
end



