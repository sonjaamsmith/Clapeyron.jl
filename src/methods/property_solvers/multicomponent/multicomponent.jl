## Pure saturation conditions solver
function x0_bubble_pressure(model::ABCubicModel,T,x)
    
    #strategy: supose virial max pressure as the saturation pressure
    #suppose ideal gas and calculate y0
    
    #TODO
    #on sufficiently large temps, 
    #the joule-thompson inversion occurs
    #making the virial coeff positive
    #on those cases, use an strategy that supposes pure gas on that side
    #Pbi = inf
    #xi = 0

    #check each T with T_scale, if treshold is over, replace Pi with inf
    
    T_threshold = T_scales(model,x)
    @show T_threshold
    replaceP = ifelse.(T_threshold .< T,true,false)
    @show replaceP

    eachx = eachcol(Diagonal(ones(eltype(x),length(x))))
    Bi = second_virial_coefficient.(model,T,eachx)
    #using P_B(2B) as a sat aproximation
    #z = 1 + B/v
    #P_B = RT/v(1+B/v)
    #P_B(2B) = -RT/2B(1-B/2B)
    #P_B(2B) = -0.25*RT/B

    P_Bi = @. -0.25*R̄*T/Bi
    #=xP0 = yP
    #dot(x,P0) = P
    P = dot(x,P0)
    =#
    P = zero(T)
    for i in 1:length(x)
        if !replaceP[i]
            P+=x[i]*P_Bi[i]
        end
    end

    #@show P_Bi
    #P = dot(x,P_Bi)
    y = @. x*P_Bi/P
    ysum = 1/∑(y)
    return y .* ysum
    #return y

    #=
    lb_v = lb_volume(model,x)
    k0 = 10.0
    y0    = k0 .*x./(1 .+x.*(k0 .- 1))
    y0    = y0 ./sum(y0)
    v0    = [log10(lb_v/0.45),
    log10(lb_v/1e-4)]
    return append!(v0,y0[1:end-1])
    =#
end

function x0_bubble_pressure(model::SAFTModel,T,x)
    
    #strategy: supose virial max pressure as the saturation pressure
    #suppose ideal gas and calculate y0
    
    #TODO
    #on sufficiently large temps, 
    #the joule-thompson inversion occurs
    #making the virial coeff positive
    #on those cases, use an strategy that supposes pure gas on that side
    #Pbi = inf
    #xi = 0

    #check each T with T_scale, if treshold is over, replace Pi with inf
    
    T_threshold = 1.5*T_scales(model,x)
    @show T_threshold
    replaceP = ifelse.(T_threshold .< T,true,false)
    @show replaceP

    eachx = eachcol(Diagonal(ones(eltype(x),length(x))))
    Bi = second_virial_coefficient.(model,T,eachx)
    #using P_B(2B) as a sat aproximation
    #z = 1 + B/v
    #P_B = RT/v(1+B/v)
    #P_B(2B) = -RT/2B(1-B/2B)
    #P_B(2B) = -0.25*RT/B

    P_Bi = @. -0.25*R̄*T/Bi
    #=xP0 = yP
    #dot(x,P0) = P
    P = dot(x,P0)
    =#
    P = zero(T)
    for i in 1:length(x)
        if !replaceP[i]
            P+=x[i]*P_Bi[i]
        end
    end

    #@show P_Bi
    #P = dot(x,P_Bi)
    y = @. x*P_Bi/P
    ysum = 1/∑(y)
    V0_l  = x0_volume(model,P,T,x;phase=:l)
    V0_v = x0_volume(model,P,T,y;phase=:v)
    
    prepend!(y,[V0_l,V0_v])
    return y
end

function bubble_pressure(model, T, x; v0 =nothing)
    TYPE = promote_type(eltype(T),eltype(x))
#     lb_v = lb_volume(model,x)
    ts = T_scales(model,x)
    pmix = p_scale(model,x)
    if v0 === nothing
        v0 = x0_bubble_pressure(model,T,x)
    end
    len = length(v0[1:end-1])
    #xcache = zeros(eltype(x0),len)
    Fcache = zeros(eltype(v0[1:end-1]),len)
    f! = (F,z) -> Obj_bubble_pressure(model, F, T, exp10(z[1]), exp10(z[2]), x,z[3:end],ts,pmix)
    r  =Solvers.nlsolve(f!,v0[1:end-1],LineSearch(Newton()))
    v_l = exp10(r.info.zero[1])
    v_v = exp10(r.info.zero[2])
    y = FractionVector(r.info.zero[3:end])
    append!(y,1-sum(y))
    P_sat = pressure(model,v_l,T,x)
    return (P_sat, v_l, v_v, y)
end

function Obj_bubble_pressure(model, F, T, v_l, v_v, x, y,ts,ps)
        println(y)
    y   = FractionVector(y) #julia magic, check misc.jl
    μ_l = VT_chemical_potential(model,v_l,T,x)
    μ_v = VT_chemical_potential(model,v_v,T,y)
    p_l = pressure(model,v_l,T,x)
    p_v = pressure(model,v_v,T,y)
    for i in 1:length(x)
        F[i] = (μ_l[i]-μ_v[i])/(R̄*ts[i])
    end
    F[end] = (p_l-p_v)/ps
    println(F)
end

    #j! = (J,z) -> Jac_bubble_pressure(model, J, T, exp10(z[1]), exp10(z[2]), x[i,:], z[3:end])
    #=
    _y0 = collect(FractionVector(v0[3:end]))
    @show _y0
    @show _pl0 = pressure(model,exp10(v0[1]),T,x)
    @show _pv0 = pressure(model,exp10(v0[2]),T,_y0)
    _P = 0.5*(_pl0+_pv0)
    for _ in 1:3
        _y0,_P = rr_bubble_pressure_refine(model,x,_y0,_P,T)
    end
    =#
function bubble_pressure_rr(model, T, x; P = 40000)
    sol0 = x0_bubble_pressure(model,T,x)
    vl0 = exp10(sol0[1])
    vv0 = exp10(sol0[2])




    @show y0 = collect(FractionVector(sol0[3:end]))
    @show vl0 = volume(model,P,T,x,phase=:l)
    @show vv0 = volume(model,P,T,y0,phase=:v)
    @show μ_l = vt_chemical_potential(model,vl0,T,x)
    @show μ_v = vt_chemical_potential(model,vv0,T,y0)
    y1 =  μ_l ./ μ_v .* x
    @show y1 = y1 ./ sum(y1)
    @show pl0 = pressure(model,vl0,T,x)
    @show pv0 = pressure(model,vv0,T,y1)

    @show P = (pl0 - pv0)/(log(pl0) - log(pv0))

    @show vl = volume(model,P,T,x,phase=:l)
    @show vv = volume(model,P,T,y1,phase=:v)
    #=
    μ_l = vt_chemical_potential(model,vl,T,x)
    μ_v = vt_chemical_potential(model,vv,T,y)
    K = log.(μ_v) ./ log.(μ_l)
    y = K .* x
    y = y./sum(y)
    pl = pressure(model,vl,T,x)
    pv = pressure(model,vv,T,y)
    P = (pl+pv)/2
    @show vl,vv,y
    return y,P
    =#
end

export bubble_pressure