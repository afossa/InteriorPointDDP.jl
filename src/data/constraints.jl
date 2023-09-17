"""
    Constraints Data
"""


# TODO: consider splitting eq and inequality constraints apart rather than using indices_inequality to determine inequalities

# struct Duals{T}
    # dual::Vector{Vector{T}} # duals (both eq and ineq) for each timestep
    # eq::Vector{T} # equality constraint dual λ
    # ineq::Vector{T} # inequality constraint dual s
    # delta_ineq::Vector{T} # δs
# end

struct ConstraintsData{T,C,CX,CU}
    constraints::Constraints{T}
    violations::Vector{C}
    jacobian_state::Vector{CX}
    jacobian_action::Vector{CU}
    duals::Vector{Vector{T}}
    # delta_ineq::Vector{T} # Unneeded??
end

function constraint_data(model::Model, constraints::Constraints) 
    H = length(constraints)
    c = [zeros(constraints[t].num_constraint) for t = 1:H]
    cx = [zeros(constraints[t].num_constraint, t < H ? model[t].num_state : model[H-1].num_next_state) for t = 1:H]
    cu = [zeros(constraints[t].num_constraint, model[t].num_action) for t = 1:H-1]
    # each constraint
    constraint_duals = [zeros(constraints[t].num_constraint) for t = 1:H]
    # eq = [zeros(constraints[t].num_constraint) for t = 1:H]
    # ineq = [zeros(constraints[t].num_constraint) for t = 1:H]
    ConstraintsData(constraints, c, cx, cu, constraint_duals)
end

function constraint!(constraint_data::ConstraintsData, x, u, w)
    constraint!(constraint_data.violations, constraint_data.constraints, x, u, w)
end

function constraint_violation(constraint_data::ConstraintsData; 
    norm_type=Inf)

    constraints = constraint_data.constraints
    H = length(constraints)
    max_violation = 0.0
    for t = 1:H
        num_constraint = constraints[t].num_constraint 
        ineq = constraints[t].indices_inequality
        for i = 1:num_constraint 
            c = constraint_data.violations[t][i]
            cti = (i in ineq) ? max(0.0, c) : abs(c)
            max_violation = max(max_violation, cti)
        end
    end
    return max_violation
end

function constraint_violation(constraint_data::ConstraintsData, x, u, w; 
    norm_type=Inf)
    constraint!(constraint_data, x, u, w)
    constraint_violation(constraint_data, 
        norm_type=norm_type)
end