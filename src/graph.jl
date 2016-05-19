function addnode!{V,W}(g::Graph{V,W}, u::V)
    if !haskey(g, u)
        g[u] = valtype(g)()
    end
    nothing
end

function deletenode!{V,W}(g::Graph{V,W}, u::V)
    for v in keys(g[u])
        delete!(g[v], u)
    end
    delete!(g, u)
end

function addedge!{V,W}(g::Graph{V,W}, u::V, v::V, ew::W)
    addnode!(g, u)
    addnode!(g, v)
    g[u][v] = ew
    g[v][u] = ew
end
addedge!{V,W}(g::Graph{V,W}, u::V, v::V) = addedge!(g, u, v, zero(W))

function deleteedge!{V,W}(g::Graph{V,W}, u::V, v::V)
    delete!(g[u], v)
    delete!(g[v], u)
end

function ne{V,W}(g::Graph{V,W})
	m = 0
	for u in keys(g)
		m += length(g[u])
	end
	return div(m, 2)
end
