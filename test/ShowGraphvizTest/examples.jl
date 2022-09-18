module Examples

using ShowGraphviz: @derive, @deriveall, @dot_str

const hello_world = dot"digraph G {Hello->World}"

# https://graphviz.org/Gallery/directed/cluster.html
const cluster = dot"""
digraph G {

	subgraph cluster_0 {
		style=filled;
		color=lightgrey;
		node [style=filled,color=white];
		a0 -> a1 -> a2 -> a3;
		label = "process #1";
	}

	subgraph cluster_1 {
		node [style=filled];
		b0 -> b1 -> b2 -> b3;
		label = "process #2";
		color=blue
	}
	start -> a0;
	start -> b0;
	a1 -> b3;
	b2 -> a3;
	a3 -> a0;
	a3 -> end;
	b3 -> end;

	start [shape=Mdiamond];
	end [shape=Msquare];
}
"""

abstract type AbstractHelloWorld end
struct HelloWorldSVG <: AbstractHelloWorld end
struct HelloWorldAll <: AbstractHelloWorld end

Base.show(io::IO, m::MIME"text/vnd.graphviz", ::AbstractHelloWorld) =
    show(io, m, hello_world)

@derive HelloWorldSVG "image/svg+xml"
@deriveall HelloWorldAll

end  # module
