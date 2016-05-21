using StatsBase

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

function range_shuffle!(r, a::AbstractVector)
    @inbounds for i=r:-1:2
        j = StatsBase.randi(i)
        a[i],a[j] = a[j],a[i]
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
    range_shuffle!(c.neigh_last-1, c.neigh_pos)
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
    range_shuffle!(c.neigh_last-1, c.neigh_pos)
    for lbl in c.neigh_pos
        if c.neigh_cnt[lbl] == max_cnt
            return lbl
        end
    end
end

function update!(g, m, c::NeighComm, active_nodes)
    num_active_nodes = 0
    while !isempty(active_nodes)
        if length(active_nodes) > num_active_nodes
            num_active_nodes = length(active_nodes)
        end
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
    num_active_nodes
end

function lpa_addnode!(g, m, u)
    if !haskey(g, u)
        addnode!(g, u)
        m[u] = u
    end
end

function lpa_deletenode!(g, m, c, u, active_lbls, pre_active_nodes, active_nodes)
    if haskey(g, u)
        empty!(pre_active_nodes)
        empty!(active_nodes)
        empty!(active_lbls)
        for v in keys(g[u])
            push!(active_lbls, m[v])
        end
        deletenode!(g, u)
        delete!(m, u)
        for v in keys(g)
            if in(m[v], active_lbls)
                push!(pre_active_nodes, v)
                push!(active_nodes, v)
                m[v] = v
            end
        end
        pre_update!(g, m, c, pre_active_nodes, active_nodes)
        return update!(g, m, c, active_nodes)
    end
    return 0
end

function lpa_addedge!(g, m, c, u, v, pre_active_nodes, active_nodes)
    lpa_addnode!(g, m, u)
    lpa_addnode!(g, m, v)
    if !haskey(g[u], v)
        u_comm = m[u]
        v_comm = m[v]
        if u_comm != v_comm
            ku_int = 0
            ku_ext = 0
            kv_int = 0
            kv_ext = 0
            for neigh in keys(g[u])
                if m[neigh] == u_comm
                    ku_int += 1
                else
                    ku_ext += 1
                end
            end
            for neigh in keys(g[v])
                if m[neigh] == v_comm
                    kv_int += 1
                else
                    kv_ext += 1
                end
            end
            if ku_ext+1 >= ku_int || kv_ext+1 >= kv_int
                empty!(pre_active_nodes)
                empty!(active_nodes)
                for i in keys(g)
                    i_comm = m[i]
                    if i_comm == u_comm || i_comm == v_comm
                        push!(pre_active_nodes, i)
                        push!(active_nodes, i)
                        m[i] = i
                    end
                end
                addedge!(g, u, v)
                pre_update!(g, m, c, pre_active_nodes, active_nodes)
                return update!(g, m, c, active_nodes)
            else
                addedge!(g, u, v)
            end
        else
            addedge!(g, u, v)
        end
    end
    return 0
end

function lpa_deleteedge!(g, m, c, u, v, pre_active_nodes, active_nodes)
    if haskey(g, u) && haskey(g[u], v)
        u_comm = m[u]
        v_comm = m[v]
        if u_comm == v_comm
            empty!(pre_active_nodes)
            empty!(active_nodes)
            for i in keys(g)
                if m[i] == u_comm
                    push!(pre_active_nodes, i)
                    push!(active_nodes, i)
                    m[i] = i
                end
            end
            deleteedge!(g, u, v)
            pre_update!(g, m, c, pre_active_nodes, active_nodes)
            return update!(g, m, c, active_nodes)
        else
            deleteedge!(g, u, v)
        end
    end
    return 0
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
