include("simple.jl")
using Genie, Genie.Renderer.Json, Genie.Requests, HTTP
using UUIDs

sim_store = isdefined(@__MODULE__, :sim_store) ? sim_store : Dict{String, Any}()

serialize_light(l::TrafficLight) = Dict(
    "id"    => l.id,
    "pos"   => [l.pos[1], l.pos[2]],
    "dir"   => String(l.dir),
    "state" => String(light_state(l))
)

serialize_vehicle(v::Vehicle) = Dict(
    "id"    => v.id,
    "pos"   => [v.pos[1], v.pos[2]],
    "vel"   => [v.vel[1], v.vel[2]],
    "dir"   => String(v.dir),
    "speed" => v.speed,
    "target"=> v.target
)

function gather(model)
    lights = Vector{Any}()
    cars   = Vector{Any}()
    for a in allagents(model)
        if a isa TrafficLight
            push!(lights, serialize_light(a))
        elseif a isa Vehicle
            push!(cars, serialize_vehicle(a))
        end
    end
    return lights, cars
end

function compute_metrics(model)
    nEW = 0; sumEW = 0.0
    nNS = 0; sumNS = 0.0
    for a in allagents(model)
        if a isa Vehicle
            if a.dir === :EW
                nEW += 1; sumEW += a.speed
            else
                nNS += 1; sumNS += a.speed
            end
        end
    end
    Dict(
        "avg_speed_ew" => (nEW == 0 ? 0.0 : sumEW/nEW),
        "avg_speed_ns" => (nNS == 0 ? 0.0 : sumNS/nNS),
        "count_ew" => nEW,
        "count_ns" => nNS
    )
end

# ---- Rutas ----
route("/simulations", method = POST) do
    payload = jsonpayload()
    cpl = haskey(payload, "cars_per_lane") ? Int(payload["cars_per_lane"]) : 3
    model = initialize_model((25,25); cars_per_lane=cpl)
    id = string(uuid1())
    sim_store[id] = model
    lights, cars = gather(model)
    json(Dict(
        "Location" => "/simulations/$id",
        "lights"   => lights,
        "cars"     => cars,
        "metrics"  => compute_metrics(model)
    ))
end

route("/simulations/:id") do
    sim_id = payload(:id)
    if !haskey(sim_store, sim_id)
        return json(Dict("error" => "simulation not found"), status = 404)
    end
    model = sim_store[sim_id]
    run!(model, 1)
    lights, cars = gather(model)
    json(Dict(
        "lights"  => lights,
        "cars"    => cars,
        "metrics" => compute_metrics(model)
    ))
end

# ---- CORS / servidor ----
Genie.config.run_as_server = true
Genie.config.cors_headers["Access-Control-Allow-Origin"]  = "*"
Genie.config.cors_headers["Access-Control-Allow-Headers"] = "Content-Type"
Genie.config.cors_headers["Access-Control-Allow-Methods"] = "GET,POST,PUT,DELETE,OPTIONS"
Genie.config.cors_allowed_origins = ["*"]

up()
