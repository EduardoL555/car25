using Agents, Random
using StaticArrays: SVector

# ===== Semáforos =====
# Ciclo: 10 verde, 4 amarillo, 14 rojo ⇒ 28 ticks
const CYCLE  = 28
const G_T    = 10
const Y_T    = 4
# R_T = 14 (implicado)

@agent struct Light(ContinuousAgent{2,Float64})
    dir::Symbol   # :EW (este-oeste) o :NS (norte-sur)
    tick::Int     # contador 0..27
end

# Estado del semáforo según su tick actual
light_state(l::Light)::Symbol = begin
    t = mod(l.tick, CYCLE)
    if t < G_T
        :green
    elseif t < G_T + Y_T
        :yellow
    else
        :red
    end
end

# Avance 1 tick del semáforo (no se mueve, solo cambia estado)
function agent_step!(l::Light, model)
    l.tick = mod(l.tick + 1, CYCLE)
    # Velocidad cero (por claridad, aunque no se usa)
    l.vel = SVector{2, Float64}(0.0, 0.0)
end

# Inicialización SOLO con semáforos (sin autos)
function initialize_model(extent = (25, 25))
    # Espacio cuadrado y periódico (wrap-around no afecta, pues no nos movemos)
    space2d = ContinuousSpace(extent; spacing = 0.5, periodic = true)
    rng = Random.MersenneTwister()

    # ABM de semáforos
    model = StandardABM(Light, space2d; rng, agent_step!, scheduler = Schedulers.Randomly())

    # Centro del cruce
    cx, cy = extent[1] / 2, extent[2] / 2

    # Dos semáforos: uno para flujo Este-Oeste (EW) y otro para Norte-Sur (NS)
    # Sincronización: cuando EW está en verde, NS está en rojo (offset de media vuelta = 14)
    add_agent!(
        SVector{2, Float64}(cx - 0.5, cy),  # ubicación simbólica en la vía EW
        model;
        vel  = SVector{2, Float64}(0.0, 0.0),
        dir  = :EW,
        tick = 0              # arranca en verde
    )

    add_agent!(
        SVector{2, Float64}(cx, cy - 0.5),  # ubicación simbólica en la vía NS
        model;
        vel  = SVector{2, Float64}(0.0, 0.0),
        dir  = :NS,
        tick = 14             # arranca en rojo (desfase 14)
    )

    return model
end