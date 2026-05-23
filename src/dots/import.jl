# import dot files


### read & clean dot file:

function openfile(filename)
    f = open(filename, "r")
    lines = readlines(f)
    close(f)
    lines
end


function read_lines(filename::AbstractString)

    lines = openfile(filename)
    lines = delete_comments(lines)
    lines = small_corrections(lines)

    Base.join(lines, "\n")
    return lines
end



# use ParserCombinator.Parsers.DOT to convert to attributes
function parse_dot_file(my_graph)
    graphs_parser_combinator = ParserCombinator.Parsers.DOT.parse_dot(my_graph)

    #TODO: if more graphs are in one dot-files:
    graph_parser_combinator = graphs_parser_combinator[1]

    return graph_parser_combinator
end

# delete comments "//", "/*", "*" or "*/"
function delete_comments(lines)
    new_lines = []
    for line in lines
        if !isnothing(findfirst("//", lstrip(line))) || !isnothing(findfirst("/*", lstrip(line))) || !isnothing(findfirst("*", lstrip(line))) || isempty(line)
            continue
        end
        push!(new_lines, line)
    end
    return new_lines
end

function small_corrections(lines)
    for line in lines
        line = replace(line, "\t" => "")
        line = replace(line, " ]" => "]")
        line = replace(line, "[ " => "[")
        line = replace(line, ";" => ";\n")
        # line = replace(line, "node" => "\n node")
        # line = replace(line, "edge" => "\n edge")
        # line = replace(line, "graph" => "\n graph")
    end
    return lines
end


function preprocessing(filename)
    lines = openfile(filename)
    new_lines = []
    temp = ""
    multi_line_option = false
    subgraph = false

    edge_options = 0
    node_options = 0

    for line in lines

        # some small corrections:
        line = replace(line, "\t" => "")
        line = replace(line, " ]" => "]")
        line = replace(line, "[ " => "[")
        line = replace(line, ";" => ";\n")
        # line = replace(line, "node" => "\n node")
        # line = replace(line, "edge" => "\n edge")
        # line = replace(line, "graph" => "\n graph")

        # identify node, edge subgraphs
        if !isnothing(findfirst("node", line))
            node_options += 1
            if node_options == 2
                line = "subgraph {\n" * line
            elseif node_options > 2
                node_options = 1
                line = line * "\n}"
            end
        end


        # delete comments and empty lines:
        if !isnothing(findfirst("//", lstrip(line))) || !isnothing(findfirst("/*", lstrip(line))) || !isnothing(findfirst("*", lstrip(line))) || isempty(line)
            continue
        end

        if !(multi_line_option)

            # multi subgraph lines:
            if !isnothing(findfirst("{", lstrip(line)))
                idx = findfirst("{", lstrip(line))
                if idx.stop < 2
                    subgraph = true
                    multi_line_option = true
                end
            end

            # in case of edge line: 
            # if !(isnothing(findfirst("--", line))) || !(isnothing(findfirst("->", line)))
            #     push!(new_lines, line)
            #     continue
            # end

            optionend = findfirst("]", line)
            if !isnothing(optionend)
                if !(isempty(lstrip(line[(optionend.stop+1):end])))
                    if (lstrip(line[optionend.stop+1:optionend.stop+1]) == "\"")
                        optionend = findlast("]", line)
                    end
                end
            end

            # if there are node,egde or graph options:
            if !isnothing(findfirst("node", line)) || !isnothing(findfirst("edge", line)) || !isnothing(findfirst("graph", line))
                if !isnothing(optionend)
                    if !(isempty(lstrip(line[(optionend.stop+1):end]))) && !(lstrip(line[(optionend.stop+1):end]) == ";") && !(lstrip(line[(optionend.stop+1):end]) == ";\n") && (isnothing(findfirst("[", line[(optionend.stop+1):end])))

                        str = "subgraph {\n " * line * " \n}"
                        push!(new_lines, str)
                        continue
                    else
                        push!(new_lines, line)
                        continue
                    end
                end
            end

            # if multi-line syntax:
            if !isnothing(findfirst("[", line)) && isnothing(optionend)
                temp = temp * line
                multi_line_option = true
                continue
            end

            # one-line sub-graph "node"
            if !isnothing(optionend)

                if isnothing(findfirst("{", line[1:optionend.start]))

                    if (isnothing(findfirst("--", line))) && (isnothing(findfirst("->", line)))

                        if !(isempty(lstrip(line[(optionend.stop+1):end]))) && !(lstrip(line[(optionend.stop+1):end]) == ";")

                            # @show lstrip(line[(optionend.stop+1):end])
                            if !isnothing(findfirst("[", line[optionend.stop:end]))
                                push!(new_lines, line)
                                continue

                            elseif isnothing(findfirst("{", line[optionend.stop:end]))

                                if (isempty(lstrip(line[(optionend.stop+1):end]))) # !(lstrip(line[(optionend.stop+1):end]) == ";") && 
                                    str = "subgraph {\n " * line * " \n}"
                                    push!(new_lines, str)
                                    continue
                                end
                            else
                                idx = findfirst("{", line[optionend.stop:end])
                                str = insert_at!(line, "\n", (optionend.stop + idx.start - 1))
                                push!(new_lines, str)
                                continue
                            end
                        end
                    end
                end
            end

            # add line to new_lines
            push!(new_lines, line)
        else

            if (subgraph == false)
                temp = temp * " " * line
                if !isnothing(findfirst("]", line))
                    temp = replace(temp, "\t" => "")
                    temp = replace(temp, " ]" => "]")
                    temp = replace(temp, "[ " => "[")
                    temp = replace(temp, ";" => ";\n")
                    push!(new_lines, temp)
                    multi_line_option = false
                    temp = ""
                end
            else
                push!(new_lines, line)
                if !isnothing(findfirst("}", lstrip(line)))
                    subgraph = false
                    multi_line_option = false
                end
            end
        end
    end

    if node_options == 2
        str = "\n}"
        push!(new_lines, str)
    end

    # #DEBUG:
    #for line in new_lines
    #    @show line
    #end


    return Base.join(new_lines, "\n")
end


