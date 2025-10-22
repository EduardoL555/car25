include("simple.jl")
using Genie, Genie.Renderer.Json, Genie.Requests, HTTP
using UUIDs

# Reutilizable entre recargas del archivo:
instances = isdefined(@__MODULE__, :instances) ? instances : Dict{String, Any}()

# ---- Serialización plana ----
# { id, pos:[x,y], dir:"EW"|"NS", state:"green"|"yellow"|"red" }
serialize_light(l) = Dict(
    "id"    => l.id,
    "pos"   => [l.pos[1], l.pos[2]],
    "dir"   => String(l.dir),
    "state" => String(light_state(l))
)

serialize_lights(model) = [serialize_light(l) for l in allagents(model)]

# ---- Rutas ----
route("/simulations", method = POST) do
    model = initialize_model()
    id = string(uuid1())
    instances[id] = model
    json(Dict(
        "Location" => "/simulations/$id",
        "lights"   => serialize_lights(model),
        "cars"     => Any[]   # etapa sin autos
    ))
end

route("/simulations/:id") do
    sim_id = payload(:id)
    if !haskey(instances, sim_id)
        return json(Dict("error" => "simulation not found"), status = 404)
    end
    model = instances[sim_id]
    run!(model, 1)
    json(Dict(
        "lights" => serialize_lights(model),
        "cars"   => Any[]     # etapa sin autos
    ))
end

# ---- CORS / servidor ----
Genie.config.run_as_server = true
Genie.config.cors_headers["Access-Control-Allow-Origin"]  = "*"
Genie.config.cors_headers["Access-Control-Allow-Headers"] = "Content-Type"
Genie.config.cors_headers["Access-Control-Allow-Methods"] = "GET,POST,PUT,DELETE,OPTIONS"
Genie.config.cors_allowed_origins = ["*"]

up()