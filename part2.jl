# Part 2: convert md files to txt files

ispath("TXTFiles") || mkdir("TXTFiles")
ispath("TXTFiles/GitHubPkgs") || mkdir("TXTFiles/GitHubPkgs")

const pkgs = readdir("MDFiles/GitHubPkgs")
popat!(pkgs, findfirst(==("pkgswitherror.txt"), pkgs))

for pkg in pkgs
    path = "TXTFiles/GitHubPkgs/$pkg"
    ispath(path) || mkdir(path)

    files = readdir("MDFiles/GitHubPkgs/$pkg")
    
    for file in files
        text = read("MDFiles/GitHubPkgs/$pkg/$file")
        filename = first(splitext(file))
        write("$path/$filename.txt", text)
    end
end
