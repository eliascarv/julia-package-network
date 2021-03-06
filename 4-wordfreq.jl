# Part 4: Word frequency
using Plots
using Plots.Measures

# count words
const path = "TXTFiles/GitHubPkgs"
const pkgs = readdir(path)
const strcount = Dict{String, Int}()

for pkg in pkgs
    txts = readdir("$path/$pkg")
    
    for txt in txts
        text = read("$path/$pkg/$txt", String)
        strs = split(text)
        
        for str in unique(strs)
            if haskey(strcount, str)
                strcount[str] += count(==(str), strs)
            else
                strcount[str] = count(==(str), strs)
            end
        end
    end
end

# plot the 100 most frequently occurring words
counts = collect(strcount)
sort!(counts, by=p -> last(p), rev=true)

x = last.(counts[1:100])
labels = first.(counts[1:100])
bar(x,
    xticks=(1:100, labels), 
    xrotation=90,
    legend=false,
    size=(1400, 800),
    bottom_margin=10mm
)
