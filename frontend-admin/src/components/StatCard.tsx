import React from 'react';
import type { LucideIcon } from 'lucide-react';
import { clsx, type ClassValue } from 'clsx';
import { twMerge } from 'tailwind-merge';

function cn(...inputs: ClassValue[]) {
  return twMerge(clsx(inputs));
}

interface StatCardProps {
  title: string;
  value: string | number;
  delta?: string | number;
  deltaType?: 'positive' | 'negative' | 'neutral';
  icon: LucideIcon;
  accentColor?: 'blue' | 'teal' | 'amber' | 'red' | 'purple';
}

export const StatCard: React.FC<StatCardProps> = ({
  title, value, delta, deltaType = 'neutral', icon: Icon, accentColor = 'blue'
}) => {
  const colors = {
    blue: 'text-[var(--color-accent-blue)] bg-[var(--color-accent-blue)]/10',
    teal: 'text-[var(--color-accent-teal)] bg-[var(--color-accent-teal)]/10',
    amber: 'text-[var(--color-accent-amber)] bg-[var(--color-accent-amber)]/10',
    red: 'text-[var(--color-accent-red)] bg-[var(--color-accent-red)]/10',
    purple: 'text-[var(--color-accent-purple)] bg-[var(--color-accent-purple)]/10',
  };

  return (
    <div className="card flex flex-col gap-4">
      <div className="flex items-center justify-between">
        <div className={cn("p-2 rounded-md", colors[accentColor])}>
          <Icon size={20} />
        </div>
        {delta && (
          <span className={cn(
            "text-xs font-medium px-2 py-0.5 rounded-full",
            deltaType === 'positive' && "bg-[var(--color-accent-teal)]/10 text-[var(--color-accent-teal)]",
            deltaType === 'negative' && "bg-[var(--color-accent-red)]/10 text-[var(--color-accent-red)]",
            deltaType === 'neutral' && "bg-[var(--color-text-muted)]/10 text-[var(--color-text-muted)]"
          )}>
            {deltaType === 'positive' ? '↑' : deltaType === 'negative' ? '↓' : ''} {delta}%
          </span>
        )}
      </div>
      <div>
        <p className="text-sm font-medium text-[var(--color-text-label)] mb-1 uppercase tracking-tight">{title}</p>
        <h2 className="text-3xl font-bold tracking-tight">{value}</h2>
      </div>
    </div>
  );
};
