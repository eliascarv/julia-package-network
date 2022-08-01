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

# parameters
const m = 3
const d = 300
const k = 15
const η = 0.1
const t = 1e-3
const α = 3/4

# constants
const nw = length(vocab)
const wordind = Dict(w => i for (i, w) in pairs(vocab))
# Unigram Dist: U(w) = count(w) / length(corpus)
const unidist = wcount ./ length(corpus)
# Noise Dist: Pₙ(w) = U(w)^α / Z, where Z is a normalization factor
const noisedist = pweights(normalize(unidist .^ α, 1))

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
    probs  = noisedist[sinds]
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
logσ(x) = -log1p(exp(-x))

Jₜ(vc, uo, us) = logσ(dot(uo, vc)) + sum(logσ(-dot(ui, vc)) for ui in us)

loader = DataLoader(corpus, batchsize=128, shuffle=true)

for batch in loader
    # Subsampling of Frequent Words
    keep = map(batch) do word
        i = wordind[word]
        z = unidist[i]
        p = min((sqrt(z/t) + 1) * t/z, 1)
        ps = pweights([1-p, p])
        sample([false, true], ps)
    end

    batch = batch[keep]

    for i in eachindex(batch)
        wcind, woind, wsinds = sampleinds(batch, i)

        # wcount[wcind] < 2 && continue
        
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

wordcount = 1:nw .=> wcount
sort!(wordcount, by=p -> last(p), rev=true)
inds = first.(wordcount[300:600])

v2d = tsne(hcat(params.v[inds]...)')

scatter(v2d[:, 1], v2d[:, 2], 
    ms=0, legend=false,
    size=(1200, 800), 
    dpi=400
)

anns = [(x, y, text(word, 10)) for (x, y, word) in eachrow(hcat(v2d, vocab[inds]))]
annotate!(anns)
savefig("words.png")

# tests
cosine(x, y) = dot(x, y) / (norm(x) * norm(y))

function similar(word)
    wi = wordind[word]
    v = params.v[wi]
    dists = map(vi -> cosine(v, vi), params.v)
    vocab[sortperm(dists, rev=true)[1:10]]
end
