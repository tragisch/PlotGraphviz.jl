"""
    write_dot_file(g, file; attributes, path, colors)


Export graph `g` to DOT-Format and store it in file `file`.

#### Arguments
- `g::Graphs.AbstractGraph`: a graph representation to export
- `filename::AbstractString`: the filename to store (i.e. "graph.dot")
- (optional) `attributes::AttributeDict`: Dot-Attributes like node color stored in a dictionary
- (optional) `path = []`: Int-Array of nodes. Nodes and their edges are drawn in red color (i.e. shortest path)
- (optional) `colors = zeros(Int, nv(mat))`: Components-colors vector representated by a color number each node.
"""
function write_dot_file(graph::Graphs.AbstractGraph, filename::AbstractString;
    attributes=GraphvizAttributes(graph), path=[], colors=zeros(Int, nv(graph)))

    if !isempty(path)
        color_path!(attributes, path, graph)
    end

    if (!is_all_zero(colors))
        color_nodes!(attributes, colors)
    end

    open(filename, "w") do f
        pprint(f, legacy_graphviz_graph(graph, attributes))
    end
end


# internal function to get the dot representation of a graph as a string.
function string_dot(graph::Graphs.AbstractGraph, attributes=GraphvizAttributes(graph), path=[], colors=zeros(Int, nv(graph)))

    if !isempty(path)
        color_path!(attributes, path, graph)
    end

    if (!is_all_zero(colors))
        color_nodes!(attributes, colors)
    end

    str = IOBuffer()
    pprint(str, legacy_graphviz_graph(graph, attributes))
    String(take!(str))
end

function save_dot_as(graph::AbstractSimpleWeightedGraph, filename::AbstractString;
    attributes=GraphvizAttributes(graph), path=[], colors=zeros(Int, nv(graph)))

    ## ToDo

end
