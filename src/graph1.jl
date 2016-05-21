typealias  Graph Dict{Int, Set{Int}}

function addnode!(g::Graph, u::Int)
    if !haskey(g, u)
        g[u] = valtype(g)()
    end
    nothing
end

function delnode!(g::Graph, u::Int)
    if haskey(g, u)
        for v in keys(g[u])
            delete!(g[v], u)
        end
        delete!(g, u)
    end
    nothing
end

function addedge!(g::Graph, u::Int, v::Int)
    addnode!(g, u)
    addnode!(g, v)
    push!(g[u], v)
    push!(g[v], u)
    nothing
end

function deledge!(g::Graph, u::Int, v::Int)
    if haskey(g, u) && haskey(g, v)
        delete!(g[u], v)
        delete!(g[v], u)
    end
    nothing
end

function numedge(g::Graph)
    m = 0
    for u in keys(g)
        m += length(g[u])
    end
    return div(m, 2)
end
