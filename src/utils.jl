function modularity(g, c)
	Q = 0.
	m = 2*ne(g)
	m == 0 && return 0.
	s1 = 0
	s2 = 0
	for u in keys(g)
		for v in keys(g)
			c[u] != c[v] && continue
			s1 += haskey(g[u], v) ? 1 : 0
			s2 += length(g[u])*length(g[v])
		end
	end
	Q = s1/m - s2/m^2
	return Q
end
