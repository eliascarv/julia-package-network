# Part 1.1: Generate package lists

using TOML
using GitHub
using Downloads: download

ispath("PkgLists") || mkdir("PkgLists")

const github = open("PkgLists/githubpkgs.txt", write=true)
const gitlab = open("PkgLists/gitlabpkgs.txt", write=true)
const others = open("PkgLists/otherpkgs.txt", write=true)

const auth = authenticate(ENV["GITHUB_AUTH"])
const repo = "JuliaRegistries/General"

# github download url
const url = "https://raw.githubusercontent.com/JuliaRegistries/General/master"

for letter in 'A':'Z'
    contents = directory(repo, letter; auth)[1]
    pkgs = map(c -> c.name, contents)
    # remove jll packages
    filter!(pkg -> !endswith(pkg, "_jll"), pkgs)

    for pkg in pkgs
        pkgfile = download("$url/$letter/$pkg/Package.toml")
        pkgtoml = TOML.parsefile(pkgfile)
        pkgname = pkgtoml["name"]
        pkgrepo = pkgtoml["repo"]

        pkgname == "julia" && continue

        if startswith(pkgrepo, "https://github.com")
            write(github, "$pkgname,$pkgrepo\n")
        elseif startswith(pkgrepo, "https://gitlab.com")
            write(gitlab, "$pkgname,$pkgrepo\n")
        else
            write(others, "$pkgname,$pkgrepo\n")
        end
    end
end

close(github)
close(gitlab)
close(others)
