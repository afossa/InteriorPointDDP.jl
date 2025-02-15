using IterativeLQR 
using LinearAlgebra
using Plots
using Random
using BenchmarkTools
using Printf

visualise = false
benchmark = true
verbose = true

N = 101
h = 0.05
r_car = 0.02
xN = [1.0; 1.0; π / 4]

options = Options()
options.scaling_penalty = 2.0
options.initial_constraint_penalty = 1e-1
options.max_iterations = 1000
options.max_dual_updates = 30

# ## car 
num_state = 3
num_action = 2

# ## control limits

ul = [-0.1; -5.0]
uu = [1.0; 5.0]

# ## obstacles

xyr_obs = [
    [0.05, 0.25, 0.1],
    [0.45, 0.1, 0.15],
    [0.7, 0.7, 0.2],
    [0.35, 0.4, 0.1]
    ]
num_obstacles = length(xyr_obs)

include("../../examples/visualise/concar.jl")

# ## Dynamics - explicit midpoint for integrator

function car_continuous(x, u)
    [u[1] * cos(x[3]); u[1] * sin(x[3]); u[2]]
end

function car_discrete(x, u)
    x + h * car_continuous(x + 0.5 * h * car_continuous(x, u), u)
end

car = Dynamics(car_discrete, num_state, num_action)
dynamics = [car for k = 1:N-1] 

# ## objective 

stage_cost = (x, u) -> begin
    J = 0.0
    J += 1e-2 * dot(x - xN, x - xN)
    J += 1e-1 * dot(u, u)
    return J
end
objective = [
    [Cost(stage_cost, num_state, num_action) for k = 1:N-1]...,
    Cost((x, u) -> 1e3 * dot(x - xN, x - xN), num_state, 0)
]

# ## constraints - waypoints are constraints for iLQR

obs_dist(obs_xy) = (x, u) -> begin
    xy_diff = x[1:2] - obs_xy
    return dot(xy_diff, xy_diff)
end
stage_constr_fn = (x, u) -> begin
[
    ul - u; ## control limit (lower)
    u - uu; ## control limit (upper)
    # obstacle avoidance constraints i.e., d_thresh^2 - d_obs^2 <= 0 
    [(obs[3] + r_car)^2 - obs_dist(obs[1:2])(x, u)
        for (i, obs) in enumerate(xyr_obs)];
    # bound constraints, car must stay within [0, 1] x [0, 1] box
    -x[1];
    -x[2];
    x[1] - 1.0;
    x[2] - 1.0;
]
end

obs_constr = Constraint(stage_constr_fn, num_state, num_action,
    indices_inequality=collect(1:2*num_action+num_obstacles+4))

constraints = [[obs_constr for k = 1:N-1]..., Constraint()]

solver = Solver(dynamics, objective, constraints; options=options)

open("results/concar.txt", "w") do io
	@printf(io, " seed  iterations  status     objective           primal        time (s)  \n")
	for seed = 1:50
		solver.options.verbose = verbose
		Random.seed!(seed)
		
        # ## Initialise solver and solve
        
        x0 = [0.0; 0.0; 0.0] + rand(3) .* [0.05, 0.05, π / 2]
        ū = [1.0e-3 .* (rand(2) .- 0.5) for k = 1:N-1]
        x̄ = rollout(dynamics, x0, ū)
        
        solve!(solver, x̄, ū)
		
		if benchmark
            solver.options.verbose = false
            solve_time = @belapsed solve!($solver, $x̄, $ū)
            @printf(io, " %2s     %5s      %5s    %.8e    %.8e    %.5f  \n", seed, solver.data.iterations[1], solver.data.status[1], solver.data.objective[1], solver.data.max_violation[1], solve_time)
        else
            @printf(io, " %2s     %5s      %5s    %.8e    %.8e \n", seed, solver.data.iterations[1], solver.data.status[1], solver.data.objective[1], solver.data.max_violation[1])
        end
    end
end

# ## Plot solution

if visualise
    # ## solution
    x_sol, u_sol = get_trajectory(solver)
    
    # ## visualize
    plot()
    plotTrajectory!(x_sol)
    for xyr in xyr_obs
        plotCircle!(xyr[1], xyr[2], xyr[3])
    end
    savefig("plots/concar.png")
end
