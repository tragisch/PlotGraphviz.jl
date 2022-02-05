# Functions for representing graphs in GraphViz's dot format
# http://www.graphviz.org/
# http://www.graphviz.org/Documentation/dotguide.pdf
# http://www.graphviz.org/pub/scm/graphviz2/doc/info/lang.html

# orientated and based more or less on :
# https://github.com/JuliaAttic/OldGraphs.jl/blob/master/src/dot.jl
# https://github.com/tkf/ShowGraphviz.jl
# and only simply modified (Roettgermann, 12/21)

# internal function to get a suitable string out of the attribute dictionary:
function _parse_attributes(attrs::AttributeDict, gne::String)

    gne_attrs = _get_GNE_attributes(attrs, gne)
    str_attr::String = ""

    if contains(gne, "N") # node attributes
        str_attr = string("[", join(map(a -> _to_dot(a[1], a[2][2]), collect(gne_attrs)), ","))
    elseif contains(gne, "G") # graph attributes
        for key in keys(attrs)
            if contains(attrs[key][1], "G")
                str_attr = str_attr * string(_to_dot(key, attrs[key][2]), ";\n ")
            end
        end
    elseif contains(gne, "E") # edge attributes
        str_attr = string("[", join(map(a -> _to_dot(a[1], a[2][2]), collect(gne_attrs)), ","))
    end
    return str_attr
end

# internal functions to identify strings:
_to_dot(sym::Symbol, value::String) = "$sym=$value"
_graph_type_string(graph::AbstractSimpleWeightedGraph) = Graphs.is_directed(graph) ? "digraph" : "graph"
_edge_op(graph::AbstractSimpleWeightedGraph) = Graphs.is_directed(graph) ? "->" : "--"



function _to_dot_graph_attributes(g::AbstractSimpleWeightedGraph, stream::IO, attrs::AttributeDict)

    # write beginning: graph or digraph:
    graph_type_string = Graphs.is_directed(g) ? "digraph" : "graph"
    write(stream, "$graph_type_string {\n")

    # write general attributes, belongs to all elements:
    G = "G"
    write(stream, " $(_parse_attributes(attrs, G))\n")

    N = "N"
    write(stream, " node $(_parse_attributes(attrs, N))];\n")

    E = "E"
    write(stream, " edge $(_parse_attributes(attrs, E))];\n")
end


function _to_dot_node_attributes(g::AbstractSimpleWeightedGraph, stream::IO, attrs::AttributeDict, path, colors)

    # hard-coded color scheme:
    color_scheme = "colorscheme=set19"

    (!isempty(path)) ? show_path = true : show_path = false
    (!_is_all_zero(colors)) ? show_color = true : show_color = false
    (show_color == true) ? write(stream, " node [$color_scheme]\n\n") : nothing

    # iter:
    for node = 1:nv(g)

        # get node specific attributes:
        n_attrs = _parse_attributes(attrs, "N$node")


        if show_color && (colors[node] > 0)
            (length(n_attrs) > 1) ? n_attrs = n_attrs * "," : nothing
            n_attrs = n_attrs * "color=$(colors[node])"
        end

        if show_path && !Base.isnothing(findfirst(isequal(node), path))
            (length(n_attrs) > 1) ? n_attrs = n_attrs * "," : nothing
            n_attrs = n_attrs * "fillcolor=red"
        end
        write(stream, " $node $n_attrs];\n")
    end
end

function _to_dot_edge_attributes(g::AbstractSimpleWeightedGraph, stream::IO, attrs::AttributeDict, path, colors)

    # check if `weighted` and labeled:
    if haskey(attrs, :weights)
        attr_ = attrs[:weights][2]
        (attr_ == "true") ? edge_label = true : edge_label = false
    end

    # check if colored or path:
    (!isempty(path)) ? show_path = true : show_path = false
    (!_is_all_zero(colors)) ? show_color = true : show_color = false


    for node = 1:nv(g)
        childs = Graphs.inneighbors(g, node)

        for kid in childs
            # get edge specific attributes:
            par = "-"
            e_attrs = _parse_attributes(attrs, "E$node$par$kid")

            if show_color && (colors[node] > 0) && (colors[kid] > 0)
                (length(e_attrs) > 1) ? e_attrs = e_attrs * "," : nothing
                e_attrs = e_attrs * "color=$(colors[node])"
            end

            if show_path && !Base.isnothing(findfirst(isequal(node), path)) && !Base.isnothing(findfirst(isequal(kid), path)) && (kid != path[1])
                (length(e_attrs) > 1) ? e_attrs = e_attrs * "," : nothing
                e_attrs = e_attrs * "color=red"
            end

            if edge_label
                w = g.weights[node, kid]
                write(stream, " $node $(_edge_op(g)) $kid $e_attrs, xlabel=$w];\n")
            else
                write(stream, " $node $(_edge_op(g)) $kid $e_attrs];\n")
            end

        end

    end


end


# internal function DOT-Language representation:
function _to_dot(mat::AbstractSimpleWeightedGraph, stream::IO, attrs::AttributeDict, path, colors)

    # standard colorscheme (max 9)
    if (!_is_all_zero(colors))  # ToDo: no hardcoded part!!!!
        if maximum(colors) > 9
            colors = _reduce_colors!(colors)
        end
    end

    # write Header an Graph Attributes:
    _to_dot_graph_attributes(mat, stream, attrs)

    # write Node Attributes
    _to_dot_node_attributes(mat, stream, attrs, path, colors)

    #write Edge Attributes
    _to_dot_edge_attributes(mat, stream, attrs, path, colors)


    write(stream, "}\n")
    return stream
end

########### helper


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

# internal function to get `G`raph, `E`dge and `N`ode relateted attributes:
function _get_GNE_attributes(attrs::AttributeDict, gne::String)
    if !isempty(attrs)
        GNE_attrs = Dict()
        for key in keys(attrs)
            # if (single == true)
            #     if contains(attrs[key][1], gne)
            #         GNE_attrs[key] = attrs[key]
            #     end
            # else # to get node or edge specific attributes.
            if attrs[key][1] == gne
                GNE_attrs[key] = attrs[key]
            end
            #end
        end
        return GNE_attrs
    else
        return ""
    end

end

# internal function to get the dot representation of a graph as a string.
function _to_dot(graph::AbstractSimpleWeightedGraph, attributes::AttributeDict = get_attributes(graph), path = [], colors = zeros(Int, nv(g)))
    str = IOBuffer()
    _to_dot(graph, str, attributes, path, colors)
    String(take!(str)) #takebuf_string(str)
end