"use client";

import { useState, useMemo, useEffect } from "react";
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
import { useStore } from "@/store/useStore";
import { supabase } from "@/lib/supabase";

export default function DashboardLayout({ children }: { children: React.ReactNode }) {
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
    profile, 
    fetchProfile,
    fetchCenterData 
  } = useStore();

  const isAuthPage = pathname === "/login" || pathname === "/onboarding" || pathname === "/select-center";

  const navItems = useMemo(() => {
    const items = [
      { id: "home", label: "الرئيسية", icon: Home, href: "/" },
      { id: "students", label: centerType === 'men' ? "الطلاب" : centerType === 'women' ? "الطالبات" : "الطلاب والطالبات", icon: Users, href: "/students" },
      { id: "parents", label: "أولياء الأمور", icon: User, href: "/parents" },
      { id: "attendance", label: "الحضور", icon: ClipboardCheck, href: "/attendance" },
      { id: "discipline", label: "الانضباط", icon: AlertTriangle, href: "/discipline" },
      { id: "memorization", label: "الحفظ", icon: BookOpen, href: "/memorization" },
      { id: "plans", label: "الخطط الذكية", icon: Target, href: "/plans" },
      { id: "points", label: "السلوك والنقاط", icon: ShieldCheck, href: "/points" },
      { id: "fund", label: "صندوق الحلقة", icon: Wallet, href: "/fund" },
      { id: "vacations", label: "الإجازات", icon: Palmtree, href: "/vacations" },
      { id: "exams", label: "الامتحانات", icon: FileText, href: "/exams" },
      { id: "honor-board", label: "لوحة الشرف", icon: Trophy, href: "/honor-board" },
      { id: "daily-excellence", label: "متميزو اليوم", icon: Award, href: "/daily-excellence" },
      { id: "reports", label: "التقارير", icon: BarChart3, href: "/reports" },
      { id: "notifications", label: "الإشعارات", icon: Bell, href: "/notifications" },
    ];

    if (profile?.role === 'center_admin' || profile?.role === 'supervisor') {
      items.push({ id: "teachers", label: "المعلمون", icon: Users, href: "/teachers" });
      items.push({ id: "audit-log", label: "سجل التدقيق", icon: ShieldCheck, href: "/audit-log" });
    }

    items.push({ id: "settings", label: "الإعدادات", icon: Settings, href: "/settings" });
    return items;
  }, [centerType, profile?.role]);

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
        if (isAuthPage) return;

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
        console.error("Auth check error:", err);
      }
    };
    checkUser();
  }, [user, profile, pathname, isAuthPage]);

  useEffect(() => {
    if (user && currentCenter && profile && !isAuthPage) {
      fetchCenterData();
    }
  }, [user, currentCenter, profile, isAuthPage, fetchCenterData]);

  useEffect(() => {
    if (isAuthPage) return;
    
    if (!user) {
      router.push("/login");
    } else if (!currentCenter && pathname !== "/select-center" && !pathname.startsWith("/manage-center")) {
      router.push("/select-center");
    }
  }, [user, currentCenter, pathname, isAuthPage]);

  const handleNavClick = (href: string) => {
    router.push(href);
    setMobileMenuOpen(false);
  };

  // --- RENDER LOGIC STARTS HERE ---

  if (isAuthPage || pathname.startsWith("/manage-center")) {
    return <div dir="rtl" className={`${darkMode ? "dark" : ""} min-h-screen bg-[var(--background)] text-[var(--foreground)]`}>{children}</div>;
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
    <div className={`${darkMode ? "dark" : ""} min-h-screen bg-[var(--background)] text-[var(--foreground)] flex flex-col lg:flex-row transition-colors duration-300`} dir="rtl">
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
          <div className="safe-top safe-bottom bg-[var(--surface)] w-72 h-full px-4 flex flex-col shadow-2xl animate-in slide-in-from-right duration-300" onClick={(e) => e.stopPropagation()}>
            <div className="flex justify-between items-center mb-8 px-2">
              <h2 className="text-xl font-extrabold text-[#1f6b5d] dark:text-[#8ed7c5]">حلقتي</h2>
              <button aria-label="إغلاق القائمة الرئيسية" onClick={() => setMobileMenuOpen(false)} className="p-2 hover:bg-gray-100 dark:hover:bg-gray-800 rounded-full transition-colors">
                <X className="w-5 h-5 text-gray-500 dark:text-gray-400" />
              </button>
            </div>
            <nav className="space-y-1.5 overflow-y-auto overflow-x-hidden flex-1 sidebar-scroll">
              {navItems.map((item) => (
                <button
                  key={item.id}
                  onClick={() => handleNavClick(item.href)}
                  aria-current={activeNav === item.id ? "page" : undefined}
                  className={`w-full flex items-center gap-3 px-4 py-3 rounded-2xl transition-all duration-200 ${
                    activeNav === item.id
                      ? "bg-[#ddefe8] dark:bg-[#1d4f44] text-[#174f45] dark:text-[#b7f3e3] font-bold"
                      : "text-gray-500 dark:text-gray-400 hover:bg-gray-50 dark:hover:bg-gray-800 hover:text-gray-900 dark:hover:text-white"
                  }`}
                >
                  <item.icon className="w-5 h-5" />
                  <span className="text-sm">{item.label}</span>
                </button>
              ))}
            </nav>
          </div>
        </div>
      )}

      {/* Desktop Sidebar */}
      <aside className="hidden lg:flex flex-col w-72 bg-[var(--surface)] border-l border-[var(--border)] h-screen sticky top-0 p-5">
        <div className="mb-10 px-4 flex justify-between items-center">
          <div>
            <h1 className="text-2xl font-extrabold text-[#1f6b5d] dark:text-[#8ed7c5]">حلقتي</h1>
            <p className="text-xs text-gray-400 mt-1">لوحة إدارة الحلقات القرآنية</p>
          </div>
          <button aria-label={darkMode ? "تفعيل الوضع الفاتح" : "تفعيل الوضع الداكن"} onClick={toggleDarkMode} className="p-2 rounded-xl bg-gray-100 dark:bg-gray-800 text-gray-600 dark:text-gray-300">
            {darkMode ? <Sun className="w-5 h-5" /> : <Moon className="w-5 h-5" />}
          </button>
        </div>
        
        <nav className="flex-1 space-y-1.5 overflow-y-auto overflow-x-hidden sidebar-scroll">
          {navItems.map((item) => (
            <button
              key={item.id}
              onClick={() => handleNavClick(item.href)}
              aria-current={activeNav === item.id ? "page" : undefined}
              className={`w-full flex items-center gap-3 px-4 py-3.5 rounded-2xl transition-all duration-200 group ${
                activeNav === item.id
                  ? "bg-[#ddefe8] text-[#174f45] dark:bg-[#1d4f44] dark:text-[#b7f3e3]"
                  : "text-gray-500 dark:text-gray-400 hover:bg-gray-50 dark:hover:bg-gray-800 hover:text-gray-900 dark:hover:text-white"
              }`}
            >
              <item.icon className="w-5 h-5 transition-transform group-hover:scale-105" />
              <span className="font-semibold text-sm">{item.label}</span>
              {activeNav === item.id && (
                <div className="mr-auto w-1.5 h-1.5 bg-[#1f6b5d] dark:bg-[#8ed7c5] rounded-full" />
              )}
            </button>
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
              <p className="text-xs font-black text-gray-500 dark:text-gray-400 group-hover:text-white">تبديل المركز</p>
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
      <main className="safe-main-bottom flex-1 p-4 lg:p-8 max-w-[1440px] mx-auto w-full">
        {children}
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
