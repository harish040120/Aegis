import React from 'react';
import { ShieldAlert, ShieldX, UserX, AlertTriangle, Search, Activity } from 'lucide-react';

export const Fraud: React.FC = () => {
  // Mock data for professional display
  const stats = [
    { label: 'Fraud Flags', value: '18', sub: 'Detected Today', icon: AlertTriangle, color: 'red' },
    { label: 'Terminated', value: '3', sub: 'Hard Blocked', icon: UserX, color: 'red' },
    { label: 'Avg Risk Score', value: '0.12', sub: 'Behavioral Baseline', icon: ShieldAlert, color: 'teal' },
    { label: 'Shield Efficiency', value: '94.2%', sub: 'True Positive Rate', icon: Activity, color: 'blue' },
  ];

  const signals = [
    { id: 'WK-4821', type: 'Mock GPS', score: 0.71, action: 'BANNED', time: '12m ago', details: 'Simulated location outside delivery zone' },
    { id: 'WK-9022', type: 'Device Spoof', score: 0.65, action: 'HELD', time: '45m ago', details: 'Multiple device IDs for same worker' },
    { id: 'WK-1102', type: 'Static Signal', score: 0.52, action: 'WATCH', time: '1h ago', details: 'Location not moving for 4+ hours' },
    { id: 'WK-3142', type: 'Session Spike', score: 0.48, action: 'WATCH', time: '2h ago', details: 'Unusual session duration pattern' },
    { id: 'WK-7721', type: 'Velocity Anomaly', score: 0.42, action: 'WATCH', time: '3h ago', details: 'Speed exceeds delivery vehicle limits' },
    { id: 'WK-2234', type: 'Order Pattern', score: 0.38, action: 'WATCH', time: '4h ago', details: 'Suspicious order cluster detected' },
  ];

  const defenseLayers = [
    { name: 'GPS Spatio-Temporal', status: 'Hardened', lastScan: '2 min ago', threats: 0 },
    { name: 'Device Hardware Hash', status: 'Hardened', lastScan: '5 min ago', threats: 2 },
    { name: 'Velocity Checks', status: 'Active', lastScan: '1 min ago', threats: 1 },
    { name: 'Behavioral Pattern', status: 'Active', lastScan: '3 min ago', threats: 3 },
  ];

  return (
    <div className="p-8 flex flex-col gap-8 animate-in fade-in duration-500">
      <div className="flex items-center justify-between">
        <div>
          <h1 className="text-2xl font-black text-[var(--deep-navy)] tracking-tight uppercase">Fraud Security</h1>
          <p className="text-[var(--color-text-muted)] text-[10px] font-bold uppercase tracking-widest mt-1">Behavioral Integrity & Anomaly Mitigation</p>
        </div>
        <div className="flex gap-3">
          <button className="px-4 py-2 bg-white border border-slate-200 rounded text-[10px] font-black uppercase tracking-widest text-[var(--red-alert)] hover:bg-red-50 transition-all">
            Terminate High Risk
          </button>
        </div>
      </div>

      <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-4 gap-6">
        {stats.map((s) => (
          <div key={s.label} className="metric-card border-l-4 border-slate-50 hover:border-[var(--gw-blue)]">
            <p className="text-[10px] font-black text-slate-400 uppercase tracking-widest">{s.label}</p>
            <h2 className="text-2xl font-black text-[var(--deep-navy)] data-mono mt-1">{s.value}</h2>
            <p className="text-[9px] font-bold text-slate-400 mt-2 uppercase">{s.sub}</p>
          </div>
        ))}
      </div>

      <div className="grid grid-cols-1 lg:grid-cols-3 gap-8">
        {/* Signal Log */}
        <div className="lg:col-span-2 metric-card !p-0 overflow-hidden">
          <div className="p-5 border-b border-slate-100 flex items-center justify-between bg-white">
            <h3 className="text-xs font-black text-slate-400 uppercase tracking-widest">Fraud Signal Stream</h3>
            <div className="relative">
               <Search className="absolute left-2 top-1/2 -translate-y-1/2 text-slate-300" size={12} />
               <input type="text" placeholder="SEARCH ID..." className="pl-7 pr-3 py-1 bg-slate-50 border-none rounded text-[9px] font-bold tracking-widest outline-none focus:ring-1 focus:ring-[var(--gw-blue)]" />
            </div>
          </div>
          <table className="high-density-table">
            <thead>
              <tr>
                <th>Agent ID</th>
                <th>Signal Type</th>
                <th>Confidence</th>
                <th>Detected</th>
                <th>Details</th>
                <th className="text-right">Enforcement</th>
              </tr>
            </thead>
            <tbody>
              {signals.map((s, i) => (
                <tr key={i}>
                  <td className="data-mono font-bold text-[var(--gw-blue)]">{s.id}</td>
                  <td className="text-xs font-bold text-[var(--deep-navy)]">{s.type}</td>
                  <td className="data-mono font-black">{s.score}</td>
                  <td className="text-[10px] font-bold text-slate-400 uppercase">{s.time}</td>
                  <td className="text-[10px] text-slate-500 max-w-[200px] truncate">{s.details}</td>
                  <td className="text-right">
                    <span className={`status-pill ${s.action === 'BANNED' ? 'status-breach' : s.action === 'HELD' ? 'status-watch' : 'status-blue'}`}>
                      {s.action}
                    </span>
                  </td>
                </tr>
              ))}
            </tbody>
          </table>
        </div>

         {/* Security Health */}
         <div className="flex flex-col gap-6">
            <div className="metric-card bg-[var(--red-alert)] border-none text-black p-6 relative overflow-hidden">
               <div className="absolute top-0 right-0 w-32 h-32 bg-white/10 rounded-full -translate-y-1/2 translate-x-1/2" />
               <div className="relative z-10">
                  <ShieldX size={32} className="opacity-40 mb-4" />
                  <h3 className="text-lg font-black leading-tight">Hard Block Active: 0.6 Threshold</h3>
                  <p className="text-[10px] font-bold text-slate-100 mt-2 leading-relaxed uppercase tracking-wider">
                     Any agent exceeding 0.6 fraud score is automatically suspended from disbursements.
                  </p>
               </div>
            </div>
            <div className="metric-card flex-1">
               <h3 className="text-xs font-black text-slate-400 uppercase tracking-widest mb-6">Defense Topography</h3>
               <div className="space-y-3">
                  {defenseLayers.map(layer => (
                    <div key={layer.name} className="p-3 bg-slate-50 rounded border border-slate-100">
                       <div className="flex justify-between items-center mb-2">
                          <span className="text-[10px] font-bold text-[var(--deep-navy)] uppercase tracking-tight">{layer.name}</span>
                          <span className="text-[9px] font-black text-[var(--teal-accent)] uppercase">{layer.status}</span>
                       </div>
                       <div className="flex justify-between items-center text-[9px] text-slate-400">
                          <span>Last scan: {layer.lastScan}</span>
                          <span className={layer.threats > 0 ? 'text-[var(--red-alert)]' : 'text-[var(--teal-accent)]'}>
                            {layer.threats} threats
                          </span>
                       </div>
                    </div>
                  ))}
               </div>
            </div>
         </div>
      </div>
    </div>
  );
};
