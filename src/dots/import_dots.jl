"""
    read_dot_file(file)

Import graph from DOT-Format and store it in file `SimpleWeightedGraph` or `SimpleWeightedDiGraph``.
Return AttributeDict for graph layouts.
ToDo: ERROR-Handling if not a suitable DOT-File is not implemented

#### Arguments
- `file::AbstractString`: the filename of dot-file (i.e. "graph.dot")
"""
function read_dot_file(filename::AbstractString)
    # to count total lines in the file
    node_count = 0

    directed = false

    # generate an AtributeDict
    attrs = AttributeDict()


    # get size of graph
    f = open(filename, "r")
    for line in readlines(f)
        (line_type, nodes, weight, attrs) = _read_dotline(line, attrs)
        if line_type == "DiGraph"
            directed = true
        elseif line_type == "node"
            node_count += 1
        end
    end
    close(f)

    adj = zeros(node_count - 1, node_count - 1)

    # get edges
    f = open(filename, "r")  ### ah, twice??
    for line in readlines(f)
        (line_type, nodes, weight, attrs) = _read_dotline(line, attrs)
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
        return SimpleWeightedDiGraph(adj), attrs
    else
        return SimpleWeightedGraph(adj), attrs
    end

end


function _read_dotline(str::String, attrs::AttributeDict)

    tokens = collect(tokenize(str))
    nodes = []
    weight = 1
    # get line_type
    line_type = _line_type(tokens)

    # call line-read function:
    if line_type == "Graph"
        # now?
    elseif line_type == "DiGraph"
        # now?
    elseif line_type == "graph"
        attrs = _read_graph_line!(attrs, tokens)
    elseif line_type == "node"
        attrs = _read_node_line!(attrs, tokens)
    elseif line_type == "edge"
        nodes, weight, attrs = _read_edge_line!(attrs, tokens)
    elseif (line_type == "node_options") || (line_type == "edge_options")
        attrs = _read_options_line!(attrs, tokens)
    end

    return (line_type, nodes, weight, attrs)

end

function _read_options_line!(attrs, tokens)
    options = false
    count = 0
    keys = []
    attributes = []
    edge_node = ""

    for token in tokens
        if token.kind == Tokenize.Tokens.WHITESPACE
            continue
        elseif (token.kind == Tokenize.Tokens.COMMA) || (token.kind == Tokenize.Tokens.OP)
            continue
        elseif (token.kind == Tokenize.Tokens.INTEGER) && (options == false)
            continue
        elseif (token.kind == Tokenize.Tokens.IDENTIFIER) && (options == false)
            edge_node = token.val
        elseif token.kind == Tokenize.Tokens.LSQUARE
            options = true # ab jetzt zählst
        elseif ((token.kind == Tokenize.Tokens.IDENTIFIER)
                || (token.kind == Tokenize.Tokens.INTEGER)
                || (token.kind == Tokenize.Tokens.FLOAT)
                || (token.kind == Tokenize.Tokens.TRUE)
                || (token.kind == Tokenize.Tokens.FALSE)) && (options == true)
            if count == 0
                count = 1
                push!(keys, token.val)
            else
                count = 0
                push!(attributes, token.val)
            end
        end
    end

    (edge_node == "node") ? str_a = "N" : str_a = "E"

    if !isempty(keys)
        for (k, a) in zip(keys, attributes)
            attrs[(k, str_a)] = a
        end
    end

    return attrs

end

function _read_edge_line!(attrs, tokens)
    nodes = zeros(Int64, 2)
    child = false
    options = false
    count = 0
    keys = []
    attributes = []
    weight = 1
    weight_identifier = false

    for token in tokens
        if token.kind == Tokenize.Tokens.WHITESPACE
            continue
        elseif (token.kind == Tokenize.Tokens.COMMA) || (token.kind == Tokenize.Tokens.OP)
            continue
        elseif (token.kind == Tokenize.Tokens.INTEGER) && (options == false)
            if child == false
                nodes[1] = parse(Int64, token.val)
                child = true
            else
                nodes[2] = parse(Int64, token.val)
            end
        elseif token.kind == Tokenize.Tokens.LSQUARE
            options = true
        elseif ((token.kind == Tokenize.Tokens.IDENTIFIER)
                || (token.kind == Tokenize.Tokens.INTEGER)
                || (token.kind == Tokenize.Tokens.FLOAT)
                || (token.kind == Tokenize.Tokens.TRUE)
                || (token.kind == Tokenize.Tokens.FALSE)) && (options == true) && (weight_identifier == false)

            if (token.val == "xlabel")
                weight_identifier = true
            else

                if count == 0
                    count = 1
                    push!(keys, token.val)
                else
                    count = 0
                    push!(attributes, token.val)
                end
            end
        elseif ((token.kind == Tokenize.Tokens.FLOAT)
                ||
                (token.kind == Tokenize.Tokens.INTEGER)) && (weight_identifier == true)
            weight = parse(Float64, token.val)
            weight_identifier = false
        end

    end

    if !isempty(keys)
        for (k, a) in zip(keys, attributes)
            pa = nodes[1]
            kid = nodes[2]
            attrs[(k, "E$pa-$kid")] = a
        end
    end

    (weight != 1) ? attrs[("weights", "P")] = "true" : attrs[("weights", "P")] = "false"

    return nodes, weight, attrs

end

function _read_node_line!(attrs, tokens)
    node_number = 0
    options = false
    count = 0
    keys = []
    attributes = []

    for token in tokens
        if token.kind == Tokenize.Tokens.WHITESPACE
            continue
        elseif token.kind == Tokenize.Tokens.COMMA
            continue
        elseif (token.kind == Tokenize.Tokens.INTEGER) && (options == false)
            node_number = token.val
            continue
        elseif token.kind == Tokenize.Tokens.LSQUARE
            options = true # ab jetzt zählst
        elseif ((token.kind == Tokenize.Tokens.IDENTIFIER)
                || (token.kind == Tokenize.Tokens.INTEGER)
                || (token.kind == Tokenize.Tokens.FLOAT)
                || (token.kind == Tokenize.Tokens.TRUE)
                || (token.kind == Tokenize.Tokens.FALSE)) && (options == true)
            if count == 0
                count = 1
                push!(keys, token.val)
            else
                count = 0
                push!(attributes, token.val)
            end
        end
    end

    if !isempty(keys)
        for (k, a) in zip(keys, attributes)
            attrs[(k, "N$node_number")] = a
        end
    end

    return attrs

end

function _read_graph_line!(attrs, tokens)
    str_key = ""
    str_attribute = ""

    count = 0
    for token in tokens
        if token.kind == Tokenize.Tokens.WHITESPACE
            continue
        elseif token.kind == Tokenize.Tokens.OP
            continue
        elseif ((token.kind == Tokenize.Tokens.IDENTIFIER)
                || (token.kind == Tokenize.Tokens.INTEGER)
                || (token.kind == Tokenize.Tokens.FLOAT)
                || (token.kind == Tokenize.Tokens.TRUE)
                || (token.kind == Tokenize.Tokens.FALSE))

            if count == 0
                str_key = token.val
                count = count + 1
            else
                str_attribute = token.val
                break
            end
        end
    end
    attrs[(str_key, "G")] = str_attribute
    return attrs
end

# determine line_type (for future enhancements)
function _line_type(tokens)
    line_type = "node"
    start_options = false
    for token in tokens
        if token.val == "digraph"
            line_type = "DiGraph"
            break
        elseif token.val == "graph"
            line_type = "Graph"
            break
        elseif token.val == "node"
            line_type = "node_options"
            break
        elseif token.val == "edge"
            line_type = "edge_options"
            break
        elseif ((Tokenize.Tokens.exactkind(token) == Tokenize.Tokens.ANON_FUNC)
                ||
                (Tokenize.Tokens.exactkind(token) == Tokenize.Tokens.ERROR))
            line_type = "edge"
            break
        elseif token.kind == Tokenize.Tokens.LSQUARE
            start_options = true
            idx_LSQARE = token.startpos[2]
        elseif (token.kind == Tokenize.Tokens.EQ) && (start_options == false)
            line_type = "graph"
        end
    end
    return line_type
end

