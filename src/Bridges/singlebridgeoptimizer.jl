struct SingleBridgeOptimizer{BT<:AbstractBridge, MT<:MOI.ModelLike, T, OT<:MOI.ModelLike} <: AbstractBridgeOptimizer
    model::OT
    bridged::MT
    bridges::Dict{CI, BT}
end
function SingleBridgeOptimizer{BT, MT, T}(model::OT) where {BT, MT, T, OT <: MOI.ModelLike}
    SingleBridgeOptimizer{BT, MT, T, OT}(model, MT(), Dict{CI, BT}())
end

isbridged(b::SingleBridgeOptimizer, ::Type{<:MOI.AbstractFunction}, ::Type{<:MOI.AbstractSet}) = false
bridgetype(b::SingleBridgeOptimizer{BT}, ::Type{<:MOI.AbstractFunction}, ::Type{<:MOI.AbstractSet}) where BT = BT

# :((Zeros, SecondOrderCone)) -> (:(MOI.Zeros), :(MOI.SecondOrderCone))
_tuple_prefix_moi(t) = MOIU._moi.(t.args)

"""
macro bridge(modelname, bridge, scalarsets, typedscalarsets, vectorsets, typedvectorsets, scalarfunctions, typedscalarfunctions, vectorfunctions, typedvectorfunctions)

Creates a type `modelname` implementing the MOI model interface and bridging the `scalarsets` scalar sets `typedscalarsets` typed scalar sets, `vectorsets` vector sets, `typedvectorsets` typed vector sets, `scalarfunctions` scalar functions, `typedscalarfunctions` typed scalar functions, `vectorfunctions` vector functions and `typedvectorfunctions` typed vector functions.
To give no set/function, write `()`, to give one set `S`, write `(S,)`.

### Examples

The optimizer layer bridging the constraints `ScalarAffineFunction`-in-`Interval` is created as follows:
```julia
@bridge SplitInterval MOIB.SplitIntervalBridge () (Interval,) () () () (ScalarAffineFunction,) () ()
```
Given an optimizer `optimizer` implementing `ScalarAffineFunction`-in-`GreaterThan` and `ScalarAffineFunction`-in-`LessThan`, the optimizer
```
bridgedmodel = SplitInterval(model)
```
will additionally support `ScalarAffineFunction`-in-`Interval`.
"""
macro bridge(modelname, bridge, ss, sst, vs, vst, sf, sft, vf, vft)
    bridgedmodelname = Symbol(string(modelname) * "Instance")
    bridgedfuns = :(Union{$(_tuple_prefix_moi(sf)...), $(_tuple_prefix_moi(sft)...), $(_tuple_prefix_moi(vf)...), $(_tuple_prefix_moi(vft)...)})
    bridgedsets = :(Union{$(_tuple_prefix_moi(ss)...), $(_tuple_prefix_moi(sst)...), $(_tuple_prefix_moi(vs)...), $(_tuple_prefix_moi(vst)...)})

    esc(quote
        $MOIU.@model $bridgedmodelname $ss $sst $vs $vst $sf $sft $vf $vft
        const $modelname{T, OT<:MOI.ModelLike} = $MOIB.SingleBridgeOptimizer{$bridge{T}, $bridgedmodelname{T}, T, OT}
        isbridged(::$modelname, ::Type{<:$bridgedfuns}, ::Type{<:$bridgedsets}) = true
        supportsbridgingconstraint(::$modelname, ::Type{<:$bridgedfuns}, ::Type{<:$bridgedsets}) = true
    end)
end
