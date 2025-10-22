using Agents, Random
using StaticArrays: SVector
using Distributions: Uniform

# Agente continuo; el flag `accelerating` queda por compatibilidad (no lo usamos aquí)
@agent struct Car(ContinuousAgent{2,Float64})
    accelerating::Bool = true
end

# Reglas de cambio de velocidad (componente X)
accelerate(agent) = agent.vel[1] + 0.05
decelerate(agent) = agent.vel[1] - 0.1

# Detecta si hay un auto "adelante" en la MISMA vía (misma Y) dentro de un rango de vista
function car_ahead(agent, model; lookahead::Float64 = 3.0, lane_tol::Float64 = 0.01)
    ahead = nothing
    min_dx = Inf
    for nb in nearby_agents(agent, model, lookahead)
        # misma vía (Y casi igual)
        if abs(nb.pos[2] - agent.pos[2]) <= lane_tol
            dx = nb.pos[1] - agent.pos[1]  # diferencia en X
            if dx > 0 && dx < min_dx
                ahead = nb
                min_dx = dx
            end
        end
    end
    return ahead
end

function agent_step!(agent, model)
    # Si hay un auto por delante en la misma vía -> desacelera, si no -> acelera
    new_velocity = isnothing(car_ahead(agent, model)) ? accelerate(agent) : decelerate(agent)

    # Saturación en [0, 1]
    if new_velocity > 1.0
        new_velocity = 1.0
    elseif new_velocity < 0.0
        new_velocity = 0.0
    end

    # Actualiza vector de velocidad (horizontal)
    agent.vel = SVector{2, Float64}(new_velocity, 0.0)

    # Avanza (dt = 0.4)
    move_agent!(agent, model, 0.4)
end

function initialize_model(extent = (25, 10))
    space2d = ContinuousSpace(extent; spacing = 0.5, periodic = true)
    rng = Random.MersenneTwister()

    model = StandardABM(Car, space2d; rng, agent_step!, scheduler = Schedulers.Randomly())

    y_lane = 1.0  # <-- local, NO const
    first = true
    for px in randperm(rng, 25)[1:5]
        speed = first ? 1.0 : rand(rng, Uniform(0.2, 0.7))
        add_agent!(
            SVector{2, Float64}(px, y_lane),
            model;
            vel = SVector{2, Float64}(speed, 0.0),
            accelerating = true
        )
        first = false
    end

    return model
end
