## Parte 2 – Pregunta 3: Completar simulación con múltiples autos y monitoreo

### Cambios clave
- Soporte de **múltiples autos por vía** (horizontal **EW** y vertical **NS**) con `initialize_model((25,25); n_ew, n_ns)`.
- **Car-following** básico: respeta **semáforo** (verde/amarillo/rojo) y **distancia mínima** entre autos, con **aceleración** (`ACC=0.05`) y **frenado** (`DEC=0.10`).
- **Spawns aleatorios** fuera del cruce y **separación mínima** inicial.
- **Ícono compacto** para autos (círculos) que permite mayor densidad en UI.
- **Monitoreo**: el backend reporta `metrics.avg_units_per_tick` (promedio por tick) y `dt`; el frontend muestra **px/s** y **unidades/tick**.

### Parámetros principales
- `MIN_GAP=0.8`, `ACC=0.05`, `DEC=0.10`, `VMAX=1.0`, `DT=0.4`.
- Semáforo: ciclo México (10 **verde**, 4 **amarillo**, 14 **rojo**).

### Cómo medir
1. Configurar `Autos EW` y `Autos NS` a **3**, presionar `Setup` → `Start`, esperar, y registrar **velocidad promedio**.
2. Repetir con **5** y **7**.
3. Nota: la UI se ve mejor con ≤5, pero con 7 también se calcula la métrica.

### Reflexión individual
Durante la ampliación del modelo apareció el reto de **ordenar las actualizaciones** para evitar decisiones con estados desfasados. Al usar `Schedulers.ByType((TrafficLight, Vehicle), false)` me aseguré de evaluar antes los semáforos y después a los autos, lo que redujo inconsistencias (por ejemplo, un auto que “se come” un alto). También ajusté la dinámica de los vehículos con **aceleración y frenado** para evitar cambios bruscos, y fijé una **distancia mínima** con una regla simple de car-following. A nivel de visualización, sustituir el ícono por círculos compactos facilitó ver más autos sin saturar. Finalmente, expuse una **métrica estable** (velocidad promedio en unidades/tick) para comparar escenarios con 3, 5 y 7 autos por calle, manteniendo separada la conversión visual (px/s) en el frontend.
