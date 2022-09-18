# Functions for representing graphs in GraphViz's dot format
# http://www.graphviz.org/
# http://www.graphviz.org/Documentation/dotguide.pdf
# http://www.graphviz.org/pub/scm/graphviz2/doc/info/lang.html

# based on :
# https://github.com/JuliaAttic/OldGraphs.jl/blob/master/src/dot.jl
# https://github.com/tkf/ShowGraphviz.jl
# and modified by U.Roettgermann, 12/21


# internal helper functions
to_dot(sym::String, value::Any) = "$sym=$value"
edge_op(graph::AbstractSimpleWeightedGraph) = Graphs.is_directed(graph) ? "->" : "--"
parse_attributes(attributes) = string("[", join(map(a -> to_dot(a.key, a.value), attributes), ", "))
is_all_zero(arr) = length(arr) == 0 || all(==(0), arr)


function dot(g::AbstractSimpleWeightedGraph, stream::IO, attrs::GraphvizAttributes)

    # write beginning: graph or digraph:
    directed = Graphs.is_directed(g)

    graph_type_string = directed ? "digraph" : "graph"
    write(stream, "$graph_type_string G {\n")

    set!(attrs.plot_options, "type", graph_type_string)
    set!(attrs.graph_options, "concentrate", "true")
    set!(attrs.graph_options, "layout", (directed) ? "dot" : "neato")

    # write GENERAL attributes, belongs to all elements:
    write(stream, " graph$(parse_attributes(attrs.graph_options))]\n")
    write(stream, " node$(parse_attributes(attrs.node_options))]\n")
    write(stream, " edge$(parse_attributes(attrs.edge_options))]\n")


    # write subgraphs:
    if !isempty(attrs.subgraphs)
        for subgraph in attrs.subgraphs
            write(stream, "subgraph $(subgraph.type) { \n")

            write(stream, " graph$(parse_attributes(subgraph.graph_options))]\n")
            write(stream, " node$(parse_attributes(subgraph.node_options))]\n")
            write(stream, " edge$(parse_attributes(subgraph.edge_options))]\n")

            # write node 
            for n in subgraph.nodes
                write(stream, " $(n.id) $(parse_attributes(n.attributes))];\n")
            end

            # write edges
            for e in subgraph.edges
                write(stream, " $(e.from) $(edge_op(g)) $(e.to) $(parse_attributes(e.attributes))];\n")
            end

            write(stream, "}\n")
        end
    end

    # write node 
    for n in attrs.nodes
        write(stream, " $(n.id) $(parse_attributes(n.attributes))];\n")
    end

    # write edges
    for e in attrs.edges
        write(stream, " $(e.from) $(edge_op(g)) $(e.to) $(parse_attributes(e.attributes))];\n")
    end

    write(stream, "}\n")
    return stream
end


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

