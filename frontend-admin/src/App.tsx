import React, { useState } from 'react';
import { 
  LayoutDashboard, Users, CreditCard, 
  Zap, BrainCircuit, ShieldAlert, Banknote, FileText, Search
} from 'lucide-react';

// CSS Import (Ensuring global styles are loaded)
import './index.css';

// Page Imports
import { SystemOverview } from './pages/SystemOverview';
import { Workers } from './pages/Workers';
import { Financials } from './pages/Financials';
import { Triggers } from './pages/Triggers';
import { AIPredictions } from './pages/AIPredictions';
import { Fraud } from './pages/Fraud';
import { Payouts } from './pages/Payouts';
import { Policies } from './pages/Policies';

type ViewType = 'Overview' | 'Workers' | 'Financials' | 'Triggers' | 'AI Predictions' | 'Fraud' | 'Payouts' | 'Policy Controls';

const App: React.FC = () => {
  const [currentView, setCurrentView] = useState<ViewType>('Overview');
  const [sidebarOpen, setSidebarOpen] = useState(true);

  const renderContent = () => {
    switch (currentView) {
      case 'Overview':        return <SystemOverview />;
      case 'Workers':         return <Workers />;
      case 'Financials':      return <Financials />;
      case 'Triggers':        return <Triggers />;
      case 'AI Predictions':  return <AIPredictions />;
      case 'Fraud':           return <Fraud />;
      case 'Payouts':         return <Payouts />;
      case 'Policy Controls': return <Policies />;
      default:                return <SystemOverview />;
    }
  };

  const NavItem = ({ id, label, icon: Icon, badge, badgeColor }: { id: ViewType, label: string, icon: any, badge?: string, badgeColor?: string }) => {
    const active = currentView === id;
    return (
      <button 
        onClick={() => setCurrentView(id)}
        className={`w-full flex items-center justify-between px-6 py-3 transition-all duration-200 group ${
          active 
            ? 'bg-[#002B54] text-white border-l-4 border-[var(--gw-blue)] shadow-[inset_4px_0_0_0_var(--gw-blue)]' 
            : 'text-slate-400 hover:bg-white/5 hover:text-white border-l-4 border-transparent'
        }`}
      >
        <div className="flex items-center gap-3">
          <Icon size={18} className={active ? 'text-[var(--gw-blue)]' : 'text-slate-500'} />
          {sidebarOpen && <span className={`text-[13px] font-medium tracking-tight ${active ? 'text-white' : ''}`}>{label}</span>}
        </div>
        {sidebarOpen && badge && (
          <span className={`text-[10px] font-black px-1.5 py-0.5 rounded-sm uppercase ${badgeColor} text-white`}>
            {badge}
          </span>
        )}
      </button>
    );
  };

  return (
    <div className="flex h-screen w-screen bg-[var(--light-gray)] overflow-hidden">
      
      {/* 3.2 Sidebar (Operations) */}
      <aside className={`bg-[#0A1526] flex flex-col shrink-0 z-50 shadow-2xl border-r border-slate-800 transition-all duration-300 ${sidebarOpen ? 'w-64' : 'w-20'}`}>
        
        {/* Brand Header */}
        <div className="h-16 px-6 flex items-center gap-3 bg-[var(--deep-navy)] border-b border-slate-800 overflow-hidden">
          <div className="shrink-0 w-8 h-8 flex items-center justify-center cursor-pointer" onClick={() => setSidebarOpen(!sidebarOpen)}>
            <img src="/logo.png" alt="Aegis Logo" className="w-full h-full object-contain" />
          </div>
          {sidebarOpen && <span className="font-bold text-[15px] tracking-tight text-white uppercase whitespace-nowrap">Aegis Console</span>}
        </div>

        <nav className="flex-1 overflow-y-auto py-6 custom-scrollbar overflow-x-hidden">
          <div className={`px-6 pb-2 text-[10px] font-black text-slate-500 uppercase tracking-widest ${!sidebarOpen && 'text-center px-0'}`}>
            {sidebarOpen ? '1. System' : '1'}
          </div>
          <NavItem id="Overview" label="Overview" icon={LayoutDashboard} />
          <NavItem id="Workers" label="Workers" icon={Users} />
          <NavItem id="Financials" label="Financials" icon={CreditCard} />
          
          <div className={`px-6 pt-8 pb-2 text-[10px] font-black text-slate-500 uppercase tracking-widest ${!sidebarOpen && 'text-center px-0'}`}>
            {sidebarOpen ? '2. Operations' : '2'}
          </div>
          <NavItem id="Triggers" label="Triggers" icon={Zap} />
          <NavItem id="AI Predictions" label="AI Predictions" icon={BrainCircuit} />
          <NavItem id="Fraud" label="Fraud" icon={ShieldAlert} badge="18" badgeColor="bg-[var(--red-alert)]" />
          <NavItem id="Payouts" label="Payouts" icon={Banknote} badge="Live" badgeColor="bg-[var(--teal-accent)]" />
          
          <div className={`px-6 pt-8 pb-2 text-[10px] font-black text-slate-500 uppercase tracking-widest ${!sidebarOpen && 'text-center px-0'}`}>
            {sidebarOpen ? '3. Admin' : '3'}
          </div>
          <NavItem id="Policy Controls" label="Policy Controls" icon={FileText} />
        </nav>

        <div className="p-6 bg-black/20 border-t border-white/5">
          <div className="flex items-center gap-2">
            <div className="w-2 h-2 rounded-full bg-[var(--teal-accent)] animate-pulse shrink-0" />
            {sidebarOpen && <span className="text-[10px] font-black tracking-widest text-white/40 uppercase">LIVE SYNC</span>}
          </div>
        </div>
      </aside>

      {/* Workspace */}
      <main className="flex-1 flex flex-col min-w-0 bg-[var(--light-gray)]">
        
        {/* 3.1 Header (Navigation) */}
        <header className="h-16 bg-white border-b border-[var(--border-gray)] flex items-center justify-between px-8 z-40 shrink-0">
          <div className="flex items-center gap-6 flex-1">
            <div className="relative w-80 group">
              <Search className="absolute left-3 top-1/2 -translate-y-1/2 text-slate-400 group-focus-within:text-[var(--gw-blue)]" size={16} />
              <input 
                type="text" 
                placeholder="Global Search (⌘K)" 
                className="w-full bg-[var(--light-gray)] border border-transparent rounded-md pl-10 pr-4 py-2 text-[13px] font-medium focus:bg-white focus:border-[var(--gw-blue)] outline-none transition-all placeholder:text-slate-400"
              />
            </div>
          </div>
          
          <div className="flex items-center gap-4">
            <div className="hidden md:flex items-center gap-2 px-3 py-1.5 bg-[#00A4A410] border border-[#00A4A420] rounded-full">
              <div className="w-1.5 h-1.5 rounded-full bg-[var(--teal-accent)]" />
              <span className="text-[10px] font-black text-[var(--teal-accent)] uppercase tracking-widest">Network Stable</span>
            </div>
            <div className="h-6 w-px bg-[var(--border-gray)] mx-2" />
            <div className="flex items-center gap-3">
              <div className="text-right hidden sm:block">
                <p className="text-[12px] font-bold text-[var(--deep-navy)] leading-none mb-1">Admin Console</p>
                <p className="text-[9px] font-bold text-[var(--text-muted)] uppercase tracking-widest leading-none">Cluster: TN-01</p>
              </div>
              <div className="w-9 h-9 rounded bg-[var(--gw-blue)] text-white flex items-center justify-center font-bold text-sm shadow-sm">AD</div>
            </div>
          </div>
        </header>

        {/* Dynamic Content Area */}
        <div className="flex-1 overflow-y-auto custom-scrollbar">
          <div className="p-8 max-w-[1600px] mx-auto">
            {renderContent()}
          </div>
        </div>

      </main>
    </div>
  );
};

export default App;
