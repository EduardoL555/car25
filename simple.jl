using Agents, Random
using StaticArrays: SVector

const CYCLE       = 28
const G_T         = 10
const Y_T         = 4
const DT          = 0.4
const CROSS_HALF  = 1.25
const STOP_MARGIN = 0.20
const ACC         = 0.05
const DEC         = 0.10
const LOOKAHEAD   = 3.5
const LANE_TOL    = 0.15
const SAFE_GAP    = 0.35
const STOP_ZONE   = 3.0

@agent struct TrafficLight(ContinuousAgent{2,Float64})
    dir::Symbol
    tick::Int
end

@agent struct Vehicle(ContinuousAgent{2,Float64})
    dir::Symbol
    speed::Float64
    target::Float64
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

function random_x_outside(rng::AbstractRNG, xmin::Float64, xmax::Float64, a::Float64, b::Float64)
    a = clamp(a, xmin, xmax); b = clamp(b, xmin, xmax)
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

function random_y_outside(rng::AbstractRNG, ymin::Float64, ymax::Float64, a::Float64, b::Float64)
    a = clamp(a, ymin, ymax); b = clamp(b, ymin, ymax)
    low_len  = max(0.0, a - ymin)
    high_len = max(0.0, ymax - b)
    if low_len + high_len == 0
        return ymin + 0.1
    end
    if rand(rng) < low_len / (low_len + high_len)
        return ymin + rand(rng) * low_len
    else
        return b + rand(rng) * high_len
    end
end

@inline function forward_gap(curr::Real, nxt::Real, L::Real)
    Δ = nxt - curr
    return Δ > 0 ? Δ : (Δ + L)
end

function ahead_vehicle(c::Vehicle, model; lookahead::Float64 = LOOKAHEAD, lane_tol::Float64 = LANE_TOL)
    if c.dir === :EW
        L = model.Lx
        ahead = nothing
        dmin  = Inf
        for a in allagents(model)
            if a isa Vehicle && a.dir === :EW && a.id != c.id &&
               abs(a.pos[2] - c.pos[2]) <= lane_tol
                d = forward_gap(c.pos[1], a.pos[1], L)
                if 0 < d < lookahead && d < dmin
                    ahead = a; dmin = d
                end
            end
        end
        return ahead, dmin
    else
        L = model.Ly
        ahead = nothing
        dmin  = Inf
        for a in allagents(model)
            if a isa Vehicle && a.dir === :NS && a.id != c.id &&
               abs(a.pos[1] - c.pos[1]) <= lane_tol
                d = forward_gap(c.pos[2], a.pos[2], L)
                if 0 < d < lookahead && d < dmin
                    ahead = a; dmin = d
                end
            end
        end
        return ahead, dmin
    end
end

function agent_step!(c::Vehicle, model)
    dt = DT
    sp = c.speed

    lstate = :green
    if c.dir === :EW
        for a in allagents(model); if a isa TrafficLight && a.dir === :EW; lstate = light_state(a); break; end; end
        stop_line = model.stop_x_ew
        pos       = c.pos[1]
        dist_to_stop = stop_line - pos
        must_brake_zone = (lstate != :green) && (0 < dist_to_stop <= STOP_ZONE)

        if must_brake_zone
            if dist_to_stop <= sp*dt + SAFE_GAP
                sp = max(0.0, (dist_to_stop - SAFE_GAP) / dt)
            else
                sp = max(0.0, sp - DEC)
            end
        else
            sp = min(c.target, sp + ACC)
        end

        nb, gap = ahead_vehicle(c, model)
        if nb !== nothing
            allowed = max(0.0, (gap - SAFE_GAP) / dt)
            sp = min(sp, allowed)
        end

        c.speed = clamp(sp, 0.0, 1.0)
        c.vel   = SVector{2,Float64}(c.speed, 0.0)

    else
        for a in allagents(model); if a isa TrafficLight && a.dir === :NS; lstate = light_state(a); break; end; end
        stop_line = model.stop_y_ns
        pos       = c.pos[2]
        dist_to_stop = stop_line - pos
        must_brake_zone = (lstate != :green) && (0 < dist_to_stop <= STOP_ZONE)

        if must_brake_zone
            if dist_to_stop <= sp*dt + SAFE_GAP
                sp = max(0.0, (dist_to_stop - SAFE_GAP) / dt)
            else
                sp = max(0.0, sp - DEC)
            end
        else
            sp = min(c.target, sp + ACC)
        end

        nb, gap = ahead_vehicle(c, model)
        if nb !== nothing
            allowed = max(0.0, (gap - SAFE_GAP) / dt)
            sp = min(sp, allowed)
        end

        c.speed = clamp(sp, 0.0, 1.0)
        c.vel   = SVector{2,Float64}(0.0, c.speed)
    end

    move_agent!(c, model, dt)
end

function ok_spawn_ew(x0::Float64, y::Float64, model)::Bool
    L = model.Lx
    for a in allagents(model)
        if a isa Vehicle && a.dir === :EW && abs(a.pos[2] - y) <= LANE_TOL
            if forward_gap(x0, a.pos[1], L) < SAFE_GAP*1.2 || forward_gap(a.pos[1], x0, L) < SAFE_GAP*1.2
                return false
            end
        end
    end
    return true
end

function ok_spawn_ns(y0::Float64, x::Float64, model)::Bool
    L = model.Ly
    for a in allagents(model)
        if a isa Vehicle && a.dir === :NS && abs(a.pos[1] - x) <= LANE_TOL
            if forward_gap(y0, a.pos[2], L) < SAFE_GAP*1.2 || forward_gap(a.pos[2], y0, L) < SAFE_GAP*1.2
                return false
            end
        end
    end
    return true
end

function initialize_model(extent = (25, 25); cars_per_lane::Int = 3)
    space2d = ContinuousSpace(extent; spacing = 0.5, periodic = true)
    rng = Random.MersenneTwister()

    cx, cy = extent[1] / 2, extent[2] / 2
    stop_x_ew = cx - CROSS_HALF - STOP_MARGIN
    stop_y_ns = cy - CROSS_HALF - STOP_MARGIN

    model = StandardABM(Union{TrafficLight, Vehicle}, space2d;
        rng,
        properties = Dict(
            :cx => cx, :cy => cy,
            :stop_x_ew => stop_x_ew, :stop_y_ns => stop_y_ns,
            :Lx => float(extent[1]),
            :Ly => float(extent[2])
        ),
        agent_step!,
        scheduler = Schedulers.ByType((TrafficLight, Vehicle), false)
    )

    add_agent!(SVector{2,Float64}(cx - 0.5, cy), TrafficLight, model;
        vel=SVector{2,Float64}(0.0, 0.0), dir=:EW, tick=0)
    add_agent!(SVector{2,Float64}(cx, cy - 0.5), TrafficLight, model;
        vel=SVector{2,Float64}(0.0, 0.0), dir=:NS, tick=14)

    ex_a = cx - CROSS_HALF - 0.6
    ex_b = cx + CROSS_HALF + 0.6
    ey_a = cy - CROSS_HALF - 0.6
    ey_b = cy + CROSS_HALF + 0.6

    for _ in 1:cars_per_lane
        x0 = random_x_outside(rng, 0.5, extent[1]-0.5, ex_a, ex_b)
        tries = 0
        while !ok_spawn_ew(x0, cy, model) && tries < 80
            x0 = random_x_outside(rng, 0.5, extent[1]-0.5, ex_a, ex_b); tries += 1
        end
        target = 0.4 + 0.5*rand(rng)
        speed0 = target * rand(rng)
        add_agent!(SVector{2,Float64}(x0, cy), Vehicle, model;
            vel=SVector{2,Float64}(speed0, 0.0), dir=:EW, speed=speed0, target=target)
    end

    for _ in 1:cars_per_lane
        y0 = random_y_outside(rng, 0.5, extent[2]-0.5, ey_a, ey_b)
        tries = 0
        while !ok_spawn_ns(y0, cx, model) && tries < 80
            y0 = random_y_outside(rng, 0.5, extent[2]-0.5, ey_a, ey_b); tries += 1
        end
        target = 0.4 + 0.5*rand(rng)
        speed0 = target * rand(rng)
        add_agent!(SVector{2,Float64}(cx, y0), Vehicle, model;
            vel=SVector{2,Float64}(0.0, speed0), dir=:NS, speed=speed0, target=target)
    end

    return model
end
