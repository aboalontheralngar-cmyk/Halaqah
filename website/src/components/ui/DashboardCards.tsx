import { LucideIcon } from "lucide-react";

interface StatCardProps {
  label: string;
  value: string;
  icon: LucideIcon;
  trend?: string;
  color: "teal" | "blue" | "amber" | "rose" | "cyan";
}

export function StatCard({ label, value, icon: Icon, trend, color }: StatCardProps) {
  const colorClasses = {
    teal: "bg-teal-50 dark:bg-teal-900/20 text-teal-600 dark:text-teal-400",
    blue: "bg-blue-50 dark:bg-blue-900/20 text-blue-600 dark:text-blue-400",
    amber: "bg-amber-50 dark:bg-amber-900/20 text-amber-600 dark:text-amber-400",
    rose: "bg-rose-50 dark:bg-rose-900/20 text-rose-600 dark:text-rose-400",
    cyan: "bg-cyan-50 dark:bg-cyan-900/20 text-cyan-600 dark:text-cyan-400",
  };

  return (
    <div className="bg-white dark:bg-gray-900 p-8 rounded-[2.5rem] border border-gray-100 dark:border-gray-800 shadow-xl shadow-gray-200/20 dark:shadow-none group hover:-translate-y-1 transition-all duration-500">
      <div className="flex items-start justify-between mb-6">
        <div className={`p-4 rounded-2xl ${colorClasses[color]} transition-colors`}>
          <Icon className="w-7 h-7" />
        </div>
        {trend && (
          <span className={`text-[10px] font-black uppercase tracking-widest px-3 py-1 rounded-full ${colorClasses[color]}`}>
            {trend}
          </span>
        )}
      </div>
      <p className="text-[11px] font-black text-gray-400 dark:text-gray-500 uppercase tracking-[0.2em] mb-1">{label}</p>
      <h3 className="text-4xl font-black text-gray-900 dark:text-white tracking-tight">{value}</h3>
    </div>
  );
}

interface ActionButtonProps {
  label: string;
  icon: LucideIcon;
  color: string;
  onClick: () => void;
}

export function ActionButton({ label, icon: Icon, color, onClick }: ActionButtonProps) {
  return (
    <button 
      onClick={onClick}
      className="group flex flex-col items-center justify-center p-8 bg-white dark:bg-gray-900 rounded-[2.5rem] border border-gray-100 dark:border-gray-800 shadow-lg shadow-gray-200/20 dark:shadow-none hover:shadow-2xl hover:shadow-teal-100 dark:hover:shadow-none transition-all duration-500 active:scale-95"
    >
      <div className={`w-16 h-16 bg-gradient-to-br ${color} rounded-2xl flex items-center justify-center text-white mb-4 shadow-lg transition-transform group-hover:scale-110 group-hover:rotate-3`}>
        <Icon className="w-8 h-8" />
      </div>
      <span className="text-sm font-black text-gray-700 dark:text-gray-300 group-hover:text-teal-600 dark:group-hover:text-teal-400 transition-colors">{label}</span>
    </button>
  );
}
