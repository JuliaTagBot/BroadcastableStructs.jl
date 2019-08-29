module BroadcastableStructs

export BroadcastableStruct, BroadcastableCallable

using Setfield: constructor_of

abstract type BroadcastableStruct end

fieldvalues(obj) = ntuple(i -> getfield(obj, i), fieldcount(typeof(obj)))

Broadcast.broadcastable(obj::BroadcastableStruct) =
    Broadcast.broadcasted(constructor_of(typeof(obj)), fieldvalues(obj)...)

#=
Base.ndims(T::Type{<:BroadcastableStruct}) =
    mapreduce(ndims, max, fieldtypes(T); init=0)

Base.axes(obj::BroadcastableStruct) = axes(Broadcast.broadcastable(obj))
Base.length(obj::BroadcastableStruct) = prod(length.(axes(obj)))

Base.getindex(obj::BroadcastableStruct, i::Int...) =
    Broadcast.broadcastable(obj)[i...]
=#

abstract type BroadcastableCallable <: BroadcastableStruct end

call(f, args...) = f(args...)

@inline Broadcast.broadcasted(c::BroadcastableCallable, args...) =
    Broadcast.broadcasted(call, c, args...)

end # module
