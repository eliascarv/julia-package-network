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
const pkgs = readdir(path)[1:10]

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
const k = 60
const η = 0.1

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

dist = Uniform(-0.1, 0.1)
params = (
    v = [rand(dist, d) for _ in 1:nw],
    u = [rand(dist, d) for _ in 1:nw]
)

# log(1 / (1 + exp(-x)))
# log(1) - log(1 + exp(-x))
# -log(1 + exp(-x))
# -log1p(exp(-x))
logσ(x) = -log1p(exp(-x))

Jₜ(vc, uo, us) = logσ(dot(uo, vc)) + sum(logσ(-dot(ui, vc)) for ui in us)

loader = DataLoader(corpus, batchsize=128, shuffle=true)

objst = BitVector()
for batch in loader
    for i in eachindex(batch)
        wcind, woind, wsinds = sampleinds(batch, i)
        
        vc = params.v[wcind]
        uo = params.u[woind]
        us = params.u[wsinds]

        y = Jₜ(vc, uo, us)

        # maximize Jₜ
        ∇vc, ∇uo, ∇us = gradient(Jₜ, vc, uo, us)

        nvc = vc + η*∇vc
        nuo = uo + η*∇uo
        nus = map(us, ∇us) do ui, ∇ui
            ui + η*∇ui
        end

        ny = Jₜ(nvc, nuo, nus)
        push!(objst, ny > y)

        params.v[wcind] = nvc
        params.u[woind] = nuo
        for (i, nui) in zip(wsinds, nus)
            params.u[i] = nui
        end
    end
end

# Plot
using Plots

plot(cumsum(objst))
