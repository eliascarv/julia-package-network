using LinearAlgebra
using Statistics
using Word2Vec
using Plots
using TSne

model = wordvectors("model.txt")
vocab = Set(vocabulary(model))

path = "TXTFiles/GitHubPkgs"
pkgs = readdir(path)
pkgvec = Dict{String,Vector{Float64}}()

for pkg in pkgs
    txts = readdir("$path/$pkg")
    
    words = Vector{String}()
    for txt in txts
        text = read("$path/$pkg/$txt", String)
        append!(words, split(text))
    end

    vecs = Vector{Vector{Float64}}()
    for word in unique(words)
        if word ∈ vocab
            push!(vecs, get_vector(model, word))
        end
    end

    if !isempty(vecs)
        pkgvec[pkg] = mean(vecs) 
    end
end

# pkg cloud
pkgpairs = collect(pkgvec)[1:500]
pkgnames = first.(pkgpairs)
pkgvecs  = last.(pkgpairs)

v2d = tsne(hcat(pkgvecs...)')

anns = [(x, y, text(w, 6)) for (x, y, w) in zip(v2d[:,1], v2d[:,2], pkgnames)]
scatter(v2d[:,1], v2d[:,2],
    ms=0, legend=false,
    size=(1200, 800),
    anns=anns,
    dpi=400
)

savefig("pkg_cloud.png")

# similarity
cosine(x, y) = dot(x, y) / (norm(x) * norm(y))

pkgpairs = collect(pkgvec)
pkgnames = first.(pkgpairs)
pkgvecs  = last.(pkgpairs)

function similar(pkg, n=10)
    v = pkgvec[pkg]
    dists = map(vi -> cosine(v, vi), pkgvecs)
    pkgnames[sortperm(dists, rev=true)[1:n]]
end
