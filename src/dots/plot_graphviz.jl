
"""
    plot_graphviz(g, node_label= true, edge_label=false; path = zeros(Int, nv(mat))


Render graph `g` in iJulia using `Graphviz` engines.

#### Arguments
- `g::AbstractSimpleWeightedGraph`: a graph representation to export 
- (optional) `edge_label::Bool`: if true all edges are labeled with their weights (default = false)
- (optional) `path = []`: Int-Array of nodes. Nodes and their edges are drawn in red color (i.e. shortest path)
- (optional) `colors = zeros(Int, nv(mat))`: Color nodes using Brewer Color Scheme (max 9 colors).
- (optional) `scale = 3.0`: Scale your plot
- (optional) `landscape = false`: if true > set `rankdir` to `LR`
"""
function plot_graphviz(g::Graphs.AbstractGraph; edge_label::Bool=false, scale=3.0, landscape=false)
    gGraph = get_GraphvizGraph_Standard(g; node_label=true, edge_label=edge_label)
    gGraph.graph_attrs[:size] = string(scale)
    if landscape
        gGraph.graph_attrs[:rankdir] = "LR"
    end
    plot_graphviz(gGraph)
end

# function plot_graphviz(tup::Tuple{SimpleWeightedDiGraph{Int64,Float64},GraphvizAttributes};
#     edge_label::Bool=false,
#     colors=zeros(Int, SimpleWeightedGraphs.nv(tup[1])),
#     path=[],
#     scale=3.0,
#     landscape=false)

#     g = tup[1]
#     attrs = tup[2]

#     (edge_label) ? set!(attrs.graph_options, "forcelabels", "true") : set!(attrs.graph_options, "forcelabels", "false")
#     (landscape) ? set!(attrs.graph_options, "rankdir", "LR") : set!(attrs.graph_options, "rankdir", "TB")

#     plot_graphviz(g, attrs; path, colors, scale)

# end


# """
#     plot_graphviz(g, attributes; path = zeros(Int, nv(mat)))


# Render graph `g` in **iJulia** using `Graphviz` engines.

# #### Arguments
# - `g::AbstractSimpleWeightedGraph`: a graph representation to export 
# - `attributes::AttributeDict`: Render with own set of plotting attributes (see http://www.graphviz.org/ for details)
# - (optional) `path = []`: Int-Array of nodes. Nodes and their edges are drawn in red color (i.e. shortest path)
# - (optional) `colors = zeros(Int, nv(mat))`: Color nodes using Brewer Color Scheme (max 9 colors).
# - (optional) `scale = 3.0`: Scale your plot
# - (optional) `landscape = false`: if true > set `rankdir` to `LR`
# """
# function plot_graphviz(g::AbstractSimpleWeightedGraph, attributes::GraphvizAttributes;
#     path=[],
#     colors=zeros(Int, nv(g)),
#     scale=3.0
# )
#     if !isempty(val(attributes.plot_options, "weights"))
#         (val(attributes.plot_options, "weights") == "true") ? set!(attributes.graph_options, "forcelabels", "true") : nothing
#     end
#     set!(attributes.graph_options, "size", string(scale))
#     gv_dot = string_dot(g, attributes, path, colors)
#     plot_graphviz(gv_dot)
# end


function plot_graphviz(g::GraphvizGraph)
    display(g)
end

function plot_graphviz(dot::AbstractString)
    io = IOBuffer()
    run_graphviz(io, dot; format="svg")
    display("image/svg+xml", String(take!(io)))
end


#### internal
### copied from CAPL.

function __init__()
    let cfg = joinpath(Graphviz_jll.artifact_dir, "lib", "graphviz", "config6")
        if !isfile(cfg)
            run(`$(Graphviz_jll.dot()) -c`)
        end
    end
end


""" Run a Graphviz program.

Invokes Graphviz through its command-line interface. If the `Graphviz_jll`
package is installed and loaded, it is used; otherwise, Graphviz must be
installed on the local system.

For bindings to the Graphviz C API, see the the package
[GraphViz.jl](https://github.com/Keno/GraphViz.jl). At the time of this writing,
GraphViz.jl is unmaintained.
"""
function run_graphviz(io::IO, graph::GraphvizGraph; prog::Union{String,Nothing}="dot",
    format::String="json0")
    @assert prog in ("dot", "neato", "fdp", "sfdp", "twopi", "circo")
    fun = getfield(Graphviz_jll, Symbol(prog))
    prog = fun()
    open(`$prog -q -T$format`, io, write=true) do gv
        pprint(gv, graph)
    end
end

function run_graphviz(io::IO, dot::AbstractString; prog::Union{String,Nothing}="dot",
    format::String="svg")
    @assert prog in ("dot", "neato", "fdp", "sfdp", "twopi", "circo")
    fun = getfield(Graphviz_jll, Symbol(prog))
    prog = fun()
    open(`$prog -q -T$format`, io, write=true) do gv
        write(gv, dot)
    end
end

function run_graphviz(graph::GraphvizGraph; kw...)
    io = IOBuffer()
    run_graphviz(io, graph; kw...)
    seekstart(io)
end


Base.show(io::IO, ::MIME"image/png", graph::GraphvizGraph) = run_graphviz(io, graph; format="png")
Base.show(io::IO, ::MIME"image/svg+xml", graph::GraphvizGraph) = run_graphviz(io, graph; format="svg")
