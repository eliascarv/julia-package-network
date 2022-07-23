# WIP: Embedding
using Zygote
using MLUtils
using StatsBase
using Distributions
using LinearAlgebra

using Random; Random.seed!(2)

const tokens = Vector{String}() # corpus
const words  = Vector{String}() # vocabulary
const counts = Vector{Int}()

const path = "TXTFiles/GitHubPkgs"
const pkgs = readdir(path)[1:100]

for pkg in pkgs
    txts = readdir("$path/$pkg")
    
    for txt in txts
        text = read("$path/$pkg/$txt", String)
        strs = split(text)
        append!(tokens, strs)
        
        for str in strs
            if str ∈ words
                i = findfirst(==(str), words)
                counts[i] += 1
            else
                push!(words, str)
                push!(counts, 1)
            end
        end
    end
end

# constants
const nw = length(words)
const wv = pweights(counts ./ sum(counts))

# parameters
const m = 3
const d = 300
const k = 64
const η = 1.0

function window(batch, i)
    r = min(i + m, length(batch))
    l = max(i - m, 1)
    
    iₒ = rand([l:i-1; i+1:r])
    
    batch[i], batch[iₒ]
end

# embedding
dist = Uniform(-1, 1)
params = (
    v = [rand(dist, d) for _ in words],
    u = [rand(dist, d) for _ in words]
)

# log(1 / (1 + exp(-x)))
# log(1) - log(1 + exp(-x))
# -log(1 + exp(-x))
# -log1p(exp(-x))
logσ(x) = min(0, x) - log1p(exp(-abs(x)))

Jₜ(vc, uo, us) = logσ(dot(uo, vc)) + sum(logσ(-dot(ui, vc)) for ui in us)

loader = DataLoader(tokens, batchsize=128, shuffle=true)

for batch in loader
    for i in eachindex(batch)
        wc, wo = window(batch, i)

        wcind = findfirst(==(wc), words)
        woind = findfirst(==(wo), words)
        
        inds = setdiff(1:nw, [wcind, woind])
        wsinds = sample(inds, wv[inds], k, replace=false)
        
        vc = params.v[wcind]
        uo = params.u[woind]
        us = params.u[wsinds]

        # maximize Jₜ
        ∇vc, ∇uo, ∇us = gradient(Jₜ, vc, uo, us)

        params.v[wcind] = vc + η*∇vc
        params.u[woind] = uo + η*∇uo
        for (i, ui, ∇ui) in zip(wsinds, us, ∇us)
            params.u[i] = ui + η*∇ui
        end
    end
end

# Plot
using Plots
using TSne

wordcount = 1:nw .=> counts
sort!(wordcount, by=p -> last(p), rev=true)
inds = first.(wordcount[1:500])

v2d = tsne(hcat(params.v[inds]...)')

scatter(v2d[:, 1], v2d[:, 2], 
    ms=0, legend=false,
    size=(1200, 800), 
    dpi=400
)

anns = [(x, y, text(word, 10)) for (x, y, word) in eachrow(hcat(v2d, words[inds]))]
annotate!(anns)
savefig("words.png")
