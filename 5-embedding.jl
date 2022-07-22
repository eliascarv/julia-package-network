# WIP
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
const pkgs = readdir(path)[1:10]

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
# const k = 64
const k = 16
const η = 0.1

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
logσ(x) = -log1p(exp(-x))

Jₜ(vc, uo, us) = logσ(dot(uo, vc)) + sum(logσ(-dot(ui, vc)) for ui in us)

loader = DataLoader(tokens, batchsize=128)

for batch in loader
    for i in eachindex(batch)
        wc, wo = window(batch, i)
        wcind  = findfirst(==(wc), words)
        woind  = findfirst(==(wo), words)
        wsinds = sample(1:nw, wv, k, replace=false)
        
        vc = params.v[wcind]
        uo = params.u[woind]
        us = params.u[wsinds]

        ∇vc, ∇uo, ∇us = gradient(Jₜ, vc, uo, us)

        # maximize Jₜ
        vc .= vc + η*∇vc
        uo .= uo + η*∇uo
        for i in eachindex(us)
            us[i] .= us[i] + η*∇us[i]
        end
    end
end
