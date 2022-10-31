abstract type WilsonModel <: ActivityModel end

Wilson_SETUP = ModelOptions(
        :Wilson;
        supertype=WilsonModel,
        locations=["properties/critical.csv", "properties/molarmass.csv","Activity/Wilson/Wilson_unlike.csv"],
        inputparams=[
            ParamField(:g, PairParam{Float64}),
            ParamField(:Tc, SingleParam{Float64}),
            ParamField(:pc, SingleParam{Float64}),
            ParamField(:Mw, SingleParam{Float64}),
            ParamField(:w, SingleParam{Float64}),
        ],
        params=[
            ParamField(:g, PairParam{Float64}),
            ParamField(:Tc, SingleParam{Float64}),
            ParamField(:Pc, SingleParam{Float64}),
            ParamField(:ZRA, SingleParam{Float64}),
            ParamField(:Mw, SingleParam{Float64}),
        ],
        mappings=[
            ModelMapping([:pc], [:Pc], identity),
            ModelMapping([:w], [:ZRA], x -> x * -0.08775 + 0.29056),
        ],
        param_options=ParamOptions(
            asymmetricparams=["g"],
            ignore_missing_singleparams=["g"],
        ),
        members=[
            ModelMember(:puremodel, :PR; split=true),
        ],
        references=["10.1021/ja01056a002"],
    )

createmodel(Wilson_SETUP; verbose=true)
export Wilson

"""
    Wilson <: ActivityModel

    Wilson(components::Vector{String};
    puremodel = PR,
    userlocations = String[], 
    pure_userlocations = String[],
    verbose = false)

## Input parameters
- `Tc`: Single Parameter (`Float64`) - Critical Temperature `[K]`
- `Pc`: Single Parameter (`Float64`) - Critical Pressure `[Pa]`
- `ZRA`: Single Parameter (`Float64`) - Rackett Compresibility factor
- `Mw`: Single Parameter (`Float64`) - Molecular Weight `[g/mol]`
- `g`: Pair Parameter (`Float64`, asymetrical, defaults to `0`) - Interaction Parameter

## Input models
- `puremodel`: model to calculate pure pressure-dependent properties

## Description
Wilson activity model, with Rackett correlation for liquid volume:
```
Gᴱ = nRT∑xᵢlog(∑xⱼjΛᵢⱼ)
Λᵢⱼ = exp(-gᵢⱼ/T)*Vⱼ/Vᵢ
Vᵢ = (RTcᵢ/Pcᵢ)(0.29056 - 0.08775ZRAᵢ)^(1 + (1-T/Tcᵢ)^2/7)
```

## References
1. Wilson, G. M. (1964). Vapor-liquid equilibrium. XI. A new expression for the excess free energy of mixing. Journal of the American Chemical Society, 86(2), 127–130. [doi:10.1021/ja01056a002](https://doi.org/10.1021/ja01056a002)

"""
Wilson

function activity_coefficient(model::WilsonModel,p,T,z)
    ZRA = model.params.ZRA.values
    Tc  = model.params.Tc.values
    Pc  = model.params.Pc.values
    
    Tr  = T ./ Tc
    V =  @. (R̄ *Tc/Pc)*ZRA^(1 + (1-Tr)^2/7)
    Λ = (V' ./ V) .*exp.(-model.params.g.values/R̄/T)
    x = z ./ sum(z)
    lnγ = 1 .- log.(sum(x[i]*Λ[:,i] for i ∈ @comps)) .-sum(x[j] .*Λ[j,:] ./(sum(x[i]*Λ[j,i] for i ∈ @comps)) for j ∈ @comps)
    return exp.(lnγ)
end

function excess_gibbs_free_energy(model::WilsonModel,p,T,z)
    ZRA = model.params.ZRA.values
    Tc  = model.params.Tc.values
    Pc  = model.params.Pc.values
    g = model.params.g.values
    _0 = zero(T+first(z))
    n = sum(z)
    invn = 1/n
    invRT = 1/(R̄*T)
    res = _0
    #a^b^c is too slow to be done on a quadratic loop
    V = zeros(typeof(T),length(model))
    for i ∈ @comps
        Tci = Tc[i]
        Tri = T/Tci
        V[i] = (R̄ *Tci/Pc[i])*ZRA[i]^(1 + (1-Tri)^2/7)
    end
    for i ∈ @comps
        ∑xΛ = _0
        xi = z[i]*invn
        for j ∈ @comps
            Λij = exp(-g[i,j]*invRT)*V[j]/V[i]

            ∑xΛ += Λij*z[j]*invn
        end
        res += xi*log(∑xΛ)
    end
    return -n*res*R̄*T
end
