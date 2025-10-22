# Cruce con semáforos + 1 auto (Agents.jl + Genie + React)

## Objetivo
Extender el cruce con dos semáforos sincronizados para integrar **un auto** que circula por la **vía horizontal**.  
El auto **no aparece dentro del cruce** y **se detiene** ante luz **amarilla/roja** a una distancia segura, sin invadir el carril perpendicular.  
Se emplean **dos tipos de agentes** en el mismo modelo y un **scheduler por tipo** para controlar el orden de actualización.

---

## Diseño del modelo

### Espacio
- `ContinuousSpace((25, 25), periodic=true)`; el mundo es **cuadrado**.
- El cruce está centrado en `(cx, cy) = (extent.x/2, extent.y/2)`.

### Agentes
- **`TrafficLight`** (`ContinuousAgent{2,Float64}`)
  - Campos: `dir::Symbol` (`:EW` / `:NS`), `tick::Int`.
  - Ciclo México: **Verde 10** → **Amarillo 4** → **Rojo 14** (total **28** ticks).
  - Estado por `tick`: `green` / `yellow` / `red`.
  - No se mueve; en cada paso incrementa `tick` (módulo 28).

- **`Vehicle`** (`ContinuousAgent{2,Float64}`)
  - Campos: `target_speed::Float64` (0..1).  
  - Circula **en eje X** por la vía horizontal (Y = `cy`).
  - **Regla de parada:** si el semáforo **EW** está en `yellow` o `red` y el auto aún no cruza la **línea de alto**, frena para quedar **antes** del cruce. En `green`, avanza con `target_speed`.

### Propiedades del modelo
Se guardan en `properties` y se consumen como atributos:
- `model.cx`, `model.cy` — centro del cruce.
- `model.stop_x` — **línea de alto** en la vía horizontal (X antes del cruce).

### Evitar spawn dentro del cruce
El auto se crea con `spawn_x` elegido **fuera** del intervalo central del cruce `[cx - CROSS_HALF - 0.5, cx + CROSS_HALF + 0.5]`.

### Orden de activación (Scheduler)
- `Schedulers.ByType((TrafficLight, Vehicle), false)`  
  Primero se actualizan **todos los semáforos** y **después** el auto.  
  Evita inconsistencias del tipo “el auto decide con un estado viejo del semáforo”.

---

## API (Genie, `webapi.jl`)
- **POST** `/simulations` → crea simulación
  ```json
  {
    "Location": "/simulations/<id>",
    "lights": [{ "id":1, "pos":[x,y], "dir":"EW"|"NS", "state":"green"|"yellow"|"red" }],
    "cars":   [{ "id":2, "pos":[x,y], "vel":[vx,vy] }]
  }
