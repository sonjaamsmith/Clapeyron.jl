abstract type UMRRuleModel <: MixingRule end

struct UMRRule{γ} <: UMRRuleModel
    components::Array{String,1}
    activity::γ
    references::Array{String,1}
end

@registermodel UMRRule

"""
    UMRRule{γ} <: UMRRuleModel
    
    UMRRule(components::Vector{String};
    activity = UNIFAC,
    userlocations::Vector{String}=String[],
    activity_userlocations::Vector{String}=String[],
    verbose::Bool=false)

## Input Parameters

None

## Input models 

- `activity`: Activity Model

## Description

Mixing Rule used by the Universal Mixing Rule Peng-Robinson (`UMRPR`) equation of state.
```
aᵢⱼ = √(aᵢaⱼ)(1-kᵢⱼ)
bᵢⱼ = ((√bᵢ +√bⱼ)/2)^2
b̄ = ∑bᵢⱼxᵢxⱼ
c̄ = ∑cᵢxᵢ
ā = b̄RT(∑[xᵢaᵢᵢαᵢ/(RTbᵢᵢ)] - [gᴱ/RT]/0.53)
```
"""
UMRRule
export UMRRule
function UMRRule(components::Vector{String}; activity = UNIFAC, userlocations::Vector{String}=String[],activity_userlocations::Vector{String}=String[], verbose::Bool=false)
    init_activity = activity(components;userlocations = activity_userlocations,verbose)   

    references = ["10.1021/ie049580p"]
    model = UMRRule(components, init_activity,references)
    return model
end

function ab_premixing(::Type{PR},mixing::UMRRuleModel,Tc,pc,kij)
    Ωa, Ωb = ab_consts(PR)
    _Tc = Tc.values
    _pc = pc.values
    a = epsilon_LorentzBerthelot(SingleParam(pc, @. Ωa*R̄^2*_Tc^2/_pc),kij)
    bi = @. Ωb*R̄*_Tc/_pc
    bij = ((bi.^(1/2).+bi'.^(1/2))/2).^2
    b = PairParam("b",Tc.components,bij)
    return a,b
end

UMR_g_E(model,V,T,z) = excess_gibbs_free_energy(model,V,T,z)

function UMR_g_E(model::UNIFACModel,V,T,z) 
    Σz = sum(z)
    lnγ_SG_  = lnγ_SG(model,1e5,T,z)
    lnγ_res_ = lnγ_res(model,1e5,T,z)
    return sum(z[i]*R̄*T*(lnγ_res_[i]+lnγ_SG_[i]) for i ∈ @comps)/Σz
end

function mixing_rule(model::PRModel,V,T,z,mixing_model::UMRRuleModel,α,a,b,c)
    n = sum(z)
    activity = mixing_model.activity
    invn = (one(n)/n)
    invn2 = invn^2
    g_E = UMR_g_E(activity,V,T,z)
    #b = Diagonal(b).diag
    #b = ((b.^(1/2).+b'.^(1/2))/2).^2
    b̄ = dot(z,Symmetric(b),z) * invn2
    c̄ = dot(z,c)*invn
    Σab = sum(z[i]*a[i,i]*α[i]/b[i,i]/(R̄*T) for i ∈ @comps)*invn
    ā = b̄*R̄*T*(Σab-1/0.53*g_E/(R̄*T))
    return ā,b̄,c̄
end