
using ParserCombinator
using AutoHashEquals
import Base: ==

# export uStatement, Statements, ID, StringID, NumericID, HtmlID, Attribute,
#     Attributes, Graph, Port, uNodeID, uNode, EdgeNode, uEdge, GraphAttributes,
#     NodeAttributes, EdgeAttributes, uSubGraph, parse_dot, nodes, edges

# i've gone with a very literal parsing, which returns a structure that is
# pretty much what is described in the grammar at
# http://www.graphviz.org/content/dot-language.  this is because it is not
# clear to me exactly how the syntax is connected to the semantics of graph
# layout.  for example, a simple graph like the one at
# http://www.graphviz.org/Gallery/gradient/colors.gv.txt has the uNode
# attributes specified before the uNode ID.  if you look at the syntax
# carefully that means that the attributes are not associated with that
# particular uNode (such attributes come after the uNode ID) and instead seem to
# be "global" uNode attributes in some sense.  so the format is more like a
# "program" (where order is important, with the "global" uNode attributes
# changing as the file is "processed") than a specification.

# see test/dot/examples.jl for examples accessing fields in this structure

abstract type uStatement end

const Statements = Vector{uStatement}

abstract type ID end

@auto_hash_equals struct StringID <: ID
    id::AbstractString
end

@auto_hash_equals struct NumericID <: ID
    id::AbstractString
end

@auto_hash_equals struct HtmlID <: ID
    id::AbstractString
end

@auto_hash_equals struct Attribute <: uStatement
    name::ID
    value::ID
end

const uAttributes = Vector{Attribute}

@auto_hash_equals struct Graph
    strict::Bool
    directed::Bool
    id::Union{ID,Nothing}
    stmts::Statements
    Graph(s::Bool, d::Bool, id::ID, st::Statements) = new(s, d, id, st)
    Graph(s::Bool, d::Bool, st::Statements) = new(s, d, nothing, st)
end

@auto_hash_equals struct uSubGraph <: uStatement
    id::Union{ID,Nothing}
    stmts::Statements
    uSubGraph(id::ID, s::Statements) = new(id, s)
    uSubGraph(s::Statements) = new(nothing, s)
end

@auto_hash_equals struct Port
    id::Union{ID,Nothing}
    point::Union{AbstractString,Nothing}
    Port(id::ID, p::Union{AbstractString,Nothing}=nothing) = new(id, p)
    Port(p::AbstractString) = new(nothing, p)
end

@auto_hash_equals struct uNodeID
    id::ID
    port::Union{Port,Nothing}
    uNodeID(id::ID, p::Union{Port,Nothing}=nothing) = new(id, p)
end

@auto_hash_equals struct uNode <: uStatement
    id::uNodeID
    attrs::uAttributes
    uNode(id::uNodeID, a::uAttributes) = new(id, a)
    uNode(id::uNodeID) = new(id, Attribute[])
end

const EdgeNode = Union{uNodeID,uSubGraph}
const EdgeNodes = Vector{EdgeNode}

@auto_hash_equals struct uEdge <: uStatement
    nodes::EdgeNodes
    attrs::uAttributes
    uEdge(n::EdgeNodes, a::uAttributes) = new(n, a)
    uEdge(n::EdgeNodes) = new(n, Attribute[])
end

@auto_hash_equals struct GraphAttributes <: uStatement
    attrs::uAttributes
end

@auto_hash_equals struct NodeAttributes <: uStatement
    attrs::uAttributes
end

@auto_hash_equals struct EdgeAttributes <: uStatement
    attrs::uAttributes
end


@with_names begin

    # x can include alternatives that can also be discarded
    mkspc(x) = "([ \t]|\n#.*|\n|//.*|/\\*(.|\n)*?\\*/$x)*"

    spc = mkspc("")
    spc_init = ~Pattern(string("(#.*)?", spc))
    spc_star = ~Pattern(spc)

    wrd = p"[a-zA-Z\200-\377_][a-zA-Z\200-\377_0-9]*"

    # valid strings include:
    # 1 - "..."
    # 2 - "...\
    #      ..."
    # 3 = "..." + "..."
    # and all can contain quoted quotes
    unesc(s) = replace(s, "\\\"" => "\"")
    unesc_join(s...) = string(map(unesc, s)...)
    str_cont = Pattern("((?:[^\"\n]|\\\\\")*)\\\\\\\n", 1)
    str_end = p"([^\"\n]|\\\\\")*"
    str_one = Seq!(E"\"", Star!(str_cont), str_end, E"\"")
    str_many = Seq!(str_one, Star!(Seq!(spc_star, E"+", spc_star, str_one))) > unesc_join

    str_id = Alt!(wrd, str_many) > StringID

    num_id = p"-?(\.[0-9]+|[0-9]+(\.[0-9]*)?)" > NumericID

    # this is bracketed by <> (in addition to the xml).  not clear from
    # the grammar, but see test/dot/tictactoe.dot
    html_id = Pattern("<((:?[ \t\n]|<(:?[^<>]|\n)+>)*)>", 1) > HtmlID

    id = Alt!(str_id, num_id, html_id)

    cmp = p"(n|ne|e|se|s|sw|w|nw|c|_)"
    col = E":"

    # port grammar seeems to be ambiguous, since :ID could be :point
    # this is a best guess at what was meant
    port = Alt!(Seq!(col, spc_star, id, spc_star, col, spc_star, cmp),
        Seq!(col, spc_star, cmp),
        Seq!(col, spc_star, id)) > Port

    # this is a raw ID=ID, not the attr_stmt in the grammar
    attr = Seq!(id, spc_star, E"=", spc_star, id) > Attribute

    spc_attr = ~Pattern(mkspc("|;|,"))
    # for some reason 0.3 does not like |> uAttributes here
    attr_list = PlusList!(Seq!(E"[", StarList!(attr, spc_attr), E"]"), spc_star) |> (x -> Attribute[x...])

    node_id = Seq!(id, spc_star, Opt!(port)) > uNodeID
    node_stmt = Seq!(node_id, spc_star, Opt!(attr_list)) > uNode

    NoCase(s) = Pattern(join(["[$(lowercase(c))$(uppercase(c))]" for c in s]))

    stmt = Delayed()

    # not a list because we can have a trailing ;
    # this eats trailing spaces, but i don't think it matters
    # the comma (",") below is not in the grammar at graphviz.org but is
    # needed to parse the examples in test/examples.jl
    # related, note that using a comma in this way seems to trigger bugs
    # in dot itself - see
    # https://github.com/JuliaGraphs/LightGraphs.jl/issues/107#issuecomment-131401430
    spc_stmt = ~Pattern(mkspc("|;|,"))
    # |> Statements but for 0.3
    stmt_list = Star!(Seq!(stmt, spc_stmt)) |> (x -> uStatement[x...])
    stmt_brak = Seq!(E"{", spc_star, stmt_list, spc_star, E"}")

    sub_graph = Seq!(Opt!(~NoCase("uSubGraph")), spc_star, Opt!(id), spc_star, stmt_brak) > uSubGraph

    # order important here, since we don't backtrack and "uSubGraph" could
    # be a uNode
    edge_node = Alt!(sub_graph, node_id)
    edge_sep = Seq!(spc_star, P"(--|->)", spc_star)
    # |> EdgeNodes but for 0.3
    edge_list = Seq!(edge_node, edge_sep, PlusList!(edge_node, edge_sep)) |> (x -> EdgeNode[x...])
    edge_stmt = Seq!(edge_list, spc_star, Opt!(attr_list)) > uEdge

    attr_stmt = Alt!(Seq!(~NoCase("graph"), spc_star, attr_list) > GraphAttributes,
        Seq!(~NoCase("uNode"), spc_star, attr_list) > NodeAttributes,
        Seq!(~NoCase("uEdge"), spc_star, attr_list) > EdgeAttributes)

    # order important here as node_stmt can match almost anything
    stmt.matcher = Alt!(edge_stmt, attr_stmt, attr, sub_graph, node_stmt)

    strict = Alt!(Seq!(~NoCase("strict"), Insert(true)), Insert(false))
    direct = Alt!(Seq!(~NoCase("digraph"), Insert(true)),
        Seq!(~NoCase("graph"), Insert(false)))
    graph = Seq!(strict, spc_star, direct, spc_star, Opt!(id), spc_star, stmt_brak) > Graph

    dot = Seq!(spc_init, Plus!(Seq!(graph, spc_star)), Eos())
end

# the file structured using the types above (returns an array of graphs)
function parse_my_dot(s; debug=false)
    try
        if debug
            parse_one_dbg(s, Trace(dot); debug=true)
        else
            parse_one(s, dot)
        end
    catch x
        if debug
            Base.show_backtrace(stdout, catch_backtrace())
        end
        rethrow()
    end
end


# set of all nodes
# expand both nodes and edges, then use sets to de-duplicate
nodes(g::Graph) = reduce(union, map(nodes, g.stmts))
nodes(s::uStatement) = Set()
nodes(s::uSubGraph) = reduce(union, map(nodes, s.stmts))
nodes(n::uNode) = nodes(n.id)
nodes(n::uNodeID) = Set([n.id.id])
nodes(e::uEdge) = reduce(union, map(nodes, e.nodes))

# set of all uNode pairs that correspond to edges
fix_directed(g::Graph, e) = g.directed ? Set(e) : Set([Tuple(sort(collect(p))) for p in e])
edges(g::Graph) = fix_directed(g, reduce(vcat, map(edges_, g.stmts)))
edges_(s::uStatement) = []
edges_(s::uSubGraph) = reduce(vcat, map(edges_, s.stmts))
pair(n1::uNodeID, n2::uNodeID) = [(n1.id.id, n2.id.id)]
pair(n::uNodeID, s::uSubGraph) = vcat([(n.id.id, x) for x in nodes(s)], edges_(s))
pair(s::uSubGraph, n::uNodeID) = vcat([(x, n.id.id) for x in nodes(s)], edges_(s))
pair(s1::uSubGraph, s2::uSubGraph) =
    vcat(vec([(x, y) for x in nodes(s1), y in nodes(s2)]), edges_(s1), edges_(s2))
edges_(e::uEdge) = reduce(vcat, [pair(a, b) for (a, b) in zip(e.nodes[1:end-1], e.nodes[2:end])])
