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
      { id: "reports", label: "التقارير", icon: BarChart3, href: "/reports" },
      { id: "notifications", label: "الإشعارات", icon: Bell, href: "/notifications" },
    ];

    if (profile?.role === 'center_admin' || profile?.role === 'supervisor') {
      items.push({ id: "teachers", label: "المعلمون", icon: Users, href: "/teachers" });
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
    return <div dir="rtl" className="min-h-screen bg-gray-50 dark:bg-gray-950">{children}</div>;
  }

  if (!user || !currentCenter) {
    return (
      <div className="min-h-screen flex items-center justify-center bg-gray-50 dark:bg-gray-950">
        <Loader2 className="w-10 h-10 text-teal-600 animate-spin" />
      </div>
    );
  }

  const centerNameSafe = currentCenter?.name || "المركز";
  const centerInitial = centerNameSafe[0] || "?";

  return (
    <div className={`${darkMode ? "dark" : ""} min-h-screen bg-gray-50 dark:bg-gray-950 flex flex-col lg:flex-row transition-colors duration-500`} dir="rtl">
      {/* Mobile Header */}
      <header className="lg:hidden bg-white/80 dark:bg-gray-900/80 backdrop-blur-md border-b border-gray-200 dark:border-gray-800 px-4 py-3 flex items-center justify-between sticky top-0 z-50">
        <button onClick={() => setMobileMenuOpen(true)} className="p-2 text-gray-600 dark:text-gray-300 hover:bg-gray-100 dark:hover:bg-gray-800 rounded-xl transition-colors">
          <Menu className="w-6 h-6" />
        </button>
        <h1 className="text-xl font-bold bg-gradient-to-r from-teal-700 to-teal-500 bg-clip-text text-transparent">حلقتي</h1>
        <button onClick={toggleDarkMode} className="p-2 text-gray-600 dark:text-gray-300">
          {darkMode ? <Sun className="w-5 h-5" /> : <Moon className="w-5 h-5" />}
        </button>
      </header>

      {/* Mobile Drawer */}
      {mobileMenuOpen && (
        <div className="fixed inset-0 bg-black/40 backdrop-blur-sm z-50 lg:hidden" onClick={() => setMobileMenuOpen(false)}>
          <div className="bg-white dark:bg-gray-900 w-72 h-full p-4 flex flex-col shadow-2xl animate-in slide-in-from-right duration-300" onClick={(e) => e.stopPropagation()}>
            <div className="flex justify-between items-center mb-8 px-2">
              <h2 className="text-xl font-bold text-teal-700 dark:text-teal-500">حلقتي</h2>
              <button onClick={() => setMobileMenuOpen(false)} className="p-2 hover:bg-gray-100 dark:hover:bg-gray-800 rounded-full transition-colors">
                <X className="w-5 h-5 text-gray-500 dark:text-gray-400" />
              </button>
            </div>
            <nav className="space-y-1.5 overflow-y-auto flex-1 pr-1 -mr-1">
              {navItems.map((item) => (
                <button
                  key={item.id}
                  onClick={() => handleNavClick(item.href)}
                  className={`w-full flex items-center gap-3 px-4 py-3 rounded-2xl transition-all duration-200 ${
                    activeNav === item.id
                      ? "bg-teal-50 dark:bg-teal-900/20 text-teal-700 dark:text-teal-400 font-bold"
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
      <aside className="hidden lg:flex flex-col w-72 bg-white dark:bg-gray-900 border-l border-gray-100 dark:border-gray-800 h-screen sticky top-0 p-6">
        <div className="mb-10 px-4 flex justify-between items-center">
          <div>
            <h1 className="text-2xl font-black bg-gradient-to-r from-teal-800 to-teal-600 dark:from-teal-400 dark:to-teal-200 bg-clip-text text-transparent">حلقتي</h1>
            <p className="text-xs text-gray-400 mt-1">لوحة إدارة الحلقات القرآنية</p>
          </div>
          <button onClick={toggleDarkMode} className="p-2 rounded-xl bg-gray-100 dark:bg-gray-800 text-gray-600 dark:text-gray-300">
            {darkMode ? <Sun className="w-5 h-5" /> : <Moon className="w-5 h-5" />}
          </button>
        </div>
        
        <nav className="flex-1 space-y-1.5 overflow-y-auto pr-1 -mr-1">
          {navItems.map((item) => (
            <button
              key={item.id}
              onClick={() => handleNavClick(item.href)}
              className={`w-full flex items-center gap-3 px-4 py-3.5 rounded-2xl transition-all duration-200 group ${
                activeNav === item.id
                  ? "bg-teal-600 text-white shadow-lg shadow-teal-200 dark:shadow-none scale-[1.02]"
                  : "text-gray-500 dark:text-gray-400 hover:bg-gray-50 dark:hover:bg-gray-800 hover:text-gray-900 dark:hover:text-white"
              }`}
            >
              <item.icon className={`w-5 h-5 transition-transform group-hover:scale-110 ${activeNav === item.id ? "text-white" : ""}`} />
              <span className="font-semibold text-sm">{item.label}</span>
              {activeNav === item.id && (
                <div className="mr-auto w-1.5 h-1.5 bg-white rounded-full shadow-sm" />
              )}
            </button>
          ))}
        </nav>

        <div className="mt-auto mb-6 p-5 bg-teal-50 dark:bg-teal-900/20 rounded-3xl border border-teal-100/50 dark:border-teal-800/30">
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
      <main className="flex-1 p-4 lg:p-10 pb-24 lg:pb-10 max-w-7xl mx-auto w-full">
        {children}
      </main>

      {/* Mobile Bottom Nav */}
      <nav className="lg:hidden fixed bottom-0 left-0 right-0 bg-white/90 dark:bg-gray-950/90 backdrop-blur-xl border-t border-gray-100 dark:border-gray-800 px-2 py-3 flex justify-around items-center z-40 pb-safe shadow-[0_-10px_40px_rgba(0,0,0,0.05)]">
        {navItems.slice(0, 5).map((item) => (
          <button
            key={item.id}
            onClick={() => handleNavClick(item.href)}
            className={`flex flex-col items-center gap-1.5 transition-all ${
              activeNav === item.id ? "text-teal-600 scale-110" : "text-gray-400 hover:text-gray-600"
            }`}
          >
            <div className={`p-1.5 rounded-xl ${activeNav === item.id ? "bg-teal-50" : ""}`}>
              <item.icon className="w-5 h-5" />
            </div>
            <span className="text-[10px] font-bold">{item.label}</span>
          </button>
        ))}
      </nav>
    </div>
  );
}
