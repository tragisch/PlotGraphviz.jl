
struct gvNode <: GraphvizPoperties
    id::Int64
    name::String
    attributes::Properties
end

gvNode(id::Int64) = gvNode(id, String(id), Properties())

const gvNodes = Vector{gvNode}

struct gvEdge <: GraphvizPoperties
    from::Int
    to::Int
    attributes::Properties
end

gvEdge(from::Int, to::Int) = gvEdge(from, to, Properties())

const gvEdges = Vector{gvEdge}


struct gvSubGraph
    type::String
    plot_options::Properties
    graph_options::Properties
    node_options::Properties
    edge_options::Properties
    nodes::gvNodes
    edges::gvEdges
end

# empty outer constructor:
function gvSubGraph(type::String)
    type = type
    plot_options = Properties()
    graph_options = Properties()
    node_options = Properties()
    edge_options = Properties()
    node = gvNodes()
    edges = gvEdges()

    return gvSubGraph(type, plot_options, graph_options, node_options, edge_options, node, edges)
end

const gvSubGraphs = Vector{gvSubGraph}

# the main struct!
struct GraphvizAttributes
    plot_options::Properties
    graph_options::Properties
    node_options::Properties
    edge_options::Properties
    subgraphs::gvSubGraphs
    nodes::gvNodes
    edges::gvEdges
end

# empty outer constructor:
function GraphvizAttributes()
    plot_options = Properties()
    graph_options = Properties()
    node_options = Properties()
    edge_options = Properties()
    subgraphs = gvSubGraphs()
    node = gvNodes()
    edges = gvEdges()

    return GraphvizAttributes(plot_options, graph_options, node_options, edge_options, subgraphs, node, edges)
end

# derived from SimpleWeightedGraph
function GraphvizAttributes(graph::AbstractSimpleWeightedGraph; node_label::Bool = true, edge_label::Bool = false)
    directed = Graphs.is_directed(graph)
    n = nv(graph)
    large_graph = 200

    plot_options = [Property("weights", (edge_label) ? "true" : "false"),
        Property("largenet", "200")]

    graph_options = [Property("center", "\"1,1\""),
        Property("overlap", "scale"),
        Property("concentrate", "true"),
        Property("layout", (directed) ? "dot" : "neato"),
        Property("size", (n < 20) ? "3.0" : ((n < 100) ? "7.0" : "10.0"))]  # scaling function missing!
    node_options = [Property("color", "Turquoise"),
        Property("fontsize", (node_label) ? ((n < 100) ? "7.0" : "5.0") : "1.0"),
        Property("width", (node_label) ? "0.25" : "0.20"),
        Property("height", (node_label) ? "0.25" : "0.20"),
        Property("fixedsize", "true"),
        Property("shape", (node_label) ? "circle" : "point")]
    edge_options = [Property("arrowsize", "0.5"),
        Property("arrowtype", "normal"),
        Property("fontsize", (edge_label) ? "8.0" : "1.0")]

    nodes = [gvNode(i, "$i", Properties()) for i = 1:n]

    edges = []
    for i = 1:n, j = 1:n
        if !(graph.weights[i, j] == 0)
            push!(edges, gvEdge(i, j, [Property("xlabel", graph.weights[i, j])]))
        end
    end

    gv_attr = GraphvizAttributes(plot_options, graph_options, node_options, edge_options, gvSubGraphs(), nodes, edges)

    # modifier by large networks:
    if n > large_graph
        gv_attr = mod_attr_large_network!(gv_attr)
    end

    return gv_attr
end

function mod_attr_large_network!(attrs::GraphvizAttributes)
    set!(attrs.graph_options, "fontsize", "1")
    set!(attrs.graph_options, "concetrate", "true")
    set!(attrs.graph_options, "layout", "sfdp")
    set!(attrs.plot_options, "weights", "false")
    set!(attrs.node_options, "shape", "point")
    set!(attrs.node_options, "color", "black")

    return attrs
end

"""
    set!(edges::gvEdges, from::Int, to::Int, attribute::Property)
    set!(edges::gvEdges, from::String, to::String, attribute::Property))
    set!(nodes::gvNodes, id::Int, attribute::Property)
    set!(nodes::gvNodes, name::String, attribute::Property)

    set (Graphviz) Property of nodes or edges

"""
function set!(edges::gvEdges, from::Int, to::Int, attribute::Property; override = true)
    if !isempty(edges)
        for e in edges
            if (e.from == from) && (e.to == to) && (override == true)
                set!(e.attributes, attribute.key, attribute.value)
            end
        end
    else
        push!(edges, gvEdge(from, to, [attribute]))
    end
end

function set!(nodes::gvNodes, id::Int, attribute::Property)
    if !isempty(nodes)
        for n in nodes
            if n.id == id
                set!(n.attributes, attribute.key, attribute.value)
            end
        end
    else
        push!(nodes, gvNode(id, String(id), [attribute]))
    end
end


function set!(nodes::gvNodes, name::String, attribute::Property)
    if !isempty(nodes)
        for n in nodes
            if n.name == name
                set!(n.attributes, attribute.key, attribute.value)
            end
        end
    else
        max = _max_id(nodes::gvNodes)
        push!(nodes, gvNode((max + 1), name, [attribute]))
    end
end

# getter:
function val(edges::gvEdges, from::Int, to::Int, key::String)
    if !isempty(edges)
        for e in edges
            if (e.from == from) && (e.to == to)
                return val(e.attributes, key)
            end
        end
    end
    return []
end

function val(nodes, id::Int64, key::String)
    if !isempty(nodes)
        for n in nodes
            if n.id == id
                return val(n.attributes, key)
            end
        end
    end
    return []
end

# special functions
function _get_label(nodes::gvNodes, id::Int64)
    if !isempty(nodes)
        for n in nodes
            if n.id == id
                label = val(n.attributes, "label")
                if !isempty(label)
                    return label
                end
            end
        end
    end
    return []
end

# get max (number of node) id of nodes
function _max_id(nodes::gvNodes)
    max = 0
    if !isempty(nodes)
        for n in nodes
            (n.id > max) ? max = n.id : nothing
        end
    end
    return max
end

# return id from node_label!
function get_id(nodes, str)
    if !isempty(nodes)
        for n in nodes
            #  labl = val_node(nodes, n.id, "label")
            if n.name == str
                return n.id
            end
        end
    end
    return 0
end

function get_name(nodes, id)
    if !isempty(nodes)
        for n in nodes
            #  labl = val_node(nodes, n.id, "label")
            if n.id == id
                return n.name
            end
        end
    end
    return 0
end


function get_node(nodes::gvNodes, id::Int)
    for node in nodes
        if node.id == id
            return node
        end
    end
    return []
end

