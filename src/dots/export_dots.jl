"""
    write_dot_file(g, file; attributes, path, colors)


Export graph `g` to DOT-Format and store it in file `file`.

#### Arguments
- `g::AbstractSimpleWeightedGraph`: a graph representation to export 
- `filename::AbstractString`: the filename to store (i.e. "graph.dot")
- (optional) `attributes::AttributeDict`: Dot-Attributes like node color stored in a dictionary
- (optional) `path = []`: Int-Array of nodes. Nodes and their edges are drawn in red color (i.e. shortest path)
- (optional) `colors = zeros(Int, nv(mat))`: Components-colors vector representated by a color number each node.
"""
function write_dot_file(graph::AbstractSimpleWeightedGraph, filename::AbstractString;
    attributes=GraphvizAttributes(graph), path=[], colors=zeros(Int, nv(graph)))

    if !isempty(path)
        color_path!(attributes, path, graph)
    end

    if (!is_all_zero(colors))
        color_nodes!(attributes, colors)
    end

    open(filename, "w") do f
        dot(graph, f, attributes)
    end
end


# internal function to get the dot representation of a graph as a string.
function string_dot(graph::AbstractSimpleWeightedGraph, attributes=GraphvizAttributes(g), path=[], colors=zeros(Int, nv(g)))

    if !isempty(path)
        color_path!(attributes, path, graph)
    end

    if (!is_all_zero(colors))
        color_nodes!(attributes, colors)
    end

    str = IOBuffer()
    dot(graph, str, attributes)
    String(take!(str)) #takebuf_string(str)
end

function save_dot_as(graph::AbstractSimpleWeightedGraph, filename::AbstractString;
    attributes=GraphvizAttributes(graph), path=[], colors=zeros(Int, nv(graph)))

    ## ToDo

end