import { useState, useRef, useEffect } from 'react';

export default function App() {
  // Estado
  const [location, setLocation] = useState("");
  const [cars, setCars] = useState([]);
  const [lights, setLights] = useState([]);
  const [simSpeed, setSimSpeed] = useState(10);
  const [carsPerLane, setCarsPerLane] = useState(3);
  const [metrics, setMetrics] = useState({ avg_speed_ew: 0, avg_speed_ns: 0, count_ew: 0, count_ns: 0 });

  const [samples, setSamples] = useState(0);
  const [runAvgEW, setRunAvgEW] = useState(0);
  const [runAvgNS, setRunAvgNS] = useState(0);

  const [captures, setCaptures] = useState([]);

  const running = useRef(null);

  const EXTENT = 25;
  const SCALE_PX = 32;
  const W = EXTENT * SCALE_PX;
  const H = EXTENT * SCALE_PX;
  const ROAD_W = 80;
  const size = 20;

  useEffect(() => () => clearInterval(running.current), []);

  const colorMap = (state) => (state === "green" ? "limegreen" : state === "yellow" ? "gold" : "crimson");

  const setup = () => {
    fetch("http://localhost:8000/simulations", {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ cars_per_lane: carsPerLane })
    })
      .then(r => r.json())
      .then(data => {
        setLocation(data.Location);
        setCars(data.cars || []);
        setLights(data.lights || []);
        setMetrics(data.metrics || { avg_speed_ew: 0, avg_speed_ns: 0, count_ew: 0, count_ns: 0 });
        setSamples(0);
        setRunAvgEW(0);
        setRunAvgNS(0);
      });
  };

  const tick = () => {
    fetch("http://localhost:8000" + location)
      .then(r => r.json())
      .then(data => {
        setCars(data.cars || []);
        setLights(data.lights || []);
        const m = data.metrics || { avg_speed_ew: 0, avg_speed_ns: 0, count_ew: 0, count_ns: 0 };
        setMetrics(m);
        setSamples(n => {
          const nn = n + 1;
          setRunAvgEW(prev => prev + (m.avg_speed_ew - prev) / nn);
          setRunAvgNS(prev => prev + (m.avg_speed_ns - prev) / nn);
          return nn;
        });
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

  const handleCarsPerLaneChange = (e) => setCarsPerLane(Number(e.target.value));

  const captureNow = () => {
    setCaptures(prev => [...prev, {
      when: new Date().toLocaleTimeString(),
      carsPerLane,
      avgEW: runAvgEW,
      avgNS: runAvgNS,
      ticks: samples
    }]);
  };

  const centerX = W / 2 - ROAD_W / 2;
  const centerY = H / 2 - ROAD_W / 2;

  return (
    <div style={{ fontFamily: 'system-ui, sans-serif', padding: 16 }}>
      <h2>Cruce con semáforos + múltiples autos (EW & NS)</h2>

      <div style={{ display: 'flex', gap: 12, alignItems: 'center', marginBottom: 12, flexWrap: 'wrap' }}>
        <button onClick={setup}>Setup</button>
        <button onClick={handleStart} disabled={!location}>Start</button>
        <button onClick={handleStop}>Stop</button>

        <label style={{ marginLeft: 8 }}>
          Hz:&nbsp;
          <input type="number" min={1} max={60} value={simSpeed} onChange={handleSpeedChange} style={{ width: 64 }} />
        </label>

        <label style={{ marginLeft: 8 }}>
          Autos por calle:&nbsp;
          <select value={carsPerLane} onChange={handleCarsPerLaneChange}>
            <option value={3}>3</option>
            <option value={5}>5</option>
            <option value={7}>7</option>
          </select>
        </label>

        <button onClick={captureNow} disabled={!samples}>Guardar muestra</button>
      </div>

      <svg width={W} height={H} xmlns="http://www.w3.org/2000/svg" style={{ backgroundColor: "white", borderRadius: 8 }}>
        {/* Calles */}
        <rect x="0" y={centerY} width={W} height={ROAD_W} fill="#555" opacity="0.9" />
        <rect x={centerX} y="0" width={ROAD_W} height={H} fill="#555" opacity="0.9" />

        {/* Semáforos */}
        {lights.map(l => (
          <g key={`L-${l.id}`}>
            <circle
              cx={l.pos[0] * SCALE_PX}
              cy={l.pos[1] * SCALE_PX}
              r="10"
              fill={colorMap(l.state)}
              stroke="black"
              strokeWidth="1"
            />
            <text x={l.pos[0] * SCALE_PX + 14} y={l.pos[1] * SCALE_PX + 4} fontSize="12" fill="#222">
              {l.dir}
            </text>
          </g>
        ))}

        {/* Autos pequeños, rotando los de NS */}
        {cars.map(car => {
          const x = car.pos[0] * SCALE_PX;
          const y = car.pos[1] * SCALE_PX;
          const half = size / 2;
          const href = "./racing-car.png";
          const isNS = car.dir === "NS";
          // centramos el icono y, si NS, lo rotamos -90° alrededor de su centro (x, y)
          const common = { href, width: size, height: size, x: x - half, y: y - half };
          return isNS
            ? <image key={`C-${car.id}`} {...common} transform={`rotate(-90 ${x} ${y})`} />
            : <image key={`C-${car.id}`} {...common} />;
        })}
      </svg>

      {/* Panel de métricas */}
      <div style={{ marginTop: 12, display: 'flex', gap: 24, flexWrap: 'wrap' }}>
        <div>
          <h4 style={{ margin: '8px 0' }}>Promedios instantáneos (modelo)</h4>
          <ul style={{ margin: 0 }}>
            <li>EW: <b>{metrics.avg_speed_ew.toFixed(3)}</b> (n={metrics.count_ew})</li>
            <li>NS: <b>{metrics.avg_speed_ns.toFixed(3)}</b> (n={metrics.count_ns})</li>
          </ul>
        </div>
        <div>
          <h4 style={{ margin: '8px 0' }}>Promedios acumulados (escenario actual)</h4>
          <ul style={{ margin: 0 }}>
            <li>EW: <b>{runAvgEW.toFixed(3)}</b></li>
            <li>NS: <b>{runAvgNS.toFixed(3)}</b></li>
            <li>ticks: {samples}</li>
          </ul>
        </div>
        <div>
          <h4 style={{ margin: '8px 0' }}>Bitácora (para 3, 5 y 7)</h4>
          <table style={{ borderCollapse: 'collapse', minWidth: 360 }}>
            <thead>
              <tr>
                <th style={{ borderBottom: '1px solid #ccc', textAlign: 'left' }}>Hora</th>
                <th style={{ borderBottom: '1px solid #ccc', textAlign: 'right' }}>Autos/Calle</th>
                <th style={{ borderBottom: '1px solid #ccc', textAlign: 'right' }}>EW</th>
                <th style={{ borderBottom: '1px solid #ccc', textAlign: 'right' }}>NS</th>
                <th style={{ borderBottom: '1px solid #ccc', textAlign: 'right' }}>Ticks</th>
              </tr>
            </thead>
            <tbody>
              {captures.map((c, i) => (
                <tr key={i}>
                  <td style={{ borderBottom: '1px solid #eee' }}>{c.when}</td>
                  <td style={{ borderBottom: '1px solid #eee', textAlign: 'right' }}>{c.carsPerLane}</td>
                  <td style={{ borderBottom: '1px solid #eee', textAlign: 'right' }}>{c.avgEW.toFixed(3)}</td>
                  <td style={{ borderBottom: '1px solid #eee', textAlign: 'right' }}>{c.avgNS.toFixed(3)}</td>
                  <td style={{ borderBottom: '1px solid #eee', textAlign: 'right' }}>{c.ticks}</td>
                </tr>
              ))}
            </tbody>
          </table>
          <p style={{ marginTop: 6, color: '#666' }}>
            Corre 3 escenarios: <b>3</b>, <b>5</b> y <b>7</b> autos/calle. En cada uno, deja correr unos segundos y pulsa <i>Guardar muestra</i>.
          </p>
        </div>
      </div>
    </div>
  );
}
