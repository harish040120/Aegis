import React, { useEffect, useMemo, useState } from 'react';
import { Download, Filter } from 'lucide-react';
import { apiGet, apiPost } from '../services/api';

type AdminStats = {
  recent_payouts: Array<{
    payout_id: number;
    worker_id: string;
    name: string;
    trigger_type: string;
    amount: number;
    status: string;
    triggered_at: string;
    fraud_score: number;
    auto_triggered?: boolean;
  }>;
};

export const Payouts: React.FC = () => {
  const [stats, setStats] = useState<AdminStats>({ recent_payouts: [] });
  const [filter, setFilter] = useState<'ALL' | 'PAID' | 'HELD' | 'BANNED'>('ALL');
  const [loading, setLoading] = useState(false);

  const fetchStats = async () => {
    setLoading(true);
    try {
      const data = await apiGet('/api/v1/admin/stats');
      setStats({ recent_payouts: data.recent_payouts || [] });
    } finally {
      setLoading(false);
    }
  };

  useEffect(() => {
    fetchStats();
  }, []);

  const payouts = useMemo(() => {
    const nonZero = stats.recent_payouts.filter((p) => p.amount > 0);
    if (filter === 'ALL') return nonZero;
    return nonZero.filter((p) => p.status === filter);
  }, [stats.recent_payouts, filter]);

  const triggerPayout = async (worker_id: string) => {
    await apiPost('/api/trigger-payout', { worker_id }, 'HUB');
    await fetchStats();
  };

  return (
    <div className="p-8 flex flex-col gap-8 animate-in fade-in duration-500 max-w-[1600px] mx-auto">
      <div className="flex items-center justify-between">
        <div>
          <h1 className="text-2xl font-bold text-[var(--deep-navy)] tracking-tight uppercase">Payouts</h1>
          <p className="text-[var(--color-text-muted)] text-[10px] font-bold uppercase tracking-widest mt-1">Live Disbursement Ledger</p>
        </div>
        <button className="px-4 py-2 bg-white border border-[var(--border-gray)] rounded text-[10px] font-black uppercase tracking-widest text-slate-500 flex items-center gap-2 hover:bg-slate-50 transition-all">
          <Download size={14} /> Download Ledger
        </button>
      </div>

      <div className="flex items-center gap-3">
        <Filter size={14} className="text-slate-400" />
        {(['ALL', 'PAID', 'HELD', 'BANNED'] as const).map((f) => (
          <button
            key={f}
            onClick={() => setFilter(f)}
            className={`px-3 py-1 rounded text-[10px] font-black uppercase tracking-widest border ${
              filter === f ? 'bg-[var(--deep-navy)] text-white border-[var(--deep-navy)]' : 'bg-white text-slate-500 border-[var(--border-gray)]'
            }`}
          >
            {f}
          </button>
        ))}
      </div>

      <div className="metric-card !p-0 overflow-hidden">
        <div className="p-5 border-b border-[var(--border-gray)] bg-white flex items-center justify-between">
          <h3 className="text-[11px] font-bold text-[var(--text-muted)] uppercase tracking-widest">Recent Payouts</h3>
          <span className="status-pill status-live">{loading ? 'Syncing' : 'Live'}</span>
        </div>
        <table className="high-density-table">
          <thead>
            <tr>
              <th>Worker ID</th>
              <th>Name</th>
              <th>Trigger</th>
              <th>Amount</th>
              <th>Fraud</th>
              <th>Status</th>
              <th>Time</th>
              <th className="text-right">Action</th>
            </tr>
          </thead>
          <tbody>
            {payouts.length === 0 ? (
              <tr>
                <td colSpan={8} className="text-center text-xs text-slate-400 py-6">No payouts</td>
              </tr>
            ) : (
              payouts.map((p) => (
                <tr key={p.payout_id}>
                  <td className="data-mono font-bold text-[var(--gw-blue)] uppercase">{p.worker_id}</td>
                  <td className="text-xs font-bold text-[var(--deep-navy)]">{p.name}</td>
                  <td className="text-xs font-bold text-slate-600 uppercase tracking-tight">
                    <div className="flex items-center gap-2">
                      <span>{p.trigger_type}</span>
                      {p.auto_triggered && (
                        <span className="text-[9px] font-black px-2 py-[2px] rounded bg-emerald-100 text-emerald-700 uppercase tracking-widest">
                          AUTO
                        </span>
                      )}
                    </div>
                  </td>
                  <td className="font-black data-mono text-[var(--deep-navy)]">₹{p.amount}</td>
                  <td className="data-mono font-bold">{(p.fraud_score || 0).toFixed(2)}</td>
                  <td>
                    <span className={`status-pill ${p.status === 'PAID' ? 'status-live' : p.status === 'HELD' ? 'status-watch' : p.status === 'BANNED' ? 'status-breach' : 'status-blue'}`}>
                      {p.status}
                    </span>
                  </td>
                  <td className="text-[10px] font-bold text-slate-400 uppercase">{new Date(p.triggered_at).toLocaleString()}</td>
                  <td className="text-right">
                    <button
                      onClick={() => triggerPayout(p.worker_id)}
                      className="px-3 py-1 text-[10px] font-black uppercase tracking-widest bg-[var(--gw-blue)] text-white rounded"
                    >
                      Trigger Payout
                    </button>
                  </td>
                </tr>
              ))
            )}
          </tbody>
        </table>
      </div>
    </div>
  );
};
