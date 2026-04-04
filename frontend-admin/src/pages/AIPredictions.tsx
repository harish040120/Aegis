import React from 'react';
import { BrainCircuit, ShieldAlert, ShieldX, Terminal, RefreshCw, Activity } from 'lucide-react';

export const AIPredictions: React.FC = () => {
  // Mock data for professional display
  const stats = [
    { label: 'Model Confidence', value: '94.2%', sub: 'True Positive Rate', icon: BrainCircuit, color: 'blue' },
    { label: 'Risk Forecast', value: '1,450', sub: 'Claims predicted tomorrow', icon: Activity, color: 'teal' },
    { label: 'Premium Rec.', value: '+12%', sub: 'Dynamic hike suggested', icon: RefreshCw, color: 'orange' },
    { label: 'Inference Latency', value: '0.12s', sub: 'Per analysis', icon: Terminal, color: 'blue' },
  ];

  const fraudLog = [
    { id: 'WK-4821', signal: 'Mock GPS Detected', score: '0.71', status: 'BANNED', details: 'Simulated location outside delivery zone' },
    { id: 'WK-9022', signal: 'Device Hardware Mismatch', score: '0.65', status: 'WATCH', details: 'Multiple device IDs for same worker' },
    { id: 'WK-3142', signal: 'Stationary Session', score: '0.58', status: 'HELD', details: 'Location not moving for 4+ hours' },
    { id: 'WK-1102', signal: 'Claim Velocity Spike', score: '0.42', status: 'WATCH', details: 'Unusual claim frequency detected' },
    { id: 'WK-7721', signal: 'Order Pattern Anomaly', score: '0.38', status: 'WATCH', details: 'Suspicious order cluster detected' },
    { id: 'WK-2234', signal: 'Route Deviation', score: '0.31', status: 'WATCH', details: 'Route differs from optimal path' },
  ];

  const anomalyAlerts = [
    { type: 'Static Session', location: 'Chennai-South', surge: '14%', severity: 'High', time: '2h ago' },
    { type: 'Velocity Anomaly', location: 'Chennai-North', surge: '8%', severity: 'Medium', time: '4h ago' },
    { type: 'Order Cluster', location: 'Coimbatore', surge: '6%', severity: 'Low', time: '6h ago' },
  ];

  return (
    <div className="p-8 flex flex-col gap-8 animate-in fade-in duration-500 max-w-[1600px] mx-auto">
      <div className="flex items-center justify-between">
        <div>
          <h1 className="text-2xl font-bold text-[var(--deep-navy)] tracking-tight uppercase">AI Intelligence & Fraud</h1>
          <p className="text-[11px] font-semibold text-[var(--text-muted)] uppercase tracking-wider mt-1">Predictive Risk Mitigation & Behavioral Defense</p>
        </div>
        <div className="flex gap-3">
          <button className="px-4 py-2 bg-white border border-[var(--border-gray)] rounded text-[10px] font-black uppercase tracking-widest text-[var(--red-alert)] hover:bg-red-50 transition-all flex items-center gap-2">
            <ShieldX size={14} /> Terminate All High Risk
          </button>
          <button className="px-4 py-2 bg-[var(--gw-blue)] text-white rounded text-[10px] font-black uppercase tracking-[0.2em] hover:bg-blue-700 transition-all shadow-lg shadow-blue-500/30">
            Retrain ML Cluster
          </button>
        </div>
      </div>

      <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-4 gap-6">
        {stats.map((s) => (
          <div key={s.label} className="metric-card border-l-4 border-slate-50 hover:border-l-[var(--gw-blue)]">
            <p className="text-[10px] font-black text-slate-400 uppercase tracking-widest">{s.label}</p>
            <h2 className="text-2xl font-black text-[var(--deep-navy)] data-mono mt-1">{s.value}</h2>
            <p className="text-[9px] font-bold text-slate-400 mt-2 uppercase">{s.sub}</p>
          </div>
        ))}
      </div>

      <div className="grid grid-cols-1 lg:grid-cols-3 gap-8">
        {/* Fraud Signal Log */}
        <div className="lg:col-span-2 metric-card !p-0 overflow-hidden">
          <div className="p-5 border-b border-[var(--border-gray)] bg-white flex items-center justify-between">
            <h3 className="text-[11px] font-bold text-[var(--text-muted)] uppercase tracking-widest flex items-center gap-2">
               <ShieldAlert size={14} className="text-[var(--red-alert)]" />
               Fraud Signal Console
            </h3>
            <span className="text-[9px] font-black text-slate-400 uppercase tracking-tighter">Real-Time Telemetry</span>
          </div>
          <table className="high-density-table">
            <thead>
              <tr>
                <th>Agent ID</th>
                <th>Primary Signal</th>
                <th>Confidence Score</th>
                <th>Details</th>
                <th className="text-right">Action Status</th>
              </tr>
            </thead>
            <tbody>
              {fraudLog.map((f) => (
                <tr key={f.id}>
                  <td className="data-mono font-bold text-[var(--gw-blue)] uppercase">{f.id}</td>
                  <td className="text-xs font-bold text-slate-600 uppercase tracking-tight">{f.signal}</td>
                  <td className="font-black data-mono text-[var(--deep-navy)]">
                     <span className={parseFloat(f.score) > 0.6 ? 'text-[var(--red-alert)]' : 'text-[var(--orange-warning)]'}>
                        {f.score}
                     </span>
                  </td>
                  <td className="text-[10px] text-slate-500 max-w-[180px] truncate">{f.details}</td>
                  <td className="text-right">
                    <span className={`status-pill ${f.status === 'BANNED' ? 'status-breach' : f.status === 'HELD' ? 'status-watch' : 'status-blue'}`}>
                      {f.status}
                    </span>
                  </td>
                </tr>
              ))}
            </tbody>
          </table>
        </div>

        {/* Intelligence Context */}
        <div className="flex flex-col gap-6">
          <div className="metric-card bg-[var(--deep-navy)] border-none p-6 relative overflow-hidden">
             <div className="absolute top-0 right-0 w-32 h-32 bg-white/10 rounded-full -translate-y-1/2 translate-x-1/2" />
             <div className="relative z-10 flex flex-col h-full justify-between">
                <div>
                   <p className="text-[10px] font-black uppercase tracking-[0.2em] text-slate-400">Anomaly Alert</p>
                   <h3 className="text-lg font-bold mt-4 leading-tight text-black">Detected 14% surge in "Static Session" pings from South Zone.</h3>
                   <p className="text-xs text-slate-600 mt-4 leading-relaxed">
                      ML Pattern Match suggests widespread GPS spoofing tool active in Chennai Sector 2.
                   </p>
                </div>
                <div className="mt-6">
                   <button className="w-full py-3 bg-[var(--gw-blue)] hover:bg-blue-700 border border-[var(--gw-blue)] rounded text-[10px] font-black uppercase tracking-widest transition-all text-white">
                      Initialize Hard Block
                   </button>
                </div>
             </div>
             <BrainCircuit size={100} className="absolute -right-4 -bottom-4 text-white/5" />
          </div>
          
          <div className="metric-card">
            <h3 className="text-xs font-black text-slate-400 uppercase tracking-widest mb-4">Active Anomalies</h3>
            <div className="flex flex-col gap-3">
              {anomalyAlerts.map((alert, i) => (
                <div key={i} className="p-3 bg-slate-50 rounded border border-slate-100">
                  <div className="flex justify-between items-start mb-2">
                    <span className="text-[10px] font-bold text-[var(--deep-navy)] uppercase">{alert.type}</span>
                    <span className={`text-[9px] font-black uppercase ${alert.severity === 'High' ? 'text-[var(--red-alert)]' : alert.severity === 'Medium' ? 'text-[var(--orange-warning)]' : 'text-[var(--teal-accent)]'}`}>
                      {alert.severity}
                    </span>
                  </div>
                  <div className="flex justify-between items-center text-[9px] text-slate-400">
                    <span>{alert.location}</span>
                    <span>+{alert.surge} · {alert.time}</span>
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
