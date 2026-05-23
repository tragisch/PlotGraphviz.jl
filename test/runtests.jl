using PlotGraphviz
using Graphs
using SimpleWeightedGraphs
using Test

function render_dot_to_svg(dot::AbstractString)
    io = IOBuffer()
    PlotGraphviz.run_graphviz(io, dot; format="svg")
    return String(take!(io))
end

@testset "PlotGraphviz.jl" begin
    simple = SimpleGraph(3)
    Graphs.add_edge!(simple, 1, 2)
    Graphs.add_edge!(simple, 2, 3)

    simple_graphviz = get_GraphvizGraph_Standard(simple)
    simple_dot = sprint(pprint, simple_graphviz)

    @test isdefined(PlotGraphviz, :to_graphviz)
    @test isdefined(PlotGraphviz, :to_dot)
    @test isdefined(PlotGraphviz, :savefig)
    @test isdefined(PlotGraphviz, :plot_graphviz)
    @test isdefined(PlotGraphviz, :read_dot_file)
    @test isdefined(PlotGraphviz, :write_dot_file)
    @test !isdefined(PlotGraphviz, :ShowGraphviz)

    @test to_graphviz(simple) isa GraphvizGraph
    @test to_graphviz(simple_graphviz) === simple_graphviz
    @test to_dot(simple) == simple_dot
    @test to_dot(simple_graphviz) == simple_dot

    @test count(stmt -> stmt isa PlotGraphviz.Edge, simple_graphviz.stmts) == 2
    @test occursin("graph G", simple_dot)
    @test occursin("1 -- 2", simple_dot)
    @test occursin("2 -- 3", simple_dot)
    @test !occursin("1 -- 3", simple_dot)

    directed = SimpleDiGraph(3)
    Graphs.add_edge!(directed, 1, 2)
    Graphs.add_edge!(directed, 3, 2)

    directed_graphviz = get_GraphvizGraph_Standard(directed)
    directed_dot = sprint(pprint, directed_graphviz)

    @test count(stmt -> stmt isa PlotGraphviz.Edge, directed_graphviz.stmts) == 2
    @test occursin("digraph G", directed_dot)
    @test occursin("1 -> 2", directed_dot)
    @test occursin("3 -> 2", directed_dot)
    @test !occursin("2 -> 1", directed_dot)

    g = SimpleWeightedGraph(3)
    SimpleWeightedGraphs.add_edge!(g, 1, 2, 0.5)
    SimpleWeightedGraphs.add_edge!(g, 2, 3, 0.8)

    gGraph = get_GraphvizGraph_Standard(g; edge_label=true)
    dot = sprint(pprint, gGraph)

    @test count(stmt -> stmt isa PlotGraphviz.Edge, gGraph.stmts) == 2
    @test occursin("1 -- 2", dot)
    @test occursin("2 -- 3", dot)
    @test !occursin("1 -- 3", dot)
    @test occursin("xlabel=\"0.5\"", dot)

    legacy_dot = PlotGraphviz.string_dot(g)
    @test occursin("1 -- 2", legacy_dot)
    @test occursin("2 -- 3", legacy_dot)
    @test !occursin("1 -- 3", legacy_dot)

    weighted_directed = SimpleWeightedDiGraph(3)
    SimpleWeightedGraphs.add_edge!(weighted_directed, 1, 2, 1.25)
    SimpleWeightedGraphs.add_edge!(weighted_directed, 3, 2, 2.5)

    weighted_directed_graphviz = get_GraphvizGraph_Standard(weighted_directed; edge_label=true)
    weighted_directed_dot = sprint(pprint, weighted_directed_graphviz)

    @test count(stmt -> stmt isa PlotGraphviz.Edge, weighted_directed_graphviz.stmts) == 2
    @test occursin("1 -> 2", weighted_directed_dot)
    @test occursin("3 -> 2", weighted_directed_dot)
    @test occursin("xlabel=\"1.25\"", weighted_directed_dot)
    @test occursin("xlabel=\"2.5\"", weighted_directed_dot)
    @test !occursin("1 -> 3", weighted_directed_dot)

    svg = sprint(show, MIME("image/svg+xml"), gGraph)
    @test occursin("<svg", svg)

    png = IOBuffer()
    show(png, MIME("image/png"), gGraph)
    @test length(take!(png)) > 0

    legacy_attrs = GraphvizAttributes(g)
    set!(legacy_attrs.graph_options, "rankdir", "LR")
    set!(legacy_attrs.node_options, "shape", "box")
    set!(legacy_attrs.nodes, 1, Property("color", "red"))
    set!(legacy_attrs.edges, 1, 2, Property("color", "blue"))

    legacy_graphviz = PlotGraphviz.legacy_graphviz_graph(g, legacy_attrs)
    legacy_graphviz_dot = sprint(pprint, legacy_graphviz)

    @test to_graphviz(g, legacy_attrs) isa GraphvizGraph
    @test to_dot(g, legacy_attrs) == legacy_graphviz_dot
    @test occursin("rankdir=\"LR\"", legacy_graphviz_dot)
    @test occursin("node [", legacy_graphviz_dot)
    @test occursin("shape=\"box\"", legacy_graphviz_dot)
    @test occursin("1 [color=\"red\"]", legacy_graphviz_dot)
    @test occursin("1 -- 2 [color=\"blue\"]", legacy_graphviz_dot)

    legacy_svg = sprint(show, MIME("image/svg+xml"), legacy_graphviz)
    @test occursin("<svg", legacy_svg)

    file_graph, file_attrs = read_dot_file(joinpath(@__DIR__, "data", "directed", "clust4.gv"))
    @test file_graph isa SimpleWeightedDiGraph
    @test length(file_attrs.nodes) == nv(file_graph)
    @test length(file_attrs.edges) == ne(file_graph)

    imported_dot = PlotGraphviz.string_dot(file_graph, file_attrs)
    @test occursin("digraph G", imported_dot)
    @test occursin("subgraph", imported_dot)
    @test occursin("<svg", render_dot_to_svg(imported_dot))

    dot_path = tempname() * ".dot"
    write_dot_file(g, dot_path; attributes=legacy_attrs)
    written_dot = read(dot_path, String)
    @test occursin("graph G", written_dot)
    @test occursin("rankdir=\"LR\"", written_dot)
    @test occursin("1 -- 2 [color=\"blue\"]", written_dot)
    @test occursin("<svg", render_dot_to_svg(written_dot))

    svg_path = tempname() * ".svg"
    png_path = tempname() * ".png"
    @test savefig(svg_path, gGraph) == svg_path
    @test occursin("<svg", read(svg_path, String))
    @test savefig(png_path, simple) == png_path
    @test filesize(png_path) > 0
end
