typealias  Graph{V,W} Dict{V, Dict{V, W}}

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

"""Type to record neighbor labels and their counts."""
type NeighComm
  neigh_pos::Vector{Int}
  neigh_cnt::Vector{Int}
  neigh_last::Int
end

"""Fast shuffle Array `a` in UnitRange `r` inplace."""
function range_shuffle!(r::UnitRange, a::AbstractVector)
    (r.start > 0 && r.stop <= length(a)) || error("out of bounds")
    @inbounds for i=length(r):-1:2
        j = rand(1:i)
        ii = i + r.start - 1
        jj = j + r.start - 1
        a[ii],a[jj] = a[jj],a[ii]
    end
end

"""Return the most frequency label."""
function pre_vote!(g, m, c::NeighComm, u, all_active_nodes)
    @inbounds for i=1:c.neigh_last-1
        c.neigh_cnt[c.neigh_pos[i]] = -1
    end
    c.neigh_last = 1
    c.neigh_pos[1] = m[u]
    c.neigh_cnt[c.neigh_pos[1]] = 0
    c.neigh_last = 2
    max_cnt = 0
    for neigh in keys(g[u])
        if in(neigh, all_active_nodes)
            neigh_comm = m[neigh]
            if c.neigh_cnt[neigh_comm] < 0
                c.neigh_cnt[neigh_comm] = 0
                c.neigh_pos[c.neigh_last] = neigh_comm
                c.neigh_last += 1
            end
            c.neigh_cnt[neigh_comm] += 1
            if c.neigh_cnt[neigh_comm] > max_cnt
              max_cnt = c.neigh_cnt[neigh_comm]
            end
        end
    end
    # ties breaking randomly
    range_shuffle!(1:c.neigh_last-1, c.neigh_pos)
    for lbl in c.neigh_pos
      if c.neigh_cnt[lbl] == max_cnt
        return lbl
      end
    end
end

function pre_update!(g, m, c::NeighComm, active_nodes, all_active_nodes)
  while !isempty(active_nodes)
    random_order = collect(active_nodes)
    shuffle!(random_order)
    for u in random_order
      old_comm = m[u]
      new_comm = pre_vote!(g, m, c, u, all_active_nodes)
      if new_comm != old_comm
        for v in keys(g[u])
		  if in(v, all_active_nodes)
	          push!(active_nodes, v)
	          m[u] = new_comm
		  end
        end
      else
        delete!(active_nodes, u)
      end
    end
  end
end

"""Return the most frequency label."""
function vote!(g, m, c::NeighComm, u)
    @inbounds for i=1:c.neigh_last-1
        c.neigh_cnt[c.neigh_pos[i]] = -1
    end
    c.neigh_last = 1
    c.neigh_pos[1] = m[u]
    c.neigh_cnt[c.neigh_pos[1]] = 0
    c.neigh_last = 2
    max_cnt = 0
    for neigh in keys(g[u])
        neigh_comm = m[neigh]
        if c.neigh_cnt[neigh_comm] < 0
            c.neigh_cnt[neigh_comm] = 0
            c.neigh_pos[c.neigh_last] = neigh_comm
            c.neigh_last += 1
        end
        c.neigh_cnt[neigh_comm] += 1
        if c.neigh_cnt[neigh_comm] > max_cnt
          max_cnt = c.neigh_cnt[neigh_comm]
        end
    end
    # ties breaking randomly
    range_shuffle!(1:c.neigh_last-1, c.neigh_pos)
    for lbl in c.neigh_pos
      if c.neigh_cnt[lbl] == max_cnt
        return lbl
      end
    end
end

function update!(g, m, c::NeighComm, active_nodes)
  while !isempty(active_nodes)
    random_order = collect(active_nodes)
    shuffle!(random_order)
    for u in random_order
      old_comm = m[u]
      new_comm = vote!(g, m, c, u)
      if new_comm != old_comm
        for v in keys(g[u])
          push!(active_nodes, v)
          m[u] = new_comm
        end
      else
        delete!(active_nodes, u)
      end
    end
  end
end

function lpa_addnode!(g, m, u)
  if !haskey(g, u)
    addnode!(g, u)
    m[u] = u
  end
end

function lpa_deletenode!(g, m, c, u)
  if haskey(g, u)
      active_nodes = Set{keytype(g)}()
      active_lbls = IntSet()
      for v in keys(g[u])
        push!(active_lbls, m[v])
      end
      deletenode!(g, u)
      delete!(m, u)
      for v in keys(g)
        if in(m[v], active_lbls)
          push!(active_nodes, v)
          m[v] = v
        end
      end
      all_active_nodes = copy(active_nodes)
      pre_update!(g, m, c, active_nodes, all_active_nodes)
      update!(g, m, c, all_active_nodes)
  end
end

function lpa_addedge!(g, m, c, u, v)
  lpa_addnode!(g, m, u)
  lpa_addnode!(g, m, v)
  if !haskey(g[u], v)
      active_nodes = Set{keytype(g)}()
      if m[u] != m[v]
        for i in keys(g)
          if m[i] == m[u] || m[i] == m[v]
            push!(active_nodes, i)
            m[i] = i
          end
        end
        addedge!(g, u, v)
    	all_active_nodes = copy(active_nodes)
    	pre_update!(g, m, c, active_nodes, all_active_nodes)
        update!(g, m, c, all_active_nodes)
      else
      	addedge!(g, u, v)
      end
  end
end

function lpa_deleteedge!(g, m, c, u, v)
  if haskey(g, u) && haskey(g[u], v)
      active_nodes = Set{keytype(g)}()
      if m[u] == m[v]
        for i in keys(g)
          if m[i] == m[u]
            push!(active_nodes, i)
            m[i] = i
          end
        end
        deleteedge!(g, u, v)
    	all_active_nodes = copy(active_nodes)
    	pre_update!(g, m, c, active_nodes, all_active_nodes)
        update!(g, m, c, all_active_nodes)
      else
      	deleteedge!(g, u, v)
      end
  end
end

using ParserCombinator: Parsers.GML

function _gml_read_one_graph(gs)
    nodes = [x[:id] for x in gs[:node]]
    g = Graph{Int,Int}()
    sds = [(Int(x[:source]), Int(x[:target])) for x in gs[:edge]]
    for (s,d) in (sds)
        addedge!(g, s, d)
    end
    return g
end

function loadgml(gname::AbstractString)
    p = GML.parse_dict(readall(gname))
    for gs in p[:graph]
		return _gml_read_one_graph(gs)
    end
    error("Graph $gname not found")
end

function savegml(gname::AbstractString, g, c=Vector{Integer}())
	io = open(gname, "w")
    println(io, "graph")
    println(io, "[")
    println(io, "directed 0")
    i = 0
    nodemap = Dict{Int,Int}()
    for u in keys(g)
    	nodemap[u] = i
        println(io,"\tnode")
        println(io,"\t[")
        println(io,"\t\tid $i")
        println(io,"\t\tlabel $u")
        length(c) > 0 && println(io,"\t\tvalue $(c[u])")
        println(io,"\t]")
        i += 1
    end
    for u in keys(g)
    	for v in keys(g[u])
    		if u < v
		        println(io,"\tedge")
		        println(io,"\t[")
		        println(io,"\t\tsource $(nodemap[u])")
		        println(io,"\t\ttarget $(nodemap[v])")
		        println(io,"\t]")
		    end
		end
    end
    println(io, "]")
    close(io)
    return 1
end
