using PlotGraphviz
using Graphs
using MetaGraphsNext
using ParserCombinator
using SimpleWeightedGraphs
using Test

decode_graphviz_text(data::Vector{UInt8}) =
    try
        String(data)
    catch err
        if err isa Base.InvalidCharError
            String(Char.(data))
        else
            rethrow(err)
        end
    end

function render_dot_to_svg(dot::AbstractString)
    io = IOBuffer()
    PlotGraphviz.run_graphviz(io, dot; format="svg")
    return decode_graphviz_text(take!(io))
end

function render_dot_with_graphviz(dot::AbstractString; prog::String, format::String)
    io = IOBuffer()
    PlotGraphviz.run_graphviz(io, dot; prog=prog, format=format)
    return decode_graphviz_text(take!(io))
end

function plain_render_signature(plain::AbstractString; directed::Bool)
    nodes = Set{String}()
    edges = Set{Tuple{String,String}}()

    for raw_line in split(plain, '\n')
        line = strip(raw_line)
        isempty(line) && continue

        if startswith(line, "node ")
            parts = split(line)
            length(parts) >= 2 || continue
            push!(nodes, parts[2])
            continue
        end

        if startswith(line, "edge ")
            parts = split(line)
            length(parts) >= 3 || continue
            src = parts[2]
            dst = parts[3]

            if directed
                push!(edges, (src, dst))
            else
                push!(edges, src <= dst ? (src, dst) : (dst, src))
            end
        end
    end

    return (nodes=nodes, edges=edges)
end

has_undirected_edge(dot::AbstractString, a::AbstractString, b::AbstractString) =
    occursin("$a -- $b", dot) || occursin("$b -- $a", dot)

@testset "PlotGraphviz.jl" begin
    @testset "Interop adapters" begin
        simple_u = SimpleGraph(3)
        Graphs.add_edge!(simple_u, 1, 2)

        weighted_u = to_weighted_graph(simple_u; default_weight=3.5)
        @test weighted_u isa SimpleWeightedGraph
        @test weights(weighted_u)[1, 2] == 3.5

        simple_d = SimpleDiGraph(3)
        Graphs.add_edge!(simple_d, 1, 2)

        weighted_d = to_weighted_graph(simple_d; default_weight=2.0)
        @test weighted_d isa SimpleWeightedDiGraph
        @test weights(weighted_d)[1, 2] == 2.0

        attrs = GraphvizAttributes(weighted_u)
        set!(attrs.edges, 1, 2, Property("weight", "7.25"))
        set!(attrs.edges, 1, 2, Property("xlabel", "9.5"))

        weighted_from_attrs = apply_edge_weights(simple_u, attrs)
        @test weights(weighted_from_attrs)[1, 2] == 7.25

        weighted_from_attrs_x = apply_edge_weights(simple_u, attrs; weight_keys=("xlabel",), default_weight=1.0)
        @test weights(weighted_from_attrs_x)[1, 2] == 9.5

        weighted_from_attrs_default = apply_edge_weights(simple_u, attrs; weight_keys=("missing",), default_weight=4.0)
        @test weights(weighted_from_attrs_default)[1, 2] == 4.0

        set!(attrs.edges, 1, 2, Property("weight", 6.5))
        weighted_from_numeric_attr = apply_edge_weights(simple_u, attrs)
        @test weights(weighted_from_numeric_attr)[1, 2] == 6.5

        petersen_weighted, petersen_attrs2 = read_dot_file_weighted(joinpath(@__DIR__, "data", "undirected", "Petersen.gv"))
        petersen_ids2 = Dict(node.name => node.id for node in petersen_attrs2.nodes)
        @test petersen_weighted isa SimpleWeightedGraph
        @test weights(petersen_weighted)[petersen_ids2["0"], petersen_ids2["5"]] == 5.0
        @test weights(petersen_weighted)[petersen_ids2["0"], petersen_ids2["1"]] == 1.0
    end

    @testset "MetaGraphsNext adapters" begin
        g_meta = SimpleWeightedDiGraph(3)
        SimpleWeightedGraphs.add_edge!(g_meta, 1, 2, 2.5)
        SimpleWeightedGraphs.add_edge!(g_meta, 2, 3, 1.25)

        attrs_meta = GraphvizAttributes(g_meta)
        attrs_meta.nodes[1] = gvNode(1, "A", [Property("color", "red"), Property("shape", "box")])
        attrs_meta.nodes[2] = gvNode(2, "B", [Property("color", "blue")])
        attrs_meta.nodes[3] = gvNode(3, "C", [Property("style", "filled")])
        set!(attrs_meta.edges, 1, 2, Property("weight", "2.5"))
        set!(attrs_meta.edges, 1, 2, Property("style", "dashed"))
        set!(attrs_meta.edges, 2, 3, Property("weight", "1.25"))
        set!(attrs_meta.graph_options, "rankdir", "LR")

        mg = to_metagraph(g_meta, attrs_meta)

        @test mg isa MetaGraphsNext.MetaGraph
        @test mg["A"]["color"] == "red"
        @test mg["A", "B"]["style"] == "dashed"
        @test mg[]["rankdir"] == "LR"
        @test weights(mg)[1, 2] == 2.5

        g_back, attrs_back = from_metagraph(mg)

        @test g_back isa SimpleWeightedDiGraph
        @test weights(g_back)[1, 2] == 2.5
        @test weights(g_back)[2, 3] == 1.25
        @test attrs_back.nodes[1].name == "A"
        @test val(attrs_back.nodes, 1, "color") == "\"red\""
        @test val(attrs_back.edges, 1, 2, "style") == "\"dashed\""
        @test val(attrs_back.graph_options, "rankdir") == "\"LR\""
    end

    simple = SimpleGraph(3)
    Graphs.add_edge!(simple, 1, 2)
    Graphs.add_edge!(simple, 2, 3)

    simple_graphviz = get_GraphvizGraph_Standard(simple)
    simple_dot = sprint(pprint, simple_graphviz)

    @testset "DOT API and serialization" begin
        properties = Property[Property("color", "red")]
        set!(properties, "color", "blue"; override=false)
        @test length(properties) == 1
        @test val(properties, "color") == "red"

        modern = GraphvizDigraph(
            "graph name",
            Node("node one"; label="first \"quoted\"\nline", width=1.5),
            Node("node\"two"),
            PlotGraphviz.Edge("node one", "node\"two"; label=2);
            strict=true,
        )
        modern_dot = to_dot(modern)

        @test startswith(modern_dot, "strict digraph \"graph name\"")
        @test occursin("\"node one\"", modern_dot)
        @test occursin("\"node\\\"two\"", modern_dot)
        @test occursin("label=\"first \\\"quoted\\\"\\nline\"", modern_dot)
        @test occursin("width=\"1.5\"", modern_dot)
        @test occursin("<svg", render_dot_to_svg(modern_dot))

        @test occursin("overlap=\"scale\"", simple_dot)
        @test occursin("arrowhead=\"normal\"", simple_dot)
        @test !occursin("overlay=", simple_dot)
        @test !occursin("arrowtype=", simple_dot)

        simple_attrs = GraphvizAttributes(simple)
        set!(simple_attrs.nodes, 1, Property("shape", "box"))
        @test occursin("1 [shape=\"box\"]", to_dot(simple, simple_attrs))

        @test_throws ArgumentError PlotGraphviz.run_graphviz(IOBuffer(), "graph { a -- b }"; prog="invalid")
        @test_throws ArgumentError PlotGraphviz.run_graphviz(IOBuffer(), "graph { a -- b }"; format="")
    end

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
    @test isnothing(plot_graphviz(simple_graphviz; prog="dot"))

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

    directed_attrs = GraphvizAttributes(directed)
    directed_path_dot = to_dot(directed, directed_attrs; path=[1, 2])
    @test occursin("1 -> 2 [color=\"red\"]", directed_path_dot)
    @test !occursin("3 -> 2 [color=\"red\"]", directed_path_dot)
    @test_throws ArgumentError to_dot(directed, directed_attrs; path=[1, 3])

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
    @test !occursin("\n  a0 [label=\"a0\"];", imported_dot)
    @test !occursin("\n  b0 [label=\"b0\"];", imported_dot)
    @test findfirst("subgraph cluster_0", imported_dot).start < findfirst("start -> a0", imported_dot).start
    @test occursin("<svg", render_dot_to_svg(imported_dot))

    kw91_graph, kw91_attrs = read_dot_file(joinpath(@__DIR__, "data", "directed", "KW91.gv"))
    kw91_roundtrip_dot = PlotGraphviz.string_dot(kw91_graph, kw91_attrs)
    @test occursin("subgraph cluster_outer", kw91_roundtrip_dot)
    @test occursin("subgraph cluster_inner", kw91_roundtrip_dot)
    kw91_roundtrip_parsed = ParserCombinator.Parsers.DOT.parse_dot(kw91_roundtrip_dot)[1]
    kw91_outer = [
        stmt for stmt in kw91_roundtrip_parsed.stmts
        if stmt isa ParserCombinator.Parsers.DOT.SubGraph && !isnothing(stmt.id) && String(stmt.id.id) == "cluster_outer"
    ]
    @test length(kw91_outer) == 1
    @test any(
        stmt -> stmt isa ParserCombinator.Parsers.DOT.SubGraph && !isnothing(stmt.id) && String(stmt.id.id) == "cluster_inner",
        kw91_outer[1].stmts,
    )
    @test occursin("<svg", render_dot_to_svg(kw91_roundtrip_dot))

    ldbx_graph, ldbx_attrs = read_dot_file(joinpath(@__DIR__, "data", "directed", "ldbxtried.gv"))
    @test ldbx_graph isa SimpleWeightedDiGraph
    ldbx_ids = Dict(node.name => node.id for node in ldbx_attrs.nodes)
    @test val(ldbx_attrs.nodes, ldbx_ids["n1"], "shape") == "\"ellipse\""
    @test val(ldbx_attrs.nodes, ldbx_ids["n1"], "color") == "\"maroon1\""
    @test val(ldbx_attrs.nodes, ldbx_ids["n454"], "shape") == "\"doublecircle\""
    @test val(ldbx_attrs.nodes, ldbx_ids["n454"], "color") == "\"green\""
    ldbx_roundtrip_dot = PlotGraphviz.string_dot(ldbx_graph, ldbx_attrs)
    @test occursin(r"n1 \[[^\]]*label=\"4836\"", ldbx_roundtrip_dot)
    @test occursin(r"n1 \[[^\]]*shape=\"ellipse\"[^\]]*color=\"maroon1\"", ldbx_roundtrip_dot)
    @test occursin("n454 [label=\"bunting", ldbx_roundtrip_dot)
    @test occursin("shape=\"doublecircle\",color=\"green\"", ldbx_roundtrip_dot)
    @test occursin("<svg", render_dot_to_svg(ldbx_roundtrip_dot))

    record2_graph, record2_attrs = read_dot_file(joinpath(@__DIR__, "data", "directed", "record2.gv"))
    @test record2_graph isa SimpleWeightedDiGraph
    record2_ids = Dict(node.name => node.id for node in record2_attrs.nodes)
    @test val(record2_attrs.nodes, record2_ids["a"], "label") == "\"<f0> foo | x | <f1> bar\""
    @test val(record2_attrs.nodes, record2_ids["b"], "label") == "\"a | { <f0> foo | x | <f1> bar } | b\""
    @test val(record2_attrs.edges, record2_ids["a"], record2_ids["b"], "tailport") == "\"f0\""
    @test val(record2_attrs.edges, record2_ids["a"], record2_ids["b"], "headport") == "\"f1\""
    record2_roundtrip_dot = PlotGraphviz.string_dot(record2_graph, record2_attrs)
    @test occursin(r"a \[[^\]]*label=\"<f0> foo \| x \| <f1> bar\"", record2_roundtrip_dot)
    @test occursin(r"b \[[^\]]*label=\"a \| \{ <f0> foo \| x \| <f1> bar \} \| b\"", record2_roundtrip_dot)
    @test occursin(r"a -> b \[[^\]]*tailport=\"f0\"[^\]]*headport=\"f1\"", record2_roundtrip_dot)
    @test occursin("<svg", render_dot_to_svg(record2_roundtrip_dot))

    shells_graph, shells_attrs = read_dot_file(joinpath(@__DIR__, "data", "directed", "shells.gv"))
    @test shells_graph isa SimpleWeightedDiGraph
    shells_ids = Dict(node.name => node.id for node in shells_attrs.nodes)
    @test val(shells_attrs.nodes, shells_ids["1972"], "shape") == "\"plaintext\""
    @test val(shells_attrs.nodes, shells_ids["1972"], "fontsize") == "\"24\""
    @test val(shells_attrs.nodes, shells_ids["1976"], "shape") == "\"plaintext\""
    @test val(shells_attrs.nodes, shells_ids["1976"], "fontsize") == "\"24\""
    shells_roundtrip_dot = PlotGraphviz.string_dot(shells_graph, shells_attrs)
    @test occursin(r"1972 \[(?=[^\]]*shape=\"plaintext\")(?=[^\]]*fontsize=\"24\")[^\]]*\]", shells_roundtrip_dot)
    @test occursin(r"1976 \[(?=[^\]]*shape=\"plaintext\")(?=[^\]]*fontsize=\"24\")[^\]]*\]", shells_roundtrip_dot)
    @test occursin("<svg", render_dot_to_svg(shells_roundtrip_dot))

    biological_graph, biological_attrs = read_dot_file(joinpath(@__DIR__, "data", "directed", "biological.gv"))
    biological_roundtrip_dot = PlotGraphviz.string_dot(biological_graph, biological_attrs)
    @test occursin("Hef1a -> Gal4VP16 [arrowhead=\"none\"]", biological_roundtrip_dot)
    @test occursin("Gal4VP16 -> UAS [arrowhead=\"none\"]", biological_roundtrip_dot)
    @test !occursin("Hef1a -> Gal4VP16;", biological_roundtrip_dot)
    @test !occursin("Gal4VP16 -> UAS;", biological_roundtrip_dot)

    grammar_graph, grammar_attrs = read_dot_file(joinpath(@__DIR__, "data", "directed", "grammar.gv"))
    @test grammar_graph isa SimpleWeightedDiGraph
    grammar_ids = Dict(node.name => node.id for node in grammar_attrs.nodes)
    @test has_edge(grammar_graph, grammar_ids["n0"], grammar_ids["n1"])
    @test has_edge(grammar_graph, grammar_ids["n0"], grammar_ids["n40"])
    @test has_edge(grammar_graph, grammar_ids["n31"], grammar_ids["n32"])
    @test has_edge(grammar_graph, grammar_ids["n31"], grammar_ids["n34"])

    latin1_graph, latin1_attrs = read_dot_file(joinpath(@__DIR__, "data", "directed", "Latin1.gv"))
    @test latin1_graph isa SimpleWeightedDiGraph
    @test nv(latin1_graph) == 1
    @test ne(latin1_graph) == 0
    @test val(latin1_attrs.nodes, 1, "label") != "\"a\""

    latin1_roundtrip_dot = PlotGraphviz.string_dot(latin1_graph, latin1_attrs)
    @test occursin("charset=\"latin1\"", latin1_roundtrip_dot)
    @test !occursin("\na [label=\"a\"]", latin1_roundtrip_dot)
    latin1_svg = render_dot_to_svg(latin1_roundtrip_dot)
    @test occursin("<svg", latin1_svg)
    @test occursin("áâãäå", latin1_svg)

    xlabel_path = tempname() * ".dot"
    write(xlabel_path, "graph { a -- b [xlabel=2.5]; }")
    xlabel_graph, _ = read_dot_file(xlabel_path)
    @test weights(xlabel_graph)[1, 2] == 2.5

    er_graph, er_attrs = read_dot_file(joinpath(@__DIR__, "data", "undirected", "ER.gv"))
    @test er_graph isa SimpleWeightedGraph

    er_ids = Dict(node.name => node.id for node in er_attrs.nodes)
    for node_name in ["course", "institute", "student"]
        @test val(er_attrs.nodes, er_ids[node_name], "shape") == "\"box\""
    end
    for node_name in ["code", "grade", "number"]
        @test val(er_attrs.nodes, er_ids[node_name], "shape") == "\"ellipse\""
    end
    for node_name in ["C-I", "S-C", "S-I"]
        @test val(er_attrs.nodes, er_ids[node_name], "shape") == "\"diamond\""
        @test val(er_attrs.nodes, er_ids[node_name], "style") == "\"filled\""
        @test val(er_attrs.nodes, er_ids[node_name], "color") == "\"lightgrey\""
    end
    er_roundtrip_dot = PlotGraphviz.string_dot(er_graph, er_attrs)
    for snippet in [
        "course [label=\"course\",shape=\"box\"]",
        "code [label=\"code\",shape=\"ellipse\"]",
        "\"C-I\" [label=\"C-I\",shape=\"diamond\",style=\"filled\",color=\"lightgrey\"]",
        "name0 [label=\"name\",shape=\"ellipse\"]",
    ]
        @test occursin(snippet, er_roundtrip_dot)
    end
    @test length(ParserCombinator.Parsers.DOT.parse_dot(er_roundtrip_dot)) == 1
    @test occursin("<svg", render_dot_to_svg(er_roundtrip_dot))

    petersen_graph, petersen_attrs = read_dot_file(joinpath(@__DIR__, "data", "undirected", "Petersen.gv"))
    @test petersen_graph isa SimpleWeightedGraph

    petersen_ids = Dict(node.name => node.id for node in petersen_attrs.nodes)
    for (a, b) in [("0", "1"), ("1", "2"), ("2", "3"), ("3", "4"), ("4", "0")]
        @test val(petersen_attrs.edges, petersen_ids[a], petersen_ids[b], "color") == "\"blue\""
        @test val(petersen_attrs.edges, petersen_ids[a], petersen_ids[b], "len") == "\"2.6\""
    end
    for (a, b) in [("0", "5"), ("1", "6"), ("2", "7"), ("3", "8"), ("4", "9")]
        @test val(petersen_attrs.edges, petersen_ids[a], petersen_ids[b], "color") == "\"red\""
        @test val(petersen_attrs.edges, petersen_ids[a], petersen_ids[b], "weight") == "\"5\""
    end

    petersen_roundtrip_dot = PlotGraphviz.string_dot(petersen_graph, petersen_attrs)
    @test occursin("graph G", petersen_roundtrip_dot)
    @test occursin("node [", petersen_roundtrip_dot)
    @test occursin("edge [", petersen_roundtrip_dot)

    # Structural safeguard: all named nodes and all named edge chains must still
    # be representable in the generated DOT (even if statement order differs).
    for n in string.(0:9)
        @test occursin("$n [", petersen_roundtrip_dot)
    end
    for (a, b) in [
        ("0", "1"), ("1", "2"), ("2", "3"), ("3", "4"), ("4", "0"),
        ("0", "5"), ("1", "6"), ("2", "7"), ("3", "8"), ("4", "9"),
        ("5", "7"), ("7", "9"), ("9", "6"), ("6", "8"), ("8", "5"),
    ]
        @test has_undirected_edge(petersen_roundtrip_dot, a, b)
    end

    petersen_roundtrip_graph = ParserCombinator.Parsers.DOT.parse_dot(petersen_roundtrip_dot)[1]
    @test any(stmt -> stmt isa ParserCombinator.Parsers.DOT.NodeAttributes, petersen_roundtrip_graph.stmts)
    @test any(stmt -> stmt isa ParserCombinator.Parsers.DOT.EdgeAttributes, petersen_roundtrip_graph.stmts)

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

    @testset "CLI parity for test/data graphs" begin
        suites = [
            ("directed", "dot", true),
            ("undirected", "neato", false),
        ]

        diagnostics = String[]

        for (subdir, prog, directed) in suites
            dir = joinpath(@__DIR__, "data", subdir)
            files = sort(filter(f -> endswith(f, ".gv"), readdir(dir; join=true)))

            for file in files
                try
                    original_dot = PlotGraphviz.read_graph(file)
                    graph, attrs = read_dot_file(file)
                    roundtrip_dot = PlotGraphviz.string_dot(graph, attrs)

                    original_plain = render_dot_with_graphviz(original_dot; prog=prog, format="plain")
                    roundtrip_plain = render_dot_with_graphviz(roundtrip_dot; prog=prog, format="plain")

                    sig_original = plain_render_signature(original_plain; directed=directed)
                    sig_roundtrip = plain_render_signature(roundtrip_plain; directed=directed)

                    missing_nodes = setdiff(sig_original.nodes, sig_roundtrip.nodes)
                    extra_nodes = setdiff(sig_roundtrip.nodes, sig_original.nodes)
                    missing_edges = setdiff(sig_original.edges, sig_roundtrip.edges)
                    extra_edges = setdiff(sig_roundtrip.edges, sig_original.edges)

                    if !(isempty(missing_nodes) && isempty(extra_nodes) && isempty(missing_edges) && isempty(extra_edges))
                        push!(diagnostics,
                            string(
                                basename(file),
                                " (", prog, "): ",
                                "missing_nodes=", collect(missing_nodes), ", ",
                                "extra_nodes=", collect(extra_nodes), ", ",
                                "missing_edges=", collect(missing_edges), ", ",
                                "extra_edges=", collect(extra_edges),
                            ),
                        )
                    end
                catch err
                    push!(diagnostics, string(basename(file), " (", prog, "): ", typeof(err), " => ", sprint(showerror, err)))
                end
            end
        end

        @test isempty(diagnostics)
    end
end
