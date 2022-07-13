# Part 3: Data cleaning

# utils
const urlregex = r"https?:[\/\/www\.?a-zA-Z0-9@:%._\+~#=]{2,256}\.[a-z]{2,6}\b([-a-zA-Z0-9@:%_\+.~#?&//=]*)"

function clean(str)
    # Documenter.jl syntax
    str = replace(str,
        r"^```@docs\n[\s\S]*?```$"m => "",
        r"^```@autodocs\n[\s\S]*?```$"m => "",
        r"^```@meta\n[\s\S]*?```$"m => "",
        r"^```@index\n[\s\S]*?```$"m => "",
        r"^```@example.*?\n[\s\S]*?```$"m => "",
        r"^```@repl.*?\n[\s\S]*?```$"m => "",
        r"^```@setup \w+\n[\s\S]*?```$"m => "",
        r"^```@eval\n[\s\S]*?```$"m => "",
        r"^```@raw \w+\n[\s\S]*?```$"m => "",
        r"^```jldoctest.*?\n[\s\S]*?```$"m => "",
    )

    str = replace(str,
        r"^```[^\s\n]+?\n[\s\S]*?```$"m => "", # code block
        r"^~~~[^\s\n]+?\n[\s\S]*?~~~$"m => "", # code block
        r"^```\n[\s\S]*?```$"m => "", # code block without title
        r"^~~~\n[\s\S]*?~~~$"m => "", # code block without title
        r"```[^\n`]+?```" => "", # one line code block
        r"`[^\n`]+?`" => "" # one line code block
    )

    # url
    str = replace(str, urlregex => "")

    str = replace(str,
        r"\n+" => " ", # new lines
        r"<.*?>" => "", # html tag
        r"<.*?/>" => "", # html tag
        r"</.*?>" => "", # html tag
        r"\[[\s\S]*?\]\(.*?\)" => "", # links
        r"[^A-Za-z\s]" => "" # special chars and numbers
    )

    strip(replace(str, r"\s{2,}" => " ")) # multiple spaces
end

# data cleaning
ispath("TXTFiles") || mkdir("TXTFiles")
ispath("TXTFiles/GitHubPkgs") || mkdir("TXTFiles/GitHubPkgs")

const pkgs = readdir("MDFiles/GitHubPkgs")
popat!(pkgs, findfirst(==("pkgswitherror.txt"), pkgs))

for pkg in pkgs
    path = "TXTFiles/GitHubPkgs/$pkg"
    ispath(path) || mkdir(path)

    files = readdir("MDFiles/GitHubPkgs/$pkg")
    
    for file in files
        text = read("MDFiles/GitHubPkgs/$pkg/$file", String)
        filename = first(splitext(file))
        write("$path/$filename.txt", clean(text))
    end
end
