# Cruce con semáforos (Agents.jl + Genie + React)

## Objetivo
Extender el modelo de tráfico simple para incluir un cruce con **dos semáforos** sincronizados, usando un ciclo México **Verde (10) → Amarillo (4) → Rojo (14)**. En esta etapa no hay autos.

## Diseño del modelo
- **Espacio:** `ContinuousSpace((25, 25), periodic=true)`
- **Agente `Light`:**
  - `dir ∈ {:EW, :NS}`
  - `tick ∈ 0..27`
  - Estado por `tick`: `green` si `t<10`, `yellow` si `10≤t<14`, `red` si `t≥14`.
  - `agent_step!`: `tick = (tick + 1) % 28` (no movimiento).
- **Sincronización:** dos semáforos con desfase de **14 ticks**:
  - EW: `tick=0` (verde al iniciar)
  - NS: `tick=14` (rojo al iniciar)

## API
- `POST /simulations` → crea simulación y responde:
  ```json
  { "Location": "/simulations/<id>", "lights": [...], "cars": [] }
