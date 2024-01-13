module InteriorPointDDP

using LinearAlgebra 
using Symbolics 
using Scratch 
using JLD2
using Printf
using Crayons

include("costs.jl")
include("dynamics.jl")
include("constraints.jl")
include(joinpath("data", "model.jl"))
include(joinpath("data", "objective.jl"))
include(joinpath("data", "constraints.jl"))
include(joinpath("data", "policy.jl"))
include(joinpath("data", "problem.jl"))
include(joinpath("data", "solver.jl"))
include(joinpath("data", "methods.jl"))
include("options.jl")
include("solver.jl")
include("rollout.jl")
include("interior_point.jl")
include("gradients.jl")
include("backward_pass.jl")
include("forward_pass.jl")
include("print.jl")
include("solve.jl")

# objective 
export Cost

# constraints 
export Constraint

# dynamics 
export Dynamics

# solver 
export rollout, 
    dynamics!,
    Solver, Options,
    initialize_controls!, initialize_states!, 
    solve!,
    get_trajectory

end # module
