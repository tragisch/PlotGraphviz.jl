

function color_nodes!(attrs::GraphvizAttributes, colors)

    # hard-coded color scheme:
    set!(attrs.node_options, "colorscheme", "set19")

    # standard colorscheme (max 9)
    if (!is_all_zero(colors))  # ToDo: no hardcoded part!!!!
        if maximum(colors) > 9
            colors = _reduce_colors!(colors)
        end
    end

    for node in attrs.nodes
        if colors[node.id] > 0
            set!(node.attributes, "color", colors[node.id])
        end
    end
end


function color_path!(attrs::GraphvizAttributes, path, g::Graphs.AbstractGraph; color="red")
    for node in path
        1 <= node <= nv(g) || throw(ArgumentError("Path contains invalid vertex $node"))
        set!(attrs.nodes, node, Property("style", "filled"))
        set!(attrs.nodes, node, Property("fillcolor", color))
    end

    edges = Dict{Tuple{Int,Int},gvEdge}()
    for edge in attrs.edges
        key = (edge.from, edge.to)
        haskey(edges, key) || (edges[key] = edge)
    end

    for (from, to) in zip(path, Iterators.drop(path, 1))
        edge = get(edges, (from, to), nothing)
        if isnothing(edge) && !Graphs.is_directed(g)
            edge = get(edges, (to, from), nothing)
        end
        isnothing(edge) && throw(ArgumentError("Path contains non-edge $from -> $to"))
        set!(edge.attributes, "color", color)
    end
end

# helper function to reduce colors
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
