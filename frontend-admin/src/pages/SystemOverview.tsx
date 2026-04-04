import React, { useEffect, useState } from 'react';
import { 
  Users, ShieldCheck, ShieldAlert, TrendingUp, 
  Activity, RefreshCw, ArrowUpRight, Banknote,
  DollarSign, Zap, PieChart, BarChart3
} from 'lucide-react';
import { 
  AreaChart, Area, XAxis, YAxis, CartesianGrid, 
  Tooltip, ResponsiveContainer, BarChart, Bar, PieChart as RePieChart, Pie, Cell, Legend
} from 'recharts';

export const SystemOverview: React.FC = () => {
  const [stats] = useState<any>({
    workersCount: 5,
    policiesCount: 3,
    payoutsToday: { total: 24780, count: 12 },
    fraudToday: { count: 2, avg_fraud_score: 0.34 }
  });
  const [timeline] = useState(getMockDailyTotals());
  const [activeBreaches, setActiveBreaches] = useState<any[]>([]);
  const [financials] = useState<any>(getMockFinancials());
  const [workerStats] = useState<any>(getMockWorkerStats());
  const [liveStats] = useState<any>(getMockLiveStats());

  useEffect(() => {
    setActiveBreaches([]);
  }, []);

  return (
  <div className="flex flex-col gap-6 animate-in fade-in duration-500 max-w-[1600px] mx-auto">

    {/* 3.3 Dashboard Hero Pattern */}
    <div className="bg-white border border-[var(--border-gray)] rounded-lg flex flex-col items-center justify-center py-10 px-8 shadow-sm overflow-hidden relative mb-2">
       <div className="absolute top-0 left-0 w-full h-full opacity-[0.02] pointer-events-none" style={{ backgroundImage: 'radial-gradient(var(--gw-blue) 1px, transparent 0)', backgroundSize: '24px 24px' }} />
       <img src="/main_logo.png" alt="Aegis AIOS" className="h-14 object-contain mb-4 relative z-10 drop-shadow-sm" />
       <p className="text-[10px] font-black text-slate-400 tracking-[0.4em] uppercase relative z-10">Unified Parametric Intelligence Operating System</p>
    </div>

    {/* Page Header */}
    <div className="flex items-center justify-between mb-2">
        <div>
          <h1 className="text-2xl font-bold text-[var(--deep-navy)] tracking-tight uppercase">System Overview</h1>
          <p className="text-[11px] font-semibold text-[var(--text-muted)] uppercase tracking-wider mt-1">Live Operational Data Stream</p>
        </div>
        <button 
          className="flex items-center gap-2 px-4 py-2 bg-white border border-[var(--border-gray)] rounded shadow-sm hover:bg-slate-50 transition-colors text-[11px] font-bold text-[var(--gw-blue)] uppercase tracking-widest"
        >
          <RefreshCw size={14} />
          Live Hub
        </button>
      </div>

      {/* KPI Row (Real Data) */}
      <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-5 gap-4">
        <KpiCard label="Total Workers" value={stats.workersCount} icon={Users} color="blue" sub={workerStats ? `${workerStats.kyc_verified} KYC verified` : 'Loading...'} />
        <KpiCard label="Active Policies" value={stats.policiesCount} icon={ShieldCheck} color="teal" sub={financials ? `₹${Math.round(financials.active_policies_value).toLocaleString()} value` : 'Loading...'} />
        <KpiCard label="Payouts Today" value={`₹${stats.payoutsToday.total.toLocaleString()}`} icon={Banknote} color="amber" sub={`${stats.payoutsToday.count} claims processed`} />
        <KpiCard label="Fraud Alerts" value={stats.fraudToday.count} icon={ShieldAlert} color="red" sub={`${stats.fraudToday.avg_fraud_score}% avg score`} />
        <KpiCard label="Net Revenue (30d)" value={financials ? `₹${Math.round(financials.monthly.net_revenue).toLocaleString()}` : '...'} icon={DollarSign} color="green" sub={financials ? `${financials.monthly.loss_ratio}% loss ratio` : 'Loading...'} />
      </div>

      {/* Charts Section */}
      <div className="grid grid-cols-1 lg:grid-cols-3 gap-6 h-fit">
        
        <div className="col-span-12 lg:col-span-2 metric-card flex flex-col min-h-[450px]">
          <div className="flex items-center justify-between mb-8">
            <h3 className="text-[11px] font-bold text-[var(--text-muted)] uppercase tracking-widest flex items-center gap-2">
              <TrendingUp size={14} className="text-[var(--gw-blue)]" />
              Payout Liquidity (7D Rolling)
            </h3>
          </div>
          
          <div className="flex-1 w-full" style={{ height: '300px', minHeight: '300px' }}>
            <ResponsiveContainer width="100%" height="100%">
              <AreaChart data={timeline} margin={{ top: 10, right: 10, left: -20, bottom: 0 }}>
                <defs>
                  <linearGradient id="colorTotal" x1="0" y1="0" x2="0" y2="1">
                    <stop offset="5%" stopColor="var(--gw-blue)" stopOpacity={0.15}/>
                    <stop offset="95%" stopColor="var(--gw-blue)" stopOpacity={0}/>
                  </linearGradient>
                </defs>
                <CartesianGrid strokeDasharray="3 3" stroke="var(--border-gray)" vertical={false} />
                <XAxis 
                  dataKey="date" 
                  stroke="var(--text-muted)" 
                  fontSize={10} 
                  fontWeight={600}
                  tickFormatter={(str) => new Date(str).toLocaleDateString('en-US', { month: 'short', day: 'numeric' })} 
                />
                <YAxis stroke="var(--text-muted)" fontSize={10} fontWeight={600} />
                <Tooltip 
                  contentStyle={{ backgroundColor: '#fff', border: '1px solid var(--border-gray)', borderRadius: '6px' }}
                  labelStyle={{ fontWeight: 700, color: 'var(--deep-navy)', fontSize: '11px' }}
                />
                <Area type="monotone" dataKey="total" stroke="var(--gw-blue)" strokeWidth={3} fillOpacity={1} fill="url(#colorTotal)" />
              </AreaChart>
            </ResponsiveContainer>
          </div>
        </div>

        <div className="col-span-12 lg:col-span-1 flex flex-col gap-6">
          <div className="metric-card flex-1">
            <h3 className="text-[11px] font-bold text-[var(--text-muted)] uppercase tracking-widest mb-6">Real-Time Breaches</h3>
            <div className="flex flex-col gap-4">
              {activeBreaches.length === 0 ? (
                <div className="text-center py-10">
                  <div className="w-12 h-12 bg-emerald-50 rounded-full flex items-center justify-center text-[var(--teal-accent)] mx-auto mb-3">
                    <ShieldCheck size={24} />
                  </div>
                  <p className="text-[11px] font-bold text-slate-400 uppercase tracking-widest">All conditions normal</p>
                </div>
              ) : (
                activeBreaches.map(b => (
                  <div key={b.type} className={`p-4 bg-[var(--light-gray)] border-l-4 rounded-r-md ${b.status === 'BREACH' ? 'border-l-[var(--red-alert)]' : 'border-l-[var(--orange-warning)]'}`}>
                    <div className="flex justify-between items-center mb-2">
                      <div className="flex items-center gap-2">
                        <b.icon size={14} className={b.status === 'BREACH' ? 'text-[var(--red-alert)]' : 'text-[var(--orange-warning)]'} />
                        <span className="text-[11px] font-bold text-[var(--deep-navy)] uppercase">{b.type}</span>
                      </div>
                      <span className={`status-pill ${b.status === 'BREACH' ? 'status-breach' : 'status-watch'}`}>{b.status}</span>
                    </div>
                    <span className="text-xl font-bold font-data">{b.value}</span>
                  </div>
                ))
              )}
            </div>
          </div>
        </div>

      </div>

      {/* Worker Distribution & Risk Analysis */}
      <div className="grid grid-cols-1 lg:grid-cols-2 gap-6">
        
        {/* Worker Platform Distribution */}
        <div className="metric-card">
          <h3 className="text-[11px] font-bold text-[var(--text-muted)] uppercase tracking-widest mb-6 flex items-center gap-2">
            <PieChart size={14} className="text-[var(--gw-blue)]" />
            Worker Distribution by Platform
          </h3>
          <div style={{ height: '280px' }}>
            <ResponsiveContainer width="100%" height="100%">
              <RePieChart>
                <Pie
                  data={workerStats ? Object.entries(workerStats.by_platform).map(([name, value]) => ({ name, value })) : []}
                  cx="50%"
                  cy="50%"
                  labelLine={false}
                  label={({ name, percent }) => `${name} (${((percent || 0) * 100).toFixed(0)}%)`}
                  outerRadius={80}
                  fill="#8884d8"
                  dataKey="value"
                >
                  {workerStats && Object.keys(workerStats.by_platform).map((_entry, index) => {
                    const colors = ['#0066CC', '#00A896', '#F59E0B', '#EF4444', '#8B5CF6'];
                    return <Cell key={`cell-${index}`} fill={colors[index % colors.length]} />;
                  })}
                </Pie>
                <Tooltip />
                <Legend />
              </RePieChart>
            </ResponsiveContainer>
          </div>
        </div>

        {/* Risk Distribution */}
        <div className="metric-card">
          <h3 className="text-[11px] font-bold text-[var(--text-muted)] uppercase tracking-widest mb-6 flex items-center gap-2">
            <BarChart3 size={14} className="text-[var(--gw-blue)]" />
            Risk Distribution (Today)
          </h3>
          <div style={{ height: '280px' }}>
            <ResponsiveContainer width="100%" height="100%">
              <BarChart data={liveStats ? Object.entries(liveStats.risk_distribution).map(([name, value]) => ({ name, value })) : []} margin={{ top: 10, right: 10, left: -20, bottom: 0 }}>
                <CartesianGrid strokeDasharray="3 3" stroke="var(--border-gray)" vertical={false} />
                <XAxis dataKey="name" stroke="var(--text-muted)" fontSize={10} fontWeight={600} />
                <YAxis stroke="var(--text-muted)" fontSize={10} fontWeight={600} />
                <Tooltip 
                  contentStyle={{ backgroundColor: '#fff', border: '1px solid var(--border-gray)', borderRadius: '6px' }}
                  labelStyle={{ fontWeight: 700, color: 'var(--deep-navy)', fontSize: '11px' }}
                />
                <Bar dataKey="value" fill="var(--gw-blue)" radius={[8, 8, 0, 0]} />
              </BarChart>
            </ResponsiveContainer>
          </div>
        </div>

      </div>

      {/* Financial Summary */}
      {financials && (
        <div className="metric-card">
          <h3 className="text-[11px] font-bold text-[var(--text-muted)] uppercase tracking-widest mb-6 flex items-center gap-2">
            <DollarSign size={14} className="text-[var(--gw-blue)]" />
            Financial Performance (Last 30 Days)
          </h3>
          <div className="grid grid-cols-1 md:grid-cols-4 gap-6">
            <FinancialMetric 
              label="Premium Revenue" 
              value={`₹${Math.round(financials.monthly.premium_revenue).toLocaleString()}`} 
              trend="+12.3%" 
              positive={true}
            />
            <FinancialMetric 
              label="Total Payouts" 
              value={`₹${Math.round(financials.monthly.total_payouts).toLocaleString()}`} 
              trend="-5.2%" 
              positive={true}
            />
            <FinancialMetric 
              label="Net Revenue" 
              value={`₹${Math.round(financials.monthly.net_revenue).toLocaleString()}`} 
              trend="+18.7%" 
              positive={true}
            />
            <FinancialMetric 
              label="Loss Ratio" 
              value={`${financials.monthly.loss_ratio}%`} 
              trend="-3.1%" 
              positive={true}
              info="Lower is better"
            />
          </div>
        </div>
      )}

      {/* Live Operations Stats */}
      {liveStats && (
        <div className="metric-card">
          <h3 className="text-[11px] font-bold text-[var(--text-muted)] uppercase tracking-widest mb-6 flex items-center gap-2">
            <Zap size={14} className="text-[var(--gw-blue)]" />
            Live Operations Dashboard
          </h3>
          <div className="grid grid-cols-1 md:grid-cols-4 gap-6">
            <LiveMetric 
              label="Recent Analyses (1h)" 
              value={liveStats.recent_analyses} 
              icon={Activity}
              color="blue"
            />
            <LiveMetric 
              label="Active Sessions Today" 
              value={liveStats.active_sessions_today} 
              icon={Users}
              color="teal"
            />
            <LiveMetric 
              label="Avg Payout Amount" 
              value={`₹${Math.round(liveStats.avg_payout_amount)}`} 
              icon={Banknote}
              color="amber"
            />
            <LiveMetric 
              label="Payout Approvals" 
              value={liveStats.payout_status?.APPROVED || 0} 
              icon={ShieldCheck}
              color="green"
            />
          </div>
        </div>
      )}

    </div>
  );
};

const KpiCard = ({ label, value, sub, icon: Icon }: any) => (
  <div className="metric-card">
    <div className="flex justify-between items-start mb-2">
      <div className={`p-2 rounded bg-slate-50 text-slate-400`}><Icon size={18} /></div>
      <ArrowUpRight size={16} className="text-slate-200" />
    </div>
    <div>
      <p className="text-[10px] font-bold text-[var(--text-muted)] uppercase tracking-widest">{label}</p>
      <h2 className="text-2xl font-bold text-[var(--deep-navy)] font-data mt-1">{value}</h2>
      <p className="text-[10px] font-bold text-slate-400 mt-2 uppercase">{sub}</p>
    </div>
  </div>
);

const FinancialMetric = ({ label, value, trend, positive, info }: any) => (
  <div className="flex flex-col">
    <p className="text-[10px] font-bold text-[var(--text-muted)] uppercase tracking-widest mb-2">{label}</p>
    <h3 className="text-2xl font-bold text-[var(--deep-navy)] font-data mb-1">{value}</h3>
    <div className="flex items-center gap-2">
      <span className={`text-[10px] font-bold ${positive ? 'text-green-600' : 'text-red-600'}`}>{trend}</span>
      {info && <span className="text-[9px] text-slate-400">{info}</span>}
    </div>
  </div>
);

const LiveMetric = ({ label, value, icon: Icon }: any) => (
  <div className="flex flex-col items-center justify-center p-4 bg-slate-50 rounded-lg">
    <Icon size={20} className="text-slate-400 mb-2" />
    <h3 className="text-2xl font-bold text-[var(--deep-navy)] font-data">{value}</h3>
    <p className="text-[10px] font-bold text-[var(--text-muted)] uppercase tracking-widest mt-1 text-center">{label}</p>
  </div>
);

// Mock Data Functions for Professional Demo
const getMockDailyTotals = () => [
  { date: '2026-03-29', total: 18240 },
  { date: '2026-03-30', total: 21560 },
  { date: '2026-03-31', total: 19870 },
  { date: '2026-04-01', total: 24120 },
  { date: '2026-04-02', total: 22450 },
  { date: '2026-04-03', total: 26780 },
  { date: '2026-04-04', total: 24780 },
];

const getMockFinancials = () => ({
  monthly: {
    premium_revenue: 842000,
    total_payouts: 324000,
    net_revenue: 518000,
    loss_ratio: 38.5
  },
  active_policies_value: 1264000
});

const getMockWorkerStats = () => ({
  kyc_verified: 5,
  by_platform: { ZOMATO: 3, SWIGGY: 2, BOTH: 0 }
});

const getMockLiveStats = () => ({
  risk_distribution: { LOW: 12, MEDIUM: 8, HIGH: 3, CRITICAL: 1 },
  recent_analyses: 47,
  active_sessions_today: 24,
  avg_payout_amount: 1850,
  payout_status: { APPROVED: 18, HELD: 4, BANNED: 1 }
});
