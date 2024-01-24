"""
    Constraints Data
"""

struct ConstraintsData{T,C,CX,CU}
    constraints::Constraints{T}
    violations::Vector{C} # the current value of each constraint (includes equality and ineq.)
    jacobian_state::Vector{CX} 
    jacobian_action::Vector{CU}
    inequalities::Vector{Vector{T}} # inequality constraints only
    nominal_inequalities::Vector{Vector{T}}
    duals::Vector{Vector{T}} # duals (both eq and ineq) for each timestep # consider removing
    ineq_duals::Vector{Vector{T}} # only ineq duals for each timestep
    nominal_ineq_duals:: Vector{Vector{T}}
    slacks::Vector{Vector{T}}
    nominal_slacks::Vector{Vector{T}}
end

function constraint_data(model::Model, constraints::Constraints, κ_1::Float64, κ_2::Float64)
    H = length(constraints)
    c = [zeros(constraints[t].num_constraint) for t = 1:H]
    ineqs = [zeros(constraints[t].num_inequality) for t = 1:H]
    nominal_ineqs = [zeros(constraints[t].num_inequality) for t = 1:H]

    # take inequalities and package them together
    for t = 1:H
        @views c[t] .= constraints[t].evaluate_cache
        @views ineqs[t] .= constraints[t].evaluate_cache[constraints[t].indices_inequality] # cool indexing trick
    end
    
    cx = [zeros(constraints[t].num_constraint, t < H ? model[t].num_state : model[H-1].num_next_state) for t = 1:H]
    cu = [zeros(constraints[t].num_constraint, model[t].num_action) for t = 1:H-1]
    
    constraint_duals = [zeros(constraints[t].num_constraint) for t = 1:H]
    
    ineq_duals = [κ_1 * ones(constraints[t].num_inequality) for t = 1:H]
    nominal_ineq_duals = [κ_1 * ones(constraints[t].num_inequality) for t = 1:H]

    slacks = [κ_2 .* ones(constraints[t].num_inequality) for t = 1:H]
    nominal_slacks = [κ_2 .* ones(constraints[t].num_inequality) for t = 1:H]

    return ConstraintsData(constraints, c, cx, cu, ineqs, nominal_ineqs, constraint_duals, ineq_duals, nominal_ineq_duals, slacks, nominal_slacks)
end

function constraint!(constraint_data::ConstraintsData, x, u, w)
    constraint!(constraint_data.violations, constraint_data.inequalities, constraint_data.constraints, x, u, w)
end

function constraint_violation(constraint_data::ConstraintsData)  # TODO: needed????
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
    constraint_violation(constraint_data, norm_type=norm_type)
end

function constraint_violation_1norm(constr_data::ConstraintsData)
    c = constr_data.inequalities
    y = constr_data.slacks
    H = length(c)
    
    constr_violation = 0.
    for t = 1:H
        num_constraint = constr_data.constraints[t].num_inequality
        for i = 1:num_constraint
            constr_violation += abs(c[t][i] + y[t][i])
        end
    end
    return constr_violation
end

function reset!(data::ConstraintsData, κ_1::Float64, κ_2::Float64) 
    H = length(data.constraints)
    for t = 1:H
        fill!(data.violations[t], 0.0)
        fill!(data.jacobian_state[t], 0.0)
        t < H && fill!(data.jacobian_action[t], 0.0)
        fill!(data.inequalities[t], 0.0)
        fill!(data.nominal_inequalities[t], 0.0)
        fill!(data.duals[t], 0.0) 
        fill!(data.ineq_duals[t], κ_1) 
        fill!(data.nominal_ineq_duals[t], κ_1) 
        fill!(data.slacks[t], κ_2) 
        fill!(data.nominal_slacks[t], κ_2)
    end 
end