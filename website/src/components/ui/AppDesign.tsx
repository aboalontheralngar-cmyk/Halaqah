"use client";

import type { ReactNode } from "react";
import type { LucideIcon } from "lucide-react";
import { ArrowLeft, Search } from "lucide-react";

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
    <header className="flex flex-col gap-4 md:flex-row md:items-start md:justify-between">
      <div className="flex min-w-0 items-start gap-3">
        {Icon && (
          <span className="flex h-10 w-10 shrink-0 items-center justify-center rounded-2xl bg-[var(--primary-soft)] text-[var(--primary)]">
            <Icon className="h-5 w-5" aria-hidden="true" />
          </span>
        )}
        <div className="min-w-0">
          <h1 className="text-2xl font-extrabold leading-tight text-[var(--foreground)]">
            {title}
          </h1>
          {description && (
            <p className="mt-1 max-w-3xl text-sm font-medium leading-6 text-[var(--muted)]">
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
      className={`rounded-[var(--radius-md)] border border-[var(--border)] bg-[var(--surface)] shadow-[var(--shadow-soft)] ${className}`}
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
    <Surface className="flex items-center gap-3 p-4" >
      <span className={`flex h-10 w-10 shrink-0 items-center justify-center rounded-xl ${style.surface}`}>
        <Icon className={`h-5 w-5 ${style.icon}`} aria-hidden="true" />
      </span>
      <div>
        <p className="text-xl font-extrabold text-[var(--foreground)]">{value}</p>
        <p className="text-xs font-bold text-[var(--muted)]">{label}</p>
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
      <span className="flex h-14 w-14 items-center justify-center rounded-2xl bg-[var(--primary-soft)] text-[var(--primary)]">
        <Icon className="h-8 w-8" aria-hidden="true" />
      </span>
      <h2 className="mt-5 text-lg font-extrabold text-[var(--foreground)]">{title}</h2>
      {description && (
        <p className="mt-2 max-w-md text-sm leading-7 text-[var(--muted)]">{description}</p>
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

export function PageStack({
  children,
  className = "",
}: {
  children: ReactNode;
  className?: string;
}) {
  return <div className={`app-page space-y-6 ${className}`}>{children}</div>;
}

export function SectionHeading({
  title,
  description,
  action,
}: {
  title: string;
  description?: string;
  action?: ReactNode;
}) {
  return (
    <div className="flex flex-col gap-3 sm:flex-row sm:items-end sm:justify-between">
      <div>
        <h2 className="text-lg font-extrabold text-[var(--foreground)]">{title}</h2>
        {description && (
          <p className="mt-1 text-sm leading-6 text-[var(--muted)]">{description}</p>
        )}
      </div>
      {action}
    </div>
  );
}

export function ProgressPanel({
  eyebrow,
  title,
  description,
  progress,
  action,
}: {
  eyebrow: string;
  title: string;
  description?: string;
  progress?: number;
  action?: ReactNode;
}) {
  const safeProgress = Math.min(100, Math.max(0, progress ?? 0));
  return (
    <Surface className="overflow-hidden border-[color:color-mix(in_srgb,var(--primary)_20%,var(--border))] bg-[var(--primary-soft)] p-5 md:p-6">
      <div className="flex flex-col gap-5 md:flex-row md:items-center md:justify-between">
        <div className="min-w-0">
          <p className="text-xs font-extrabold text-[var(--primary)]">{eyebrow}</p>
          <h2 className="mt-1 text-xl font-extrabold text-[var(--primary-ink)]">{title}</h2>
          {description && (
            <p className="mt-1 max-w-2xl text-sm leading-6 text-[color:color-mix(in_srgb,var(--primary-ink)_76%,transparent)]">
              {description}
            </p>
          )}
          {progress !== undefined && (
            <div className="mt-4 flex items-center gap-3">
              <div className="h-2 flex-1 overflow-hidden rounded-full bg-[color:color-mix(in_srgb,var(--surface)_72%,transparent)]">
                <div
                  className="h-full rounded-full bg-[var(--primary)] transition-[width] duration-300"
                  style={{ width: `${safeProgress}%` }}
                />
              </div>
              <span className="text-xs font-extrabold text-[var(--primary)]">{safeProgress}%</span>
            </div>
          )}
        </div>
        {action && <div className="shrink-0">{action}</div>}
      </div>
    </Surface>
  );
}

export function ActionLinkCard({
  title,
  description,
  icon: Icon,
  tone = "teal",
  onClick,
  badge,
}: {
  title: string;
  description?: string;
  icon: LucideIcon;
  tone?: Tone;
  onClick: () => void;
  badge?: ReactNode;
}) {
  const style = toneStyles[tone];
  return (
    <button
      type="button"
      onClick={onClick}
      className="group flex min-h-20 w-full items-center gap-3 rounded-[var(--radius-md)] border border-[var(--border)] bg-[var(--surface)] p-3.5 text-right shadow-[var(--shadow-soft)] transition hover:border-[color:color-mix(in_srgb,var(--primary)_36%,var(--border))] hover:bg-[var(--surface-soft)]"
    >
      <span className={`flex h-10 w-10 shrink-0 items-center justify-center rounded-xl ${style.surface}`}>
        <Icon className={`h-5 w-5 ${style.icon}`} aria-hidden="true" />
      </span>
      <span className="min-w-0 flex-1">
        <span className="block text-sm font-extrabold text-[var(--foreground)]">{title}</span>
        {description && (
          <span className="mt-0.5 block text-xs leading-5 text-[var(--muted)]">{description}</span>
        )}
      </span>
      {badge ?? (
        <ArrowLeft
          className="h-4 w-4 shrink-0 text-[var(--muted)] transition-transform group-hover:-translate-x-0.5"
          aria-hidden="true"
        />
      )}
    </button>
  );
}
