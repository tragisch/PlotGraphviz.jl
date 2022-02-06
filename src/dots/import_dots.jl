"""
    read_dot_file(file)

Import graph from DOT-Format and store it in file `SimpleWeightedGraph` or `SimpleWeightedDiGraph``.
ToDo: ERROR-Handling if not a suitable DOT-File is not implemented

#### Arguments
- `file::AbstractString`: the filename of dot-file (i.e. "graph.dot")
"""
function read_dot_file(filename::AbstractString)
    # to count total lines in the file
    node_count = 0

    directed = false


    # get size of graph
    f = open(filename, "r")
    for line in readlines(f)
        (line_type, nodes, weight) = _read_dotline(line)
        if line_type == "digraph"
            directed = true
        elseif line_type == "node"
            node_count += 1
        end
    end
    close(f)

    adj = zeros(node_count - 1, node_count - 1)

    # get edges
    f = open(filename, "r")
    for line in readlines(f)
        (line_type, nodes, weight) = _read_dotline(line)
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
        return SimpleWeightedDiGraph(adj)
    else
        return SimpleWeightedGraph(adj)
    end

end


function _read_dotline(str::String)

    tokens = collect(tokenize(str))
    start_options = false
    weight_identifier = false
    weight = 1.0
    nodes = (Int)[]
    line_type = "node"
    idx_LSQARE = 0

    # handle input and identify edge, node or graph_line
    for token in tokens

        if token.val == "digraph"
            line_type = "digraph"
            break
        elseif token.val == "graph"
            line_type = "graph"
            break
        elseif token.kind == Tokenize.Tokens.INTEGER
            if weight_identifier == true
                weight = parse(Float64, token.val)
                weight_identifier = false
            else
                push!(nodes, parse(Int64, token.val))
            end
        elseif (Tokenize.Tokens.exactkind(token) == Tokenize.Tokens.ANON_FUNC) || Tokenize.Tokens.exactkind(token) == Tokenize.Tokens.ERROR
            line_type = "edge"
        elseif token.kind == Tokenize.Tokens.IDENTIFIER
            (token.val == "xlabel") ? weight_identifier = true : weight_identifier = false
        elseif token.kind == Tokenize.Tokens.FLOAT && (weight_identifier == true)
            weight = parse(Float64, token.val)
            weight_identifier = false
        elseif token.kind == Tokenize.Tokens.LSQUARE
            start_options = true
            idx_LSQARE = token.startpos[2]
        elseif token.kind == Tokenize.Tokens.EQ && (start_options == false)
            line_type = "graph"
        end
    end



    return (line_type, nodes, weight)

end

