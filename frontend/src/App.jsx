import { useState, useRef, useEffect } from 'react';

export default function App() {
  // --- Estado ---
  const [location, setLocation] = useState("");
  const [cars, setCars] = useState([]);           // etapa sin autos
  const [lights, setLights] = useState([]);       // NUEVO
  const [simSpeed, setSimSpeed] = useState(10);

  const running = useRef(null);

  // Mapeo modelo→px
  const EXTENT = 25;         // ancho/alto del modelo (cuadrado)
  const SCALE_PX = 32;       // 1 unidad = 32 px
  const W = EXTENT * SCALE_PX;   // 800
  const H = EXTENT * SCALE_PX;   // 800

  useEffect(() => () => clearInterval(running.current), []);

  const setup = () => {
    fetch("http://localhost:8000/simulations", {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({})
    })
      .then(r => r.json())
      .then(data => {
        setLocation(data.Location);
        setCars(data.cars || []);
        setLights(data.lights || []);
      });
  };

  const tick = () => {
    fetch("http://localhost:8000" + location)
      .then(r => r.json())
      .then(data => {
        setCars(data.cars || []);
        setLights(data.lights || []);
      });
  };

  const handleStart = () => {
    if (!location) return;
    clearInterval(running.current);
    running.current = setInterval(tick, 1000 / simSpeed);
  };

  const handleStop = () => clearInterval(running.current);

  const handleSpeedChange = (e) => {
    const v = Number(e.target.value);
    setSimSpeed(v);
    if (running.current) {
      clearInterval(running.current);
      running.current = setInterval(tick, 1000 / v);
    }
  };

  const colorMap = (state) => {
    if (state === "green")  return "limegreen";
    if (state === "yellow") return "gold";
    return "crimson"; // red
  };

  // Calles: dos bandas que se cruzan en el centro
  const ROAD_W = 80; // px
  const centerX = W / 2 - ROAD_W / 2;
  const centerY = H / 2 - ROAD_W / 2;

  return (
    <div style={{ fontFamily: 'system-ui, sans-serif', padding: 16 }}>
      <h2>Cruce con semáforos (sin autos)</h2>
      <div style={{ display: 'flex', gap: 12, alignItems: 'center', marginBottom: 12 }}>
        <button onClick={setup}>Setup</button>
        <button onClick={handleStart} disabled={!location}>Start</button>
        <button onClick={handleStop}>Stop</button>
        <label style={{ marginLeft: 16 }}>
          Velocidad (Hz):&nbsp;
          <input type="number" min={1} max={60} value={simSpeed} onChange={handleSpeedChange} style={{ width: 64 }} />
        </label>
      </div>

      <svg width={W} height={H} xmlns="http://www.w3.org/2000/svg" style={{ backgroundColor: "white", borderRadius: 8 }}>
        {/* Calles: horizontal y vertical */}
        <rect x="0" y={centerY} width={W} height={ROAD_W} fill="#555" opacity="0.9" />
        <rect x={centerX} y="0" width={ROAD_W} height={H} fill="#555" opacity="0.9" />

        {/* Semáforos */}
        {lights.map(l => (
          <g key={l.id}>
            <circle
              cx={l.pos[0] * SCALE_PX}
              cy={l.pos[1] * SCALE_PX}
              r="10"
              fill={colorMap(l.state)}
              stroke="black"
              strokeWidth="1"
            />
            <text
              x={l.pos[0] * SCALE_PX + 14}
              y={l.pos[1] * SCALE_PX + 4}
              fontSize="12"
              fill="#222"
            >
              {l.dir}
            </text>
          </g>
        ))}

        {/* (Opcional) autos: etapa sin autos */}
        {cars.map(car => (
          <image
            key={car.id}
            x={car.pos[0] * SCALE_PX}
            y={car.pos[1] * SCALE_PX}
            width={32}
            href="./racing-car.png"
          />
        ))}
      </svg>

      <p style={{ maxWidth: 800, color: '#444', marginTop: 12 }}>
        Ciclo de cada semáforo (ticks): <b>Verde 10</b>, <b>Amarillo 4</b>, <b>Rojo 14</b> (total 28). EW y NS están sincronizados por desfase.
      </p>
    </div>
  );
}
