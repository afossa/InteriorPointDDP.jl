function parse_results_ipopt(output::String)
    regex_obj = r"Objective...............:   (\d+.\d+e[+]\d+)    (\d+.\d+e[+]\d+)"
    regex_constr = r"Constraint violation....:   (\d+.\d+e[+]\d+)    (\d+.\d+e[+]\d+)"
    regex_niter = r"Number of Iterations....: (\d+)"
    regex_succ = r"EXIT: Optimal Solution Found."
    objective = Float64(0.0)
    constr_viol = Float64(0.0)
    n_iter = Int64(0)
    succ = false
    for line in Base.eachsplit(output, "\n")
        obj_match = match(regex_obj, line)
        constr_match = match(regex_constr, line)
        niter_match = match(regex_niter, line)
        succ_match = match(regex_succ, line)
        if !isnothing(obj_match)
            objective = parse(Float64, obj_match.captures[2])
        end
        if !isnothing(constr_match)
            constr_viol = parse(Float64, constr_match.captures[2])
        end
        if !isnothing(niter_match)
            n_iter = parse(Int64, niter_match.captures[1])
        end
        if !isnothing(succ_match)
            succ = true
        end
    end
    return objective, constr_viol, n_iter, succ
end
