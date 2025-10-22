include("simple.jl")
using Genie, Genie.Renderer.Json, Genie.Requests, HTTP
using UUIDs

instances = isdefined(@__MODULE__, :instances) ? instances : Dict{String, Any}()

# ---- Serialización plana ----
serialize_light(l::TrafficLight) = Dict(
    "id"    => l.id,
    "pos"   => [l.pos[1], l.pos[2]],
    "dir"   => String(l.dir),
    "state" => String(light_state(l))
)

serialize_vehicle(v::Vehicle) = Dict(
    "id"  => v.id,
    "pos" => [v.pos[1], v.pos[2]],
    "vel" => [v.vel[1], v.vel[2]]
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

route("/simulations", method = POST) do
    model = initialize_model()
    id = string(uuid1())
    instances[id] = model
    lights, cars = gather(model)
    json(Dict("Location" => "/simulations/$id", "lights" => lights, "cars" => cars))
end

route("/simulations/:id") do
    sim_id = payload(:id)
    if !haskey(instances, sim_id)
        return json(Dict("error" => "simulation not found"), status = 404)
    end
    model = instances[sim_id]
    run!(model, 1)
    lights, cars = gather(model)
    json(Dict("lights" => lights, "cars" => cars))
end

Genie.config.run_as_server = true
Genie.config.cors_headers["Access-Control-Allow-Origin"]  = "*"
Genie.config.cors_headers["Access-Control-Allow-Headers"] = "Content-Type"
Genie.config.cors_headers["Access-Control-Allow-Methods"] = "GET,POST,PUT,DELETE,OPTIONS"
Genie.config.cors_allowed_origins = ["*"]

up()
