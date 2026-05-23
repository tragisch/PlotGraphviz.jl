

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


function color_path!(attrs::GraphvizAttributes, path, g::AbstractSimpleWeightedGraph; color="red")

    for node = 1:nv(g)
        childs = Graphs.inneighbors(g, node)

        if !Base.isnothing(findfirst(isequal(node), path))
            set!(attrs.nodes, node, Property("style", "filled"))
            set!(attrs.nodes, node, Property("fillcolor", color))
            for kid in childs
                if !Base.isnothing(findfirst(isequal(kid), path)) && (kid != path[1])
                    set!(attrs.edges, node, kid, Property("color", color))
                end
            end
        end
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
