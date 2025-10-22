# Cruce con semáforos + múltiples autos (Agents.jl + Genie + React)

Pequeño simulador de tráfico con dos calles que se cruzan, dos semáforos sincronizados y varios autos circulando en ambos sentidos. Los autos aceleran/desaceleran, **solo frenan cerca del semáforo** cuando toca, **no se empalman** (mantienen una distancia mínima) y, tras cruzar, siguen su camino normal.

---

## ⚙️ ¿Qué hay aquí?

- **Backend (Julia + Genie)**
  - Expone una API muy simple para crear una simulación y avanzar un “tick”.
  - Serializa semáforos y autos en JSON (formato plano).
- **Modelo (Agents.jl)**
  - Tipos de agente: `TrafficLight` y `Vehicle`.
  - Ciclo México del semáforo: Verde 10, Amarillo 4, Rojo 14 (total 28).
  - Lógica de auto con aceleración/frenado suave, respeto a luz y distancia con el de adelante.
- **Frontend (React)**
  - Dibuja el cruce, los semáforos y los autos (ícono pequeño).
  - Controles de `Setup`, `Start`, `Stop`, Hz de muestreo y `Autos por calle (3/5/7)`.
  - Panel de métricas (promedio de velocidades) y bitácora para capturas.

---

## 🧭 Arquitectura (rápido)

- `simple.jl` → modelo Agents.jl (espacio continuo, agentes, reglas).
- `webapi.jl` → servidor Genie (POST /simulations, GET /simulations/:id).
- `App.jsx` → UI en React (SVG + controles + métricas).

---

## 📁 Archivos clave

- **`simple.jl`**  
  Define:
  - `@agent TrafficLight`: `dir`, `tick`.  
  - `@agent Vehicle`: `dir`, `speed`, `target`.  
  - Lógica de:
    - semáforo (ciclo 10/4/14).
    - auto (zona de frenado cerca del semáforo, distancia de seguridad, wrap-around).
  - Init del modelo con `StandardABM(Union{TrafficLight, Vehicle}, …; scheduler = Schedulers.ByType((TrafficLight, Vehicle), false))`.
  - Propiedades en `model`: `cx`, `cy`, `stop_x_ew`, `stop_y_ns`, `Lx`, `Ly`.

- **`webapi.jl`**  
  - Diccionario global `sim_store` para instancias.
  - `POST /simulations` (acepta `{"cars_per_lane": 3|5|7}`).
  - `GET /simulations/:id` (avanza 1 tick).
  - Devuelve `cars`, `lights` y `metrics` (promedios por calle).

- **`App.jsx`**  
  - SVG de 25×25 celdas (escalado a pixeles).
  - Ícono de autos reducido (e.g. `car_small.png`), los de NS rotados -90°.
  - Panel de métricas, bitácora y selector 3/5/7.

---

## 🧩 Requisitos

- **Julia** (1.8+ recomendado)
- Paquetes Julia: `Agents`, `StaticArrays`, `Genie`
- **Node.js** (para el front)
- Un ícono simple de auto, por ejemplo `public/car_small.png` (16–24 px aprox.)

---

## ▶️ Cómo correr (paso a paso)

1) **Backend (Julia)**
   - Abre `webapi.jl` en VS Code o REPL.
   - Ejecuta el archivo. Arranca en `http://localhost:8000`.

2) **Frontend (React)**
   - En la carpeta del front:
     
         npm install
         npm run dev
     
   - Abre la URL que te dé Vite/React en tu navegador.

3) **Flujo en la UI**
   - Elige **Autos por calle** (3/5/7).
   - Pulsa **Setup** (se crea una nueva simulación).
   - Pulsa **Start** (comienza a pedir ticks al backend).
   - Ajusta **Hz** si quieres. **Stop** para pausar.

---

## 🔌 API (formato)

- **Crear simulación**
  
      POST /simulations
      Body: { "cars_per_lane": 3 }   // o 5 o 7

  **Respuesta** (ejemplo):
  
      {
        "Location": "/simulations/0b1c-...-id",
        "lights": [
          { "id":1, "pos":[12.5,12.5], "dir":"EW", "state":"green" },
          ...
        ],
        "cars": [
          { "id":3, "pos":[x,y], "vel":[vx,vy], "dir":"EW"|"NS", "speed":0.53, "target":0.82 },
          ...
        ],
        "metrics": {
          "avg_speed_ew": 0.47,
          "avg_speed_ns": 0.51,
          "count_ew": 3,
          "count_ns": 3
        }
      }

- **Avanzar simulación un tick**
  
      GET /simulations/:id

  **Respuesta**: Igual que arriba, sin `Location`.

---

## 🧠 Reglas clave del modelo

- **Frenado cerca del semáforo**  
  Usamos una `STOP_ZONE` (p. ej. 3.0 unidades). Un auto **solo frena** si:
  - está **dentro** de esa zona, y
  - la luz de su vía **no está en verde**.

  Lejos del cruce, acelera hacia su `target`.

- **Distancia de seguridad (no empalme)**  
  Se busca el auto de adelante en la misma vía (considerando el mundo cerrado: “wrap-around”).  
  Si el hueco es chico, se limita la velocidad para respetar un `SAFE_GAP`.

- **Aceleración suave**  
  `ACC` y `DEC` controlan qué tanto sube/baja la velocidad por tick.

- **Orden de activación**  
  `ByType((TrafficLight, Vehicle), false)` → primero semáforos, luego autos.  
  Así el auto decide con el **estado correcto** del semáforo.

---

## 📊 Visualizaciones y métricas

- **Instantáneo**: promedio de velocidades por calle (EW/NS) en el tick actual.
- **Acumulado**: promedio a lo largo del escenario (se va actualizando).
- **Bitácora**: botón “Guardar muestra” para registrar resultados de 3, 5 y 7.

Sugerencia: corre ~10–30 segundos cada escenario y guarda la muestra.

---

## 🛠️ Parámetros útiles (los puedes “tunear”)

- `ACC = 0.05`, `DEC = 0.10` → aceleración / frenado por tick.
- `STOP_ZONE = 3.0` → qué tan lejos empieza a frenar con amarillo/rojo.
- `SAFE_GAP = 0.35` → distancia mínima entre autos.
- `LOOKAHEAD = 3.5` → alcance para detectar el de adelante.
- `DT = 0.4` → paso de integración (afecta “suavidad” del movimiento).
- Velocidad objetivo inicial `target ∈ [0.4, 0.9]`; arranque `speed0 ~ U(0, target)`.
- Mundo: `(25,25)` con `periodic=true` (toro).

---

## 🧪 Cómo recolectar 3/5/7 autos por calle

1. Selecciona `3` → **Setup** → **Start** → espera unos segundos → **Guardar muestra**.
2. Cambia a `5` → **Setup** → **Start** → espera → **Guardar muestra**.
3. Cambia a `7` → **Setup** → **Start** → espera → **Guardar muestra**.

La tabla de la UI te queda con tres filas: hora, autos/calle, promedio EW, promedio NS, ticks.

---

## 🧯 Troubleshooting (errores típicos)

- **“invalid redefinition of constant Car”**  
  Ya tenías un tipo `Car` en el REPL. Reinicia el REPL o usa otro nombre (`Vehicle`).

- **“cannot assign to imported variable Base.instances”**  
  Cambiamos el map global de simulaciones a `sim_store` (evita choque con `Base.instances`).

- **`KeyError: key :space not found`**  
  No uses `model.space` como propiedad.  
  Guardamos `Lx`/`Ly` en propiedades del modelo (`Float64`) y usamos `model.Lx`, `model.Ly`.

- **`MethodError: forward_gap(::Float64, ::Float64, ::Int64)`**  
  Asegúrate de que `forward_gap` acepte `Real` y de guardar `Lx/Ly` como `Float64`.

- **Autos frenan “desde el principio”**  
  Aumenta `STOP_ZONE` y revisa que la condición de frenado sólo aplique si `0 < dist_to_stop <= STOP_ZONE`.

---

## ✅ Definition of Done (DoD)

- [x] Dos semáforos sincronizados (ciclo 10/4/14).
- [x] Múltiples autos por calle (3/5/7), posiciones aleatorias fuera del cruce.
- [x] Autos **solo frenan** cerca del semáforo en amarillo/rojo.
- [x] **No se empalman** (distancia mínima entre vehículos).
- [x] API lista (POST/GET), frontend funcionando con métricas y bitácora.

---

## 🚀 Siguientes pasos (ideas)

- Dos carriles por sentido y rebases simples.
- Perfiles de conductor (prudente/agresivo) con distintos ACC/DEC/target.
- Exportar métricas a CSV desde el backend.
- Gráficas en el front (línea/barras) para comparar escenarios.

---