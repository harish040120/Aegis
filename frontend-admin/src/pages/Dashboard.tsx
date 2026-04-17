import React, { useEffect, useMemo, useState } from 'react';
import {
  Activity,
  AlertTriangle,
  Banknote,
  CircleDollarSign,
  Clock3,
  RefreshCw,
  ShieldAlert,
  Users
} from 'lucide-react';
import { apiGet } from '../services/api';

type AdminStats = {
  kpis: {
    verified_workers: number;
    active_policies: number;
    today_payouts: number;
    today_paid_inr: number;
    fraud_flags: number;
    paid_count: number;
    held_count: number;
    active_alerts: number;
  };
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
  active_alerts: Array<{
    trigger_type: string;
    zone: string;
    severity: number;
    payout_pct: number;
    status: string;
    raw_metric: number;
    detected_at: string;
  }>;
};

const defaultStats: AdminStats = {
  kpis: {
    verified_workers: 0,
    active_policies: 0,
    today_payouts: 0,
    today_paid_inr: 0,
    fraud_flags: 0,
    paid_count: 0,
    held_count: 0,
    active_alerts: 0
  },
  recent_payouts: [],
  active_alerts: []
};

export const Dashboard: React.FC = () => {
  const [stats, setStats] = useState<AdminStats>(defaultStats);
  const [loading, setLoading] = useState(false);
  const [lastUpdated, setLastUpdated] = useState<Date | null>(null);
  const [riskSnapshot, setRiskSnapshot] = useState<any>(null);

  const fetchStats = async () => {
    setLoading(true);
    try {
      const data = await apiGet('/api/v1/admin/stats');
      setStats(data);
      setLastUpdated(new Date());
    } finally {
      setLoading(false);
    }
  };

  const fetchRisk = async () => {
    try {
      const data = await apiGet('/api/v1/live-metrics/W001');
      setRiskSnapshot(data);
    } catch {
      setRiskSnapshot(null);
    }
  };

  useEffect(() => {
    fetchStats();
    fetchRisk();
    const statsId = setInterval(fetchStats, 30000);
    const riskId = setInterval(fetchRisk, 60000);
    return () => {
      clearInterval(statsId);
      clearInterval(riskId);
    };
  }, []);

  const ticker = useMemo(() => stats.recent_payouts.slice(0, 4), [stats.recent_payouts]);

  const headline = useMemo(() => {
    const totalPaid = stats.kpis.today_paid_inr || 0;
    const totalPayouts = stats.kpis.today_payouts || 0;
    const fraud = stats.kpis.fraud_flags || 0;
    return {
      totalPaid,
      totalPayouts,
      fraud,
      paidCount: stats.kpis.paid_count || 0,
      heldCount: stats.kpis.held_count || 0
    };
  }, [stats]);

  return (
    <div className="flex flex-col gap-6 animate-in fade-in duration-500 max-w-[1600px] mx-auto">
      <div className="flex flex-col gap-3 lg:flex-row lg:items-center lg:justify-between">
        <div>
          <h1 className="text-2xl font-bold text-[var(--deep-navy)] tracking-tight uppercase">Operations Dashboard</h1>
          <p className="text-[11px] font-semibold text-[var(--text-muted)] uppercase tracking-wider mt-1">Live Risk + Payout Overview</p>
        </div>
        <div className="flex items-center gap-3">
          <div className="flex items-center gap-2 px-3 py-2 bg-white border border-[var(--border-gray)] rounded">
            <Clock3 size={14} className="text-slate-400" />
            <span className="text-[10px] font-bold uppercase tracking-widest text-slate-500">
              Last refresh: {lastUpdated ? lastUpdated.toLocaleTimeString() : '--'}
            </span>
          </div>
          <button
            onClick={fetchStats}
            className="flex items-center gap-2 px-4 py-2 bg-[var(--gw-blue)] text-white rounded shadow-sm transition-colors text-[11px] font-bold uppercase tracking-widest"
          >
            <RefreshCw size={14} className={loading ? 'animate-spin' : ''} />
            Refresh
          </button>
        </div>
      </div>

      <div className="grid grid-cols-1 lg:grid-cols-3 gap-6">
          <div className="metric-card lg:col-span-2 bg-gradient-to-br from-slate-900 via-[#0F1C2E] to-[#001B32] text-white border-transparent">
            <div className="flex items-center justify-between">
              <div className="flex items-center gap-2">
                <Activity size={16} className="text-[var(--teal-accent)]" />
                <span className="text-[11px] font-bold uppercase tracking-widest text-white/70">Live Payout Pulse</span>
              </div>
            <span className="text-[10px] font-black uppercase tracking-widest text-white/60">TN-01 Cluster</span>
            </div>
            <div className="mt-6 grid grid-cols-2 md:grid-cols-4 gap-4">
              <PulseStat label="Paid Today" value={`INR ${Math.round(headline.totalPaid).toLocaleString()}`} icon={CircleDollarSign} />
              <PulseStat label="Payouts" value={headline.totalPayouts} icon={Banknote} />
              <PulseStat label="Held" value={headline.heldCount} icon={ShieldAlert} />
              <PulseStat label="Fraud Flags" value={headline.fraud} icon={AlertTriangle} tone="danger" />
            </div>
            <div className="mt-6 flex items-center justify-between text-[10px] uppercase tracking-widest text-white/60">
              <span>Risk Score: {riskSnapshot?.risk_score?.toFixed(1) ?? '--'} / 10</span>
              <span>Risk Level: {riskSnapshot?.risk_level ?? '--'}</span>
              <span>Scenario: {riskSnapshot?.active_scenario ?? 'normal'}</span>
            </div>
            <div className="mt-6 flex flex-wrap gap-4 text-[10px] uppercase tracking-widest text-white/60">
              <span>Paid Count: {headline.paidCount}</span>
              <span>Active Alerts: {stats.kpis.active_alerts}</span>
              <span>Verified Workers: {stats.kpis.verified_workers}</span>
              <span>Active Policies: {stats.kpis.active_policies}</span>
            </div>
          </div>

        <div className="metric-card">
          <div className="flex items-center justify-between">
            <div className="flex items-center gap-2">
              <Users size={16} className="text-[var(--gw-blue)]" />
              <span className="text-[11px] font-bold uppercase tracking-widest text-[var(--text-muted)]">Coverage Snapshot</span>
            </div>
            <span className="status-pill status-live">Live</span>
          </div>
          <div className="mt-6 flex flex-col gap-4">
            <SummaryRow label="Verified Workers" value={stats.kpis.verified_workers} />
            <SummaryRow label="Active Policies" value={stats.kpis.active_policies} />
            <SummaryRow label="Today's Payouts" value={stats.kpis.today_payouts} />
            <SummaryRow label="Today's Paid" value={`INR ${Math.round(stats.kpis.today_paid_inr).toLocaleString()}`} />
          </div>
          <div className="mt-6 p-3 rounded bg-slate-50 border border-[var(--border-gray)]">
            <p className="text-[10px] font-bold uppercase tracking-widest text-slate-400">Loss Ratio</p>
            <p className="text-sm font-bold text-[var(--deep-navy)] mt-2">Track in `v_loss_ratio` view</p>
            <p className="text-[10px] text-slate-400 mt-1">Use SQL view for plan-level analytics</p>
          </div>
        </div>
      </div>

      <div className="grid grid-cols-1 lg:grid-cols-3 gap-6">
        <div className="metric-card lg:col-span-2">
          <div className="flex items-center justify-between mb-4">
            <h3 className="text-[11px] font-bold text-[var(--text-muted)] uppercase tracking-widest flex items-center gap-2">
              <AlertTriangle size={14} className="text-[var(--gw-blue)]" />
              Active Disruption Alerts
            </h3>
            <div className="flex items-center gap-2">
              <span className="status-pill status-live">Live</span>
              <span className="text-[10px] font-bold text-slate-400 uppercase tracking-widest">
                {lastUpdated ? lastUpdated.toLocaleTimeString() : '--'}
              </span>
            </div>
          </div>
          <div className="overflow-x-auto">
            <table className="high-density-table">
              <thead>
                <tr>
                  <th>Zone</th>
                  <th>Trigger</th>
                  <th>Severity</th>
                  <th>Payout %</th>
                  <th>Raw Metric</th>
                  <th>Status</th>
                </tr>
              </thead>
              <tbody>
                {stats.active_alerts.length === 0 ? (
                  <tr>
                    <td colSpan={6} className="text-center text-xs text-slate-400 py-6">No active alerts</td>
                  </tr>
                ) : (
                  stats.active_alerts.map((a, idx) => (
                    <tr key={`${a.zone}-${idx}`}>
                      <td className="font-bold text-[var(--gw-blue)] uppercase">{a.zone}</td>
                      <td className="text-xs font-semibold text-[var(--deep-navy)] uppercase tracking-tight">{a.trigger_type}</td>
                      <td className="data-mono font-bold">{a.severity.toFixed(2)}</td>
                      <td className="data-mono font-bold">{(a.payout_pct * 100).toFixed(0)}%</td>
                      <td className="data-mono">{a.raw_metric?.toFixed(2)}</td>
                      <td>
                        <span className="status-pill status-live">{a.status}</span>
                      </td>
                    </tr>
                  ))
                )}
              </tbody>
            </table>
          </div>
        </div>

        <div className="metric-card">
          <div className="flex items-center justify-between mb-4">
            <div className="flex items-center gap-2">
              <ShieldAlert size={16} className="text-[var(--gw-blue)]" />
              <span className="text-[11px] font-bold uppercase tracking-widest text-[var(--text-muted)]">Latest Payouts</span>
            </div>
            <span className="text-[10px] font-bold uppercase tracking-widest text-slate-400">Live</span>
          </div>
          <div className="flex flex-col gap-3">
            {ticker.length === 0 ? (
              <span className="text-xs text-slate-400">No payouts yet</span>
            ) : (
              ticker.map((p) => (
                <div key={p.payout_id} className="p-3 border border-[var(--border-gray)] rounded bg-slate-50">
                  <div className="flex items-center justify-between">
                    <span className="text-[11px] font-black uppercase tracking-widest text-[var(--deep-navy)]">{p.worker_id}</span>
                    <span className={`status-pill ${p.status === 'PAID' ? 'status-live' : p.status === 'HELD' ? 'status-watch' : 'status-breach'}`}>{p.status}</span>
                  </div>
                  <div className="mt-2 flex items-center gap-2 text-[10px] uppercase tracking-widest text-slate-500">
                    <span>{p.trigger_type}</span>
                    {p.auto_triggered && (
                      <span className="text-[9px] font-black px-2 py-[2px] rounded bg-emerald-100 text-emerald-700 uppercase tracking-widest">
                        AUTO
                      </span>
                    )}
                  </div>
                  <div className="mt-2 flex items-center justify-between text-[11px] font-bold text-[var(--deep-navy)]">
                    <span>INR {p.amount}</span>
                    <span className="text-[10px] text-slate-400">Fraud {p.fraud_score?.toFixed(2)}</span>
                  </div>
                </div>
              ))
            )}
          </div>
        </div>
      </div>
    </div>
  );
};

const SummaryRow = ({ label, value }: { label: string; value: string | number }) => (
  <div className="flex items-center justify-between text-[11px] font-bold text-[var(--deep-navy)]">
    <span className="uppercase tracking-widest text-slate-400">{label}</span>
    <span className="font-data">{value}</span>
  </div>
);

const PulseStat = ({
  label,
  value,
  icon: Icon,
  tone
}: {
  label: string;
  value: string | number;
  icon: any;
  tone?: 'danger';
}) => (
  <div className="flex flex-col gap-2">
    <div className="flex items-center gap-2 text-[10px] uppercase tracking-widest text-white/70">
      <Icon size={14} className={tone === 'danger' ? 'text-[var(--red-alert)]' : 'text-[var(--teal-accent)]'} />
      {label}
    </div>
    <div className="text-xl font-bold text-white">{value}</div>
  </div>
);
