# Part 1.2: Download markdown files from packages hosted on GitHub

using GitHub
using Downloads: download

# utils
const nreqs = Ref(0)

function getcontents(repo, auth)
    nreqs[] += 1
    directory(repo, "."; auth)[1]
end

function getcontents(repo, dir, auth)
    nreqs[] += 1
    directory(repo, dir; auth)[1]
end

hasdir(contents, dir) = any(c -> c.typ == "dir" && c.name == dir, contents)

function getreadme(contents)
    for content in contents
        content.typ ≠ "file" && continue

        filename = uppercase(content.name)
        if contains(filename, "README")
            return content
        end
    end
    return nothing
end

function _getmds!(mds, repo, dir, auth)
    contents = getcontents(repo, dir, auth)

    for content in contents
        if content.typ == "dir"
            _getmds!(mds, repo, content.path, auth)
        end

        filename = lowercase(content.name)
        if endswith(filename, ".md")
            push!(mds, content)
        end
    end
end

function getmds(repo, auth)
    mds = Content[]
    contents = getcontents(repo, "docs", auth)

    if hasdir(contents, "src")
        _getmds!(mds, repo, "docs/src", auth)
    end
    
    return mds
end

# scraping
const auth = authenticate(ENV["GITHUB_AUTH"])

ispath("MDFiles") || mkdir("MDFiles")
ispath("MDFiles/GitHubPkgs") || mkdir("MDFiles/GitHubPkgs")

const errors = open("MDFiles/GitHubPkgs/pkgswitherror.txt", write=true)

for line in eachline("PkgLists/githubpkgs.txt")
    if nreqs[] ≥ 4900
        @warn """
        The maximum number of requests has been reached.
        Run the script again in 1 hour.
        """
        break
    end

    pkg, repo = split(line, ",")

    println(pkg)

    path = "MDFiles/GitHubPkgs/$pkg"
    
    # if package has been analized, continue
    ispath(path) && continue

    # remove "https://github.com/" and ".git"
    repo = repo[20:end-4]

    try
        contents = getcontents(repo, auth)

        mkdir(path)

        readme = getreadme(contents)

        if !isnothing(readme)
            rdmfile = read(download(readme.download_url.uri))
            write("$path/readme.md", rdmfile)
        end
    
        if hasdir(contents, "docs")
            mds = getmds(repo, auth)

            for md in mds
                mdname = md.name
                mdfile = read(download(md.download_url.uri))
                write("$path/$mdname", mdfile)
            end
        end
    catch
        @warn "Error in package: $pkg"
        write(errors, "$line\n")
    end
end

close(errors)
