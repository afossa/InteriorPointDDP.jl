struct Dynamics{T}
    val 
    jacx 
    jacu
    ny::Int 
    nx::Int 
    nu::Int
    nw::Int
    val_cache::Vector{T} 
    jacx_cache::Matrix{T}
    jacu_cache::Matrix{T}
end

Model{T} = Vector{Dynamics{T}} where T

function Dynamics(f::Function, nx::Int, nu::Int, nw::Int=0)
    #TODO: option to load/save methods
    @variables x[1:nx], u[1:nu], w[1:nw] 
    y = f(x, u, w) 
    jacx = Symbolics.jacobian(y, x);
    jacu = Symbolics.jacobian(y, u);
    val_func = eval(Symbolics.build_function(y, x, u, w)[2]);
    jacx_func = eval(Symbolics.build_function(jacx, x, u, w)[2]);
    jacu_func = eval(Symbolics.build_function(jacu, x, u, w)[2]);
    ny = length(y)
    njx, mjx = size(jacx)
    nju, mju = size(jacu)

    return Dynamics(val_func, jacx_func, jacu_func, 
                    ny, nx, nu, nw, 
                    zeros(ny), zeros(njx, mjx), zeros(nju, mju))
end

function step!(d::Dynamics, x, u, w) 
    d.val(d.val_cache, x, u, w)
    return d.val_cache
end

function eval_con!(c, cons::Model, x, u, w) 
    for (t, con) in enumerate(cons)
        step!(con, x[t], u[t], w[t])
        @views x[t+1] .= con.val_cache
    end
end

function eval_con_jac!(jx, ju, cons::Model, x, u, w)
    for (t, con) in enumerate(cons) 
        con.jacx(con.jacx_cache, x[t], u[t], w[t])
        con.jacu(con.jacu_cache, x[t], u[t], w[t])
        @views jx[t] .= con.jacx_cache
        @views ju[t] .= con.jacu_cache
        fill!(con.jacx_cache, 0.0) # TODO: confirm this is necessary
        fill!(con.jacu_cache, 0.0) # TODO: confirm this is necessary
    end
end

num_var(model::Model) = sum([d.nx + d.nu for d in model]) + model[end].ny

