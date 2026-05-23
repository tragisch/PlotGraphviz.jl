
function to_graphviz(g::Graphs.AbstractGraph; edge_label::Bool=false, scale=3.0, landscape=false)
    gGraph = get_GraphvizGraph_Standard(g; node_label=true, edge_label=edge_label)
    gGraph.graph_attrs[:size] = string(scale)
    if landscape
        gGraph.graph_attrs[:rankdir] = "LR"
    end
    return gGraph
end

to_graphviz(g::GraphvizGraph; kw...) = g

function to_graphviz(g::AbstractSimpleWeightedGraph;
    edge_label::Bool=false,
    path=[],
    colors=zeros(Int, nv(g)),
    scale=3.0,
    landscape=false,
)
    attrs = GraphvizAttributes(g)
    return to_graphviz(g, attrs;
        edge_label=edge_label,
        path=path,
        colors=colors,
        scale=scale,
        landscape=landscape,
    )
end

function to_graphviz(g::AbstractSimpleWeightedGraph, attributes::GraphvizAttributes;
    edge_label::Bool=false,
    path=[],
    colors=zeros(Int, nv(g)),
    scale=3.0,
    landscape=false,
)
    attrs = deepcopy(attributes)

    if edge_label || val(attrs.plot_options, "weights") == "true"
        set!(attrs.graph_options, "forcelabels", "true")
    end
    set!(attrs.graph_options, "size", string(scale))
    if landscape
        set!(attrs.graph_options, "rankdir", "LR")
    end
    if !isempty(path)
        color_path!(attrs, path, g)
    end
    if !is_all_zero(colors)
        color_nodes!(attrs, colors)
    end

    return legacy_graphviz_graph(g, attrs)
end

function to_dot(g::GraphvizGraph)
    sprint(pprint, g)
end

function to_dot(g::Graphs.AbstractGraph; kw...)
    to_dot(to_graphviz(g; kw...))
end

function to_dot(g::AbstractSimpleWeightedGraph, attributes::GraphvizAttributes; kw...)
    to_dot(to_graphviz(g, attributes; kw...))
end

function _format_from_filename(filename::AbstractString)
    ext = lowercase(splitext(filename)[2])
    isempty(ext) && throw(ArgumentError("Cannot infer Graphviz output format from filename without extension"))
    return ext[2:end]
end

function savefig(filename::AbstractString, x; format=nothing, prog="dot", kw...)
    graph = to_graphviz(x; kw...)
    output_format = isnothing(format) ? _format_from_filename(filename) : string(format)
    open(filename, "w") do io
        run_graphviz(io, graph; prog, format=output_format)
    end
    return filename
end

function savefig(filename::AbstractString, g::AbstractSimpleWeightedGraph, attributes::GraphvizAttributes;
    format=nothing,
    prog="dot",
    kw...,
)
    graph = to_graphviz(g, attributes; kw...)
    output_format = isnothing(format) ? _format_from_filename(filename) : string(format)
    open(filename, "w") do io
        run_graphviz(io, graph; prog, format=output_format)
    end
    return filename
end

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
- (optional) `prog = "dot"`: Graphviz engine (`dot`, `neato`, `fdp`, `sfdp`, `twopi`, `circo`)
- (optional) `format = "svg"`: Display format (`svg` or `png`)
"""
function plot_graphviz(g::Graphs.AbstractGraph; prog::String="dot", format::String="svg", kw...)
    plot_graphviz(to_graphviz(g; kw...); prog=prog, format=format)
end

function plot_graphviz(tup::Tuple{<:AbstractSimpleWeightedGraph,GraphvizAttributes}; prog::String="dot", format::String="svg", kw...)
    plot_graphviz(tup[1], tup[2]; prog=prog, format=format, kw...)
end

function plot_graphviz(g::AbstractSimpleWeightedGraph, attributes::GraphvizAttributes;
    prog::String="dot",
    format::String="svg",
    kw...,
)
    plot_graphviz(to_graphviz(g, attributes; kw...); prog=prog, format=format)
end


function plot_graphviz(g::GraphvizGraph; prog::String="dot", format::String="svg")
    io = IOBuffer()
    run_graphviz(io, g; prog=prog, format=format)
    data = take!(io)

    if format == "svg"
        svg = String(data)
        try
            display("image/svg+xml", svg)
        catch err
            if err isa MethodError
                # e.g. plain terminal/TextDisplay without SVG renderer
                display("text/plain", "[SVG output: $(ncodeunits(svg)) bytes]")
            else
                rethrow(err)
            end
        end
    elseif format == "png"
        try
            display("image/png", data)
        catch err
            if err isa MethodError
                # e.g. plain terminal/TextDisplay without PNG renderer
                display("text/plain", "[PNG output: $(length(data)) bytes]")
            else
                rethrow(err)
            end
        end
    else
        throw(ArgumentError("Unsupported format for plot_graphviz: $format. Use \"svg\" or \"png\"."))
    end

    return nothing
end

function plot_graphviz(dot::AbstractString; prog::String="dot", format::String="svg")
    io = IOBuffer()
    run_graphviz(io, dot; prog=prog, format=format)
    data = take!(io)

    if format == "svg"
        svg = String(data)
        try
            display("image/svg+xml", svg)
        catch err
            if err isa MethodError
                display("text/plain", "[SVG output: $(ncodeunits(svg)) bytes]")
            else
                rethrow(err)
            end
        end
    elseif format == "png"
        try
            display("image/png", data)
        catch err
            if err isa MethodError
                display("text/plain", "[PNG output: $(length(data)) bytes]")
            else
                rethrow(err)
            end
        end
    else
        throw(ArgumentError("Unsupported format for plot_graphviz: $format. Use \"svg\" or \"png\"."))
    end

    return nothing
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
        dot = sprint(pprint, graph)
        write(gv, encoded_dot_bytes(dot))
    end
end

function run_graphviz(io::IO, dot::AbstractString; prog::Union{String,Nothing}="dot",
    format::String="svg")
    @assert prog in ("dot", "neato", "fdp", "sfdp", "twopi", "circo")
    fun = getfield(Graphviz_jll, Symbol(prog))
    prog = fun()
    open(`$prog -q -T$format`, io, write=true) do gv
        write(gv, encoded_dot_bytes(dot))
    end
end

function encoded_dot_bytes(dot::AbstractString)
    charset = detect_dot_charset(dot)
    if charset == "latin1"
        return encode_latin1(dot)
    end
    return Vector{UInt8}(codeunits(dot))
end

function detect_dot_charset(dot::AbstractString)
    m = match(r"(?i)charset\s*=\s*\"?([a-z0-9_\-]+)\"?", dot)
    return isnothing(m) ? "" : lowercase(String(m.captures[1]))
end

function encode_latin1(text::AbstractString)
    out = UInt8[]
    for c in text
        cp = UInt32(c)
        if cp <= 0xff
            push!(out, UInt8(cp))
        else
            # Fallback for non-Latin1 chars in a latin1-declared source.
            push!(out, UInt8('?'))
        end
    end
    return out
end

function run_graphviz(graph::GraphvizGraph; kw...)
    io = IOBuffer()
    run_graphviz(io, graph; kw...)
    seekstart(io)
end


Base.show(io::IO, ::MIME"image/png", graph::GraphvizGraph) = run_graphviz(io, graph; format="png")
Base.show(io::IO, ::MIME"image/svg+xml", graph::GraphvizGraph) = run_graphviz(io, graph; format="svg")
