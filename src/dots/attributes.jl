

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
set!(attributes::Properties, prop::Property; override=true) = set!(attributes, prop.key, prop.value; override)

function set!(attributes::Properties, key::String, value; override=true)
    key_exist, idx = haskey(attributes, key)
    if key_exist & (override == true)
        attributes[idx].value = check_value(value)
    else
        push!(attributes, Property(key, check_value(value)))
    end
end

# remove attribute of attributes
rm!(attributes::Properties, prop::Property) = rm!(attributes, prop.key)

function rm!(attributes::Properties, key::String)
    key_exist, idx = haskey(attributes, key)
    (key_exist) ? deleteat!(attributes, idx) : nothing
end