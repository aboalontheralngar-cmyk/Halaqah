"use client";

import type { ReactNode } from "react";
import type { LucideIcon } from "lucide-react";
import { Search } from "lucide-react";

type Tone = "teal" | "green" | "red" | "amber" | "blue" | "purple";

const toneStyles: Record<Tone, { icon: string; surface: string }> = {
  teal: { icon: "text-teal-700 dark:text-teal-300", surface: "bg-teal-50 dark:bg-teal-950/35" },
  green: { icon: "text-green-700 dark:text-green-300", surface: "bg-green-50 dark:bg-green-950/35" },
  red: { icon: "text-red-700 dark:text-red-300", surface: "bg-red-50 dark:bg-red-950/35" },
  amber: { icon: "text-amber-700 dark:text-amber-300", surface: "bg-amber-50 dark:bg-amber-950/35" },
  blue: { icon: "text-blue-700 dark:text-blue-300", surface: "bg-blue-50 dark:bg-blue-950/35" },
  purple: { icon: "text-purple-700 dark:text-purple-300", surface: "bg-purple-50 dark:bg-purple-950/35" },
};

export function PageHeader({
  title,
  description,
  icon: Icon,
  actions,
}: {
  title: string;
  description?: string;
  icon?: LucideIcon;
  actions?: ReactNode;
}) {
  return (
    <header className="flex flex-col gap-5 md:flex-row md:items-start md:justify-between">
      <div className="flex min-w-0 items-start gap-4">
        {Icon && (
          <span className="flex h-11 w-11 shrink-0 items-center justify-center rounded-2xl bg-[#ddefe8] text-[#1f6b5d] dark:bg-[#1d4f44] dark:text-[#b7f3e3]">
            <Icon className="h-6 w-6" aria-hidden="true" />
          </span>
        )}
        <div className="min-w-0">
          <h1 className="text-2xl font-extrabold text-[var(--foreground)] md:text-3xl">
            {title}
          </h1>
          {description && (
            <p className="mt-1.5 max-w-3xl text-sm font-medium leading-7 text-gray-500 dark:text-gray-400">
              {description}
            </p>
          )}
        </div>
      </div>
      {actions && <div className="flex shrink-0 flex-wrap items-center gap-3">{actions}</div>}
    </header>
  );
}

export function Surface({
  children,
  className = "",
}: {
  children: ReactNode;
  className?: string;
}) {
  return (
    <section
      className={`rounded-[22px] border border-[var(--border)] bg-[var(--surface)] shadow-[0_8px_30px_rgba(23,51,44,0.035)] ${className}`}
    >
      {children}
    </section>
  );
}

export function MetricCard({
  label,
  value,
  icon: Icon,
  tone = "teal",
}: {
  label: string;
  value: ReactNode;
  icon: LucideIcon;
  tone?: Tone;
}) {
  const style = toneStyles[tone];
  return (
    <Surface className="flex items-center gap-4 p-5" >
      <span className={`flex h-11 w-11 shrink-0 items-center justify-center rounded-2xl ${style.surface}`}>
        <Icon className={`h-5 w-5 ${style.icon}`} aria-hidden="true" />
      </span>
      <div>
        <p className="text-2xl font-extrabold text-[var(--foreground)]">{value}</p>
        <p className="text-xs font-bold text-gray-500 dark:text-gray-400">{label}</p>
      </div>
    </Surface>
  );
}

export function EmptyState({
  icon: Icon,
  title,
  description,
  action,
}: {
  icon: LucideIcon;
  title: string;
  description?: string;
  action?: ReactNode;
}) {
  return (
    <div className="flex min-h-64 flex-col items-center justify-center px-6 py-12 text-center" role="status">
      <span className="flex h-16 w-16 items-center justify-center rounded-3xl bg-[#ddefe8] text-[#1f6b5d] dark:bg-[#1d4f44] dark:text-[#b7f3e3]">
        <Icon className="h-8 w-8" aria-hidden="true" />
      </span>
      <h2 className="mt-5 text-lg font-extrabold text-[var(--foreground)]">{title}</h2>
      {description && (
        <p className="mt-2 max-w-md text-sm leading-7 text-gray-500 dark:text-gray-400">{description}</p>
      )}
      {action && <div className="mt-6">{action}</div>}
    </div>
  );
}

export function SearchField({
  value,
  onChange,
  placeholder,
  className = "",
}: {
  value: string;
  onChange: (value: string) => void;
  placeholder: string;
  className?: string;
}) {
  return (
    <label className={`relative block w-full ${className}`}>
      <span className="sr-only">{placeholder}</span>
      <Search
        className="pointer-events-none absolute right-4 top-1/2 h-5 w-5 -translate-y-1/2 text-gray-400"
        aria-hidden="true"
      />
      <input
        type="search"
        value={value}
        onChange={(event) => onChange(event.target.value)}
        placeholder={placeholder}
        className="w-full rounded-2xl border border-[var(--border)] bg-[var(--surface-soft)] py-3.5 pl-5 pr-12 text-sm font-bold text-[var(--foreground)] outline-none transition focus:border-[#1f6b5d] focus:bg-[var(--surface)] focus:ring-4 focus:ring-[#1f6b5d]/10"
      />
    </label>
  );
}
