"""
    Solver Data
"""
struct SolverData{T}
    objective::Vector{T}                # objective value
    gradient::Vector{T}                 # Lagrangian gradient
    max_violation::Vector{T}            # maximum constraint violation

    indices_state::Vector{Vector{Int}}  # indices for state trajectory
    indices_action::Vector{Vector{Int}} # indices for control trajectory

    step_size::Vector{T}                # step length
    status::Vector{Bool}                # solver status

    iterations::Vector{Int}

    cache::Dict{Symbol,Vector{T}}       # solver stats

    perturbation::Float64 = 0           # μ, the perturbation
    logcost::Vector{T}                  # log of cost for i-th iteration
    err::Vector{T}                      # ??
    filter::Vector{Vector{T}}           # filter
end

function solver_data(dynamics::Vector{Dynamics{T}};
    max_cache=1000) where T

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
    max_violation = [0.0]
    step_size = [1.0]
    gradient = zeros(num_trajectory(dynamics))
    cache = Dict(:objective     => zeros(max_cache), 
                 :gradient      => zeros(max_cache), 
                 :max_violation => zeros(max_cache), 
                 :step_size     => zeros(max_cache))

    perturbation = 0
    logcost = [0.0]
    err = [0]
    filter = [zeros(2)]

    SolverData(objective, gradient, max_violation, indices_state, indices_action, step_size, [false], [0], cache, perturbation, logcost, err, filter)
end

function reset!(data::SolverData) 
    fill!(data.objective, 0.0) 
    fill!(data.gradient, 0.0)
    fill!(data.max_violation, 0.0) 
    fill!(data.cache[:objective], 0.0) 
    fill!(data.cache[:gradient], 0.0) 
    fill!(data.cache[:max_violation], 0.0) 
    fill!(data.cache[:step_size], 0.0) 
    data.status[1] = false
    data.iterations[1] = 0
    data.perturbation = 0.0
    data.logcost = [0.0]
    data.err = [0]
    data.filter = [zeros(2)]
end

# TODO: fix iter
function cache!(data::SolverData)
    iter = 1 #data.cache[:iter] 
    # (iter > length(data[:objective])) && (@warn "solver data cache exceeded")
    data.cache[:objective][iter] = data.objective[1]
    data.cache[:gradient][iter] = data.gradient
    data.cache[:step_size][iter] = data.step_size
    data.cache[:perturbation][iter] = data.perturbation
    data.cache[:logcost][iter] = data.logcost
    data.cache[:err][iter] = data.err
    data.cache[:filter][iter] = data.filter
    return nothing
end