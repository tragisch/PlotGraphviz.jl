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
    attributes::AttributeDict = get_attributes(graph), path = [], colors = zeros(Int, nv(graph)))
    open(filename, "w") do f
        _to_dot(graph, f, attributes, path, colors)
    end
end