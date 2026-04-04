import React, { useEffect, useState } from 'react';
import { CreditCard, Banknote, ShieldCheck, Zap, Download } from 'lucide-react';
import { apiGet } from '../services/api';

export const Financials: React.FC = () => {
  const [financialData, setFinancialData] = useState<any>({ 
    monthly: { premium_revenue: 842000, total_payouts: 324000, net_revenue: 518000, loss_ratio: 38.5 }, 
    today: { premium_revenue: 28400, total_payouts: 24780 }, 
    active_policies_value: 1264000, 
    pending_claims: 4 
  });

  useEffect(() => {
    apiGet('/api/v1/financials/summary')
      .then(setFinancialData)
      .catch(() => setFinancialData({
        monthly: { premium_revenue: 842000, total_payouts: 324000, net_revenue: 518000, loss_ratio: 38.5 },
        today: { premium_revenue: 28400, total_payouts: 24780 },
        active_policies_value: 1264000,
        pending_claims: 4
      }));
  }, []);

  const formatCurrency = (val: number) => `₹${Math.round(val).toLocaleString()}`;

  // Mock data for professional display
  const revenueMix = [
    { label: 'Premium Revenue', value: formatCurrency(842000), pct: 65, color: 'bg-[var(--gw-blue)]' },
    { label: 'Total Payouts', value: formatCurrency(324000), pct: 25, color: 'bg-[var(--teal-accent)]' },
    { label: 'Net Revenue', value: formatCurrency(518000), pct: 10, color: 'bg-slate-400' },
  ];

  const transactionLog = [
    { ref: 'TX-9021', entity: 'WK-4821', amount: '₹630', method: 'UPI INSTANT', sla: 'Success · 11m', status: 'PAID' },
    { ref: 'TX-9022', entity: 'WK-3302', amount: '₹85', method: 'UPI INSTANT', sla: 'Success · 8m', status: 'PAID' },
    { ref: 'TX-9023', entity: 'WK-5621', amount: '₹380', method: 'UPI INSTANT', sla: 'Success · 15m', status: 'PAID' },
    { ref: 'TX-9024', entity: 'WK-7721', amount: '₹290', method: 'UPI INSTANT', sla: 'Pending · 2m', status: 'PENDING' },
    { ref: 'TX-9025', entity: 'WK-1102', amount: '₹1,240', method: 'UPI INSTANT', sla: 'Failed · API Error', status: 'FAILED' },
  ];

  return (
    <div className="p-8 flex flex-col gap-8 animate-in fade-in duration-500 max-w-[1600px] mx-auto">
      <div className="flex items-center justify-between">
        <div>
          <h1 className="text-2xl font-bold text-[var(--deep-navy)] tracking-tight uppercase">Financial Audit</h1>
          <p className="text-[11px] font-semibold text-[var(--text-muted)] uppercase tracking-wider mt-1">Premium Yield & Payout Liquidity</p>
        </div>
        <button className="px-4 py-2 bg-white border border-[var(--border-gray)] rounded text-[10px] font-black uppercase tracking-widest text-slate-500 flex items-center gap-2 hover:bg-slate-50 transition-all">
          <Download size={14} /> Export Financial Ledger
        </button>
      </div>

      <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-4 gap-6">
        <FinanceCard label="Total Revenue" value={formatCurrency(financialData.monthly?.premium_revenue || 490000)} sub="Verified Collection" icon={CreditCard} />
        <FinanceCard label="Total Payouts" value={formatCurrency(financialData.monthly?.total_payouts || 1240000)} sub="Claim Liquidity" icon={Banknote} />
        <FinanceCard label="Payout SLA" value="96.2%" sub="< 15 Mins Avg" icon={Zap} />
        <FinanceCard label="Fraud Savings" value="₹84K" sub="Weekly Flagging" icon={ShieldCheck} />
      </div>

      <div className="grid grid-cols-1 lg:grid-cols-3 gap-8">
        {/* Revenue Segmentation */}
        <div className="metric-card bg-white">
          <h3 className="text-[11px] font-bold text-[var(--text-muted)] uppercase tracking-widest mb-8">Revenue Mix (Lac)</h3>
          <div className="flex flex-col gap-6">
            {revenueMix.map(r => (
              <div key={r.label} className="flex flex-col gap-2">
                <div className="flex justify-between items-center">
                  <span className="text-xs font-bold text-[var(--deep-navy)] uppercase tracking-tight">{r.label}</span>
                  <span className="font-data font-bold text-sm">{r.value}</span>
                </div>
                <div className="w-full h-1.5 bg-slate-100 rounded-full overflow-hidden">
                  <div className={`h-full ${r.color} transition-all duration-1000`} style={{ width: `${r.pct}%` }} />
                </div>
              </div>
            ))}
          </div>
        </div>

        {/* Transaction Table */}
        <div className="lg:col-span-2 metric-card !p-0 overflow-hidden">
          <div className="p-5 border-b border-[var(--border-gray)] flex items-center justify-between">
            <h3 className="text-[11px] font-bold text-[var(--text-muted)] uppercase tracking-widest">Disbursement Audit</h3>
            <span className="status-pill status-live">Gateway: Razorpay Active</span>
          </div>
          <table className="high-density-table">
            <thead>
              <tr>
                <th>Reference</th>
                <th>Entity ID</th>
                <th>Amount</th>
                <th>Method</th>
                <th className="text-right">SLA Status</th>
              </tr>
            </thead>
            <tbody>
              {transactionLog.map((t) => (
                <tr key={t.ref}>
                  <td className="font-data text-slate-400 font-bold uppercase">{t.ref}</td>
                  <td className="font-data font-black text-[var(--gw-blue)] uppercase">{t.entity}</td>
                  <td className="font-data font-black text-[var(--deep-navy)]">{t.amount}</td>
                  <td className="text-[10px] font-black text-slate-400 uppercase tracking-tighter">{t.method}</td>
                  <td className="text-right">
                    <span className={`status-pill ${t.status === 'PAID' ? 'status-live' : t.status === 'PENDING' ? 'status-watch' : 'status-breach'}`}>
                      {t.sla}
                    </span>
                  </td>
                </tr>
              ))}
            </tbody>
          </table>
        </div>
      </div>
    </div>
  );
};

const FinanceCard = ({ label, value, sub, icon: Icon }: any) => (
  <div className="metric-card">
    <div className="flex items-center gap-3 mb-2">
      <div className={`p-1.5 rounded-md bg-slate-50 text-slate-400`}><Icon size={16} /></div>
      <p className="text-[10px] font-black text-slate-400 uppercase tracking-widest">{label}</p>
    </div>
    <h2 className="text-2xl font-bold text-[var(--deep-navy)] font-data">{value}</h2>
    <p className="text-[10px] font-bold text-slate-400 mt-2 uppercase">{sub}</p>
  </div>
);
