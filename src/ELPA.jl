module ELPA

typealias  Graph{V,W} Dict{V, Dict{V, W}}

export addnode!, deletenode!, addedge!, deleteedge!, ne,
    lpa_addnode!, lpa_deletenode!, lpa_addedge!, lpa_deleteedge!, loadgml, savegmal, modularity, Graph
# package code goes here
include("graph.jl")
include("evolving.jl")
include("graphio.jl")
include("utils.jl")

end # module
