

# internal functions to identify strings:
_to_dot(sym::Symbol, value::String) = "$sym=$value"
_graph_type_string(graph::AbstractSimpleWeightedGraph) = Graphs.is_directed(graph) ? "digraph" : "graph"
_edge_op(graph::AbstractSimpleWeightedGraph) = Graphs.is_directed(graph) ? "->" : "--"

# internal function to get the dot representation of a graph as a string.
function _to_dot(graph::AbstractSimpleWeightedGraph; attributes::AttributeDict = get_attributes(graph), path = [], colors = zeros(Int, nv(g)))
    str = IOBuffer()
    _to_dot(graph, str, attributes; path = path, colors = colors)
    String(take!(str)) #takebuf_string(str)
end

# internal function DOT-Language representation:
function _to_dot(mat::AbstractSimpleWeightedGraph, stream::IO, attrs::AttributeDict;
    path = [], # path in network
    colors = zeros(Int, nv(mat))) # components colors

    # standard colorscheme (max 9)
    if (!_is_all_zero(colors))  # ToDo: no hardcoded part!!!!
        if maximum(colors) > 9
            colors = _reduce_colors!(colors)
        end
        color_scheme = "colorscheme=set19"
        color = true
    else
        colors = zeros(Int, nv(mat))
        color = false
    end

    # check if `weighted` and labeled:
    edge_label = false
    if haskey(attrs, :weights)
        attr_ = attrs[:weights][2]
        (attr_ == "true") ? edge_label = true : edge_label = false
    end
    # write DOT:
    write(stream, "$(_graph_type_string(mat)) graphname {\n")
    G = "G"
    write(stream, " $(_parse_attributes(mat,attrs, G))\n")
    (color == true) ? write(stream, " node [$color_scheme]\n") : nothing
    n_vertices = nv(mat)
    N = "N"
    for node = 1:n_vertices
        if color && (colors[node] > 0)
            color_node = ",color=$(colors[node])]"
        elseif !isempty(path) && !Base.isnothing(findfirst(isequal(node), path))
            color_node = ",color=red]"
        else
            color_node = "]"
        end
        write(stream, " $node $(_parse_attributes(mat,attrs, N)) $color_node;\n")
    end
    for node = 1:n_vertices
        childs = Graphs.inneighbors(mat, node)
        # childs = WeightedNetwork.children(mat, node)
        E = "E"
        for kid in childs
            # if n_vertices > kid # seems to be wrong / to think about that.
            if color && (colors[node] > 0) && (colors[kid] > 0)
                edge_node = ",color=$(colors[node])]"
            elseif !isempty(path) && !Base.isnothing(findfirst(isequal(node), path)) && !Base.isnothing(findfirst(isequal(kid), path)) && (kid != path[1])
                edge_node = ",color=red]"
            else
                edge_node = "]"
            end

            if edge_label
                w = mat.weights[node, kid]
                write(stream, " $node $(_edge_op(mat)) $kid $(_parse_attributes(mat,attrs, E)), xlabel=$w $edge_node;\n")
            else
                write(stream, " $node $(_edge_op(mat)) $kid $(_parse_attributes(mat,attrs, E)) $edge_node;\n")
            end
            # end
        end

    end
    write(stream, "}\n")
    return stream
end

# helper function to reduze colors 
function _reduce_colors!(components)
    n = length(components)
    cz = zeros(Int, n)
    co = deepcopy(components)
    min = 1
    while true
        for i = 1:n
            cz[i] = length(findall(x -> x == co[i], co))
        end
        idx = findall(x -> x < min, cz)
        co[idx] .= 0

        j = 1
        ma = maximum(co)
        for i = 1:ma
            idx = findall(x -> x == i, co)
            if !isempty(idx)
                co[idx] .= j
                j = j + 1
            end
        end

        # end while
        (maximum(co)<9):break:(min=min+1)
    end

    return components = co
end