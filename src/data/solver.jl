"""
    Solver Data
"""
mutable struct SolverData{T}
    j::Int                              # Outer loop iteration counter
    k::Int                              # Barrier problem (inner) iteration counter
    l::Int                              # Line search iteration counter

    objective::Vector{T}                # objective value
    gradient::Vector{T}                 # Lagrangian gradient
    θ_max::T                            # filter initialization for maximum allowable constraint violation

    indices_state::Vector{Vector{Int}}  # indices for state trajectory
    indices_action::Vector{Vector{Int}} # indices for control trajectory

    step_size::Vector{T}                # step length
    status::Vector{Bool}                # solver status

    iterations::Vector{Int}

    cache::Dict{Symbol,Vector{T}}       # solver stats

    μⱼ::Float64                         # perturbation value
    # τⱼ::Float64                       # fraction to the boundary value
    logcost::Float64                    # log of cost for i-th iteration
    optimality_error::Float64           # optimality error for problem (not barrier)
    
    filter::Vector{T}                   # filter
end

function solver_data(dynamics::Vector{Dynamics{T}};
    max_cache=1000) where T
    i = 0
    j = 0
    k = 0

    # indices x and u
    indices_state = Vector{Int}[]
    indices_action = Vector{Int}[] 
    n_sum = 0 
    m_sum = 0 
    n_total = sum([d.num_state for d in dynamics]) + dynamics[end].num_next_state
    for d in dynamics
        push!(indices_state, collect(n_sum .+ (1:d.num_state))) 
        push!(indices_action, collect(n_total + m_sum .+ (1:d.num_action)))
        n_sum += d.num_state 
        m_sum += d.num_action 
    end
    push!(indices_state, collect(n_sum .+ (1:dynamics[end].num_next_state)))

    objective = [Inf]
    θ_max = 0.0
    step_size = [1.0]
    gradient = zeros(num_trajectory(dynamics))
    cache = Dict(:objective     => zeros(max_cache), 
                 :gradient      => zeros(max_cache), 
                 :θ_max => zeros(max_cache), 
                 :step_size     => zeros(max_cache))

    μⱼ = 0.0
    logcost = Inf
    optimality_error = 0.0
    filter = [Inf , 0.0]

    SolverData(i, j, k, objective, gradient, θ_max, indices_state, indices_action, step_size, [false], [0], cache, μⱼ, logcost, optimality_error, filter)
end

function reset!(data::SolverData) 
    fill!(data.objective, 0.0) 
    fill!(data.gradient, 0.0)
    fill!(data.cache[:objective], 0.0) 
    fill!(data.cache[:gradient], 0.0) 
    fill!(data.cache[:θ_max], 0.0) 
    fill!(data.cache[:step_size], 0.0) 
    data.i = 0
    data.j = 0
    data.k = 0
    data.θ_max = Inf
    data.status[1] = false
    data.iterations[1] = 0
    data.μⱼ = 0.0
    data.logcost = [0.0]
    data.optimality_error = [0]
    data.filter = [zeros(2)]
end

# TODO: fix iter
function cache!(data::SolverData)
    iter = 1 #data.cache[:iter] 
    # (iter > length(data[:objective])) && (@warn "solver data cache exceeded")
    data.cache[:objective][iter] = data.objective[1]
    data.cache[:gradient][iter] = data.gradient
    data.cache[:step_size][iter] = data.step_size
    data.cache[:μⱼ][iter] = data.μⱼ
    data.cache[:logcost][iter] = data.logcost
    data.cache[:optimality_error][iter] = data.optimality_error
    data.cache[:filter][iter] = data.filter
    return nothing
end