
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

function to_graphviz(g::Graphs.AbstractGraph, attributes::GraphvizAttributes;
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

function to_dot(g::Graphs.AbstractGraph, attributes::GraphvizAttributes; kw...)
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

function savefig(filename::AbstractString, g::Graphs.AbstractGraph, attributes::GraphvizAttributes;
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
- `g::Graphs.AbstractGraph`: a graph representation to export
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

function plot_graphviz(tup::Tuple{<:Graphs.AbstractGraph,GraphvizAttributes}; prog::String="dot", format::String="svg", kw...)
    plot_graphviz(tup[1], tup[2]; prog=prog, format=format, kw...)
end

function plot_graphviz(g::Graphs.AbstractGraph, attributes::GraphvizAttributes;
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


"""
    run_graphviz(io, graph_or_dot; prog="dot", format="svg")

Render a `GraphvizGraph` or DOT string through the executable bundled by
`Graphviz_jll`, writing the selected Graphviz output format to `io`.
"""
const GRAPHVIZ_PROGRAMS = ("dot", "neato", "fdp", "sfdp", "twopi", "circo")

function graphviz_program(prog::AbstractString)
    prog in GRAPHVIZ_PROGRAMS || throw(ArgumentError(
        "Unsupported Graphviz program: $prog. Use one of $(join(GRAPHVIZ_PROGRAMS, ", ")).",
    ))
    return getfield(Graphviz_jll, Symbol(prog))()
end

function run_graphviz(io::IO, graph::GraphvizGraph; prog::AbstractString="dot",
    format::AbstractString="svg")
    executable = graphviz_program(prog)
    isempty(format) && throw(ArgumentError("Graphviz output format must not be empty"))
    open(`$executable -q -T$format`, io, write=true) do gv
        dot = sprint(pprint, graph)
        write(gv, encoded_dot_bytes(dot))
    end
end

function run_graphviz(io::IO, dot::AbstractString; prog::AbstractString="dot",
    format::AbstractString="svg")
    executable = graphviz_program(prog)
    isempty(format) && throw(ArgumentError("Graphviz output format must not be empty"))
    open(`$executable -q -T$format`, io, write=true) do gv
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
