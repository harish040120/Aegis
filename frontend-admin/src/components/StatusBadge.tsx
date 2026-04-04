import React from 'react';
import { clsx, type ClassValue } from 'clsx';
import { twMerge } from 'tailwind-merge';

function cn(...inputs: ClassValue[]) {
  return twMerge(clsx(inputs));
}

interface StatusBadgeProps {
  status: string;
}

export const StatusBadge: React.FC<StatusBadgeProps> = ({ status }) => {
  const s = status.toUpperCase();
  
  const styles: Record<string, string> = {
    APPROVED: 'bg-[var(--color-accent-teal)]/10 text-[var(--color-accent-teal)] border-[var(--color-accent-teal)]/20',
    ACTIVE:   'bg-[var(--color-accent-teal)]/10 text-[var(--color-accent-teal)] border-[var(--color-accent-teal)]/20',
    LOW:      'bg-[var(--color-accent-teal)]/10 text-[var(--color-accent-teal)] border-[var(--color-accent-teal)]/20',
    PENDING:  'bg-[var(--color-accent-amber)]/10 text-[var(--color-accent-amber)] border-[var(--color-accent-amber)]/20',
    WATCH:    'bg-[var(--color-accent-amber)]/10 text-[var(--color-accent-amber)] border-[var(--color-accent-amber)]/20',
    MEDIUM:   'bg-[var(--color-accent-amber)]/10 text-[var(--color-accent-amber)] border-[var(--color-accent-amber)]/20',
    REJECTED: 'bg-[var(--color-accent-red)]/10 text-[var(--color-accent-red)] border-[var(--color-accent-red)]/20',
    HIGH:     'bg-[var(--color-accent-red)]/10 text-[var(--color-accent-red)] border-[var(--color-accent-red)]/20',
    BREACH:   'bg-[var(--color-accent-red)]/10 text-[var(--color-accent-red)] border-[var(--color-accent-red)]/20',
  };

  return (
    <span className={cn(
      "badge border px-2 py-0.5",
      styles[s] || 'bg-gray-500/10 text-gray-400 border-gray-500/20'
    )}>
      {s}
    </span>
  );
};
