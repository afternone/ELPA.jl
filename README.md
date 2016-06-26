# Adaptive Label Propagation Algorithm (ALPA)
## Install
```julia
Pkg.clone("https://github.com/afternone/ALPA.jl.git")
```
## Usage
```julia
using ALPA
c = Dict{Int,Int}() # initialize nodes' membership
g = Graph() # start with an empty graph
lpa_addedge!(g, c, 1, 2) # add edge (1,2)
lpa_addedge!(g, c, 2, 3) # add edge (2,3)

