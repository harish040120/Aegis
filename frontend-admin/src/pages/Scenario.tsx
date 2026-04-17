import React, { useEffect, useMemo, useState } from 'react';
import {
  Activity,
  CloudRain,
  FileJson,
  MapPin,
  Play,
  RefreshCw,
  ShieldAlert,
  SlidersHorizontal,
  UserCircle,
  Zap
} from 'lucide-react';
import { apiGet, apiPost } from '../services/api';

type Worker = { worker_id: string; name: string; zone: string };

type ParamState = {
  rain_override: number;
  aqi_override: number;
  earnings_today: number;
  hours_worked_today: number;
  traffic_index: number;
  orders_last_hour: number;
};

type ParamMeta = Record<string, { min: number; max: number }>;

  type AlertItem = {
    alert_id: number;
    type: string;
    severity: string;
    metric_value: number | null;
    threshold_value: number | null;
    claimed: boolean;
    created_at: string;
    expires_at: string;
    status: string;
  };

const scenarioPresets = [
  { key: 'normal', label: 'Normal', tag: 'Baseline', rain: 0, aqi: 45, earnings: 1800, hours: 7.5 },
  { key: 'heavy_rain', label: 'Heavy Rain', tag: 'Scenario Gate', rain: 52, aqi: 20, earnings: 1065, hours: 4.0 },
  { key: 'severe_flood', label: 'Severe Flood', tag: 'Dual Gate', rain: 80, aqi: 15, earnings: 750, hours: 1.5 },
  { key: 'hazardous_aqi', label: 'Hazardous AQI', tag: 'Scenario Gate', rain: 0, aqi: 185, earnings: 830, hours: 3.5 },
  { key: 'location_update', label: 'Location Update', tag: 'Location', rain: 0, aqi: 45, earnings: 220, hours: 0.5 }
];

const defaultParams: ParamState = {
  rain_override: 0,
  aqi_override: 0,
  earnings_today: 1500,
  hours_worked_today: 6,
  traffic_index: 45,
  orders_last_hour: 180
};

const defaultMeta: ParamMeta = {
  rain_override: { min: 0, max: 100 },
  aqi_override: { min: 0, max: 500 },
  earnings_today: { min: 0, max: 5000 },
  hours_worked_today: { min: 0, max: 24 },
  traffic_index: { min: 0, max: 100 },
  orders_last_hour: { min: 0, max: 500 }
};

export const Scenario: React.FC = () => {
  const [workers, setWorkers] = useState<Worker[]>([]);
  const [selectedWorker, setSelectedWorker] = useState('W001');
  const [selectedScenario, setSelectedScenario] = useState('normal');
  const [params, setParams] = useState<ParamState>(defaultParams);
  const [paramMeta, setParamMeta] = useState<ParamMeta>(defaultMeta);
  const [analysis, setAnalysis] = useState<any>(null);
  const [analysisJson, setAnalysisJson] = useState('');
  const [requestJson, setRequestJson] = useState('');
  const [loading, setLoading] = useState(false);
  const [payoutRef, setPayoutRef] = useState<string | null>(null);
  const [alerts, setAlerts] = useState<AlertItem[]>([]);
  const [dualGate, setDualGate] = useState<any>(null);
  const [locationUpdate, setLocationUpdate] = useState<any>(null);
  const [error, setError] = useState<string | null>(null);
  const [lat, setLat] = useState(13.0827);
  const [lon, setLon] = useState(80.2707);
  const [lastUpdated, setLastUpdated] = useState<string>('');

  const selectedWorkerInfo = useMemo(
    () => workers.find((w) => w.worker_id === selectedWorker),
    [workers, selectedWorker]
  );

  const setParamsFromHub = (data: any) => {
    const next: ParamState = {
      rain_override: data?.rain_override?.value ?? params.rain_override,
      aqi_override: data?.aqi_override?.value ?? params.aqi_override,
      earnings_today: data?.earnings_today?.value ?? params.earnings_today,
      hours_worked_today: data?.hours_worked_today?.value ?? params.hours_worked_today,
      traffic_index: data?.traffic_index?.value ?? params.traffic_index,
      orders_last_hour: data?.orders_last_hour?.value ?? params.orders_last_hour
    };
    setParams(next);
  };

  const setMetaFromHub = (data: any) => {
    const meta: ParamMeta = { ...paramMeta };
    Object.entries(data || {}).forEach(([key, value]: any) => {
      meta[key] = { min: value?.min ?? meta[key]?.min ?? 0, max: value?.max ?? meta[key]?.max ?? 100 };
    });
    setParamMeta(meta);
  };

  const loadWorkers = async () => {
    const data = await apiGet('/api/workers', 'HUB');
    setWorkers(data || []);
  };

  const loadParams = async () => {
    const data = await apiGet('/api/params', 'HUB');
    setMetaFromHub(data);
    setParamsFromHub(data);
  };

  const loadAlerts = async (workerId: string) => {
    const data = await apiGet(`/api/v1/alerts/${workerId}`);
    setAlerts(data || []);
  };

  const loadDualGate = async (workerId: string) => {
    const data = await apiGet(`/api/dual-gates?worker_id=${workerId}`, 'HUB');
    setDualGate(data || null);
  };

  useEffect(() => {
    loadWorkers();
    loadParams();
  }, []);

  useEffect(() => {
    loadAlerts(selectedWorker);
    loadDualGate(selectedWorker);
  }, [selectedWorker]);

  const applyScenario = async (scenario_key: string) => {
    setSelectedScenario(scenario_key);
    const data = await apiPost('/api/scenario', { scenario_key, worker_id: selectedWorker }, 'HUB');
    if (data?.params) {
      setParamsFromHub(data.params);
    }
    if (data?.location?.updated) {
      setLocationUpdate(data.location);
      setLat(data.location.lat);
      setLon(data.location.lon);
    } else {
      setLocationUpdate(null);
    }
    await apiPost('/api/v1/analyze', { worker_id: selectedWorker, lat, lon });
    await loadAlerts(selectedWorker);
    await loadDualGate(selectedWorker);
  };

  const updateParam = async (name: keyof ParamState, value: number) => {
    const numericValue = Number(value);
    setParams((p) => ({ ...p, [name]: numericValue }));
    await apiPost('/api/params', { name, value: numericValue }, 'HUB');
    await loadAlerts(selectedWorker);
    await loadDualGate(selectedWorker);
  };

  const runAnalysis = async () => {
    setLoading(true);
    setPayoutRef(null);
    setError(null);
    const payload = { worker_id: selectedWorker, lat, lon };
    setRequestJson(JSON.stringify(payload, null, 2));
    try {
      const data = await apiPost('/api/v1/analyze', payload);
      setAnalysis(data);
      setAnalysisJson(JSON.stringify(data, null, 2));
      setLastUpdated(new Date().toLocaleTimeString());
      await loadAlerts(selectedWorker);
      await loadDualGate(selectedWorker);
    } catch (err: any) {
      setError(err?.message || 'Analysis failed');
      setAnalysis(null);
      setAnalysisJson('');
    } finally {
      setLoading(false);
    }
  };

  const fireRazorpay = async () => {
    if (!analysis?.payout?.payout_id) return;
    const worker = workers.find((w) => w.worker_id === selectedWorker);
    const nameSeed = worker?.name?.split(' ')[0]?.toLowerCase() || selectedWorker.toLowerCase();
    const res = await apiPost('/api/v1/razorpay/payout', {
      payout_id: analysis.payout.payout_id,
      worker_id: selectedWorker,
      amount: analysis.payout.amount,
      upi_id: `${nameSeed}@upi`
    });
    setPayoutRef(res?.payment_ref || null);
  };

  const decision = useMemo(() => {
    if (!analysis) return null;
    return {
      riskScore: analysis.analytics?.risk?.score,
      riskLevel: analysis.analytics?.risk?.level,
      fraudScore: analysis.analytics?.fraud?.score,
      fraudLevel: analysis.analytics?.fraud?.level,
      incomeDrop: analysis.analytics?.income?.drop,
      incomeSeverity: analysis.analytics?.income?.severity,
      status: analysis.status,
      payout: analysis.payout?.amount,
      trigger: analysis.payout?.trigger
    };
  }, [analysis]);

  return (
    <div className="flex flex-col gap-6 animate-in fade-in duration-500 max-w-[1600px] mx-auto">
      <div className="flex items-center justify-between">
        <div>
          <h1 className="text-2xl font-bold text-[var(--deep-navy)] tracking-tight uppercase">Scenario Control</h1>
          <p className="text-[11px] font-semibold text-[var(--text-muted)] uppercase tracking-wider mt-1">Simulated Disruption Engine</p>
        </div>
        <div className="flex items-center gap-3">
          <span className="text-[10px] font-bold text-slate-400 uppercase tracking-widest">Last Run: {lastUpdated || '--'}</span>
           <button
             onClick={runAnalysis}
             className="px-4 py-2 bg-slate-200 text-slate-500 rounded text-[10px] font-black uppercase tracking-widest flex items-center gap-2 cursor-not-allowed"
             disabled
           >
             <Play size={14} /> Auto-Analysis Enabled
           </button>
        </div>
      </div>

      <div className="grid grid-cols-1 xl:grid-cols-3 gap-6">
        <div className="xl:col-span-2 flex flex-col gap-6">
          <div className="metric-card">
            <div className="flex items-center justify-between mb-4">
              <div className="flex items-center gap-2">
                <UserCircle size={16} className="text-[var(--gw-blue)]" />
                <h3 className="text-[11px] font-bold text-[var(--text-muted)] uppercase tracking-widest">Step 1 - Worker and Location</h3>
              </div>
              <span className="text-[10px] font-bold text-slate-400 uppercase tracking-widest">Worker Context</span>
            </div>
            <div className="grid grid-cols-1 md:grid-cols-3 gap-4">
              <div className="md:col-span-2">
                <label className="text-[10px] font-bold uppercase tracking-widest text-slate-400">Worker</label>
                <select
                  value={selectedWorker}
                  onChange={(e) => setSelectedWorker(e.target.value)}
                  className="w-full border border-[var(--border-gray)] rounded px-3 py-2 text-sm mt-2"
                >
                  {workers.map((w) => (
                    <option key={w.worker_id} value={w.worker_id}>
                      {w.worker_id} - {w.name}
                    </option>
                  ))}
                </select>
                <div className="mt-3 text-[11px] font-bold text-[var(--deep-navy)]">
                  Zone: <span className="text-slate-500">{selectedWorkerInfo?.zone || 'Unknown'}</span>
                </div>
              </div>
              <div>
                <label className="text-[10px] font-bold uppercase tracking-widest text-slate-400">GPS</label>
                <div className="mt-2 flex flex-col gap-2">
                  <div className="flex items-center gap-2">
                    <MapPin size={14} className="text-slate-400" />
                    <input
                      type="number"
                      step="0.0001"
                      value={lat}
                      onChange={(e) => setLat(parseFloat(e.target.value))}
                      className="w-full border border-[var(--border-gray)] rounded px-2 py-1 text-xs"
                    />
                  </div>
                  <div className="flex items-center gap-2">
                    <MapPin size={14} className="text-slate-400" />
                    <input
                      type="number"
                      step="0.0001"
                      value={lon}
                      onChange={(e) => setLon(parseFloat(e.target.value))}
                      className="w-full border border-[var(--border-gray)] rounded px-2 py-1 text-xs"
                    />
                  </div>
                </div>
              </div>
            </div>
          </div>

          <div className="metric-card">
            <div className="flex items-center justify-between mb-4">
              <div className="flex items-center gap-2">
                <Zap size={16} className="text-[var(--gw-blue)]" />
                <h3 className="text-[11px] font-bold text-[var(--text-muted)] uppercase tracking-widest">Step 2 - Scenario Presets</h3>
              </div>
              <span className="text-[10px] font-bold text-slate-400 uppercase tracking-widest">Active: {selectedScenario}</span>
            </div>
            <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-3">
              {scenarioPresets.map((s) => (
                  <button
                    key={s.key}
                    onClick={() => setSelectedScenario(s.key)}
                    className={`text-left px-4 py-3 border rounded transition-all ${
                      selectedScenario === s.key
                        ? 'border-[var(--gw-blue)] bg-blue-50/40'
                        : 'border-[var(--border-gray)] bg-white hover:bg-slate-50'
                    }`}
                  >
                  <div className="flex items-center justify-between">
                    <span className="text-[11px] font-black uppercase tracking-widest text-[var(--deep-navy)]">{s.label}</span>
                    <span className="text-[9px] font-bold uppercase tracking-widest text-slate-400">{s.tag}</span>
                  </div>
                  <div className="mt-2 text-[10px] text-slate-500 uppercase tracking-widest">
                    Rain {s.rain}mm | AQI {s.aqi}
                  </div>
                  <div className="mt-1 text-[10px] text-slate-500 uppercase tracking-widest">
                    Earnings INR {s.earnings} | Hours {s.hours}
                  </div>
                </button>
                ))}
              </div>
              <div className="mt-4 flex items-center justify-between">
                <div className="text-[10px] font-bold uppercase tracking-widest text-slate-400">
                  Selected: {selectedScenario}
                </div>
                <button
                  onClick={() => applyScenario(selectedScenario)}
                  className="px-4 py-2 bg-[var(--gw-blue)] text-white rounded text-[10px] font-black uppercase tracking-widest shadow-sm"
                >
                  Trigger Scenario
                </button>
              </div>
          </div>

          <div className="metric-card">
            <div className="flex items-center justify-between mb-4">
              <div className="flex items-center gap-2">
                <SlidersHorizontal size={16} className="text-[var(--gw-blue)]" />
                <h3 className="text-[11px] font-bold text-[var(--text-muted)] uppercase tracking-widest">Step 3 - Manual Overrides</h3>
              </div>
              <span className="text-[10px] font-bold text-slate-400 uppercase tracking-widest">Live Sync</span>
            </div>
            <div className="grid grid-cols-1 md:grid-cols-2 gap-4">
              <Slider
                label="Rain Override (mm)"
                value={params.rain_override}
                min={paramMeta.rain_override.min}
                max={paramMeta.rain_override.max}
                onChange={(v) => updateParam('rain_override', v)}
                icon={CloudRain}
              />
              <Slider
                label="AQI Override"
                value={params.aqi_override}
                min={paramMeta.aqi_override.min}
                max={paramMeta.aqi_override.max}
                onChange={(v) => updateParam('aqi_override', v)}
                icon={ShieldAlert}
              />
              <Slider
                label="Orders Last Hour"
                value={params.orders_last_hour}
                min={paramMeta.orders_last_hour.min}
                max={paramMeta.orders_last_hour.max}
                onChange={(v) => updateParam('orders_last_hour', v)}
                icon={Activity}
              />
              <Slider
                label="Traffic Index"
                value={params.traffic_index}
                min={paramMeta.traffic_index.min}
                max={paramMeta.traffic_index.max}
                onChange={(v) => updateParam('traffic_index', v)}
                icon={Activity}
              />
              <Slider
                label="Earnings Today (INR)"
                value={params.earnings_today}
                min={paramMeta.earnings_today.min}
                max={paramMeta.earnings_today.max}
                onChange={(v) => updateParam('earnings_today', v)}
                icon={Activity}
              />
              <Slider
                label="Hours Worked Today"
                value={params.hours_worked_today}
                min={paramMeta.hours_worked_today.min}
                max={paramMeta.hours_worked_today.max}
                onChange={(v) => updateParam('hours_worked_today', v)}
                icon={Activity}
              />
            </div>
          </div>

          <div className="metric-card">
            <div className="flex items-center justify-between mb-4">
              <div className="flex items-center gap-2">
                <ShieldAlert size={16} className="text-[var(--gw-blue)]" />
                <h3 className="text-[11px] font-bold text-[var(--text-muted)] uppercase tracking-widest">Dual Gate Signals</h3>
              </div>
              <button
                onClick={() => loadDualGate(selectedWorker)}
                className="px-3 py-1 text-[10px] font-black uppercase tracking-widest bg-slate-100 rounded flex items-center gap-2"
              >
                <RefreshCw size={12} /> Refresh
              </button>
            </div>
            {!dualGate ? (
              <div className="text-xs text-slate-400">No scenario evaluation yet</div>
            ) : (
              <div className="grid grid-cols-1 md:grid-cols-2 gap-3">
                <div className="p-3 rounded border border-[var(--border-gray)] bg-slate-50">
                  <div className="text-[10px] font-black uppercase tracking-widest text-[var(--deep-navy)]">
                    Scenario Gate
                  </div>
                  <div className="text-[10px] text-slate-500 uppercase tracking-widest mt-1">
                    {dualGate.gates?.scenario?.triggered ? 'Triggered' : 'Normal'}
                  </div>
                  <div className="text-[10px] text-slate-500 uppercase tracking-widest mt-1">
                    Rain {dualGate.gates?.scenario?.rain_mm ?? 0}mm | AQI {dualGate.gates?.scenario?.aqi ?? 0}
                  </div>
                  <div className="mt-2 flex items-center gap-2">
                    <span className={`status-pill ${dualGate.gates?.scenario?.triggered ? 'status-live' : 'status-watch'}`}>
                      {dualGate.gates?.scenario?.triggered ? 'TRIGGERED' : 'NORMAL'}
                    </span>
                  </div>
                </div>
                <div className="p-3 rounded border border-[var(--border-gray)] bg-slate-50">
                  <div className="text-[10px] font-black uppercase tracking-widest text-[var(--deep-navy)]">
                    Business Logic
                  </div>
                  <div className="text-[10px] text-slate-500 uppercase tracking-widest mt-1">
                    {dualGate.gates?.business?.triggered ? 'Triggered' : 'Normal'}
                  </div>
                  <div className="text-[10px] text-slate-500 uppercase tracking-widest mt-1">
                    Earnings drop {dualGate.gates?.business?.earnings_drop_pct ?? 0}%
                  </div>
                  <div className="mt-2 flex items-center gap-2">
                    <span className={`status-pill ${dualGate.gates?.business?.triggered ? 'status-live' : 'status-watch'}`}>
                      {dualGate.gates?.business?.triggered ? 'TRIGGERED' : 'NORMAL'}
                    </span>
                  </div>
                </div>
              </div>
            )}
            {dualGate?.dual_gate_triggered && (
              <div className="mt-3 text-[10px] font-bold uppercase tracking-widest text-[var(--gw-blue)]">
                Dual gate satisfied: scenario + business logic
              </div>
            )}
            {locationUpdate?.updated && (
              <div className="mt-3 text-[10px] font-bold uppercase tracking-widest text-emerald-600">
                Location updated: {locationUpdate.from_zone} → {locationUpdate.to_zone}
              </div>
            )}
          </div>
        </div>

        <div className="flex flex-col gap-6">
          <div className="metric-card">
            <div className="flex items-center justify-between mb-4">
              <div className="flex items-center gap-2">
                <Activity size={16} className="text-[var(--gw-blue)]" />
                <h3 className="text-[11px] font-bold text-[var(--text-muted)] uppercase tracking-widest">Decision Snapshot</h3>
              </div>
              <span className="text-[10px] font-bold text-slate-400 uppercase tracking-widest">Live</span>
            </div>
            {decision ? (
              <div className="grid grid-cols-2 gap-3">
                <ResultCard label="Status" value={decision.status} />
                <ResultCard label="Payout" value={`INR ${decision.payout ?? 0}`} />
                <ResultCard label="Risk" value={`${decision.riskScore ?? '--'} (${decision.riskLevel || 'NA'})`} />
                <ResultCard label="Fraud" value={`${decision.fraudScore ?? '--'} (${decision.fraudLevel || 'NA'})`} />
                <ResultCard label="Income" value={`${decision.incomeDrop ?? '--'}% ${decision.incomeSeverity || ''}`} />
                <ResultCard label="Trigger" value={decision.trigger || 'None'} />
              </div>
            ) : (
              <div className="text-xs text-slate-400">Run analysis to see the decision snapshot</div>
            )}
            {analysis?.status === 'APPROVED' && (
              <div className="mt-4 flex flex-col gap-2">
                <button
                  onClick={fireRazorpay}
                  className="px-3 py-2 text-[10px] font-black uppercase tracking-widest bg-[var(--deep-navy)] text-white rounded"
                >
                  Fire Razorpay Payout
                </button>
                {payoutRef && <span className="text-[10px] font-bold text-[var(--gw-blue)]">{payoutRef}</span>}
              </div>
            )}
          </div>

          <div className="metric-card">
            <div className="flex items-center justify-between mb-3">
              <div className="flex items-center gap-2">
                <FileJson size={16} className="text-[var(--gw-blue)]" />
                <h3 className="text-[11px] font-bold text-[var(--text-muted)] uppercase tracking-widest">Request Payload</h3>
              </div>
            </div>
            <pre className="bg-slate-50 rounded p-4 text-xs overflow-x-auto">
{requestJson || '// Run analysis to generate payload'}
            </pre>
          </div>

          <div className="metric-card">
            <div className="flex items-center justify-between mb-3">
              <div className="flex items-center gap-2">
                <FileJson size={16} className="text-[var(--gw-blue)]" />
                <h3 className="text-[11px] font-bold text-[var(--text-muted)] uppercase tracking-widest">Analysis Response</h3>
              </div>
              <button
                onClick={runAnalysis}
                className="px-3 py-1 text-[10px] font-black uppercase tracking-widest bg-slate-100 rounded flex items-center gap-2"
              >
                <RefreshCw size={12} className={loading ? 'animate-spin' : ''} /> Refresh
              </button>
            </div>
            {error ? (
              <div className="text-xs text-[var(--red-alert)]">{error}</div>
            ) : (
              <pre className="bg-slate-50 rounded p-4 text-xs overflow-x-auto">
{analysisJson || '// Run Analysis to see JSON response'}
              </pre>
            )}
          </div>
        </div>
      </div>
    </div>
  );
};

const Slider = ({
  label,
  min,
  max,
  value,
  onChange,
  icon: Icon
}: {
  label: string;
  min: number;
  max: number;
  value: number;
  onChange: (v: number) => void;
  icon: any;
}) => (
  <div className="p-3 border border-[var(--border-gray)] rounded bg-white">
    <div className="flex items-center justify-between text-[10px] font-bold uppercase tracking-widest text-slate-400 mb-2">
      <div className="flex items-center gap-2">
        <Icon size={12} className="text-slate-400" />
        <span>{label}</span>
      </div>
      <span className="text-[var(--deep-navy)]">{value}</span>
    </div>
    <input
      type="range"
      min={min}
      max={max}
      value={value}
      onChange={(e) => onChange(parseFloat(e.target.value))}
      className="w-full"
    />
  </div>
);

const ResultCard = ({ label, value }: { label: string; value: any }) => (
  <div className="p-3 bg-slate-50 rounded">
    <div className="text-[10px] font-bold text-slate-400 uppercase tracking-widest">{label}</div>
    <div className="text-sm font-bold text-[var(--deep-navy)] mt-1 break-words">{value}</div>
  </div>
);
