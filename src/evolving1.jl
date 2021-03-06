"""Type to record neighbor labels and their counts."""
type NeighComm
    neigh_pos::Vector{Int}
    neigh_cnt::Vector{Int}
    neigh_last::Int
end

type NodeStatus
    neigh_pos::Vector{Int}
    neigh_cnt::Vector{Bool}
    neigh_last::Int
end

function pre_vote!(g, m, c::NeighComm, u, nodes_int)
    @inbounds for i=1:c.neigh_last-1
        c.neigh_cnt[c.neigh_pos[i]] = -1
    end
    c.neigh_last = 1
    c.neigh_pos[1] = m[u]
    c.neigh_cnt[c.neigh_pos[1]] = 0
    c.neigh_last = 2
    max_cnt = 0
    for neigh in g[u]
        # If in community
        if nodes_int[neigh]
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

function pre_update!(g, m, c::NeighComm, active_nodes, nodes_int, random_order)
    while !isempty(active_nodes)
        #random_order = collect(active_nodes)
        i = 0
        for u in active_nodes
            i += 1
            random_order[i] = u
        end
        #shuffle!(random_order)
        range_shuffle!(i, random_order)
        for j=1:i
            u = random_order[j]
            old_comm = m[u]
            new_comm = pre_vote!(g, m, c, u, nodes_int)
            if new_comm != old_comm
                for v in g[u]
                    if nodes_int[v]
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
    for neigh in g[u]
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

function update!(g, m, c::NeighComm, active_nodes, random_order)
    num_active_nodes = 0
    while !isempty(active_nodes)
        if length(active_nodes) > num_active_nodes
            num_active_nodes = length(active_nodes)
        end
        #random_order = collect(active_nodes)
        i = 0
        for u in active_nodes
            i += 1
            random_order[i] = u
        end
        #shuffle!(random_order)
        range_shuffle!(i, random_order)
        for j=1:i
            u = random_order[j]
            old_comm = m[u]
            new_comm = vote!(g, m, c, u)
            if new_comm != old_comm
                for v in g[u]
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

function lpa_deletenode!(g, m, c, u, active_nodes, nodes_int, random_order)
    if haskey(g, u)
        empty!(active_nodes)
        u_comm = m[u]
        deletenode!(g, u)
        delete!(m, u)
        nodes_int.neigh_last = 0
        for v in keys(g)
            if m[v] == u_comm
                push!(active_nodes, v)
                nodes_int.neigh_last += 1
                nodes_int.neigh_pos[nodes_int.neigh_last] = v
                nodes_int.neigh_cnt[v] = true
                m[v] = v
            end
        end
        pre_update!(g, m, c, active_nodes, nodes_int.neigh_cnt, random_order)
        num_active = update!(g, m, c, active_nodes, random_order)
        for i=1:nodes_int.neigh_last
            nodes_int.neigh_cnt[nodes_int.neigh_pos[i]] = false
        end
        return num_active
    end
    return 0
end

function lpa_addedge!(g, m, c, u, v, active_nodes, nodes_int, random_order)
    lpa_addnode!(g, m, u)
    lpa_addnode!(g, m, v)
    if !in(v, g[u])
        u_comm = m[u]
        v_comm = m[v]
        if u_comm != v_comm
            ku_int = 0
            ku_ext = 0
            kv_int = 0
            kv_ext = 0
            for neigh in g[u]
                if m[neigh] == u_comm
                    ku_int += 1
                else
                    ku_ext += 1
                end
            end
            for neigh in g[v]
                if m[neigh] == v_comm
                    kv_int += 1
                else
                    kv_ext += 1
                end
            end
            if ku_ext+1 >= ku_int || kv_ext+1 >= kv_int
                empty!(active_nodes)
                nodes_int.neigh_last = 0
                for i in keys(g)
                    i_comm = m[i]
                    if i_comm == u_comm || i_comm == v_comm
                        push!(active_nodes, i)
                        nodes_int.neigh_last += 1
                        nodes_int.neigh_pos[nodes_int.neigh_last] = i
                        nodes_int.neigh_cnt[i] = true
                        m[i] = i
                    end
                end
                addedge!(g, u, v)
                pre_update!(g, m, c, active_nodes, nodes_int.neigh_cnt, random_order)
                num_active = update!(g, m, c, active_nodes, random_order)
                for i=1:nodes_int.neigh_last
                    nodes_int.neigh_cnt[nodes_int.neigh_pos[i]] = false
                end
                return num_active
            else
                addedge!(g, u, v)
            end
        else
            addedge!(g, u, v)
        end
    end
    return 0
end

function lpa_deleteedge!(g, m, c, u, v, active_nodes, nodes_int, random_order)
    if haskey(g, u) && haskey(g[u], v)
        u_comm = m[u]
        v_comm = m[v]
        if u_comm == v_comm
            empty!(active_nodes)
            nodes_int.neigh_last = 0
            for i in keys(g)
                if m[i] == u_comm
                    push!(active_nodes, i)
                    nodes_int.neigh_last += 1
                    nodes_int.neigh_pos[nodes_int.neigh_last] = i
                    nodes_int.neigh_cnt[i] = true
                    m[i] = i
                end
            end
            deleteedge!(g, u, v)
            pre_update!(g, m, c, active_nodes, nodes_int.neigh_cnt, random_order)
            num_active = update!(g, m, c, active_nodes, random_order)
            for i=1:nodes_int.neigh_last
                nodes_int.neigh_cnt[nodes_int.neigh_pos[i]] = false
            end
            return num_active
        else
            deleteedge!(g, u, v)
        end
    end
    return 0
end
