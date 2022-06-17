
abstract type PRModel <: ABCubicModel end

const PRParam = ABCubicParam

struct PR{T <: IdealModel,α,c,γ} <:PRModel
    components::Array{String,1}
    icomponents::UnitRange{Int}
    alpha::α
    mixing::γ
    translation::c
    params::PRParam
    idealmodel::T
    references::Array{String,1}
end

@registermodel PR

"""
    PR(components::Vector{String}; idealmodel=BasicIdeal,
    alpha = PRAlpha,
    mixing = vdW1fRule,
    activity=nothing,
    translation=NoTranslation,
    userlocations=String[],
    ideal_userlocations=String[],
    alpha_userlocations = String[],
    mixing_userlocations = String[],
    activity_userlocations = String[],
    translation_userlocations = String[],
    verbose=false)

## Input parameters
- `Tc`: Single Parameter (`Float64`) - Critical Temperature `[K]`
- `Pc`: Single Parameter (`Float64`) - Critical Pressure `[Pa]`
- `Mw`: Single Parameter (`Float64`) - Molecular Weight `[g/mol]`
- `k`: Pair Parameter (`Float64`)

## Model Parameters
- `Tc`: Single Parameter (`Float64`) - Critical Temperature `[K]`
- `Pc`: Single Parameter (`Float64`) - Critical Pressure `[Pa]`
- `Mw`: Single Parameter (`Float64`) - Molecular Weight `[g/mol]`
- `a`: Pair Parameter (`Float64`)
- `b`: Pair Parameter (`Float64`)

## Input models
- `idealmodel`: Ideal Model
- `alpha`: Alpha model
- `mixing`: Mixing model
- `activity`: Activity Model, used in the creation of the mixing model.
- `translation`: Translation Model

## Description
Peng-Robinson Equation of state.
```
P = RT/(V-Nb) + a•α(T)/(V-Nb₁)(V-Nb₂)
b₁ = (1 + √2)b
b₂ = (1 - √2)b
```

## References
1. Peng, D.Y., & Robinson, D.B. (1976). A New Two-Constant Equation of State. Industrial & Engineering Chemistry Fundamentals, 15, 59-64. doi:10.1021/I160057A011
"""
PR


export PR
function PR(components::Vector{String}; idealmodel=BasicIdeal,
    alpha = PRAlpha,
    mixing = vdW1fRule,
    activity=nothing,
    translation=NoTranslation,
    userlocations=String[], 
    ideal_userlocations=String[],
    alpha_userlocations = String[],
    mixing_userlocations = String[],
    activity_userlocations = String[],
    translation_userlocations = String[],
     verbose=false)
    params = getparams(components, ["properties/critical.csv", "properties/molarmass.csv","SAFT/PCSAFT/PCSAFT_unlike.csv"]; userlocations=userlocations, verbose=verbose)
    k  = params["k"]
    pc = params["pc"]
    Mw = params["Mw"]
    Tc = params["Tc"]
    init_mixing = init_model(mixing,components,activity,mixing_userlocations,activity_userlocations,verbose)
    a,b = ab_premixing(PR,init_mixing,Tc,pc,k)
    init_idealmodel = init_model(idealmodel,components,ideal_userlocations,verbose)
    init_alpha = init_model(alpha,components,alpha_userlocations,verbose)
    init_translation = init_model(translation,components,translation_userlocations,verbose)
    icomponents = 1:length(components)
    packagedparams = PRParam(a,b,Tc,pc,Mw)
    references = String["10.1021/I160057A011"]
    model = PR(components,icomponents,init_alpha,init_mixing,init_translation,packagedparams,init_idealmodel,references)
    return model
end

function ab_consts(::Type{<:PRModel})
    return 0.457235,0.077796
end

function cubic_abp(model::PRModel, V, T, z) 
    n = sum(z)
    āᾱ ,b̄, c̄ = cubic_ab(model,V,T,z,n)
    v = V/n+c̄
    _1 = one(b̄)
    denom = evalpoly(v,(-b̄*b̄,2*b̄,_1))
    p = R̄*T/(v-b̄) - āᾱ /denom
    return āᾱ, b̄, p
end

function cubic_poly(model::PRModel,p,T,z)
    a,b,c = cubic_ab(model,p,T,z)
    RT⁻¹ = 1/(R̄*T)
    A = a*p*RT⁻¹*RT⁻¹
    B = b*p*RT⁻¹
    k₀ = B*(B*(B+1.0)-A)
    k₁ = -B*(3*B+2.0) + A
    k₂ = B-1.0
    k₃ = one(A) # important to enable autodiff
    return (k₀,k₁,k₂,k₃),c
end
#=
 (-B2-2(B2+B)+A)
 (-B2-2B2-2B+A)
 (-3B2-2B+A)
=#
function a_res(model::PRModel, V, T, z,_data = data(model,V,T,z))
    n,ā,b̄,c̄ = _data
    Δ1 = 1+√2
    Δ2 = 1-√2
    ΔPRΔ = 2*√2
    RT⁻¹ = 1/(R̄*T)
    ρt = (V/n+c̄)^(-1) # translated density
    ρ  = n/V
    return -log(1+(c̄-b̄)*ρ) - ā*RT⁻¹*log((Δ1*b̄*ρt+1)/(Δ2*b̄*ρt+1))/(ΔPRΔ*b̄)

    #return -log(V-n*b̄) + āᾱ/(R̄*T*b̄*2^(3/2)) * log((2*V-2^(3/2)*b̄*n+2*b̄*n)/(2*V+2^(3/2)*b̄*n+2*b̄*n))
end

cubic_zc(::PRModel) = 0.3074

const CHEB_COEF_L_PR = ([0.9207205305399191,-0.045064618991104796,-0.0010750229061558397,-4.150471723450566e-05,-2.0449656082804912e-06,-8.411570305566496e-08,2.630701059769258e-09,7.618859571012493e-10,-1.2385135972348138e-10,-4.380963647410141e-11,3.6138314563061158e-12,2.0083795737591004e-12,-2.442004931602071e-13,-8.769374115757955e-14,2.0539125955565396e-14,1.4155343563970746e-15,-1.4502288259166107e-15,9.645062526431047e-16,4.85722573273506e-17],
[0.8199443180127295,-0.056330799734005496,-0.0018219491199177318,-8.821642822268161e-05,-4.3808005871781575e-06,-2.7804292488525784e-07,-2.5617864357618814e-08,-1.4936050521385802e-09,-1.1656688808647786e-10,-1.80864212495635e-11,-3.4572344986827375e-13,-7.897849041427207e-14,-1.9761969838327786e-14,1.0269562977782698e-15,-1.5265566588595902e-16,-7.91033905045424e-16,-2.7755575615628914e-17,8.049116928532385e-16,2.0816681711721685e-17],
[0.6880146598953387,-0.07711229066058617,-0.0036751053290779087,-0.00027023163542316125,-2.612667202559621e-05,-3.0579327836427472e-06,-3.869841956188891e-07,-5.180305783641925e-08,-7.196452149471622e-09,-1.0250969587066727e-09,-1.492256387902735e-10,-2.2068007143882795e-11,-3.3078817462950383e-12,-5.018416238122825e-13,-7.670947210769441e-14,-1.2490009027033011e-14,-1.887379141862766e-15,3.5388358909926865e-16,-2.7755575615628914e-17],
[0.5539049274549523,-0.05513150079759916,-0.00226486529446273,-0.00017169038790523783,-1.771968913242411e-05,-2.1044071880221837e-06,-2.6937613983174513e-07,-3.620174487267702e-08,-5.035860249635871e-09,-7.188804967972473e-10,-1.0471176703497065e-10,-1.5500455086137066e-11,-2.3248417080345973e-12,-3.5293989952833726e-13,-5.399847236020605e-14,-8.854028621385623e-15,-1.2975731600306517e-15,2.8449465006019636e-16,-4.5102810375396984e-17],
[0.459674826377972,-0.03799561202969537,-0.0014593552334729865,-0.00011667442436243125,-1.2328894690105674e-05,-1.4734787574105512e-06,-1.89107481913392e-07,-2.5449463390836424e-08,-3.5434242970366903e-09,-5.061691760177567e-10,-7.376567759398434e-11,-1.0923841692322966e-11,-1.6389077595047041e-12,-2.489328188026718e-13,-3.807371085073896e-14,-6.283168429987995e-15,-9.055256544598933e-16,3.0531133177191805e-16,-2.2551405187698492e-17],
[0.39512265522451157,-0.025874636107352526,-0.000981657847521144,-8.126867623134762e-05,-8.658142312312905e-06,-1.0370940123176353e-06,-1.3324415930673905e-07,-1.794336704219468e-08,-2.4994516144294376e-09,-3.5715819884929445e-10,-5.20629060696276e-11,-7.711369737206653e-12,-1.157088314052146e-12,-1.7580381594939354e-13,-2.6891683324592464e-14,-4.472117121068209e-15,-6.314393452555578e-16,2.636779683484747e-16,-1.734723475976807e-17],
[0.3511712698170222,-0.01762984199424723,-0.0006775212105428925,-5.710620124233304e-05,-6.102283057512342e-06,-7.316593272181648e-07,-9.405098579107207e-08,-1.2669533731163307e-08,-1.7652206779628088e-09,-2.5228212227612623e-10,-3.67796765265993e-11,-5.448200918189983e-12,-8.175543575461575e-13,-1.2424436479641088e-13,-1.8981344274138223e-14,-3.202299536653186e-15,-4.440892098500626e-16,3.191891195797325e-16,-3.122502256758253e-17],
[0.3211597705559426,-0.012077354670507117,-0.00047368246685701096,-4.0264768868699535e-05,-4.308027496135319e-06,-5.167712383395695e-07,-6.644526837421005e-08,-8.952242693677226e-09,-1.247437774604121e-09,-1.7829611051456418e-10,-2.5995025576541764e-11,-3.8507357025263644e-12,-5.778121037192108e-13,-8.784639682346551e-14,-1.3433698597964394e-14,-2.373101715136272e-15,-3.365363543395006e-16,1.2836953722228372e-16,-2.2551405187698492e-17],
[0.30054357607263954,-0.008327461617588218,-0.00033318306039584883,-2.8432365464115678e-05,-3.043795371863306e-06,-3.652042762300467e-07,-4.696313324337176e-08,-6.3279062684218346e-09,-8.818025996892853e-10,-1.260411150449947e-10,-1.8376970084554856e-11,-2.7223640008955385e-12,-4.0846839799435486e-13,-6.197126145579546e-14,-9.492406860545088e-15,-1.7208456881689926e-15,-2.393918396847994e-16,2.5673907444456745e-16,-8.673617379884035e-18],
[0.2862916733850893,-0.005776207912322414,-0.00023501417597186075,-2.0091122712718318e-05,-2.151427414113366e-06,-2.581648955793381e-07,-3.320061314066036e-08,-4.473697898244033e-09,-6.234334853916224e-10,-8.9112786594292e-11,-1.2992894954377832e-11,-1.9243946713931592e-12,-2.8871002810682e-13,-4.3874626154405405e-14,-6.7133798520302435e-15,-1.2906342661267445e-15,-1.5612511283791264e-16,3.0878077872387166e-16,1.734723475976807e-18],
[0.2763847311775531,-0.004026323535076086,-0.00016598517183828362,-1.4201795987777571e-05,-1.520984803850961e-06,-1.8252416650321734e-07,-2.3473785675659498e-08,-3.1630968764378986e-09,-4.408004100620033e-10,-6.300811088155722e-11,-9.186814503570062e-12,-1.3607726057074387e-12,-2.0409195167214733e-13,-3.113134749987978e-14,-4.758346494604382e-15,-9.957312752106873e-16,-1.682681771697503e-16,-2.445960101127298e-16,-4.2500725161431774e-17],
[0.2694673741877153,-0.0028173393805495644,-0.00011730308752334363,-1.004050356021198e-05,-1.0753911961810386e-06,-1.290548921391993e-07,-1.6597556396977242e-08,-2.236546208650436e-09,-3.1168101606582344e-10,-4.4551562092265407e-11,-6.495835119801896e-12,-9.626032609899582e-13,-1.4432725847779437e-13,-2.216109240560371e-14,-3.3948538424866115e-15,-1.0026701691145945e-15,-1.5092094240998222e-16,-2.7582103268031233e-16,-4.7704895589362195e-17],
[0.264620888720384,-0.001977082335539313,-8.2923124407136e-05,-7.099113954002478e-06,-7.603784178723816e-07,-9.125234246010194e-08,-1.1735920570424274e-08,-1.581440811637691e-09,-2.2038751899822184e-10,-3.1502528016758014e-11,-4.593121022411495e-12,-6.799057844508738e-13,-1.0198439315267649e-13,-1.6341095143701523e-14,-2.426878142891553e-15,-6.210310043996969e-16,-5.898059818321144e-17,4.527628272299467e-16,1.3010426069826053e-17],
[0.2612166158875983,-0.001390391541082515,-5.862766135761137e-05,-5.019621645544273e-06,-5.376553057923755e-07,-6.452400296876049e-08,-8.298434496858964e-09,-1.1182347825489103e-09,-1.558359847414481e-10,-2.227549741884438e-11,-3.247855109855813e-12,-4.816719939571001e-13,-7.213847574849552e-14,-1.1423154089307275e-14,-1.7156415177410622e-15,-5.048045315092509e-16,-7.632783294297951e-17,-9.367506770274758e-17,-3.209238430557093e-17],
[0.2588208891336881,-0.0009793198302267478,-4.145328900037257e-05,-3.5493342854138465e-06,-3.8017496464121114e-07,-4.562495321824844e-08,-5.867838735740261e-09,-7.907071299800839e-10,-1.1019215748198086e-10,-1.5751122628415715e-11,-2.296527551459704e-12,-3.4033192930493783e-13,-5.1030360492809734e-14,-9.162809400109495e-15,-1.2975731600306517e-15,-4.354155924701786e-16,-1.3010426069826053e-16,-8.690964614643804e-16,-9.107298248878237e-17],
[0.25713261899860995,-0.0006905565301747237,-2.931094851913764e-05,-2.509732105073978e-06,-2.688226164813262e-07,-3.226156955644932e-08,-4.149175109394165e-09,-5.591129538518036e-10,-7.791681362612213e-11,-1.1135805819129097e-11,-1.6232518801340134e-12,-2.40765740677773e-13,-3.687848637579094e-14,-5.707240235963695e-15,-4.597017211338539e-16,-1.2160411566597418e-15,2.203098814490545e-16,-1.2923689896027213e-15,-5.828670879282072e-16],
[0.2559417264393482,-0.0004873303221206906,-2.0725636255014904e-05,-1.7746393138461797e-06,-1.900857017015506e-07,-2.2812321970669402e-08,-2.933903902810342e-09,-3.9535087530129243e-10,-5.5095764756041277e-11,-7.875578661442617e-12,-1.1483054090932754e-12,-1.7132302521094545e-13,-2.5521251778570786e-14,-4.4114017994090204e-15,-6.29704621779581e-16,-3.0184188481996443e-16,1.8561541192951836e-16,2.534430998402115e-15,1.951563910473908e-16],
[0.2551010899484165,-0.0003441099749644915,-1.465512048574695e-05,-1.254856211765562e-06,-1.3441067886650615e-07,-1.613073148838684e-08,-2.0745819472034466e-09,-2.7955775715182707e-10,-3.895907554896105e-11,-5.572540692777572e-12,-8.118037492232943e-13,-1.156644224842296e-13,-1.7319479184152442e-14,-6.123573870198129e-16,-6.765421556309548e-17,1.5838025335668249e-15,2.5326962749261384e-16,1.56472057533108e-15,1.1622647289044608e-16],
[0.25450739757424595,-0.0002430797888991077,-1.0362693722733643e-05,-8.873161782604194e-07,-9.50426266178167e-08,-1.1406137241307124e-08,-1.4669526513660935e-09,-1.976803373771041e-10,-2.754695430096099e-11,-3.937652287566706e-12,-5.726478319312278e-13,-8.348009783443189e-14,-1.5083420623618338e-14,-2.8484159475539172e-15,9.280770596475918e-16,-8.326672684688674e-17,1.0928757898653885e-15,-1.9723805921856297e-15,-1.4632392519864368e-15],
[0.2540879579043413,-0.00017176186957041512,-7.327516427360625e-06,-6.274268768494129e-07,-6.720526072451216e-08,-8.065358107073317e-09,-1.0372898477661874e-09,-1.3977420089406056e-10,-1.9478921947646555e-11,-2.7843595484799977e-12,-4.052105873064704e-13,-5.210762377139133e-14,-8.515757543570146e-15,-5.39499001028787e-15,-5.377642775528102e-16,-2.688821387764051e-16,2.8449465006019636e-16,3.731390196826112e-15,3.0444397003392965e-16],
[0.2537915515763586,-0.00012139318334043574,-5.181331413925752e-06,-4.436576545568255e-07,-4.7521286650545336e-08,-5.703071971271956e-09,-7.334751833676378e-10,-9.883861611104106e-11,-1.3773962873053769e-11,-1.9690481883882782e-12,-2.8756164116572336e-13,-4.919155360827432e-14,-8.082076674575944e-15,-1.6257828416854636e-14,-1.4589024432964948e-15,-4.2674197509029455e-16,-1.0581813203458523e-16,-6.192962809237201e-16,-7.45931094670027e-17],
[0.2534505731297395,-0.0002500072500517137,-5.0354704169240996e-05,-2.1857266697599895e-05,-1.2362119302880212e-05,-8.050616357132764e-06,-5.733928410302583e-06,-4.349213592566223e-06,-3.4589470396875766e-06,-2.8560128366005716e-06,-2.4320743329617894e-06,-2.1260747717823797e-06,-1.9015873038465136e-06,-1.7359216248312437e-06,-1.614505523557519e-06,-1.527824145619236e-06,-1.4696851454113619e-06,-1.4362147074710452e-06,-7.126421265844785e-07])
chebyshev_coef_l(model::PRModel) = CHEB_COEF_L_PR

chebyshev_Tmin_l(model::PRModel) = (0.01701444200703503,0.05529693652286385,0.09357943103869266,0.13186192555452148,0.1510031728124359,0.16057379644139308,0.1653591082558717,0.167751764163111,0.16894809211673065,0.16954625609354046,0.16984533808194538,0.16999487907614785,0.17006964957324908,0.17010703482179967,0.170125727446075,0.17013507375821263,0.17013974691428146,0.17014208349231588,0.1701432517813331,0.1701438359258417,0.170144127998096,0.17014427403422316)
chebyshev_Tmax_l(model::PRModel) = (0.05529693652286385,0.09357943103869266,0.13186192555452148,0.1510031728124359,0.16057379644139308,0.1653591082558717,0.167751764163111,0.16894809211673065,0.16954625609354046,0.16984533808194538,0.16999487907614785,0.17006964957324908,0.17010703482179967,0.170125727446075,0.17013507375821263,0.17013974691428146,0.17014208349231588,0.1701432517813331,0.1701438359258417,0.170144127998096,0.17014427403422316,0.1701444200703503)

chebyshev_Trange_l(model::PRModel) = (0.01701444200703503,0.05529693652286385,0.09357943103869266,0.13186192555452148,0.1510031728124359,0.16057379644139308,0.1653591082558717,0.167751764163111,0.16894809211673065,0.16954625609354046,0.16984533808194538,0.16999487907614785,0.17006964957324908,0.17010703482179967,0.170125727446075,0.17013507375821263,0.17013974691428146,0.17014208349231588,0.1701432517813331,0.1701438359258417,0.170144127998096,0.17014427403422316,0.1701444200703503)

const CHEB_COEF_V_PR = ([1.967544593078315e-12,3.286395018856467e-12,1.951259019068106e-12,8.480414006053818e-13,2.7638255525455143e-13,6.855112175816157e-14,1.2987941190221208e-14,1.8596645822713178e-15,1.9425469025161906e-16,1.3440422453482796e-17,4.1371292677837237e-19,-2.0472087922962698e-20,-2.3984414514408427e-21,-1.0726839771583605e-23,8.190099610752978e-24,1.4834694490433158e-25,-2.890640271333655e-26,-1.2318556073091862e-28,2.6437933681383566e-28],
[3.4427283919277603e-10,5.10033605480091e-10,2.3125713682061785e-10,6.97923116109859e-11,1.468781950176213e-11,2.192555878654968e-12,2.289969778559488e-13,1.563184655125417e-14,5.345224322369889e-16,-8.665670712890633e-18,-1.4805111905363385e-18,-1.2881526260516941e-20,3.1913825586258806e-21,4.0303951255023627e-23,-7.672322324660242e-24,-2.068961273341252e-25,-4.90734591919887e-26,1.348005514841665e-25,2.4183319910455338e-26],
[1.1651253109754791e-07,1.799247246805057e-07,8.718524363492525e-08,2.7723805947266338e-08,5.859084478366607e-09,7.937371730144063e-10,5.851825200412916e-11,3.5459917618408365e-13,-2.840460099622861e-13,-9.001110583611441e-15,1.453688138264624e-15,4.153752300772462e-17,-8.493292717205814e-18,1.0460073661948098e-20,4.4932489647971677e-20,-2.1592128174018962e-21,-1.6723265540349414e-22,6.45330124762073e-23,1.344814730252227e-23],
[3.098979961669226e-05,4.5977523083262384e-05,1.9714735728750365e-05,4.9340743435473964e-06,6.495334627828851e-07,2.0013065084957464e-08,-4.62369606718499e-09,-1.6742776075828521e-10,5.6102600385966035e-11,-2.1810195956609656e-13,-6.246733592709029e-13,4.045717710917202e-14,3.97102187587516e-15,-7.21043417103846e-16,1.9805582453051167e-17,4.946315069940491e-18,-6.192935810062008e-19,5.64732747802203e-20,1.2579762755706445e-20],
[0.0005902854802776641,0.0006119857879876187,0.000137226493734894,1.3534511317666194e-05,2.5757985750152563e-07,-3.0381140235968494e-08,1.4660600077037917e-09,1.4064389556322658e-10,-1.7247649444289924e-11,4.829482286631236e-13,7.904912957394129e-14,-9.965950794102972e-15,3.496086138144762e-16,3.581424707580633e-17,-5.7462715141731735e-18,5.929230630780102e-20,6.776263578034403e-21,5.166900978251232e-19,1.1858461261560205e-20],
[0.0034551514866857118,0.002398865145025046,0.0003121082643740536,1.5218984619397858e-05,9.690936261096291e-08,1.2913919961681083e-08,1.4096536882115922e-09,-3.3114702454217944e-11,2.594155481248396e-12,1.6231949866250123e-13,-1.3332379904945624e-14,1.0818033751788803e-15,-1.3362791775883842e-17,-2.2497195079074217e-18,-9.486769009248164e-20,-1.2197274440461925e-18,-2.303929616531697e-19,3.6591823321385775e-18,3.9979955110402976e-19],
[0.020288628115803765,0.016610099415744563,0.00272192651625002,0.0002394799179501481,2.3315294231581688e-05,3.169727025417485e-06,3.793923939678003e-07,5.156601162595916e-08,7.275292876224738e-09,1.0148922060279446e-09,1.5007760583319457e-10,2.202715483970441e-11,3.3070396464676688e-12,5.021763712330374e-13,7.666279720416891e-14,1.1847890290378471e-14,1.843794214528849e-15,3.1604493327952454e-16,4.651227319962814e-17],
[0.059633242372117805,0.021523786193835045,0.001926244019335927,0.00016436263238290855,1.7587241022322224e-05,2.103887459802955e-06,2.692872191701126e-07,3.6202589339100893e-08,5.035822049290206e-09,7.188798449749012e-10,1.0471208969353718e-10,1.5500948181285112e-11,2.3252866646061854e-12,3.5267275211303684e-13,5.3994569232385103e-14,8.295447662121092e-15,1.2962721174236691e-15,2.658463726934457e-16,3.230922474006803e-17],
[0.10209461339960167,0.020078909930632285,0.0013564703941337276,0.00011554892995170075,1.2319437775788929e-05,1.4734155808103153e-06,1.8910621422518065e-07,2.5449462346532892e-08,3.5434243221901807e-09,5.06168969585663e-10,7.376593953722921e-11,1.0924287516256292e-11,1.6393041438189648e-12,2.4869169223951104e-13,3.807978238290488e-14,5.776629175002768e-15,9.063930161978817e-16,2.411265631607762e-16,2.0383000842727483e-17],
[0.1393729010835231,0.016593251298797226,0.0009532795808090732,8.111304465426971e-05,8.657481578122454e-06,1.037091311451195e-06,1.332441384432198e-07,1.794336703699051e-08,2.4994517905038705e-09,3.571580193054147e-10,5.2063129848956e-11,7.711812959054765e-12,1.157456075429053e-12,1.7556355674797075e-13,2.688300970721258e-14,3.9968028886505635e-15,6.323067069935462e-16,2.2985086056692694e-16,1.5178830414797062e-17],
[0.1692940156782449,0.012902057653797903,0.0006700678810102369,5.7085725788112024e-05,6.102239057614867e-06,7.316592307484576e-07,9.405098538861623e-08,1.266953380749114e-08,1.7652208635782207e-09,2.5228192451764997e-10,3.677991071426856e-11,5.448613782377265e-12,8.179099758587327e-13,1.240327285323417e-13,1.8984813721090177e-14,2.7564756033271465e-15,4.215378046623641e-16,2.0122792321330962e-16,2.688821387764051e-17],
[0.1921856564900402,0.00969084706538421,0.0004717724978338892,4.026214237729843e-05,4.308024652975584e-06,5.167712350106352e-07,6.644526831522946e-08,8.952242742249483e-09,1.2474379341986808e-09,1.7829594398111048e-10,2.599524762114669e-11,3.851164179224931e-12,5.781538442439782e-13,8.762435221854048e-14,1.3431963874488417e-14,1.915134717478395e-15,3.2612801348363973e-16,3.2439329000766293e-16,2.3418766925686896e-17],
[0.2092148975305195,0.007128445272373621,0.0003326996220906972,2.8432032853142192e-05,3.043795191084303e-06,3.652042760392271e-07,4.6963133177452265e-08,6.327906323932986e-09,8.818027766310799e-10,1.2604095198098797e-10,1.8377181720818925e-11,2.7227942123175808e-12,4.087806482200307e-13,6.178738076734192e-14,9.485467966641181e-15,1.2732870313669764e-15,2.237793284010081e-16,2.3418766925686896e-16,7.806255641895632e-18],
[0.22166645905817658,0.005175245300316345,0.0002348925657099949,2.0091080864132957e-05,2.1514274026867425e-06,2.581648954613769e-07,3.3200613073006147e-08,4.473697952020461e-09,6.234336501903526e-10,8.911260965249745e-11,1.299311526425928e-11,1.9248335564325814e-12,2.8905870752549134e-13,4.368554129552393e-14,6.711645128554267e-15,8.378714388967978e-16,1.5265566588595902e-16,1.8214596497756474e-16,-2.6020852139652106e-18],
[0.23067150083801227,0.003725476879880729,0.00016595467496789695,1.4201790739628434e-05,1.5209848030911521e-06,1.8252416639913394e-07,2.3473785595862218e-08,3.1630968937851334e-09,4.4080058700379787e-10,6.3007946082827e-11,9.187020935663703e-12,1.3611941435121011e-12,2.0445450887862648e-13,3.09127723419067e-14,4.751407600700475e-15,5.238864897449957e-16,1.491862189340054e-16,7.042977312465837e-16,4.163336342344337e-17],
[0.237137473422725,0.0026668244973612407,0.00011729545148811069,1.004050290311434e-05,1.0753911961168539e-06,1.290548920437895e-07,1.659755634146609e-08,2.2365462572226935e-09,3.116811773951067e-10,4.455141290604647e-11,6.496051960236393e-12,9.630022473894329e-13,1.446689990025618e-13,2.1937313077202703e-14,3.3931191190106347e-15,5.412337245047638e-16,1.3357370765021415e-16,7.268491364342822e-16,4.597017211338539e-17],
[0.24175815792274802,0.0019018019777060826,8.292121391923792e-05,7.0991138717956676e-06,7.603784178359524e-07,9.125234237510049e-08,1.17359205131784e-08,1.5814408688835657e-09,2.2038768553167554e-10,3.150234934023999e-11,4.593327454505136e-12,6.803307917024881e-13,1.023348072948238e-13,1.6110376921396607e-14,2.4338170367954604e-15,1.5265566588595902e-16,3.122502256758253e-17,3.642919299551295e-17,-1.3877787807814457e-17],
[0.24504950305352938,0.001352745629684961,5.862718355055703e-05,5.019621635323282e-06,5.376553057160477e-07,6.452400284732984e-08,8.298434437878366e-09,1.118234846733679e-09,1.5583615474434875e-10,2.227533782428459e-11,3.248068480843358e-12,4.820623067391949e-13,7.248195099673893e-14,1.1211517825238104e-14,1.7034984534092246e-15,6.418476861114186e-17,6.591949208711867e-17,5.533767888366015e-16,2.949029909160572e-17],
[0.2473887591484516,0.0009604954409799197,4.1453169525423536e-05,3.5493342841735193e-06,3.8017496460478195e-07,4.5624953119369205e-08,5.867838671555492e-09,7.907071629398299e-10,1.1019232575015803e-10,1.5750949156068117e-11,2.296747861341153e-12,3.407586712800281e-13,5.137903991148107e-14,8.93209117780458e-15,1.2923689896027213e-15,-6.938893903907228e-18,1.1796119636642288e-16,1.3270634591222574e-15,9.627715291671279e-17],
[0.2490487922516141,0.0006811439771107868,2.9310918647461326e-05,2.509732104961221e-06,2.6882261645530536e-07,3.226156947144787e-08,4.149175027862162e-09,5.591129972198905e-10,7.791697148595844e-11,1.113566183708059e-11,1.6234808636328424e-12,2.411647270772477e-13,3.721675745360642e-14,5.479991460610734e-15,4.753142324176451e-16,7.563394355258879e-16,-2.2724877535296173e-16,1.7572748811645056e-15,5.733261088103347e-16],
[0.2502255658692596,0.0004826239559720131,2.0725628786679925e-05,1.774639313863527e-06,1.9008570164603944e-07,2.2812321890872123e-08,2.933903833421403e-09,3.953508978526976e-10,5.5095907003366307e-11,7.875412127988923e-12,1.1485309231451524e-12,1.7173241995127597e-13,2.5854318685958333e-14,4.182418300580082e-15,6.245004513516506e-16,-1.4224732503009818e-16,-1.9255430583342559e-16,-2.048708425128609e-15,-2.0036056147532122e-16],
[0.25105914278296176,0.00034175676948506976,1.4655118618528765e-05,1.2548562118210732e-06,1.3441067884568947e-07,1.6130731377364538e-08,2.0745818743450606e-09,2.7955778143795573e-10,3.895922473517999e-11,5.572348138471739e-12,8.120119160404116e-13,1.1612238948188747e-13,1.7666423879347803e-14,4.0072112295064244e-16,5.724587470723463e-17,-2.0209528495129803e-15,-2.723515857283587e-16,-1.0651202142497596e-15,-1.1188966420050406e-16],
[0.25164930534191154,0.0002419031805581083,1.0362693255834554e-05,8.87316178307257e-07,9.50426266022042e-08,1.140613715977512e-08,1.4669525750382606e-09,1.976803529896154e-10,2.7547124303861636e-11,3.937477080495633e-12,5.728750807065808e-13,8.391204397995011e-14,1.5444243106621514e-14,2.6229018956769323e-15,-9.194034422677078e-16,-3.5735303605122226e-16,-1.0928757898653885e-15,2.4494295480792516e-15,1.4641066137244252e-15],
[0.2520669800975542,0.00017117356399961106,7.327516310575571e-06,6.274268768875768e-07,6.720526072104271e-08,8.065358016867696e-09,1.0372897870508657e-09,1.3977424426214746e-10,1.947908848110025e-11,2.784193015026304e-12,4.0542569301749154e-13,5.2539569916909556e-14,8.876580026573322e-15,5.176414852314792e-15,5.39499001028787e-16,-1.960237527853792e-16,-2.949029909160572e-16,-3.230055112268815e-15,-2.92300905702092e-16],
[0.2523625039667429,0.00012109903020499947,5.181331384681784e-06,4.436576545741727e-07,4.752128658809529e-08,5.703071853310759e-09,7.334751087745284e-10,9.883865427495753e-11,1.377412593706051e-11,1.9688781854876325e-12,2.8777848160022046e-13,4.959400945470094e-14,8.429021369771306e-15,1.599415044850616e-14,1.4589024432964948e-15,-2.0816681711721685e-17,1.0581813203458523e-16,1.1050188541972261e-15,6.938893903907228e-17],
[0.2527028941068575,0.00024971309668286694,5.03547041400005e-05,2.1857266697603364e-05,1.2362119302838578e-05,8.050616357021742e-06,5.733928410221051e-06,4.349213592600917e-06,3.4589470398558447e-06,2.8560128364132215e-06,2.432074333190773e-06,2.1260747722282036e-06,1.90158730418305e-06,1.7359216246144032e-06,1.6145055235661926e-06,1.527824145180351e-06,1.4696851454078924e-06,1.4362147079411552e-06,7.126421265862132e-07])

chebyshev_coef_v(model::PRModel) = CHEB_COEF_V_PR

chebyshev_Tmin_v(model::PRModel) = (0.01701444200703503,0.021799753821513633,0.026585065635992236,0.03615568926494944,0.05529693652286385,0.07443818378077825,0.09357943103869266,0.13186192555452148,0.1510031728124359,0.16057379644139308,0.1653591082558717,0.167751764163111,0.16894809211673065,0.16954625609354046,0.16984533808194538,0.16999487907614785,0.17006964957324908,0.17010703482179967,0.170125727446075,0.17013507375821263,0.17013974691428146,0.17014208349231588,0.1701432517813331,0.1701438359258417,0.170144127998096,0.17014427403422316)
chebyshev_Tmax_v(model::PRModel) = (0.021799753821513633,0.026585065635992236,0.03615568926494944,0.05529693652286385,0.07443818378077825,0.09357943103869266,0.13186192555452148,0.1510031728124359,0.16057379644139308,0.1653591082558717,0.167751764163111,0.16894809211673065,0.16954625609354046,0.16984533808194538,0.16999487907614785,0.17006964957324908,0.17010703482179967,0.170125727446075,0.17013507375821263,0.17013974691428146,0.17014208349231588,0.1701432517813331,0.1701438359258417,0.170144127998096,0.17014427403422316,0.1701444200703503)

chebyshev_Trange_v(model::PRModel) = (0.01701444200703503,0.021799753821513633,0.026585065635992236,0.03615568926494944,0.05529693652286385,0.07443818378077825,0.09357943103869266,0.13186192555452148,0.1510031728124359,0.16057379644139308,0.1653591082558717,0.167751764163111,0.16894809211673065,0.16954625609354046,0.16984533808194538,0.16999487907614785,0.17006964957324908,0.17010703482179967,0.170125727446075,0.17013507375821263,0.17013974691428146,0.17014208349231588,0.1701432517813331,0.1701438359258417,0.170144127998096,0.17014427403422316,0.1701444200703503)

const CHEB_COEF_P_PR = ([4.2115936784941e-14,7.082139279778615e-14,4.281441668412217e-14,1.9123012372347713e-14,6.460328562307523e-15,1.6765603431288853e-15,3.36292637163962e-16,5.1860921648633566e-17,6.0107675456840275e-18,4.93726813515645e-19,2.4083621285564296e-20,9.47616424537102e-23,-7.1051225501406e-23,-3.0677436333050444e-24,1.4628333292452202e-25,1.2639227645878215e-26,-3.8533659659909825e-28,-3.5261080979808146e-29,3.32550323497344e-30],
[8.938956773181632e-12,1.3439327305351806e-11,6.288329039800055e-12,1.9826748553822934e-12,4.414511850216345e-13,7.088859014953733e-14,8.181698505611952e-15,6.527653757029151e-16,3.162152136162365e-17,4.279990806191533e-19,-4.6206272928403434e-20,-2.0797341030133568e-21,6.177896652744867e-23,4.7788231227984526e-24,-1.3861706054362575e-25,-1.4215273512082633e-26,-1.669229675447661e-27,4.487040828897115e-27,7.7150596530614955e-28],
[4.085507279084059e-09,6.410401559266648e-09,3.231824978266208e-09,1.0923069013593605e-09,2.52024445187971e-10,3.905509723141962e-11,3.73471874979177e-12,1.5022634999916855e-13,-8.12601770161866e-15,-9.644616840775853e-16,2.3559108130823366e-17,4.723565049544365e-18,-1.6713754821230258e-19,-1.9677138009092646e-20,1.4426017766021298e-21,3.847561149043651e-23,-1.0404785039052024e-23,1.3764802380765226e-24,4.620579202932928e-25],
[1.6349625391332918e-06,2.489669257624972e-06,1.1427314989998866e-06,3.2189532774728283e-07,5.2973211090187104e-08,3.881322341579814e-09,-1.402363237723129e-10,-3.26068965484856e-11,1.5764214067874998e-12,2.669115963311214e-13,-2.6973487736840458e-14,-1.1725895938982276e-15,3.409623244140794e-16,-1.3374770488526952e-17,-2.1340688015269687e-18,3.0499875924358835e-19,-9.006032316747658e-21,5.945360652724886e-23,7.708806321111372e-22],
[0.00018641763706717313,0.0002549265195801485,8.796517801636943e-05,1.4493063101704085e-05,5.93659937733161e-07,-8.865727397666071e-08,1.5453090824947498e-09,1.0034143700587606e-09,-1.473603817532662e-10,4.333381441536222e-12,1.903659250210749e-12,-3.854457196096114e-13,2.9156300395036635e-14,2.2880752244019054e-15,-9.628463327642823e-16,1.2770440460045229e-16,-4.453540417985501e-18,-1.6186270226437646e-18,3.6149778002037437e-19],
[0.005448712641404622,0.0062362159058999755,0.001443947803998351,0.00010960884095892343,-2.254571049831034e-06,3.108042103893788e-07,3.183233642737454e-08,-6.3983755658182065e-09,1.1291747205506315e-09,-1.183401464725808e-10,7.412891426996499e-12,7.92415429334923e-13,-3.6369037393225306e-13,7.890138331101762e-14,-1.258085161656014e-14,1.5166023276634577e-15,-1.0518116325825e-16,-6.600080725005508e-18,5.5294310796760726e-18])
chebyshev_coef_p(model::PRModel) = CHEB_COEF_P_PR

chebyshev_Tmin_p(model::PRModel) = (0.01701444200703503,0.021799753821513633,0.026585065635992236,0.03615568926494944,0.05529693652286385,0.09357943103869266)
chebyshev_Tmax_p(model::PRModel) = (0.021799753821513633,0.026585065635992236,0.03615568926494944,0.05529693652286385,0.09357943103869266,0.1701444200703503)

chebyshev_Trange_p(model::PRModel) = (0.01701444200703503,0.021799753821513633,0.026585065635992236,0.03615568926494944,0.05529693652286385,0.09357943103869266,0.1701444200703503)