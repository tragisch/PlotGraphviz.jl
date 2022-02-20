"""
    read_dot_file(file)

Import graph from DOT-Format and store it in file `SimpleWeightedGraph` or `SimpleWeightedDiGraph``.
Return AttributeDict for graph layouts.
ToDo: ERROR-Handling if not a suitable DOT-File is not implemented

#### Arguments
- `file::AbstractString`: the filename of dot-file (i.e. "graph.dot")
"""

struct node
    id::Int64
    name
end

#get max id of an array of node(s)
function _max_id(nodes)
    max = 0
    if !isempty(nodes)
        for n in nodes
            (n.id > max) ? max = n.id : nothing
        end
    end
    return max
end

# return
function _get_node(nodes, str)
    if !isempty(nodes)
        for n in nodes
            if str == n.name
                return n
            end
        end
    end
    return 0
end



function read_dot_file(filename::AbstractString)
    # to count total lines in the file
    node_count = 0

    directed = false

    # generate an AtributeDict
    attrs = AttributeDict()
    node_array = Vector{node}()


    # get size of graph
    f = open(filename, "r")
    for line in readlines(f)
        line_type = _read_dotline_simple(line)
        if line_type == "DiGraph"
            directed = true
        elseif line_type == "node"
            node_count += 1
        end
    end
    close(f)


    edge_array = []

    # get edges
    f = open(filename, "r")  ### ah, twice??
    for line in readlines(f)
        (line_type, nodes, weight, attrs, node_array) = _read_dotline(line, attrs, node_array)
        if line_type == "edge"
            push!(edge_array, (nodes, weight))
        end
    end
    # close file
    close(f)

    g_dim = _max_id(node_array)
    adj = zeros(g_dim, g_dim)

    for e in edge_array
        node = e[1]
        adj[node[1], node[2]] = e[2]
        if directed == false
            adj[node[2], node[1]] = e[2]
        end

    end

    if directed
        adj = adj'
        return SimpleWeightedDiGraph(adj), attrs
    else
        set!(attrs["G"], "concetrate", "true")
        return SimpleWeightedGraph(adj), attrs
    end

end

function _read_dotline_simple(str::String)
    tokens = collect(tokenize(str))
    (isempty(strip(str)) == true) ? line_type = nothing : line_type = _line_type(tokens)
    return line_type
end


function _read_dotline(str::String, attrs::AttributeDict, node_array)

    tokens = collect(tokenize(str))
    nodes = []
    weight = 1
    # get line_type
    (isempty(strip(str)) == true) ? line_type = nothing : line_type = _line_type(tokens)


    # call line-read function:
    if line_type == "Graph"
        # now?
    elseif line_type == "DiGraph"
        # now?
    elseif line_type == "graph"
        attrs = _read_graph_line!(attrs, tokens)
    elseif line_type == "node"
        attrs, node_array = _read_node_line!(attrs, tokens, node_array)
    elseif line_type == "edge"
        nodes, weight, attrs, node_array = _read_edge_line!(attrs, tokens, node_array)
    elseif (line_type == "node_options") || (line_type == "edge_options")
        attrs = _read_options_line!(attrs, tokens)
    elseif (line_type == "graph_options")

    end

    return (line_type, nodes, weight, attrs, node_array)

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
            set!(attrs, str_a, (k, a))
            # attrs[(k, str_a)] = a
        end
    end

    return attrs

end

function _read_edge_line!(attrs, tokens, node_array)
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
        elseif ((token.kind == Tokenize.Tokens.INTEGER) || (token.kind == Tokenize.Tokens.IDENTIFIER)) && (options == false)
            if child == false
                val, attrs, node_array = _set_node_array!(node_array, attrs, token.val)
                nodes[1] = val
                child = true
            else
                val, attrs, node_array = _set_node_array!(node_array, attrs, token.val)
                nodes[2] = val
                # child = false
            end

        elseif token.kind == Tokenize.Tokens.LSQUARE
            options = true
        elseif ((token.kind == Tokenize.Tokens.IDENTIFIER)
                || (token.kind == Tokenize.Tokens.INTEGER)
                || (token.kind == Tokenize.Tokens.FLOAT)
                || (token.kind == Tokenize.Tokens.STRING)
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
            set!(attrs, "E$pa-$kid", (k, a))
        end
    end

    # (weight != 1) ? attrs[("weights", "P")] = "true" : attrs[("weights", "P")] = "false"

    (weight != 1) ? set!(attrs, "P", ("weights", "true")) : set!(attrs, "P", ("weights", "false"))

    return nodes, weight, attrs, node_array

end

function _read_node_line!(attrs, tokens, node_array)
    node_number = 0
    options = false
    count = 0
    keys = []
    attributes = []

    for token in tokens
        # @show token
        if token.kind == Tokenize.Tokens.WHITESPACE
            continue
        elseif token.kind == Tokenize.Tokens.COMMA
            continue
        elseif ((token.kind == Tokenize.Tokens.INTEGER) || (token.kind == Tokenize.Tokens.IDENTIFIER)) && (options == false)
            val, attrs, node_array = _set_node_array!(node_array, attrs, token.val)
            node_number = val
            continue
        elseif token.kind == Tokenize.Tokens.LSQUARE
            options = true # ab jetzt zählst
        elseif ((token.kind == Tokenize.Tokens.IDENTIFIER)
                || (token.kind == Tokenize.Tokens.INTEGER)
                || (token.kind == Tokenize.Tokens.STRING)
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
            set!(attrs, "N$node_number", (k, a))
        end
    end

    return attrs, node_array

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
                || (token.kind == Tokenize.Tokens.STRING)
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
    set!(attrs, "G", (str_key, str_attribute))
    return attrs
end

# determine line_type (for future enhancements)
function _line_type(tokens)
    line_type = "node"
    start_options = false
    for token in tokens
        if token.val == "digraph"
            return "DiGraph"
        elseif token.val == "graph"
            return "Graph"
        elseif token.val == "//"
            return "commentary"
        elseif token.val == "node"
            return "node_options"
        elseif token.val == "edge"
            return "edge_options"
        elseif ((Tokenize.Tokens.exactkind(token) == Tokenize.Tokens.ANON_FUNC)
                ||
                (Tokenize.Tokens.exactkind(token) == Tokenize.Tokens.ERROR))
            return "edge"
        elseif token.kind == Tokenize.Tokens.LSQUARE
            start_options = true
            idx_LSQARE = token.startpos[2]
        elseif (token.kind == Tokenize.Tokens.EQ) && (start_options == false)
            return "graph"
        elseif (token.kind == Tokenize.Tokens.RBRACE)
            return "nothing"
        end
    end
    return line_type
end

# set node_array and AttributeDict and return node_id
function _set_node_array!(node_array, attrs, val)
    n = _get_node(node_array, val)
    if n != 0
        return n.id, attrs, node_array
    else
        if !(isequal(tryparse(Int, val), nothing))
            node_id = parse(Int, val)
        else
            node_id = _max_id(node_array) + 1
        end
        push!(node_array, node(node_id, val))

        set!(attrs, "N$node_id", ("label", val))

        return node_id, attrs, node_array
    end
end

