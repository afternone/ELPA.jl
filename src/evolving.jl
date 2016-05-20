function vote2{V,W}(g::Graph{V,W}, m::Dict{V,Int}, u::V)
	c = Dict{V,Int}()
	max_cnt = 0
    if !isempty(keys(g[u]))
    	for neigh in keys(g[u])
    		neigh_comm = m[neigh]
    		c[neigh_comm] = get(c, neigh_comm, 0) + 1
    		if c[neigh_comm] > max_cnt
    			max_cnt = c[neigh_comm]
    		end
    	end
    	random_order = collect(keys(c))
    	shuffle!(random_order)
    	for lbl in random_order
    		if c[lbl] == max_cnt
    			return lbl
    		end
    	end
    else
        return m[u]
    end
end

function vote{V,W}(g::Graph{V,W}, m::Dict{V,Int}, u::V)
	c = Dict{V,Int}()
	max_cnt = 0
    if !isempty(keys(g[u]))
    	for neigh in keys(g[u])
    		neigh_comm = m[neigh]
    		c[neigh_comm] = get(c, neigh_comm, 0) + 1
    		if c[neigh_comm] > max_cnt
    			max_cnt = c[neigh_comm]
    		end
    	end
    	#random_order = collect(keys(c))
    	#shuffle!(random_order)
    	for (lbl, cnt) in c
    		if cnt == max_cnt
    			return lbl
    		end
    	end
    else
        return m[u]
    end
end

function vote1{V,W}(g::Graph{V,W}, m::Dict{V,Int}, u::V, all_active_nodes)
	c = Dict{V,Int}()
	max_cnt = 0
    if !isempty(keys(g[u]))
    	for neigh in keys(g[u])
			if in(neigh, all_active_nodes)
	    		neigh_comm = m[neigh]
	    		c[neigh_comm] = get(c, neigh_comm, 0) + 1
	    		if c[neigh_comm] > max_cnt
	    			max_cnt = c[neigh_comm]
	    		end
			end
    	end
		if isempty(c)
			return m[u]
		end
    	random_order = collect(keys(c))
    	shuffle!(random_order)
    	for lbl in random_order
    		if c[lbl] == max_cnt
    			return lbl
    		end
    	end
    else
        return m[u]
    end
end

function update!(g, m, active_nodes)
  num_active_nodes = 0
  while !isempty(active_nodes)
    if length(active_nodes) > num_active_nodes
        num_active_nodes = length(active_nodes)
    end
    random_order = collect(active_nodes)
    shuffle!(random_order)
    for u in random_order
      old_comm = m[u]
      new_comm = vote(g, m, u)
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
  num_active_nodes
end

function update1!(g, m, active_nodes)
  all_active_nodes = copy(active_nodes)
  while !isempty(active_nodes)
    random_order = collect(active_nodes)
    shuffle!(random_order)
    for u in random_order
      old_comm = m[u]
      new_comm = vote1(g, m, u, all_active_nodes)
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

function lpa_addnode!(g, m, u)
  if !haskey(g, u)
    addnode!(g, u)
    m[u] = u
  end
end

function lpa_deletenode1!(g, m, u)
  active_nodes = Set{keytype(g)}()
  for v in keys(g[u])
    push!(active_nodes, v)
    m[v] = v
  end
  deletenode!(g, u)
  delete!(m, u)
  update!(g, m, active_nodes)
end

function lpa_deletenode!(g, m, u)
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
  update1!(g, m, active_nodes)
  update!(g, m, all_active_nodes)
end

function lpa_addedge1!(g, m, u, v)
  lpa_addnode!(g, m, u)
  lpa_addnode!(g, m, v)
  active_nodes = Set{keytype(g)}()
  if m[u] != m[v]
    for i in keys(g[u])
      push!(active_nodes, i)
      m[i] = i
    end
    for i in keys(g[v])
      push!(active_nodes, i)
      m[i] = i
    end
    push!(active_nodes, u)
    m[u] = u
    push!(active_nodes, v)
    m[v] = v
    addedge!(g, u, v)
	all_active_nodes = copy(active_nodes)
	update1!(g, m, active_nodes)
    return update!(g, m, all_active_nodes)
  else
  	addedge!(g, u, v)
    return 0
  end
end

function lpa_addedge!(g, m, u, v)
  lpa_addnode!(g, m, u)
  lpa_addnode!(g, m, v)
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
	update1!(g, m, active_nodes)
    return update!(g, m, all_active_nodes)
  else
  	addedge!(g, u, v)
    return 0
  end
end

function lpa_deleteedge1!(g, m, u, v)
  active_nodes = Set{keytype(g)}()
  if m[u] == m[v]
    for i in keys(g[u])
      push!(active_nodes, i)
      m[i] = i
    end
    for i in keys(g[v])
      push!(active_nodes, i)
      m[i] = i
    end
    push!(active_nodes, u)
    m[u] = u
    push!(active_nodes, v)
    m[v] = v
    deleteedge!(g, u, v)
    update!(g, m, active_nodes)
  else
  	deleteedge!(g, u, v)
  end
end

function lpa_deleteedge!(g, m, u, v)
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
	update1!(g, m, active_nodes)
    return update!(g, m, all_active_nodes)
  else
  	deleteedge!(g, u, v)
    return 0
  end
end
