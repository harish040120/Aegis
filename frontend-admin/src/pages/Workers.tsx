import React, { useState } from 'react';
import { Users, Search, MapPin, CheckCircle, Clock, Eye } from 'lucide-react';
import { StatusBadge } from '../components/StatusBadge';

export const Workers: React.FC = () => {
  const [search, setSearch] = useState("");
  const stats = { total: 5, verified_kyc: 5, pending_kyc: 0, active_today: 4 };
  const workers = [
    { worker_id: 'W001', name: 'Shiva Kumar', platform: 'ZOMATO', zone: 'Chennai-Central', kyc_status: 'VERIFIED', policy_status: 'ACTIVE', hours_online: 7.5, deliveries_done: 14 },
    { worker_id: 'W002', name: 'Anand Rajan', platform: 'SWIGGY', zone: 'Chennai-South', kyc_status: 'VERIFIED', policy_status: 'ACTIVE', hours_online: 6.2, deliveries_done: 11 },
    { worker_id: 'W003', name: 'Karthik Selvan', platform: 'ZOMATO', zone: 'Chennai-North', kyc_status: 'VERIFIED', policy_status: 'EXPIRED', hours_online: 0, deliveries_done: 0 },
    { worker_id: 'W004', name: 'Murugan Pillai', platform: 'BOTH', zone: 'Chennai-East', kyc_status: 'VERIFIED', policy_status: 'ACTIVE', hours_online: 5.0, deliveries_done: 8 },
    { worker_id: 'W005', name: 'Priya Lakshmi', platform: 'SWIGGY', zone: 'Coimbatore-Central', kyc_status: 'VERIFIED', policy_status: 'ACTIVE', hours_online: 4.8, deliveries_done: 7 },
  ];

  const filtered = workers.filter(w => 
    w.name.toLowerCase().includes(search.toLowerCase()) || 
    w.worker_id.toLowerCase().includes(search.toLowerCase())
  );

  return (
    <div className="p-8 flex flex-col gap-8 animate-in fade-in duration-500 max-w-[1600px] mx-auto">
      <div className="flex items-center justify-between">
        <div>
          <h1 className="text-2xl font-bold text-[var(--deep-navy)] tracking-tight uppercase">Agent Registry</h1>
          <p className="text-[11px] font-semibold text-[var(--text-muted)] uppercase tracking-wider mt-1">Total Workforce Monitoring</p>
        </div>
        <div className="flex gap-3">
          <div className="relative">
            <Search className="absolute left-3 top-1/2 -translate-y-1/2 text-slate-400" size={14} />
            <input 
              type="text" 
              placeholder="SEARCH BY ID OR NAME..." 
              className="pl-9 pr-4 py-2 bg-white border border-[var(--border-gray)] rounded text-[10px] font-bold w-64 focus:border-[var(--gw-blue)] outline-none tracking-widest"
              value={search}
              onChange={(e) => setSearch(e.target.value)}
            />
          </div>
          <button className="px-4 py-2 bg-[var(--gw-blue)] text-white rounded text-[10px] font-black uppercase tracking-[0.2em] shadow-sm shadow-blue-500/20">
            Register New Agent
          </button>
        </div>
      </div>

      {/* 4.2 Stats Bar */}
      <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-4 gap-6">
        <StatItem label="Total Registered" value={stats.total} icon={Users} />
        <StatItem label="KYC Verified" value={stats.verified_kyc} icon={CheckCircle} color="teal" />
        <StatItem label="KYC Pending" value={stats.pending_kyc} icon={Clock} color="amber" />
        <StatItem label="Active Today" value={stats.active_today} icon={MapPin} color="purple" />
      </div>

      {/* Workers Table */}
      <div className="bg-white border border-[var(--border-gray)] rounded-lg overflow-hidden shadow-sm">
        <table className="high-density-table">
          <thead>
            <tr>
              <th>Agent ID & Name</th>
              <th>Platform</th>
              <th>Zone</th>
              <th>KYC Status</th>
              <th>Coverage</th>
              <th className="text-right">Today's Activity</th>
              <th className="text-right">Actions</th>
            </tr>
          </thead>
          <tbody>
            {filtered.map((w) => {
              const displayId = `WK-${w.worker_id.replace('W', '').padStart(4, '0')}`;
              return (
                <tr key={w.worker_id}>
                  <td>
                    <div className="flex flex-col">
                      <span className="font-bold text-[var(--deep-navy)]">{w.name}</span>
                      <span className="font-data text-[10px] text-[var(--gw-blue)] uppercase">{displayId}</span>
                    </div>
                  </td>
                <td>
                  <span className={`text-[10px] font-black tracking-widest ${w.platform === 'ZOMATO' ? 'text-red-500' : 'text-orange-500'}`}>
                    {w.platform}
                  </span>
                </td>
                <td className="text-xs font-bold text-slate-600 uppercase">{w.zone}</td>
                <td><StatusBadge status={w.kyc_status} /></td>
                <td><StatusBadge status={w.policy_status || 'NONE'} /></td>
                <td className="text-right">
                   <div className="flex flex-col items-end">
                      <span className="text-[10px] font-bold text-[var(--deep-navy)] uppercase tracking-tighter">{w.hours_online || 0}H Online</span>
                      <span className="text-[9px] font-medium text-slate-400 uppercase">{w.deliveries_done || 0} Deliveries</span>
                   </div>
                </td>
                <td className="text-right">
                  <button className="p-2 hover:bg-slate-50 rounded transition-colors text-[var(--gw-blue)]">
                    <Eye size={16} />
                  </button>
                </td>
              </tr>
              );
            })}
          </tbody>
        </table>
      </div>
    </div>
  );
};

const StatItem = ({ label, value, icon: Icon }: any) => (
  <div className="bg-white p-5 rounded-lg border border-[var(--border-gray)] shadow-sm">
    <div className="flex items-center gap-3 mb-2">
      <div className={`p-1.5 rounded-md bg-slate-50 text-slate-400`}><Icon size={16} /></div>
      <p className="text-[10px] font-black text-slate-400 uppercase tracking-widest">{label}</p>
    </div>
    <h2 className="text-2xl font-bold text-[var(--deep-navy)] font-data">{value}</h2>
  </div>
);
