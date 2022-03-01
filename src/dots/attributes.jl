

abstract type GraphvizPoperties end

mutable struct Property{T} 
    key::String
    value::T
end


const Properties = Vector{Property}

# return val of attribute:
function val(attributes::Properties, attribute::String)
    if !isempty(attributes)
        for a in attributes
            if a.key == attribute
                return a.value
            end
        end
    end
    return []
end

# return Tuple (bool, pos). bool=true if key exist in Attributes
import Base.haskey
function haskey(attributes::Properties, key::String)
    if !isempty(attributes)
        for i = 1:length(attributes)
            if attributes[i].key == key
                return true, i
            end
        end
    end
    return false, 0
end

# set val to attributeDict
function set!(attributes::Properties, key::String, value)
    key_exist, idx = haskey(attributes, key)
    if key_exist
        attributes[idx].value = value
    else
        push!(attributes, Property(key, value))
    end
end

# remove attribute of attributes
function rm!(attributes::Properties, key::String)
    key_exist, idx = haskey(attributes, key)
    (key_exist) ? deleteat!(attributes, idx) : nothing
end