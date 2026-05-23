using PlotGraphviz
using SimpleWeightedGraphs
using Test

@testset "PlotGraphviz.jl" begin
    g = SimpleWeightedGraph(3)
    SimpleWeightedGraphs.add_edge!(g, 1, 2, 0.5)
    SimpleWeightedGraphs.add_edge!(g, 2, 3, 0.8)

    gGraph = get_GraphvizGraph_Standard(g; edge_label=true)
    dot = sprint(pprint, gGraph)

    @test count(stmt -> stmt isa Edge, gGraph.stmts) == 2
    @test occursin("1 -- 2", dot)
    @test occursin("2 -- 3", dot)
    @test !occursin("1 -- 3", dot)
    @test occursin("xlabel=\"0.5\"", dot)

    legacy_dot = PlotGraphviz.string_dot(g)
    @test occursin("1 -- 2", legacy_dot)
    @test occursin("2 -- 3", legacy_dot)
    @test !occursin("1 -- 3", legacy_dot)

    svg = sprint(show, MIME("image/svg+xml"), gGraph)
    @test occursin("<svg", svg)
end
