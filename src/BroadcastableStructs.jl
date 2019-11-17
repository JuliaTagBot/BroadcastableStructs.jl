module BroadcastableStructs

# Use README as the docstring of the module:
@doc let path = joinpath(dirname(@__DIR__), "README.md")
    include_dependency(path)
    replace(read(path, String), r"^```julia"m => "```jldoctest README")
end BroadcastableStructs

export BroadcastableStruct, BroadcastableCallable

import Setfield
using ZygoteRules: @adjoint

const constructorof = try
    Setfield.constructorof
catch
    Setfield.constructor_of
end

@inline foldlargs(op, x) = x
@inline foldlargs(op, x1, x2, xs...) = foldlargs(op, op(x1, x2), xs...)
# Unroll by hand (optimization):
@inline foldlargs(op, x1, x2) = op(x1, x2)
@inline foldlargs(op, x1, x2, x3) = op(op(x1, x2), x3)
@inline foldlargs(op, x1, x2, x3, x4) = op(op(op(x1, x2), x3), x4)
@inline foldlargs(op, x1, x2, x3, x4, x5) = op(op(op(op(x1, x2), x3), x4), x5)
@inline foldlargs(op, x1, x2, x3, x4, x5, x6) = op(op(op(op(op(x1, x2), x4), x3), x5), x6)
@inline foldlargs(op, x1, x2, x3, x4, x5, x6, x7) =
    op(op(op(op(op(op(x1, x2), x3), x4), x5), x6), x7)
@inline foldlargs(op, x1, x2, x3, x4, x5, x6, x7, x8) =
    op(op(op(op(op(op(op(x1, x2), x3), x4), x5), x6), x7), x8)
@inline foldlargs(op, x1, x2, x3, x4, x5, x6, x7, x8, x9) =
    op(op(op(op(op(op(op(op(x1, x2), x3), x4), x5), x6), x7), x8), x9)
@inline foldlargs(op, x1, x2, x3, x4, x5, x6, x7, x8, x9, x10) =
    op(op(op(op(op(op(op(op(op(x1, x2), x3), x4), x5), x6), x7), x8), x9), x10)

abstract type BroadcastableStruct end

fieldvalues(obj) = ntuple(i -> getfield(obj, i), nfields(obj))

Broadcast.broadcastable(obj::BroadcastableStruct) =
    Broadcast.broadcasted(constructorof(typeof(obj)), fieldvalues(obj)...)

Base.ndims(T::Type{<:BroadcastableStruct}) =
    mapreduce(ndims, max, fieldtypes(T); init=0)

#=
Base.axes(obj::BroadcastableStruct) = axes(Broadcast.broadcastable(obj))
Base.length(obj::BroadcastableStruct) = prod(length.(axes(obj)))

Base.getindex(obj::BroadcastableStruct, i::Int...) =
    Broadcast.broadcastable(obj)[i...]
=#

abstract type BroadcastableCallable <: BroadcastableStruct end

@inline Broadcast.broadcasted(c::BroadcastableCallable, args...) =
    Broadcast.broadcasted(calling(c), deconstruct(c)..., args...)

@inline deconstruct(obj::T) where T =
    foldlargs((), fieldvalues(obj)...) do fields, x
        if x isa BroadcastableStruct
            (fields..., deconstruct(x)...)
        else
            (fields..., x)
        end
    end

@inline _reconstruct(::T, fields) where T = constructorof(T)(fields...)

@inline function reconstruct(f, obj::T, allargs...) where T
    fields, args = foldlargs(((), allargs), fieldvalues(obj)...) do (fields, allargs), x
        if x isa BroadcastableStruct
            y, rest = reconstruct(f, x, allargs...)
            ((fields..., y), rest)
        else
            ((fields..., allargs[1]), Base.tail(allargs))
        end
    end
    return f(obj, fields), args
end

# Manually flatten broadcast to avoid unbroadcast MethodError:
# https://github.com/FluxML/Zygote.jl/issues/313
calling(obj::T) where T = @inline function(allargs...)
    f, args = reconstruct(_reconstruct, obj, allargs...)
    return f(args...)
end

@adjoint fieldvalues(obj::T) where T = fieldvalues(obj), function(v)
    (NamedTuple{fieldnames(T)}(v),)
end

end # module
