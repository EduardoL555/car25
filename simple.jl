using Agents, Random
using StaticArrays: SVector

const CYCLE  = 28
const G_T    = 10
const Y_T    = 4
const DT     = 0.4
const CROSS_HALF = 1.25
const STOP_MARGIN = 0.2

@agent struct TrafficLight(ContinuousAgent{2,Float64})
    dir::Symbol
    tick::Int
end

@agent struct Vehicle(ContinuousAgent{2,Float64})
    target_speed::Float64
end

light_state(l::TrafficLight)::Symbol = begin
    t = mod(l.tick, CYCLE)
    if t < G_T
        :green
    elseif t < G_T + Y_T
        :yellow
    else
        :red
    end
end

function agent_step!(l::TrafficLight, model)
    l.tick = mod(l.tick + 1, CYCLE)
    l.vel = SVector{2, Float64}(0.0, 0.0)
end

function light_ew(model)
    for a in allagents(model)
        if a isa TrafficLight && a.dir === :EW
            return a
        end
    end
    return nothing
end

function random_x_outside(rng::AbstractRNG, xmin::Float64, xmax::Float64, a::Float64, b::Float64)
    a = clamp(a, xmin, xmax)
    b = clamp(b, xmin, xmax)
    left_len  = max(0.0, a - xmin)
    right_len = max(0.0, xmax - b)
    if left_len + right_len == 0
        return xmin + 0.1
    end
    if rand(rng) < left_len / (left_len + right_len)
        return xmin + rand(rng) * left_len
    else
        return b + rand(rng) * right_len
    end
end

function agent_step!(c::Vehicle, model)
    cx = model.cx
    stop_x = model.stop_x

    dt = DT
    desired = c.target_speed

    # Estado del semáforo de la vía horizontal
    lew = light_ew(model)
    st  = isnothing(lew) ? :green : light_state(lew)

    x = c.pos[1]
    dist = stop_x - x  

    if (st != :green) && dist > 0
        if dist <= desired * dt
            v = max(0.0, dist / dt - 1e-6)
            c.vel = SVector{2,Float64}(v, 0.0)
        else
            c.vel = SVector{2,Float64}(desired, 0.0)
        end
    else
        c.vel = SVector{2,Float64}(desired, 0.0)
    end

    move_agent!(c, model, dt)
end

function initialize_model(extent = (25, 25))
    space2d = ContinuousSpace(extent; spacing = 0.5, periodic = true)
    rng = Random.MersenneTwister()

    cx, cy = extent[1] / 2, extent[2] / 2
    stop_x = cx - CROSS_HALF - STOP_MARGIN

    model = StandardABM(Union{TrafficLight, Vehicle}, space2d;
        rng,
        properties = Dict(:cx => cx, :cy => cy, :stop_x => stop_x),
        agent_step!,
        scheduler = Schedulers.ByType((TrafficLight, Vehicle), false)
    )

    add_agent!(SVector{2,Float64}(cx - 0.5, cy), TrafficLight, model;
        vel  = SVector{2,Float64}(0.0, 0.0), dir = :EW, tick = 0)

    add_agent!(SVector{2,Float64}(cx, cy - 0.5), TrafficLight, model;
        vel  = SVector{2,Float64}(0.0, 0.0), dir = :NS, tick = 14)

    ex_a = cx - CROSS_HALF - 0.5
    ex_b = cx + CROSS_HALF + 0.5
    spawn_x = random_x_outside(rng, 0.5, extent[1]-0.5, ex_a, ex_b)
    add_agent!(SVector{2,Float64}(spawn_x, cy), Vehicle, model;
        vel = SVector{2,Float64}(0.8, 0.0), target_speed = 0.8)

    return model
end
