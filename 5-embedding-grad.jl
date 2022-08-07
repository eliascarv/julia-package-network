# WIP: Embedding
using Random
using Zygote
using MLUtils
using StatsBase
using Distributions
using LinearAlgebra

hasnan(x) = any(isnan, x)

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

Random.seed!(2)

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
# logσ(x) = min(0, x) - log1p(exp(-abs(x)))

Jₜ(vc, uo, us) = logσ(dot(uo, vc)) + sum(logσ(-dot(ui, vc)) for ui in us)

loader = DataLoader(corpus, batchsize=128, shuffle=true)

wy = Vector{Pair{NTuple{2,Int},Float64}}()
for batch in loader
    # batch = filter(w -> wcount[wordind[w]] > 6, batch)
    for i in eachindex(batch)
        wcind, woind, wsinds = sampleinds(batch, i)
        
        vc = params.v[wcind]
        uo = params.u[woind]
        us = params.u[wsinds]

        # maximize Jₜ
        ∇vc, ∇uo, ∇us = gradient(Jₜ, vc, uo, us)

        nvc = vc + η*∇vc
        nuo = uo + η*∇uo
        nus = map(us, ∇us) do ui, ∇ui
            ui + η*∇ui
        end

        J = Jₜ(nvc, nuo, nus)
        push!(wy, (wcind, woind) => J)

        params.v[wcind] = nvc
        params.u[woind] = nuo
        for (i, nui) in zip(wsinds, nus)
            params.u[i] = nui
        end
    end
end

# Plot
using Plots
using TSne

y = last.(wy)
plot(y, leg=false)

n = length(wy)
ym = [mean(y[i:min(i+99, n)]) for i in 1:100:n]
plot(ym, leg=false)

out = filter(p -> last(p) ≤ -5, wy[20000:end])
ws, ys = first.(out), last.(out)
wcs, wos = vocab[first.(ws)], vocab[last.(ws)]

wcanns = [(x, y, text(w, 8)) for (x, y, w) in zip(1:length(wcs), ys, wcs)]
scatter(ys, ms=0, anns=wcanns, leg=false)

woanns = [(x, y, text(w, 8)) for (x, y, w) in zip(1:length(wos), ys, wos)]
scatter(ys, ms=0, anns=woanns, leg=false)

wordcount = 1:nw .=> wcount
sort!(wordcount, by=p -> last(p), rev=true)
inds = first.(wordcount[1:500])

v2d = tsne(hcat(params.v[inds]...)')

scatter(v2d[:,1], v2d[:,2], 
    ms=0, legend=false,
    size=(1200, 800), 
    dpi=400
)

anns = [(x, y, text(word, 10)) for (x, y, word) in eachrow(hcat(v2d, vocab[inds]))]
annotate!(anns)
savefig("words.png")

# tests
cosine(x, y) = dot(x, y) / (norm(x) * norm(y))

function similar(word, n=10)
    v = params.v[wordind[word]]
    dists = map(vi -> cosine(v, vi), params.v)
    vocab[sortperm(dists, rev=true)[1:n]]
end
