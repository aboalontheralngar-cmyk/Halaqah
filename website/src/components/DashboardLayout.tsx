"use client";

import { logOperationalError } from "@/lib/operationalLog";
import {
  useState,
  useMemo,
  useEffect,
  type ComponentType,
  type MouseEvent,
  type ReactNode,
} from "react";
import { useRouter, usePathname } from "next/navigation";
import {
  Home,
  Users,
  ClipboardCheck,
  BookOpen,
  Award,
  FileText,
  BarChart3,
  Settings,
  Menu,
  X,
  Moon,
  Sun,
  ShieldCheck,
  Palmtree,
  Wallet,
  Target,
  AlertTriangle,
  Trophy,
  User,
  Bell,
  LogOut,
  Building2,
  Loader2
} from "lucide-react";
import type { LucideProps } from "lucide-react";
import { useStore } from "@/store/useStore";
import { supabase } from "@/lib/supabase";
import { useShallow } from "zustand/react/shallow";

type NavigationItem = {
  id: string;
  label: string;
  icon: ComponentType<LucideProps>;
  href: string;
  section: "daily" | "people" | "learning" | "management";
};

const sectionLabels: Record<NavigationItem["section"], string> = {
  daily: "عمل اليوم",
  people: "الطلاب والأسر",
  learning: "التعلّم والمتابعة",
  management: "الإدارة",
};

export default function DashboardLayout({ children }: { children: ReactNode }) {
  const router = useRouter();
  const pathname = usePathname();
  const [mobileMenuOpen, setMobileMenuOpen] = useState(false);
  
  const {
    darkMode,
    toggleDarkMode,
    centerType,
    user,
    setUser,
    currentCenter,
    currentSupervisor,
    profile,
    fetchProfile,
    fetchCenterData,
  } = useStore(
    useShallow((state) => ({
      darkMode: state.darkMode,
      toggleDarkMode: state.toggleDarkMode,
      centerType: state.centerType,
      user: state.user,
      setUser: state.setUser,
      currentCenter: state.currentCenter,
      currentSupervisor: state.currentSupervisor,
      profile: state.profile,
      fetchProfile: state.fetchProfile,
      fetchCenterData: state.fetchCenterData,
    })),
  );

  const isAuthPage = pathname === "/login" || pathname === "/onboarding" || pathname === "/select-center";
  const isPublicPage = isAuthPage || pathname.startsWith("/portal");
  const isCenterIndependentPage = pathname.startsWith("/supervision");

  const navItems = useMemo(() => {
    const items: NavigationItem[] = [
      { id: "home", label: "الرئيسية", icon: Home, href: "/", section: "daily" },
      { id: "attendance", label: "الحضور", icon: ClipboardCheck, href: "/attendance", section: "daily" },
      { id: "daily-closing", label: "مراجعة اليوم", icon: ShieldCheck, href: "/daily-closing", section: "daily" },
      { id: "notifications", label: "الإشعارات", icon: Bell, href: "/notifications", section: "daily" },
      { id: "students", label: centerType === 'men' ? "الطلاب" : centerType === 'women' ? "الطالبات" : "الطلاب والطالبات", icon: Users, href: "/students", section: "people" },
      { id: "parents", label: "أولياء الأمور", icon: User, href: "/parents", section: "people" },
      { id: "vacations", label: "الإجازات", icon: Palmtree, href: "/vacations", section: "people" },
      { id: "memorization", label: "الحفظ والمراجعة", icon: BookOpen, href: "/memorization", section: "learning" },
      { id: "plans", label: "الخطط الذكية", icon: Target, href: "/plans", section: "learning" },
      { id: "exams", label: "الامتحانات", icon: FileText, href: "/exams", section: "learning" },
      { id: "reports", label: "التقارير", icon: BarChart3, href: "/reports", section: "learning" },
      { id: "honor-board", label: "لوحة الشرف", icon: Trophy, href: "/honor-board", section: "learning" },
      { id: "daily-excellence", label: "متميزو اليوم", icon: Award, href: "/daily-excellence", section: "learning" },
      { id: "discipline", label: "الانضباط", icon: AlertTriangle, href: "/discipline", section: "management" },
      { id: "points", label: "السلوك والنقاط", icon: ShieldCheck, href: "/points", section: "management" },
      { id: "fund", label: "صندوق الحلقة", icon: Wallet, href: "/fund", section: "management" },
    ];

    if (profile?.role === 'center_admin' || profile?.role === 'supervisor') {
      items.push({ id: "teachers", label: "المعلمون", icon: Users, href: "/teachers", section: "management" });
      items.push({ id: "audit-log", label: "سجل التدقيق", icon: ShieldCheck, href: "/audit-log", section: "management" });
    }

    if (currentSupervisor) {
      items.push({ id: "supervision", label: "لوحة الإشراف", icon: Building2, href: "/supervision", section: "management" });
    }

    items.push({ id: "settings", label: "الإعدادات", icon: Settings, href: "/settings", section: "management" });
    return items;
  }, [centerType, profile?.role, currentSupervisor]);

  const navGroups = useMemo(
    () => (["daily", "people", "learning", "management"] as const)
      .map((section) => ({
        section,
        label: sectionLabels[section],
        items: navItems.filter((item) => item.section === section),
      }))
      .filter((group) => group.items.length > 0),
    [navItems],
  );

  const activeNav = useMemo(() => {
    const current = navItems.find(item => 
      item.href === "/" ? pathname === "/" : pathname.startsWith(item.href)
    );
    return current?.id || "home";
  }, [pathname, navItems]);

  const mobileNavItems = useMemo(() => {
    const primaryIds = new Set(["home", "students", "attendance", "memorization", "reports"]);
    return navItems.filter((item) => primaryIds.has(item.id));
  }, [navItems]);

  useEffect(() => {
    const checkUser = async () => {
      try {
        if (isPublicPage) return;

        if (user && !profile) {
          await fetchProfile();
          const updatedProfile = useStore.getState().profile;
          if (!updatedProfile) {
            router.push("/onboarding");
          }
        } else if (!user) {
          if (!supabase) return;
          const { data } = await supabase.auth.getSession();
          if (data?.session) {
            setUser(data.session.user);
          } else {
            router.push("/login");
          }
        }
      } catch (err) {
        logOperationalError("dashboard.auth_check", err);
      }
    };
    checkUser();
  }, [fetchProfile, isPublicPage, pathname, profile, router, setUser, user]);

  useEffect(() => {
    if (user && currentCenter && profile && !isPublicPage) {
      fetchCenterData();
    }
  }, [user, currentCenter, profile, isPublicPage, fetchCenterData]);

  useEffect(() => {
    if (isPublicPage) return;
    
    if (!user) {
      router.push("/login");
    } else if (!currentCenter && pathname !== "/select-center" && !pathname.startsWith("/manage-center") && !isCenterIndependentPage) {
      router.push("/select-center");
    }
  }, [currentCenter, isCenterIndependentPage, isPublicPage, pathname, router, user]);

  const handleNavClick = (href: string) => {
    router.push(href);
    setMobileMenuOpen(false);
  };

  // --- RENDER LOGIC STARTS HERE ---

  if (isPublicPage || pathname.startsWith("/manage-center") || isCenterIndependentPage) {
    return <div dir="rtl" className={`${darkMode ? "dark" : ""} app-shell min-h-screen`}>{children}</div>;
  }

  if (!user || !currentCenter) {
    return (
      <div className={`${darkMode ? "dark" : ""} min-h-screen flex items-center justify-center bg-[var(--background)]`}>
        <Loader2 className="w-9 h-9 text-[#1f6b5d] animate-spin" />
      </div>
    );
  }

  const centerNameSafe = currentCenter?.name || "المركز";
  const centerInitial = centerNameSafe[0] || "?";

  return (
    <div className={`${darkMode ? "dark" : ""} app-shell min-h-screen flex flex-col lg:flex-row transition-colors duration-200`} dir="rtl">
      <style dangerouslySetInnerHTML={{__html: `
        .sidebar-scroll::-webkit-scrollbar {
          width: 5px;
          height: 0px;
        }
        .sidebar-scroll::-webkit-scrollbar-track {
          background: transparent;
        }
        .sidebar-scroll::-webkit-scrollbar-thumb {
          background: rgba(13, 148, 136, 0.15);
          border-radius: 99px;
        }
        .sidebar-scroll::-webkit-scrollbar-thumb:hover {
          background: rgba(13, 148, 136, 0.35);
        }
        .sidebar-scroll {
          -ms-overflow-style: none;
          scrollbar-width: thin;
          scrollbar-color: rgba(13, 148, 136, 0.15) transparent;
        }
      `}} />
      {/* Mobile Header */}
      <header className="safe-top lg:hidden bg-[color:var(--surface)]/95 backdrop-blur-md border-b border-[var(--border)] px-4 pb-3 flex items-center justify-between sticky top-0 z-50">
        <button aria-label="فتح القائمة الرئيسية" onClick={() => setMobileMenuOpen(true)} className="p-2 text-gray-600 dark:text-gray-300 hover:bg-gray-100 dark:hover:bg-gray-800 rounded-xl transition-colors">
          <Menu className="w-6 h-6" />
        </button>
        <h1 className="text-xl font-extrabold text-[#1f6b5d] dark:text-[#8ed7c5]">حلقتي</h1>
        <button aria-label={darkMode ? "تفعيل الوضع الفاتح" : "تفعيل الوضع الداكن"} onClick={toggleDarkMode} className="p-2 text-gray-600 dark:text-gray-300">
          {darkMode ? <Sun className="w-5 h-5" /> : <Moon className="w-5 h-5" />}
        </button>
      </header>

      {/* Mobile Drawer */}
      {mobileMenuOpen && (
        <div className="fixed inset-0 bg-black/40 backdrop-blur-sm z-50 lg:hidden" onClick={() => setMobileMenuOpen(false)}>
          <div className="safe-top safe-bottom bg-[var(--surface)] w-72 h-full px-4 flex flex-col shadow-2xl animate-in slide-in-from-right duration-300" onClick={(e: MouseEvent<HTMLDivElement>) => e.stopPropagation()}>
            <div className="flex justify-between items-center mb-8 px-2">
              <h2 className="text-xl font-extrabold text-[#1f6b5d] dark:text-[#8ed7c5]">حلقتي</h2>
              <button aria-label="إغلاق القائمة الرئيسية" onClick={() => setMobileMenuOpen(false)} className="p-2 hover:bg-gray-100 dark:hover:bg-gray-800 rounded-full transition-colors">
                <X className="w-5 h-5 text-[var(--muted)]" />
              </button>
            </div>
            <nav className="overflow-y-auto overflow-x-hidden flex-1 sidebar-scroll">
              {navGroups.map((group) => (
                <div key={group.section} className="mb-5">
                  <p className="mb-1.5 px-3 text-[10px] font-extrabold text-[var(--muted)]">{group.label}</p>
                  <div className="space-y-1">
                    {group.items.map((item) => (
                      <button
                        key={item.id}
                        onClick={() => handleNavClick(item.href)}
                        aria-current={activeNav === item.id ? "page" : undefined}
                        className={`w-full flex items-center gap-3 px-3 py-2.5 rounded-xl transition-colors duration-150 ${
                          activeNav === item.id
                            ? "bg-[var(--primary-soft)] text-[var(--primary-ink)] font-bold"
                            : "text-[var(--muted)] hover:bg-[var(--surface-soft)] hover:text-[var(--foreground)]"
                        }`}
                      >
                        <item.icon className="w-4.5 h-4.5" />
                        <span className="text-sm">{item.label}</span>
                      </button>
                    ))}
                  </div>
                </div>
              ))}
            </nav>
          </div>
        </div>
      )}

      {/* Desktop Sidebar */}
      <aside className="hidden lg:flex flex-col w-72 bg-[var(--surface)] border-l border-[var(--border)] h-screen sticky top-0 p-4">
        <div className="mb-6 px-3 flex justify-between items-center">
          <div>
            <h1 className="text-2xl font-extrabold text-[var(--primary)]">حلقتي</h1>
            <p className="text-xs text-[var(--muted)] mt-1">إدارة الحلقة القرآنية</p>
          </div>
          <button aria-label={darkMode ? "تفعيل الوضع الفاتح" : "تفعيل الوضع الداكن"} onClick={toggleDarkMode} className="p-2 rounded-xl bg-gray-100 dark:bg-gray-800 text-gray-600 dark:text-gray-300">
            {darkMode ? <Sun className="w-5 h-5" /> : <Moon className="w-5 h-5" />}
          </button>
        </div>
        
        <nav className="flex-1 overflow-y-auto overflow-x-hidden sidebar-scroll">
          {navGroups.map((group) => (
            <div key={group.section} className="mb-4">
              <p className="mb-1 px-3 text-[10px] font-extrabold text-[var(--muted)]">{group.label}</p>
              <div className="space-y-0.5">
                {group.items.map((item) => (
                  <button
                    key={item.id}
                    onClick={() => handleNavClick(item.href)}
                    aria-current={activeNav === item.id ? "page" : undefined}
                    className={`group w-full flex items-center gap-3 px-3 py-2.5 rounded-xl transition-colors duration-150 ${
                      activeNav === item.id
                        ? "bg-[var(--primary-soft)] text-[var(--primary-ink)]"
                        : "text-[var(--muted)] hover:bg-[var(--surface-soft)] hover:text-[var(--foreground)]"
                    }`}
                  >
                    <item.icon className="w-4.5 h-4.5" />
                    <span className="font-semibold text-sm">{item.label}</span>
                    {activeNav === item.id && (
                      <div className="mr-auto w-1.5 h-1.5 bg-[var(--primary)] rounded-full" />
                    )}
                  </button>
                ))}
              </div>
            </div>
          ))}
        </nav>

        <div className="mt-auto mb-5 p-4 bg-[#f3efe6] dark:bg-[#18231f] rounded-3xl border border-[var(--border)]">
          <div className="flex items-center gap-3">
            <div className={`w-10 h-10 rounded-2xl flex items-center justify-center text-white font-bold ${centerType === 'men' ? "bg-teal-600" : centerType === 'women' ? "bg-rose-500" : "bg-amber-500"}`}>
              {centerInitial}
            </div>
            <div className="flex-1 overflow-hidden">
              <p className="text-xs font-black text-gray-800 dark:text-white truncate">{centerNameSafe}</p>
              <p className="text-[10px] font-bold text-teal-600 dark:text-teal-400 truncate">حلقة: {currentCenter?.activeHalaqa?.name || "عام"}</p>
            </div>
          </div>
        </div>

        <button 
          onClick={() => router.push("/select-center")}
          className="mb-3 p-4 bg-gray-50 dark:bg-gray-800 rounded-2xl border border-gray-100 dark:border-gray-700 group hover:bg-teal-600 transition-all text-right"
        >
          <div className="flex items-center gap-3">
            <div className="w-10 h-10 bg-teal-100 dark:bg-teal-900/30 rounded-2xl flex items-center justify-center text-teal-600 group-hover:bg-white group-hover:text-teal-600 transition-all">
              <Building2 className="w-5 h-5" />
            </div>
            <div>
              <p className="text-xs font-black text-[var(--muted)] group-hover:text-white">تبديل المركز</p>
              <p className="text-[10px] text-gray-400 dark:text-gray-500 group-hover:text-teal-100">إدارة حلقة أخرى</p>
            </div>
          </div>
        </button>

        <button 
          onClick={() => {
            setUser(null);
            router.push("/login");
          }}
          className="p-4 bg-rose-50 dark:bg-rose-900/20 rounded-2xl border border-rose-100/50 dark:border-rose-800/30 group hover:bg-rose-600 transition-all text-right"
        >
          <div className="flex items-center gap-3">
            <div className="w-10 h-10 bg-rose-600 rounded-2xl flex items-center justify-center text-white font-bold group-hover:bg-white group-hover:text-rose-600 transition-all">
              <LogOut className="w-5 h-5" />
            </div>
            <div>
              <p className="text-xs font-black text-rose-900 dark:text-rose-100 group-hover:text-white">تسجيل الخروج</p>
              <p className="text-[10px] text-rose-600 dark:text-rose-400 group-hover:text-rose-100">إنهاء الجلسة الحالية</p>
            </div>
          </div>
        </button>
      </aside>

      {/* Main Content */}
      <main className="app-main safe-main-bottom flex-1">
        <div className="app-page">{children}</div>
      </main>

      {/* Mobile Bottom Nav */}
      <nav className="safe-bottom lg:hidden fixed bottom-0 left-0 right-0 bg-[color:var(--surface)]/95 backdrop-blur-xl border-t border-[var(--border)] px-2 pt-2.5 flex justify-around items-center z-40 shadow-[0_-8px_28px_rgba(23,51,44,0.06)]">
        {mobileNavItems.map((item) => (
          <button
            key={item.id}
            onClick={() => handleNavClick(item.href)}
            aria-label={item.label}
            aria-current={activeNav === item.id ? "page" : undefined}
            className={`flex flex-col items-center gap-1.5 transition-all ${
              activeNav === item.id ? "text-[#1f6b5d] dark:text-[#8ed7c5]" : "text-gray-400 hover:text-gray-600"
            }`}
          >
            <div className={`p-1.5 rounded-xl ${activeNav === item.id ? "bg-[#ddefe8] dark:bg-[#1d4f44]" : ""}`}>
              <item.icon className="w-5 h-5" />
            </div>
            <span className="text-[10px] font-bold">{item.label}</span>
          </button>
        ))}
      </nav>
    </div>
  );
}
