import React from 'react';
import { Settings, ShieldCheck, Lock, Calendar, Save, RotateCcw } from 'lucide-react';

export const Policies: React.FC = () => {
  // 4.7 Policy Controls (Spec data)
  const configs = [
    { label: 'Payout Cap', value: '₹2,000', sub: 'Max Weekly Limit', icon: Lock },
    { label: 'Entry Cost', value: '₹50/week', sub: 'Min Weekly Premium', icon: Settings },
    { label: 'Hard Block', value: '0.6', sub: 'Fraud Threshold', icon: ShieldCheck },
    { label: 'Verification', value: '12 Mo', sub: 'KYC Expiry Cycle', icon: Calendar },
  ];

  return (
    <div className="p-8 flex flex-col gap-8 animate-in fade-in duration-500 max-w-[1600px] mx-auto">
      <div className="flex items-center justify-between">
        <div>
          <h1 className="text-2xl font-bold text-[var(--deep-navy)] tracking-tight uppercase">Admin Governance</h1>
          <p className="text-[11px] font-semibold text-[var(--text-muted)] uppercase tracking-wider mt-1">Global Policy Controls & Governance Logic</p>
        </div>
        <div className="flex gap-3">
          <button className="px-4 py-2 bg-white border border-[var(--border-gray)] rounded text-[10px] font-black uppercase tracking-widest text-slate-500 flex items-center gap-2 hover:bg-slate-50 transition-all">
            <RotateCcw size={14} /> Reset Defaults
          </button>
          <button className="px-4 py-2 bg-[var(--gw-blue)] text-white rounded text-[10px] font-black uppercase tracking-[0.2em] hover:bg-blue-700 transition-all shadow-lg shadow-blue-500/30 flex items-center gap-2">
            <Save size={14} /> Save Deployment
          </button>
        </div>
      </div>

      <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-4 gap-6">
        {configs.map((c) => (
          <div key={c.label} className="metric-card group">
            <div className="flex items-center gap-3 mb-4">
               <div className="p-1.5 bg-slate-50 rounded text-slate-400 group-hover:text-[var(--gw-blue)] transition-colors"><c.icon size={16} /></div>
               <p className="text-[10px] font-black text-slate-400 uppercase tracking-widest">{c.label}</p>
            </div>
            <div className="flex items-center justify-between">
               <h2 className="text-2xl font-bold text-[var(--deep-navy)] font-data">{c.value}</h2>
               <button className="text-[9px] font-bold text-[var(--gw-blue)] uppercase hover:underline">Edit</button>
            </div>
            <p className="text-[9px] font-bold text-slate-400 mt-2 uppercase">{c.sub}</p>
          </div>
        ))}
      </div>

      <div className="grid grid-cols-1 lg:grid-cols-2 gap-8">
         {/* Interaction Logic Rules */}
         <div className="metric-card">
            <h3 className="text-[11px] font-bold text-[var(--text-muted)] uppercase tracking-widest mb-6">Interaction & Business Logic (Section 5)</h3>
            <div className="flex flex-col gap-4">
               {[
                 { rule: 'Fraud Score > 0.6', result: 'Status = Banned + Payout = Blocked', color: 'red' },
                 { rule: 'Value > Threshold', result: 'Status = Breach + Trigger Batch', color: 'blue' },
                 { rule: 'KYC Status == Pending', result: 'Payout = Held for Review', color: 'orange' },
                 { rule: 'Loss Ratio > 85%', result: 'Automated Premium Surcharge', color: 'red' }
               ].map((r, i) => (
                 <div key={i} className="p-4 bg-slate-50 rounded border border-slate-100 flex flex-col gap-2">
                    <p className="text-[10px] font-black text-slate-400 uppercase">RULE {i+1}</p>
                    <div className="flex justify-between items-center">
                       <span className="text-[11px] font-bold text-[var(--deep-navy)] font-mono">{r.rule}</span>
                       <span className={`status-pill ${r.color === 'red' ? 'status-breach' : r.color === 'blue' ? 'status-blue' : 'status-watch'}`}>
                          {r.result}
                       </span>
                    </div>
                 </div>
               ))}
            </div>
         </div>

         {/* Verification Cycle Info */}
         <div className="metric-card bg-[var(--gw-blue)] border-none text-black p-8 relative overflow-hidden">
            <div className="relative z-10 flex flex-col h-full justify-between">
               <div>
                  <h3 className="text-xl font-black leading-tight tracking-tight uppercase">Actuarial Calibration Phase 2</h3>
                  <p className="text-xs text-slate-100 mt-4 leading-relaxed">
                     All percentages currently deployed are actuarially calibrated using zone-level historical disruption frequency and verified earnings loss data from IMD records.
                  </p>
               </div>
               <div className="mt-10">
                  <div className="flex items-center gap-2 mb-2">
                     <div className="w-1.5 h-1.5 rounded-full bg-[var(--teal-accent)]" />
                     <span className="text-[10px] font-black uppercase tracking-widest text-slate-200">Model Confidence: 94.2%</span>
                  </div>
                  <div className="w-full h-1 bg-white/20 rounded-full">
                     <div className="h-full bg-[var(--teal-accent)] w-[94.2%]" />
                  </div>
               </div>
            </div>
            <Lock size={140} className="absolute -right-8 -bottom-8 text-white/20" />
         </div>
      </div>
    </div>
  );
};
