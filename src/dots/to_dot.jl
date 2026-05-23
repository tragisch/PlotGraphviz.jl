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




