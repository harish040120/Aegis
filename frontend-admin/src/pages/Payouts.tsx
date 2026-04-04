import React from 'react';
import { Download, CreditCard, Clock, Activity, ArrowUpRight } from 'lucide-react';

export const Payouts: React.FC = () => {
  // Mock data for professional display
  const stats = [
    { label: 'Total Paid (Lac)', value: '₹12.4L', sub: 'Active Period', icon: CreditCard },
    { label: 'Avg Payout Time', value: '11 min', sub: 'Razorpay UPI', icon: Clock },
    { label: 'Peak Volume', value: 'Friday', sub: 'Weekly Trend', icon: Activity },
    { label: 'Success Rate', value: '99.8%', sub: 'Gateway Health', icon: ArrowUpRight },
  ];

  const payoutLog = [
    { id: 'WK-4821', trigger: 'Rainfall (82mm)', amount: '₹630', status: 'PAID', time: '2 min ago' },
    { id: 'WK-9022', trigger: 'AQI (220)', amount: '₹480', status: 'PENDING', time: '8 min ago' },
    { id: 'WK-3142', trigger: 'Rainfall (55mm)', amount: '₹150', status: 'PAID', time: '15 min ago' },
    { id: 'WK-1102', trigger: 'Income Loss (48%)', amount: '₹1,240', status: 'BLOCKED', time: '22 min ago' },
    { id: 'WK-0042', trigger: 'Heavy Rain (68mm)', amount: '₹720', status: 'PAID', time: '31 min ago' },
    { id: 'WK-5621', trigger: 'AQI (185)', amount: '₹380', status: 'PAID', time: '45 min ago' },
    { id: 'WK-3302', trigger: 'Base Coverage', amount: '₹85', status: 'PAID', time: '1h ago' },
    { id: 'WK-7721', trigger: 'Rainfall (42mm)', amount: '₹290', status: 'PENDING', time: '1h ago' },
  ];

  return (
    <div className="p-8 flex flex-col gap-8 animate-in fade-in duration-500 max-w-[1600px] mx-auto">
      <div className="flex items-center justify-between">
        <div>
          <h1 className="text-2xl font-bold text-[var(--deep-navy)] tracking-tight uppercase">Payout Management</h1>
          <p className="text-[var(--color-text-muted)] text-[10px] font-bold uppercase tracking-widest mt-1">Real-Time Disbursement Ledger & Audit</p>
        </div>
        <button className="px-4 py-2 bg-white border border-[var(--border-gray)] rounded text-[10px] font-black uppercase tracking-widest text-slate-500 flex items-center gap-2 hover:bg-slate-50 transition-all">
          <Download size={14} /> Download Ledger
        </button>
      </div>

      <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-4 gap-6">
        {stats.map((s) => (
          <div key={s.label} className="metric-card">
            <p className="text-[10px] font-black text-slate-400 uppercase tracking-widest">{s.label}</p>
            <h2 className="text-2xl font-black text-[var(--deep-navy)] data-mono mt-1">{s.value}</h2>
            <p className="text-[9px] font-bold text-slate-400 mt-2 uppercase">{s.sub}</p>
          </div>
        ))}
      </div>

      <div className="grid grid-cols-1 lg:grid-cols-3 gap-8">
        {/* Payout Log */}
        <div className="lg:col-span-2 metric-card !p-0 overflow-hidden">
          <div className="p-5 border-b border-[var(--border-gray)] bg-white flex items-center justify-between">
            <h3 className="text-[11px] font-bold text-[var(--text-muted)] uppercase tracking-widest">Active Payout Stream</h3>
            <span className="status-pill status-live">Live Sync</span>
          </div>
          <table className="high-density-table">
            <thead>
              <tr>
                <th>Agent ID</th>
                <th>Trigger Source</th>
                <th>Disbursement</th>
                <th>Time</th>
                <th className="text-right">Gateway Status</th>
              </tr>
            </thead>
            <tbody>
              {payoutLog.map((p, i) => {
              const displayId = `WK-${p.id.replace('W', '').replace('K-', '').padStart(4, '0')}`;
              return (
                <tr key={i}>
                  <td className="data-mono font-bold text-[var(--gw-blue)] uppercase">{displayId}</td>
                  <td className="text-xs font-bold text-slate-600 uppercase tracking-tight">{p.trigger}</td>
                  <td className="font-black data-mono text-[var(--deep-navy)]">{p.amount}</td>
                  <td className="text-[10px] font-bold text-slate-400 uppercase">{p.time}</td>
                  <td className="text-right">
                    <span className={`status-pill ${p.status === 'PAID' ? 'status-live' : p.status === 'PENDING' ? 'status-watch' : 'status-breach'}`}>
                      {p.status}
                    </span>
                  </td>
                </tr>
              );
            })}
          </tbody>
        </table>
      </div>

        {/* Volume Trend Visual */}
        <div className="metric-card bg-slate-50 border-none">
           <h3 className="text-[11px] font-bold text-[var(--text-muted)] uppercase tracking-widest mb-8">Weekly Volume Peak</h3>
           <div className="flex flex-col gap-4">
              {['Mon', 'Tue', 'Wed', 'Thu', 'Fri'].map(day => (
                <div key={day} className="flex items-center gap-4">
                   <span className="text-[10px] font-bold text-slate-400 w-8">{day}</span>
                   <div className="flex-1 h-2 bg-slate-200 rounded-full overflow-hidden">
                      <div 
                        className={`h-full ${day === 'Fri' ? 'bg-[var(--deep-navy)]' : 'bg-[var(--gw-blue)]'} opacity-80`} 
                        style={{ width: day === 'Fri' ? '95%' : `${40 + Math.random()*40}%` }} 
                      />
                   </div>
                </div>
              ))}
           </div>
           <div className="mt-10 p-4 bg-white rounded border border-slate-200">
              <p className="text-[10px] font-black text-[var(--deep-navy)] uppercase tracking-widest">Actuarial Note</p>
              <p className="text-xs text-slate-500 mt-2 leading-relaxed">
                 Volume tracks daily worker activity; peaks on **Friday** due to weekend delivery surge.
              </p>
           </div>
        </div>
      </div>
    </div>
  );
};
