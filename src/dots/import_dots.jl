"""
    read_dot_file(file)

Import graph from DOT-Format and store it in file `SimpleWeightedGraph` or `SimpleWeightedDiGraph``.
Return AttributeDict for graph layouts.
ToDo: ERROR-Handling if not a suitable DOT-File is not implemented

#### Arguments
- `file::AbstractString`: the filename of dot-file (i.e. "graph.dot")
"""
function read_dot_file(filename::AbstractString)

    # Prefer parsing the raw DOT source to preserve structure.
    # Fallback to legacy preprocessing for DOT variants that the parser
    # cannot handle directly (e.g. `node [attrs] n1 n2;` style blocks).
    my_graph = read_graph(filename)

    graphs_parser_combinator = try
        try_parse_dot_robust(my_graph, filename)
    catch err
        return read_dot_file_via_plain_fallback(my_graph, err)
    end

    # use first graph (toDo for more graphs)  !!! TODO
    if length(graphs_parser_combinator) == 1
        graph_parser_combinator = graphs_parser_combinator[1]
    else
        graph_parser_combinator = graphs_parser_combinator[1]
    end

    attrs = init_Attributes!(graph_parser_combinator)

    # set! attributes
    set_attributes!(attrs, graph_parser_combinator)

    # postprocessing
    postprocessing!(attrs)

    # get AbstractSimpleWeightedGraph
    g = get_AbstractSimpleWeightedGraph(attrs)

    n = nv(g)
    large_graph = 200
    if n > large_graph
        attrs = mod_attr_large_network!(attrs)
    end

    return g, attrs
end

function read_dot_file_via_plain_fallback(raw_dot::AbstractString, original_err)
    directed = detect_dot_directed(raw_dot)
    prog = directed ? "dot" : "neato"

    io = IOBuffer()
    try
        run_graphviz(io, raw_dot; prog=prog, format="plain")
    catch
        rethrow(original_err)
    end

    plain = String(take!(io))
    attrs = graphviz_attributes_from_plain(plain; directed=directed)
    g = get_AbstractSimpleWeightedGraph(attrs)
    return g, attrs
end

function detect_dot_directed(dot_text::AbstractString)
    return !isnothing(match(r"(?im)^\s*(strict\s+)?digraph\b", dot_text))
end

function graphviz_attributes_from_plain(plain::AbstractString; directed::Bool)
    ordered_names = String[]
    seen_names = Set{String}()
    raw_edges = Tuple{String,String}[]

    for raw_line in split(plain, '\n')
        line = strip(raw_line)
        isempty(line) && continue

        if startswith(line, "node ")
            parts = split(line)
            length(parts) >= 2 || continue
            name = parts[2]
            if !(name in seen_names)
                push!(ordered_names, name)
                push!(seen_names, name)
            end
            continue
        end

        if startswith(line, "edge ")
            parts = split(line)
            length(parts) >= 3 || continue
            push!(raw_edges, (parts[2], parts[3]))
        end
    end

    name_to_id = Dict{String,Int}(name => i for (i, name) in enumerate(ordered_names))

    nodes = gvNodes()
    for (i, name) in enumerate(ordered_names)
        push!(nodes, gvNode(i, name, [Property("label", check_value(name))]))
    end

    edges = gvEdges()
    for (from_name, to_name) in raw_edges
        from_id = get(name_to_id, from_name, 0)
        to_id = get(name_to_id, to_name, 0)
        if from_id == 0 || to_id == 0
            continue
        end

        push!(edges, gvEdge(from_id, to_id, Properties()))
        if !directed
            push!(edges, gvEdge(to_id, from_id, Properties()))
        end
    end

    plot_options = [Property("directed", directed)]
    graph_options = Properties()
    node_options = Properties()
    edge_options = Properties()
    subgraphs = gvSubGraphs()

    return GraphvizAttributes(plot_options, graph_options, node_options, edge_options, subgraphs, nodes, edges)
end

function try_parse_dot_robust(raw_dot::AbstractString, filename::AbstractString)
    last_err = nothing

    try
        return ParserCombinator.Parsers.DOT.parse_dot(raw_dot)
    catch err
        last_err = err
    end

    # Some DOT files use compact node statements like
    #   node [shape=box] a b c;
    # which are valid DOT but not always accepted by ParserCombinator directly.
    # Normalize this shape first, while preserving subgraph structure.
    normalized = normalize_compact_node_statements(raw_dot)
    try
        return ParserCombinator.Parsers.DOT.parse_dot(normalized)
    catch err
        last_err = err
    end

    # Graphviz canonicalization is a robust fallback for parser edge-cases
    # (charset oddities, exotic statement forms, implicit defaults).
    try
        canon = normalize_with_graphviz_canon(raw_dot)
        return ParserCombinator.Parsers.DOT.parse_dot(canon)
    catch err
        last_err = err
    end

    # Final fallback: legacy preprocessing for additional loose DOT variants.
    try
        return ParserCombinator.Parsers.DOT.parse_dot(preprocessing(filename))
    catch err
        throw(last_err === nothing ? err : last_err)
    end
end

function normalize_with_graphviz_canon(dot_text::AbstractString)
    io = IOBuffer()
    run_graphviz(io, dot_text; prog="dot", format="canon")
    return String(take!(io))
end

function normalize_compact_node_statements(dot_text::AbstractString)
    lines = split(dot_text, '\n'; keepempty=true)
    out = String[]

    for line in lines
        m = match(r"^(\s*)node\s*(\[[^\]]+\])\s+([^;{}]+);\s*$", line)
        if isnothing(m)
            push!(out, line)
            continue
        end

        indent = m.captures[1]
        attr_block = m.captures[2]
        nodes_part = m.captures[3]

        push!(out, string(indent, "node ", attr_block, ";"))
        for node_name in split(nodes_part, r"[\s,]+")
            isempty(node_name) && continue
            push!(out, string(indent, node_name, ";"))
        end
    end

    return join(out, "\n")
end

function openfile(filename)
    f = open(filename, "r")
    lines = readlines(f)
    close(f)
    lines
end

function read_lines(filename::AbstractString)
    lines = openfile(filename)
    lines = delete_comments(lines)
    lines = small_corrections(lines)

    return Base.join(lines, "\n")
end

function parse_dot_file(my_graph)
    graphs_parser_combinator = ParserCombinator.Parsers.DOT.parse_dot(my_graph)

    return graphs_parser_combinator[1]
end

parse_my_dot(my_graph; debug=false) = ParserCombinator.Parsers.DOT.parse_dot(my_graph)

function delete_comments(lines)
    new_lines = []
    for line in lines
        if !isnothing(findfirst("//", lstrip(line))) || !isnothing(findfirst("/*", lstrip(line))) || !isnothing(findfirst("*", lstrip(line))) || isempty(line)
            continue
        end
        push!(new_lines, line)
    end
    return new_lines
end

function small_corrections(lines)
    return map(lines) do line
        line = replace(line, "\t" => "")
        line = replace(line, " ]" => "]")
        line = replace(line, "[ " => "[")
        replace(line, ";" => ";\n")
    end
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
        line = replace(line, ";" => ";\n")
        # line = replace(line, "node" => "\n node")
        # line = replace(line, "edge" => "\n edge")
        # line = replace(line, "graph" => "\n graph")

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
            if !isnothing(optionend)
                if !(isempty(lstrip(line[(optionend.stop+1):end])))
                    if (lstrip(line[optionend.stop+1:optionend.stop+1]) == "\"")
                        optionend = findlast("]", line)
                    end
                end
            end

            # if there are node,egde or graph options:
            if !isnothing(findfirst("node", line)) || !isnothing(findfirst("edge", line)) || !isnothing(findfirst("graph", line))
                if !isnothing(optionend)
                    if !(isempty(lstrip(line[(optionend.stop+1):end]))) && !(lstrip(line[(optionend.stop+1):end]) == ";") && !(lstrip(line[(optionend.stop+1):end]) == ";\n") && (isnothing(findfirst("[", line[(optionend.stop+1):end])))

                        str = "subgraph {\n " * line * " \n}"
                        push!(new_lines, str)
                        continue
                    else
                        push!(new_lines, line)
                        continue
                    end
                end
            end

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

                        if !(isempty(lstrip(line[(optionend.stop+1):end]))) && !(lstrip(line[(optionend.stop+1):end]) == ";")

                            # @show lstrip(line[(optionend.stop+1):end])
                            if !isnothing(findfirst("[", line[optionend.stop:end]))
                                push!(new_lines, line)
                                continue

                            elseif isnothing(findfirst("{", line[optionend.stop:end]))

                                if (isempty(lstrip(line[(optionend.stop+1):end]))) # !(lstrip(line[(optionend.stop+1):end]) == ";") && 
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
                    temp = replace(temp, ";" => ";\n")
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
    #for line in new_lines
    #    @show line
    #end


    return Base.join(new_lines, "\n")
end

function postprocessing!(attrs)

    # subgraph
    for subg in attrs.subgraphs
        for s_node in subg.nodes
            sub_n_id = s_node.id
            for node in attrs.nodes
                if node.id == sub_n_id
                    for prop in node.attributes
                        has_key, pos = haskey(s_node.attributes, prop.key)
                        if has_key
                            rm!(node.attributes, prop.key)
                        end
                    end
                end
            end
        end
    end

end


function read_graph(filename)
    bytes = read(filename)
    return decode_dot_source(bytes)
end

function decode_dot_source(bytes::Vector{UInt8})
    # Fast path for regular UTF-8 DOT files.
    if isvalid(String, bytes)
        return String(bytes)
    end

    # If the source advertises Latin-1, decode byte-for-byte into U+00xx.
    # This preserves labels like in Graphviz's Latin1 sample files.
    charset = detect_dot_charset(bytes)
    if charset == "latin1"
        return String(Char.(bytes))
    end

    # Fallback for other non-UTF-8 sources: preserve byte values instead of
    # replacing them with unknown characters, so parsing/rendering keeps data.
    return String(Char.(bytes))
end

function detect_dot_charset(bytes::Vector{UInt8})
    lowered = lowercase_ascii(bytes)
    text = String(Char.(lowered))

    m = match(r"charset\s*=\s*\"?([a-z0-9_\-]+)\"?", text)
    return isnothing(m) ? "" : String(m.captures[1])
end

function lowercase_ascii(bytes::Vector{UInt8})
    out = similar(bytes)
    for i in eachindex(bytes)
        b = bytes[i]
        out[i] = (0x41 <= b <= 0x5a) ? (b + 0x20) : b
    end
    return out
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

function _push_unique!(items::Vector{String}, value::String)
    if !(value in items)
        push!(items, value)
    end
    return items
end

function _dot_endpoint_node_names(endpoint)
    names = String[]

    if endpoint isa ParserCombinator.Parsers.DOT.NodeID
        if !isnothing(endpoint.id)
            _push_unique!(names, String(endpoint.id.id))
        end
    elseif endpoint isa ParserCombinator.Parsers.DOT.Node
        if !isnothing(endpoint.id)
            _push_unique!(names, String(endpoint.id.id.id))
        end
    elseif endpoint isa ParserCombinator.Parsers.DOT.SubGraph
        for stm in endpoint.stmts
            if stm isa ParserCombinator.Parsers.DOT.Node
                if !isnothing(stm.id)
                    _push_unique!(names, String(stm.id.id.id))
                end
            elseif stm isa ParserCombinator.Parsers.DOT.SubGraph
                for name in _dot_endpoint_node_names(stm)
                    _push_unique!(names, name)
                end
            elseif stm isa ParserCombinator.Parsers.DOT.Edge
                for edge_endpoint in stm.nodes
                    for name in _dot_endpoint_node_names(edge_endpoint)
                        _push_unique!(names, name)
                    end
                end
            end
        end
    end

    return names
end

function _edge_endpoint_ids(nodes::gvNodes, endpoint)
    ids = Int[]
    seen = Set{Int}()
    for node_name in _dot_endpoint_node_names(endpoint)
        node_id = get_id(nodes, node_name)
        if (node_id > 0) && !(node_id in seen)
            push!(ids, node_id)
            push!(seen, node_id)
        end
    end
    return ids
end

function _edge_endpoint_id_names(nodes::gvNodes, endpoint)
    pairs = Tuple{Int,String}[]
    seen = Set{Int}()
    for node_name in _dot_endpoint_node_names(endpoint)
        node_id = get_id(nodes, node_name)
        if (node_id > 0) && !(node_id in seen)
            push!(pairs, (node_id, node_name))
            push!(seen, node_id)
        end
    end
    return pairs
end

function set_attributes!(attrs, g)
    active_node_attrs = Properties()
    active_edge_attrs = Properties()

    for stm in g.stmts

        if stm isa ParserCombinator.Parsers.DOT.Attribute
            set!(attrs.graph_options, String(stm.name.id), check_value(String(stm.value.id)))
        elseif stm isa ParserCombinator.Parsers.DOT.GraphAttributes
            for attr in stm.attrs
                set!(attrs.graph_options, String(attr.name.id), check_value(String(attr.value.id)))
            end
        elseif stm isa ParserCombinator.Parsers.DOT.NodeAttributes
            for attr in stm.attrs
                prop = Property(String(attr.name.id), check_value(String(attr.value.id)))
                set!(attrs.node_options, prop)
                set!(active_node_attrs, prop)
            end
        elseif stm isa ParserCombinator.Parsers.DOT.EdgeAttributes
            for attr in stm.attrs
                prop = Property(String(attr.name.id), check_value(String(attr.value.id)))
                set!(attrs.edge_options, prop)
                set!(active_edge_attrs, prop)
            end
        elseif stm isa ParserCombinator.Parsers.DOT.Edge

            for i = 1:(length(stm.nodes)-1)
                from_ids = _edge_endpoint_ids(attrs.nodes, stm.nodes[i])
                to_ids = _edge_endpoint_ids(attrs.nodes, stm.nodes[i+1])

                if isempty(from_ids) || isempty(to_ids)
                    continue
                end

                for from_id in from_ids
                    for to_id in to_ids
                        for prop in active_edge_attrs
                            set!(attrs.edges, from_id, to_id,
                                Property(prop.key, prop.value); override=true)

                            if (g.directed == false)
                                set!(attrs.edges, to_id, from_id,
                                    Property(prop.key, prop.value); override=true)
                            end
                        end
                    end
                end
            end

            if !(isempty(stm.attrs))
                for i = 1:(length(stm.nodes)-1)
                    from_ids = _edge_endpoint_ids(attrs.nodes, stm.nodes[i])
                    to_ids = _edge_endpoint_ids(attrs.nodes, stm.nodes[i+1])

                    if isempty(from_ids) || isempty(to_ids)
                        continue
                    end

                    for from_id in from_ids
                        for to_id in to_ids
                            for attr in stm.attrs
                                set!(attrs.edges, from_id, to_id,
                                    Property(String(attr.name.id), check_value(String(attr.value.id))); override=true)

                                if (g.directed == false)
                                    set!(attrs.edges, to_id, from_id,
                                        Property(String(attr.name.id), check_value(String(attr.value.id))); override=true)
                                end
                            end
                        end
                    end
                end
            end
        elseif stm isa ParserCombinator.Parsers.DOT.Node
            for prop in active_node_attrs
                set!(attrs.nodes, get_id(attrs.nodes, String(stm.id.id.id)),
                    Property(prop.key, prop.value))
            end
            if !(isempty(stm.attrs))
                for attr in stm.attrs
                    set!(attrs.nodes, get_id(attrs.nodes, String(stm.id.id.id)),
                        Property(String(attr.name.id), check_value(String(attr.value.id))))
                end
            end
        elseif stm isa ParserCombinator.Parsers.DOT.SubGraph
            if !isnothing(stm.id) # use only cluster as subgraphs.
                push!(attrs.subgraphs, gvSubGraph(String(stm.id.id)))
            else
                push!(attrs.subgraphs, gvSubGraph(""))
            end
            set_subgraph!(attrs.subgraphs[end], stm, attrs.nodes, g.directed;
                inherited_node_attrs=active_node_attrs,
                inherited_edge_attrs=active_edge_attrs)
            # else

            #     # all other subgraphs are lazy syntax
            #     attributes = Properties()
            #     for attr_sub in stm.stmts
            #         @show attr_sub
            #         if attr_sub isa ParserCombinator.Parsers.DOT.NodeAttributes
            #             for attr in attr_sub.attrs
            #                 set!(attributes, String(attr.name.id), check_value(String(attr.value.id)))
            #             end
            #         end
            #     end

            #     # for all node in subgraph
            #     for attr_sub in stm.stmts
            #         if attr_sub isa ParserCombinator.Parsers.DOT.Node
            #             for single_attr in attributes
            #                 set!(attrs.nodes, get_id(attrs.nodes, String(attr_sub.id.id.id)), single_attr)
            #             end
            #         end

            #     end
            # end


        end
    end

end


function set_subgraph!(subs::gvSubGraph, g::ParserCombinator.Parsers.DOT.SubGraph, nodes::gvNodes, directed::Bool;
    inherited_node_attrs::Properties=Properties(),
    inherited_edge_attrs::Properties=Properties(),
)
    attrs3 = [Property(prop.key, prop.value) for prop in inherited_node_attrs]
    edge_attrs3 = [Property(prop.key, prop.value) for prop in inherited_edge_attrs]
    for stm in g.stmts

        if stm isa ParserCombinator.Parsers.DOT.SubGraph
            for attr_sub in stm.stmts

                if attr_sub isa ParserCombinator.Parsers.DOT.NodeAttributes
                    attrs3 = [Property(prop.key, prop.value) for prop in inherited_node_attrs]
                    for attr3 in attr_sub.attrs
                        set!(subs.node_options, String(attr3.name.id), check_value(String(attr3.value.id)))
                        push!(attrs3, Property(String(attr3.name.id), check_value(String(attr3.value.id))))
                    end

                elseif attr_sub isa ParserCombinator.Parsers.DOT.Node
                    push!(subs.nodes, gvNode(get_id(nodes, String(attr_sub.id.id.id)), String(attr_sub.id.id.id), Properties()))
                    for attr in attrs3
                        set!(subs.nodes, get_id(nodes, String(attr_sub.id.id.id)),
                            Property(attr.key, attr.value))
                    end
                end
            end

        elseif stm isa ParserCombinator.Parsers.DOT.Node
            push!(subs.nodes, gvNode(get_id(nodes, String(stm.id.id.id)), String(stm.id.id.id), Properties()))
            for attr in attrs3
                set!(subs.nodes, get_id(nodes, String(stm.id.id.id)),
                    Property(attr.key, attr.value))
            end

            for attr in stm.attrs
                set!(subs.nodes, get_id(nodes, String(stm.id.id.id)),
                    Property(String(attr.name.id), check_value(String(attr.value.id))))
            end

        elseif stm isa ParserCombinator.Parsers.DOT.Attribute
            set!(subs.graph_options, String(stm.name.id), check_value(String(stm.value.id)))

        elseif stm isa ParserCombinator.Parsers.DOT.GraphAttributes

            for attr in stm.attrs
                set!(subs.graph_options, String(attr.name.id), check_value(String(attr.value.id)))
            end

        elseif stm isa ParserCombinator.Parsers.DOT.NodeAttributes
            attrs3 = [Property(prop.key, prop.value) for prop in inherited_node_attrs]
            for attr in stm.attrs
                set!(subs.node_options, String(attr.name.id), check_value(String(attr.value.id)))
                push!(attrs3, Property(String(attr.name.id), check_value(String(attr.value.id))))
            end
        elseif stm isa ParserCombinator.Parsers.DOT.EdgeAttributes
            edge_attrs3 = [Property(prop.key, prop.value) for prop in inherited_edge_attrs]
            for attr in stm.attrs
                set!(subs.edge_options, String(attr.name.id), check_value(String(attr.value.id)))
                push!(edge_attrs3, Property(String(attr.name.id), check_value(String(attr.value.id))))
            end
        elseif stm isa ParserCombinator.Parsers.DOT.Edge
            for i = 1:(length(stm.nodes)-1)
                from_pairs = _edge_endpoint_id_names(nodes, stm.nodes[i])
                to_pairs = _edge_endpoint_id_names(nodes, stm.nodes[i+1])

                if isempty(from_pairs) || isempty(to_pairs)
                    continue
                end

                for (from_id, from_name) in from_pairs
                    for (to_id, to_name) in to_pairs

                        # Track implicit subgraph nodes that only appear in edge statements,
                        # so subgraph node defaults and explicit node overrides can be rendered.
                        if get_node(subs.nodes, from_id) == []
                            push!(subs.nodes, gvNode(from_id, from_name, Properties()))
                        end
                        if get_node(subs.nodes, to_id) == []
                            push!(subs.nodes, gvNode(to_id, to_name, Properties()))
                        end

                        push!(subs.edges, gvEdge(from_id, to_id, Properties()))

                        if (directed == false)
                            push!(subs.edges, gvEdge(to_id, from_id, Properties()))
                        end

                        for prop in edge_attrs3
                            set!(subs.edges, from_id, to_id,
                                Property(prop.key, prop.value))
                            if (directed == false)
                                set!(subs.edges, to_id, from_id,
                                    Property(prop.key, prop.value))
                            end
                        end

                        if !(isempty(stm.attrs))
                            for attr in stm.attrs
                                set!(subs.edges, from_id, to_id,
                                    Property(String(attr.name.id), check_value(String(attr.value.id))))
                                if (directed == false)
                                    set!(subs.edges, to_id, from_id,
                                        Property(String(attr.name.id), check_value(String(attr.value.id))))
                                end
                            end
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

function check_value(value::T) where {T}
    if value isa String
        if (contains(value, "\"") == false)
            value = "\"" * value * "\""
        end
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

