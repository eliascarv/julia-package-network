using Word2Vec
using Plots
using TSne

# generate corpus
path = "TXTFiles/GitHubPkgs"
pkgs = readdir(path)
file = open("corpus.txt", write=true)

for pkg in pkgs
    txts = readdir("$path/$pkg")
    
    for txt in txts
        text = read("$path/$pkg/$txt", String)
        write(file, text * " ")
    end
end

close(file)

# embedding
word2vec("corpus.txt", "model.txt")

model = wordvectors("model.txt")

# plot word cloud
corpus = split(read("corpus.txt", String))
vocab  = vocabulary(model)
wcount = Dict(vocab .=> 0)

for word in corpus
    if word ∈ vocab 
        wcount[word] += 1
    end
end

counts = collect(wcount)
sort!(counts, by=p -> last(p), rev=true)
words = first.(counts[1:500])

v2d = tsne(hcat([get_vector(model, w) for w in words]...)')

anns = [(x, y, text(w, 10)) for (x, y, w) in zip(v2d[:,1], v2d[:,2], words)]
scatter(v2d[:,1], v2d[:,2],
    ms=0, legend=false,
    size=(1200, 800),
    anns=anns,
    dpi=400
)

savefig("word_cloud.png")
