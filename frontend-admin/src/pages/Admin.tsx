import React, { useEffect, useState } from 'react';
import { Settings, ShieldCheck, Database, History, UserPlus } from 'lucide-react';

export const Admin: React.FC = () => {
  const [auditLog, setAuditLog] = useState<any[]>([]);

  useEffect(() => {
    setAuditLog([
      { id: 1, action: 'KYC_VERIFIED', target: 'W001', actor: 'admin', time: '10m ago', details: 'Manual verification completed' },
      { id: 2, action: 'POLICY_CREATED', target: 'W003', actor: 'system', time: '1h ago', details: 'Auto-renewal triggered' },
      { id: 3, action: 'ZONE_ADDED', target: 'Chennai-North', actor: 'admin', time: '3h ago', details: 'New zone configuration' },
      { id: 4, action: 'PAYOUT_APPROVED', target: 'P-4821', actor: 'ML_MODEL', time: '5h ago', details: 'Auto-approved: Rainfall trigger' },
      { id: 5, action: 'FRAUD_ALERT', target: 'W9022', actor: 'ML_MODEL', time: '6h ago', details: 'Device spoofing detected' },
    ]);
  }, []);

  return (
    <div className="flex flex-col gap-8 p-8">
      <div>
        <h1 className="text-2xl font-bold tracking-tight">Admin Controls</h1>
        <p className="text-[var(--color-text-muted)]">System configuration and security audit logs.</p>
      </div>

      <div className="grid grid-cols-1 lg:grid-cols-2 gap-8">
         <div className="flex flex-col gap-6">
            <div className="card">
               <h3 className="text-sm font-bold uppercase tracking-wider text-[var(--color-text-label)] mb-6">System Actions</h3>
               <div className="grid grid-cols-1 md:grid-cols-2 gap-4">
                  <ActionButton icon={UserPlus} label="Manual Registration" color="blue" />
                  <ActionButton icon={ShieldCheck} label="Bulk KYC Verify" color="teal" />
                  <ActionButton icon={Database} label="Sync Data Tables" color="purple" />
                  <ActionButton icon={Settings} label="Global Config" color="amber" />
               </div>
            </div>

            <div className="card flex flex-col gap-4">
               <h3 className="text-sm font-bold uppercase tracking-wider text-[var(--color-text-label)]">Database Metrics</h3>
               <div className="flex justify-between items-center p-4 bg-[var(--color-bg-primary)] rounded border border-[var(--color-border)]">
                  <span className="text-xs font-bold text-[var(--color-text-muted)] uppercase tracking-widest">Postgres Status</span>
                  <span className="text-xs font-black text-[var(--color-accent-teal)] uppercase">Connected (2003)</span>
               </div>
            </div>
         </div>

         <div className="card flex flex-col gap-6">
            <div className="flex items-center gap-2">
               <History size={18} className="text-[var(--color-accent-blue)]" />
               <h3 className="text-sm font-bold uppercase tracking-wider text-[var(--color-text-label)]">Security Audit Log</h3>
            </div>
            <div className="flex flex-col gap-2">
               {auditLog.map(log => (
                 <div key={log.id} className="p-4 bg-[var(--color-bg-primary)] rounded border border-[var(--color-border)] flex justify-between items-center">
                    <div className="flex flex-col">
                       <span className="text-xs font-black uppercase tracking-tighter text-[var(--color-accent-blue)]">{log.action}</span>
                       <span className="text-[10px] font-bold text-[var(--color-text-muted)] uppercase">Target: {log.target}</span>
                    </div>
                    <div className="text-right flex flex-col">
                       <span className="text-[10px] font-bold uppercase">{log.actor}</span>
                       <span className="text-[10px] text-[var(--color-text-muted)] font-medium">{log.time}</span>
                    </div>
                 </div>
               ))}
            </div>
         </div>
      </div>
    </div>
  );
};

const ActionButton: React.FC<{ icon: any, label: string, color: string }> = ({ icon: Icon, label, color }) => (
  <button className="flex items-center gap-3 p-4 bg-[var(--color-bg-primary)] border border-[var(--color-border)] rounded-lg hover:border-[var(--color-accent-blue)] transition-all group">
     <div className={`p-2 rounded bg-[var(--color-accent-${color})]/10 text-[var(--color-accent-${color})]`}>
        <Icon size={18} />
     </div>
     <span className="text-xs font-bold text-[var(--color-text-primary)]">{label}</span>
  </button>
);
