# WIP: Embedding
using Zygote
using MLUtils
using StatsBase
using Distributions
using LinearAlgebra

using Random; Random.seed!(2)

const corpus = Vector{String}()
const vocab  = Vector{String}()
const wcount = Vector{Int}()

const path = "TXTFiles/GitHubPkgs"
const pkgs = readdir(path)[1:50]

for pkg in pkgs
    txts = readdir("$path/$pkg")
    
    for txt in txts
        text = read("$path/$pkg/$txt", String)
        strs = split(text)
        append!(corpus, strs)
        
        for str in strs
            if str ∈ vocab
                i = findfirst(==(str), vocab)
                wcount[i] += 1
            else
                push!(vocab, str)
                push!(wcount, 1)
            end
        end
    end
end

# constants
const nw = length(vocab)
const wordind = Dict(w => i for (i, w) in pairs(vocab))
# Unigram Dist: U(w) = count(w) / length(corpus)
const unidist = pweights(wcount ./ length(corpus))

# parameters
const m = 3
const d = 300
const k = 10
const η = 0.3

# embedding
function sampleinds(batch, i)
    r = min(i + m, length(batch))
    l = max(i - m, 1)
    
    iₒ = rand([l:i-1; i+1:r])
    
    wc = batch[i]
    wo = batch[iₒ]

    wcind = wordind[wc]
    woind = wordind[wo]

    sinds  = setdiff(1:nw, [wcind, woind])
    probs  = unidist[sinds]
    wsinds = sample(sinds, probs, k, replace=false)

    wcind, woind, wsinds
end

dist = Uniform(-1, 1)
params = (
    v = [rand(dist, d) for _ in 1:nw],
    u = [rand(dist, d) for _ in 1:nw]
)

# log(1 / (1 + exp(-x)))
# log(1) - log(1 + exp(-x))
# -log(1 + exp(-x))
# -log1p(exp(-x))
# logσ(x) = -log1p(exp(-x))
logσ(x) = min(0, x) - log1p(exp(-abs(x)))

Jₜ(vc, uo, us) = logσ(dot(uo, vc)) + sum(logσ(-dot(ui, vc)) for ui in us)

loader = DataLoader(corpus, batchsize=128, shuffle=true)

lastvc = params.v[1]
lastuo = params.u[2]
lastus = params.u[1:k]
br = false

hasnan(x) = any(isnan, x)

for batch in loader
    global br
    br && break
    for i in eachindex(batch)
        wcind, woind, wsinds = sampleinds(batch, i)
        
        vc = params.v[wcind]
        uo = params.u[woind]
        us = params.u[wsinds]

        global lastvc = copy(vc)
        global lastuo = copy(uo)
        global lastus = copy(us)

        # maximize Jₜ
        ∇vc, ∇uo, ∇us = gradient(Jₜ, vc, uo, us)

        params.v[wcind] = vc + η*∇vc
        params.u[woind] = uo + η*∇uo
        for (i, ui, ∇ui) in zip(wsinds, us, ∇us)
            params.u[i] = ui + η*∇ui
        end

        if (
            hasnan(params.v[wcind]) ||
            hasnan(params.u[woind]) ||
            any(i -> hasnan(params.u[i]), wsinds)
        )
            global br = true
            break
        end
    end
end
