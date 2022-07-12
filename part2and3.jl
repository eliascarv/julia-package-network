# Part 2 and 3: convert md files to txt files and data cleaning

# utils
function clean(str)
    # Documenter.jl syntax
    str = replace(str,
        r"```@docs\n[\s\S]*?```" => "",
        r"```@autodocs\n[\s\S]*?```" => "",
        r"```@meta\n[\s\S]*?```" => "",
        r"```@index\n[\s\S]*?```" => "",
        r"```@example[\w\s;=]*?\n[\s\S]*?```" => "",
        r"```@repl[\w\s;=]*?\n[\s\S]*?```" => "",
        r"```@setup [\w]+\n[\s\S]*?```" => "",
        r"```@eval\n[\s\S]*?```" => "",
        r"```@raw [\w]+\n[\s\S]*?```" => ""
    )

    str = replace(str,
        r"```[A-Za-z]+\n```" => "", # empty code block
        r"```[A-Za-z]+\n[\s\S]*?\n```" => "", # code block
        r"```\n[\s\S]*?\n```" => "", # code block without title
        r"```[^\n]+?```" => "", # one line code block
        r"`[^\n]+?`" => "" # one line code block
    )

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
        write("$path/$filename.txt", clean(text))
    end
end
