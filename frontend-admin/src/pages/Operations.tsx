import React, { useEffect, useState } from 'react';
import { Activity, Radio, Package, Sliders, CheckCircle2 } from 'lucide-react';
import { StatCard } from '../components/StatCard';
import { apiGet, apiPost } from '../services/api';

export const Operations: React.FC = () => {
  const [liveStats, setLiveStats] = useState<any>({ 
    online_now: 24, 
    total_deliveries_today: 142,
    utilization: 24,
    health: 99.9
  });
  const [params, setParams] = useState<any>({
    orders_last_hour: { value: 180, min: 0, max: 500 },
    earnings_today: { value: 1600, min: 0, max: 5000 },
    hours_worked_today: { value: 7.5, min: 0, max: 24 },
    traffic_index: { value: 45, min: 0, max: 100 },
    rain_override: { value: 0, min: 0, max: 100 },
    aqi_override: { value: 0, min: 0, max: 500 }
  });

  const fetchData = async () => {
    try {
      const [stats, pData] = await Promise.all([
        apiGet('/api/v1/operations/live-stats').catch(() => getMockLiveOps()),
        apiGet('/api/params', 'HUB').catch(() => params)
      ]);
      setLiveStats(stats);
      setParams(pData);
    } catch (err) {
      console.error(err);
    }
  };

  const updateParam = async (name: string, value: number) => {
    try {
      await apiPost('/api/params', { name, value, min: params[name].min, max: params[name].max }, 'HUB');
      setParams({...params, [name]: {...params[name], value}});
    } catch (err) {
      setParams({...params, [name]: {...params[name], value}});
    }
  };

  useEffect(() => {
    fetchData();
    const interval = setInterval(fetchData, 10000);
    return () => clearInterval(interval);
  }, []);

  const simulationLog = [
    { type: 'Parameter Sync', msg: 'Manual rainfall override: 45.2mm', time: '12 seconds ago', color: 'blue' },
    { type: 'Trigger Event', msg: 'Heavy Rain Threshold Activated', time: '45 seconds ago', color: 'orange' },
    { type: 'API Call', msg: 'Risk analysis completed for W001', time: '2 min ago', color: 'teal' },
    { type: 'ML Inference', msg: 'Fraud score calculated: 0.12', time: '3 min ago', color: 'purple' },
  ];

  return (
    <div className="workspace animate-in fade-in duration-500">
      <div className="flex items-center justify-between mb-8">
        <div>
          <h1 className="text-2xl font-black text-[var(--deep-navy)] tracking-tight uppercase">Control Center</h1>
          <p className="text-[var(--color-text-muted)] text-[10px] font-bold uppercase tracking-widest mt-1">Live Simulation & Orchestration</p>
        </div>
        <div className="flex items-center gap-3 px-4 py-2 bg-green-500/5 border border-green-500/20 rounded">
          <div className="w-2 h-2 rounded-full bg-green-500 animate-ping" />
          <span className="text-[10px] font-black text-green-600 uppercase tracking-widest">System Signal Live</span>
        </div>
      </div>

      <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-4 gap-6 mb-10">
        <StatCard title="Active Riders" value={liveStats.online_now} icon={Radio} accentColor="teal" />
        <StatCard title="Total Orders" value={liveStats.total_deliveries_today} icon={Package} accentColor="blue" />
        <StatCard title="System Utilization" value={`${liveStats.utilization}%`} icon={Activity} accentColor="purple" />
        <StatCard title="Health Index" value={`${liveStats.health}%`} icon={CheckCircle2} accentColor="teal" />
      </div>

      <div className="grid grid-cols-1 lg:grid-cols-3 gap-8">
        <div className="lg:col-span-2 flex flex-col gap-8">
           <div className="kpi-card border-t-4 border-[var(--gw-blue)]">
              <div className="flex items-center justify-between mb-10">
                <div className="flex items-center gap-2">
                  <Sliders size={16} className="text-[var(--gw-blue)]" />
                  <h3 className="text-xs font-black uppercase tracking-widest text-[var(--deep-navy)]">Environment Orchestrator</h3>
                </div>
                <span className="text-[9px] font-mono text-[var(--color-text-muted)] tracking-widest">TARGET: NODE-HUB-01</span>
              </div>
              
              <div className="grid grid-cols-1 md:grid-cols-2 gap-x-12 gap-y-10">
                {Object.entries(params).map(([name, p]: [string, any]) => (
                  <div key={name} className="flex flex-col gap-4">
                    <div className="flex justify-between items-center">
                      <label className="text-[10px] font-black uppercase text-[var(--color-text-muted)] tracking-widest">{name.replace(/_/g, ' ')}</label>
                      <span className="text-sm font-mono font-black text-[var(--gw-blue)] bg-blue-50 px-2 py-0.5 rounded border border-blue-100">{p.value}</span>
                    </div>
                    <input 
                      type="range" 
                      min={p.min} 
                      max={p.max} 
                      step={name.includes('pct') ? 1 : 0.1}
                      value={p.value}
                      onChange={(e) => updateParam(name, parseFloat(e.target.value))}
                      className="w-full h-1.5 bg-gray-100 rounded-lg appearance-none cursor-pointer accent-[var(--gw-blue)]"
                    />
                    <div className="flex justify-between text-[9px] text-gray-400 font-bold font-mono">
                      <span>{p.min}</span>
                      <span>{p.max}</span>
                    </div>
                  </div>
                ))}
              </div>
           </div>
        </div>

         <div className="flex flex-col gap-6">
           <div className="kpi-card h-full">
              <h3 className="text-xs font-black uppercase tracking-widest text-[var(--color-text-muted)] mb-6">Simulation Log</h3>
              <div className="flex flex-col gap-4">
                {simulationLog.map((log, i) => (
                  <div key={i} className={`p-3 bg-${log.color}-50/50 rounded border border-${log.color}-100 border-l-4 border-${log.color}-500`}>
                     <p className="text-[10px] font-black text-[var(--color-accent-blue)] uppercase">{log.type}</p>
                     <p className="text-xs font-bold text-[var(--deep-navy)] mt-1">{log.msg}</p>
                     <p className="text-[9px] text-gray-400 mt-1 uppercase font-bold">{log.time}</p>
                  </div>
                ))}
              </div>
           </div>
        </div>
      </div>
    </div>
  );
};

const getMockLiveOps = () => ({
  online_now: 24,
  total_deliveries_today: 142,
  utilization: 24,
  health: 99.9
});
