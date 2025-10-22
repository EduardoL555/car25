import { useState, useRef, useEffect } from 'react';
import {
  LineChart, Line, XAxis, YAxis, CartesianGrid, Tooltip, ResponsiveContainer
} from 'recharts';

export default function App() {
  // --- Estado del modelo y UI ---
  let [location, setLocation] = useState("");
  let [cars, setCars] = useState([]);
  let [simSpeed, setSimSpeed] = useState(10);

  // --- Timer y refs ---
  const running = useRef(null);

  // --- Constantes de mapeo y dominio ---
  const EXTENT_X = 25;    // ancho del espacio en unidades del modelo (Julia)
  const SCALE_PX = 32;    // 1 unidad del modelo => 32 px (para render)
  const BLUE_ID  = 1;     // id del carro azul

  // --- Serie de velocidad del carro azul ---
  const [speedData, setSpeedData] = useState([]);  // [{ n, speedPxPerSec }]
  const sampleIndexRef = useRef(0);
  const prevXRef = useRef(null); // última X (en unidades del modelo) para id=1

  // Limpieza de intervalo al desmontar
  useEffect(() => {
    return () => clearInterval(running.current);
  }, []);

  // Setup: crea simulación en el backend y obtiene estado inicial
  let setup = () => {
    fetch("http://localhost:8000/simulations", {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({})
    })
      .then(resp => resp.json())
      .then(data => {
        setLocation(data["Location"]);
        setCars(data["cars"]);
        // Reset de la serie al reiniciar simulación
        setSpeedData([]);
        sampleIndexRef.current = 0;
        prevXRef.current = null;

        // Si ya viene el azul, inicializamos prevX
        const blue = (data["cars"] || []).find(c => c.id === BLUE_ID);
        if (blue && blue.pos && blue.pos.length > 0) {
          prevXRef.current = blue.pos[0];
        }
      });
  };

  // Start: empieza el pull al backend a simSpeed Hz
  const handleStart = () => {
    if (!location) return; // guard: exige Setup primero
    clearInterval(running.current);
    running.current = setInterval(() => {
      fetch("http://localhost:8000" + location)
        .then(res => res.json())
        .then(data => {
          setCars(data["cars"]);
          // Actualiza velocidad del azul
          const blue = (data["cars"] || []).find(c => c.id === BLUE_ID);
          if (blue && blue.pos && blue.pos.length > 0) {
            const currX = blue.pos[0]; // en unidades del modelo
            if (prevXRef.current != null) {
              // delta X con corrección por wrap-around
              let dx = currX - prevXRef.current;
              // Si hubo envoltura (el espacio es periódico)
              if (dx < -EXTENT_X / 2) dx += EXTENT_X;
              if (dx >  EXTENT_X / 2) dx -= EXTENT_X;

              // Velocidad en px/seg:
              // dx [unidades/tick] * SCALE_PX [px/unidad] * simSpeed [ticks/seg]
              const speedPxPerSec = dx * SCALE_PX * simSpeed;

              const n = ++sampleIndexRef.current;
              setSpeedData(prev => {
                const next = [...prev, { n, speed: speedPxPerSec }];
                // Limita tamaño para no crecer infinito (ej. últimos 200 puntos)
                if (next.length > 200) next.shift();
                return next;
              });
            }
            prevXRef.current = currX;
          }
        });
    }, 1000 / simSpeed);
  };

  const handleStop = () => {
    clearInterval(running.current);
  };

  const handleSimSpeedSliderChange = (event) => {
    const newValue = Number(event.target.value);
    // Si cambia la velocidad, reinicia el intervalo para aplicar el nuevo Hz
    setSimSpeed(newValue);
    if (running.current) {
      clearInterval(running.current);
      handleStart();
    }
  };

  return (
    <div style={{ fontFamily: 'system-ui, sans-serif', padding: 16 }}>
      <h2>Simulación de Tráfico</h2>

      <div style={{ display: 'flex', gap: 12, alignItems: 'center', marginBottom: 12 }}>
        <button onClick={setup}>Setup</button>
        <button onClick={handleStart} disabled={!location}>Start</button>
        <button onClick={handleStop}>Stop</button>

        <label style={{ marginLeft: 16 }}>
          Velocidad (Hz):&nbsp;
          <input
            type="number"
            min={1}
            max={60}
            step={1}
            value={simSpeed}
            onChange={handleSimSpeedSliderChange}
            style={{ width: 64 }}
          />
        </label>
      </div>

      {/* Pista / carretera */}
      <svg width="800" height="500" xmlns="http://www.w3.org/2000/svg" style={{ backgroundColor: "white", borderRadius: 8, boxShadow: '0 0 8px rgba(0,0,0,0.1)' }}>
        <rect x={0} y={200} width={800} height={80} style={{ fill: "darkgray" }}></rect>
        {/* Autos */}
        {cars.map(car => (
          <image
            key={car.id}
            id={car.id}
            x={car.pos[0] * SCALE_PX}
            y={240}
            width={32}
            href={car.id === 1 ? "./dark-racing-car.png" : "./racing-car.png"}
            alt={car.id === 1 ? "carro-azul" : "carro"}
          />
        ))}
      </svg>

      {/* Gráfico de velocidad del carro azul */}
      <div style={{ width: 800, height: 220, marginTop: 18 }}>
        <ResponsiveContainer>
          <LineChart data={speedData} margin={{ top: 10, right: 20, bottom: 10, left: 0 }}>
            <CartesianGrid strokeDasharray="3 3" />
            <XAxis dataKey="n" tickCount={6} label={{ value: 'muestra', position: 'insideBottomRight', offset: -5 }} />
            <YAxis tickCount={6} label={{ value: 'px/seg', angle: -90, position: 'insideLeft' }} />
            <Tooltip formatter={(v) => `${v.toFixed(1)} px/s`} labelFormatter={(l) => `muestra ${l}`} />
            <Line type="monotone" dataKey="speed" dot={false} strokeWidth={2} />
          </LineChart>
        </ResponsiveContainer>
      </div>

    </div>
  );
}
