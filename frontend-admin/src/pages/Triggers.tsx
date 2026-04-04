import React from 'react';
import { Zap, Map } from 'lucide-react';

export const Triggers: React.FC = () => {
  // Mock data for professional display
  const activeTriggers = [
    { type: 'Rainfall', threshold: '> 50mm', current: '82mm', status: 'BREACH', color: 'red', zone: 'Chennai-Central' },
    { type: 'AQI (PM2.5)', threshold: '> 200', current: '220', status: 'WATCH', color: 'orange', zone: 'Chennai-North' },
    { type: 'Heat Index', threshold: '> 41°C', current: '38°C', status: 'LIVE', color: 'teal', zone: 'All Zones' },
    { type: 'Income Drop', threshold: '> 45%', current: '28%', status: 'LIVE', color: 'teal', zone: 'Coimbatore' },
  ];

  const triggerHistory = [
    { time: '08:00 AM', trigger: 'Chennai-Central Rainfall Breach', gate: 'Gate 1 Passed', value: '82mm', active: true },
    { time: '09:45 AM', trigger: 'Chennai-North AQI Watch', gate: 'Gate 2 Passed', value: '220', active: true },
    { time: '11:30 AM', trigger: 'Coimbatore Income Drop', gate: 'Gate 3 Passed', value: '52%', active: false },
    { time: '02:15 PM', trigger: 'Chennai-East Rainfall Breach', gate: 'Gate 1 Passed', value: '65mm', active: true },
    { time: '04:45 PM', trigger: 'Chennai-South AQI Alert', gate: 'Gate 2 Passed', value: '195', active: true },
  ];

  return (
    <div className="p-8 flex flex-col gap-8 animate-in fade-in duration-500 max-w-[1600px] mx-auto">
      <div className="flex items-center justify-between">
        <div>
          <h1 className="text-2xl font-bold text-[var(--deep-navy)] tracking-tight uppercase">Trigger Logic Engine</h1>
          <p className="text-[11px] font-semibold text-[var(--text-muted)] uppercase tracking-wider mt-1">Parametric Threshold Monitoring & Automation</p>
        </div>
        <div className="flex items-center gap-2 px-3 py-1 bg-slate-100 border border-slate-200 rounded text-[10px] font-black uppercase text-slate-500">
           <Map size={14} className="text-[var(--gw-blue)]" />
           Chennai Zone 4 Operational
        </div>
      </div>

      <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-4 gap-6">
        {activeTriggers.map((t) => (
          <div key={t.type} className={`metric-card border-t-4 ${t.status === 'BREACH' ? 'border-[var(--red-alert)]' : t.status === 'WATCH' ? 'border-[var(--orange-warning)]' : 'border-[var(--teal-accent)]'}`}>
            <div className="flex justify-between items-center mb-4">
              <span className={`status-pill ${t.status === 'BREACH' ? 'status-breach' : t.status === 'WATCH' ? 'status-watch' : 'status-live'}`}>{t.status}</span>
              <span className="text-[9px] font-black text-slate-400 uppercase tracking-widest">Logic Node 01</span>
            </div>
            <p className="text-[10px] font-black text-slate-400 uppercase tracking-widest">{t.type}</p>
            <h2 className="text-2xl font-black text-[var(--deep-navy)] data-mono mt-1">{t.current}</h2>
            <p className="text-[9px] font-bold text-slate-400 mt-2 uppercase tracking-tight">Threshold: {t.threshold}</p>
          </div>
        ))}
      </div>

      <div className="grid grid-cols-1 lg:grid-cols-3 gap-8">
         {/* Operational Impact */}
         <div className="metric-card bg-white flex flex-col items-center justify-center text-center p-10">
            <div className="w-16 h-16 rounded-full bg-[var(--gw-blue)]/10 flex items-center justify-center text-[var(--gw-blue)] mb-6 animate-pulse">
               <Zap size={32} />
            </div>
            <h2 className="text-4xl font-black text-[var(--deep-navy)] font-data tracking-tighter">1,240</h2>
            <p className="text-[11px] font-black text-[var(--gw-blue)] uppercase tracking-widest mt-2">Active Disbursements</p>
            <p className="text-xs text-slate-400 mt-4 leading-relaxed max-w-[200px]">
               Workers currently being processed for Rainfall Breach in Chennai Zone 4.
            </p>
            <button className="mt-8 px-6 py-3 bg-[var(--gw-blue)] text-white text-[10px] font-black uppercase tracking-[0.2em] rounded-md shadow-lg shadow-blue-500/30 hover:bg-blue-700 transition-all">
               View Affected agents
            </button>
         </div>

          {/* Distribution Log */}
          <div className="lg:col-span-2 metric-card !p-0 overflow-hidden">
             <div className="p-5 border-b border-[var(--border-gray)] bg-white flex items-center justify-between">
                <h3 className="text-[11px] font-bold text-[var(--text-muted)] uppercase tracking-widest">Trigger Distribution History</h3>
                <span className="text-[10px] font-bold text-slate-400 uppercase tracking-tighter">Last 24 Hours</span>
             </div>
             <div className="flex flex-col">
                {triggerHistory.map((item, i) => (
                  <div key={i} className="px-6 py-4 flex items-center justify-between border-b border-slate-50 hover:bg-slate-50 transition-colors">
                     <div className="flex items-center gap-4">
                        <span className="text-xs font-bold text-slate-400 font-mono w-16">{item.time}</span>
                        <div className="flex flex-col">
                           <span className="text-sm font-bold text-[var(--deep-navy)] uppercase tracking-tight">{item.trigger}</span>
                           <span className="text-[10px] font-bold text-[var(--gw-blue)] uppercase tracking-widest">{item.gate} · {item.value}</span>
                        </div>
                     </div>
                     <span className={`status-pill ${item.active ? 'status-live' : 'status-watch'}`}>{item.active ? 'Active' : 'Resolved'}</span>
                  </div>
                ))}
             </div>
          </div>
      </div>
    </div>
  );
};
