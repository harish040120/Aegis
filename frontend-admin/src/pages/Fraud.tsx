import React, { useEffect, useMemo, useState } from 'react';
import { AlertTriangle } from 'lucide-react';
import { apiGet, apiPost } from '../services/api';

type AdminStats = {
  fraud_watchlist: Array<{
    worker_id: string;
    name: string;
    fraud_score: number;
    fraud_level: string;
    trigger_type: string;
    amount: number;
    status: string;
    triggered_at: string;
  }>;
};

export const Fraud: React.FC = () => {
  const [stats, setStats] = useState<AdminStats>({ fraud_watchlist: [] });
  const [loading, setLoading] = useState(false);

  const fetchStats = async () => {
    setLoading(true);
    try {
      const data = await apiGet('/api/v1/admin/stats');
      setStats({ fraud_watchlist: data.fraud_watchlist || [] });
    } finally {
      setLoading(false);
    }
  };

  useEffect(() => {
    fetchStats();
  }, []);

  const highRisk = useMemo(
    () => stats.fraud_watchlist.filter((w) => (w.fraud_score || 0) > 0.6),
    [stats.fraud_watchlist]
  );

  const doAction = async (worker_id: string, action: 'hold' | 'ban' | 'clear') => {
    await apiPost(`/api/v1/admin/fraud-action?worker_id=${worker_id}&action=${action}`, {}, 'ML');
    await fetchStats();
  };

  const terminateHighRisk = async () => {
    await Promise.all(highRisk.map((w) => doAction(w.worker_id, 'ban')));
  };

  return (
    <div className="p-8 flex flex-col gap-8 animate-in fade-in duration-500">
      <div className="flex items-center justify-between">
        <div>
          <h1 className="text-2xl font-black text-[var(--deep-navy)] tracking-tight uppercase">Fraud</h1>
          <p className="text-[var(--color-text-muted)] text-[10px] font-bold uppercase tracking-widest mt-1">Behavioral Integrity & Actions</p>
        </div>
        <div className="flex gap-3">
          <button
            onClick={terminateHighRisk}
            className="px-4 py-2 bg-white border border-slate-200 rounded text-[10px] font-black uppercase tracking-widest text-[var(--red-alert)] hover:bg-red-50 transition-all"
          >
            Terminate All HIGH Risk
          </button>
        </div>
      </div>

      <div className="metric-card !p-0 overflow-hidden">
        <div className="p-5 border-b border-slate-100 flex items-center justify-between bg-white">
          <h3 className="text-xs font-black text-slate-400 uppercase tracking-widest">Fraud Watchlist</h3>
          <span className="status-pill status-live">{loading ? 'Syncing' : 'Live'}</span>
        </div>
        <table className="high-density-table">
          <thead>
            <tr>
              <th>Worker ID</th>
              <th>Name</th>
              <th>Fraud Score</th>
              <th>Fraud Level</th>
              <th>Last Trigger</th>
              <th>Action</th>
            </tr>
          </thead>
          <tbody>
            {stats.fraud_watchlist.length === 0 ? (
              <tr>
                <td colSpan={6} className="text-center text-xs text-slate-400 py-6">No fraud signals</td>
              </tr>
            ) : (
              stats.fraud_watchlist.map((s, i) => (
                <tr key={`${s.worker_id}-${i}`}>
                  <td className="data-mono font-bold text-[var(--gw-blue)]">{s.worker_id}</td>
                  <td className="text-xs font-bold text-[var(--deep-navy)]">{s.name}</td>
                  <td className="data-mono font-black">
                    <div className="flex items-center gap-2">
                      <div className="w-20 h-1.5 bg-slate-100 rounded-full overflow-hidden">
                        <div
                          className="h-full bg-[var(--red-alert)]"
                          style={{ width: `${Math.min(100, (s.fraud_score || 0) * 100)}%` }}
                        />
                      </div>
                      {(s.fraud_score || 0).toFixed(2)}
                    </div>
                  </td>
                  <td>
                    <span className={`status-pill ${s.fraud_level === 'HIGH' ? 'status-breach' : s.fraud_level === 'MODERATE' ? 'status-watch' : 'status-blue'}`}>
                      {s.fraud_level}
                    </span>
                  </td>
                  <td className="text-[10px] font-bold text-slate-400 uppercase">{s.trigger_type}</td>
                  <td className="flex items-center gap-2">
                    <button onClick={() => doAction(s.worker_id, 'hold')} className="px-2 py-1 text-[10px] font-black uppercase bg-slate-100 rounded">Hold</button>
                    <button onClick={() => doAction(s.worker_id, 'ban')} className="px-2 py-1 text-[10px] font-black uppercase bg-[var(--red-alert)] text-white rounded">Ban</button>
                    <button onClick={() => doAction(s.worker_id, 'clear')} className="px-2 py-1 text-[10px] font-black uppercase bg-[var(--gw-blue)] text-white rounded">Clear</button>
                  </td>
                </tr>
              ))
            )}
          </tbody>
        </table>
      </div>

      <div className="metric-card flex items-center gap-3">
        <AlertTriangle size={16} className="text-[var(--gw-blue)]" />
        <span className="text-[11px] font-bold text-[var(--text-muted)] uppercase tracking-widest">Hard Block Threshold: 0.60</span>
        <span className="text-[10px] font-bold text-slate-400 uppercase tracking-widest">Auto-ban on HIGH risk</span>
      </div>
    </div>
  );
};
