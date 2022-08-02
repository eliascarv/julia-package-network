# Part 3: Data cleaning

# utils
const urlregex = r"(https?:\/\/(www\.)?)?[a-zA-Z0-9@:%._\+~#=]{2,256}\.[a-z]{2,6}\b([-a-zA-Z0-9@:%_\+.~#?&//=]*)"i

function clean(str)
    # remove invadid chars
    str = filter(isvalid, str)

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

    # Markdown syntax
    str = replace(str,
        # code blocks
        r"^```[^\s\n]+?\n[\s\S]*?```$"m => "", # with title
        r"^~~~[^\s\n]+?\n[\s\S]*?~~~$"m => "", # with title
        r"^ *\n(( {4}|\t).+?\n?)+?$"m => "", # indented
        r"^```\n[\s\S]*?```$"m => "", # without title
        r"^~~~\n[\s\S]*?~~~$"m => "", # without title
        r"```[^\n`]+?```" => "", # inline
        r"`[^\n`]+?`" => "", # inline
        # math
        r"^\$\$[\s\S]+?\$\$$"m => "", # block
        r"\$[^\n`]+?\$" => "", # inline
        r"``[^\n`]+?``" => "", # inline
        # links
        r"\[[^\[\]]*?\]\(.*?\)" => "",
        r"^\[.+?\]: .+?$"m => "",
        r"\[.+?\]\[.+?\]" => ""
    )

    # HTML syntax
    str = replace(str,
        r"<script.*?>[\s\S]*?</script>" => "",
        r"<style.*?>[\s\S]*?</style>" => "",
        r"<code.*?>[\s\S]*?</code>" => "",
        r"<.+?>" => ""
    )

    # .jl
    str = replace(str, r".jl"i => "")

    # URLs
    str = replace(str, urlregex => "")

    str = replace(str,
        r"\n+" => " ", # new lines
        r"[^A-Za-z\s]" => " " # special chars
    )

    str = replace(str, r"\s{2,}" => " ") # multiple spaces

    strip(lowercase(str)) 
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
