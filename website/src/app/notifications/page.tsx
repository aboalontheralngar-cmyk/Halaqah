"use client";

import { useState, useMemo } from "react";
import {
  Bell,
  Check,
  X,
  Trash2,
  MessageSquare,
  AlertCircle,
  CheckCircle,
  Info,
  Clock,
  Filter,
  Archive,
} from "lucide-react";
import { useStore } from "@/store/useStore";

interface Notification {
  id: string;
  type: "warning" | "success" | "info" | "alert";
  title: string;
  message: string;
  date: string;
  read: boolean;
  relatedTo?: "student" | "attendance" | "behavior" | "exam";
  relatedId?: string;
}

export default function NotificationsPage() {
  const { students } = useStore();

  // محاكاة إشعارات
  const [notifications, setNotifications] = useState<Notification[]>([
    {
      id: "1",
      type: "warning",
      title: "غياب متكرر",
      message: "أحمد محمد غاب 3 مرات في الأسبوع الماضي",
      date: new Date(Date.now() - 1000 * 60 * 30).toISOString(),
      read: false,
      relatedTo: "attendance",
      relatedId: "1",
    },
    {
      id: "2",
      type: "success",
      title: "نتيجة ممتازة",
      message: "عمر علي حقق 95/100 في اختبار التسميع",
      date: new Date(Date.now() - 1000 * 60 * 60 * 2).toISOString(),
      read: false,
      relatedTo: "exam",
      relatedId: "2",
    },
    {
      id: "3",
      type: "info",
      title: "تنبيه نظامي",
      message: "تم تحديث نسخة التطبيق إلى v2.1.0",
      date: new Date(Date.now() - 1000 * 60 * 60 * 5).toISOString(),
      read: true,
    },
    {
      id: "4",
      type: "alert",
      title: "سلوك سلبي",
      message: "خالد يوسف حصل على 2 نقاط سلبية في السلوك",
      date: new Date(Date.now() - 1000 * 60 * 60 * 24).toISOString(),
      read: true,
      relatedTo: "behavior",
      relatedId: "3",
    },
  ]);

  const [filterType, setFilterType] = useState<"all" | Notification["type"]>("all");
  const [showArchived, setShowArchived] = useState(false);

  const filteredNotifications = useMemo(() => {
    let filtered = notifications.filter((n) => n.read === showArchived);
    if (filterType !== "all") {
      filtered = filtered.filter((n) => n.type === filterType);
    }
    return filtered.sort(
      (a, b) =>
        new Date(b.date).getTime() - new Date(a.date).getTime()
    );
  }, [notifications, filterType, showArchived]);

  const stats = useMemo(() => {
    return {
      unread: notifications.filter((n) => !n.read).length,
      total: notifications.length,
      warnings: notifications.filter((n) => n.type === "warning").length,
      success: notifications.filter((n) => n.type === "success").length,
    };
  }, [notifications]);

  const getNotificationIcon = (type: Notification["type"]) => {
    switch (type) {
      case "warning":
        return <AlertCircle className="w-5 h-5" />;
      case "success":
        return <CheckCircle className="w-5 h-5" />;
      case "info":
        return <Info className="w-5 h-5" />;
      case "alert":
        return <AlertCircle className="w-5 h-5" />;
    }
  };

  const getNotificationColor = (type: Notification["type"]) => {
    switch (type) {
      case "warning":
        return "bg-orange-50 dark:bg-orange-900/20 border-orange-200 dark:border-orange-800 text-orange-900 dark:text-orange-100";
      case "success":
        return "bg-green-50 dark:bg-green-900/20 border-green-200 dark:border-green-800 text-green-900 dark:text-green-100";
      case "info":
        return "bg-blue-50 dark:bg-blue-900/20 border-blue-200 dark:border-blue-800 text-blue-900 dark:text-blue-100";
      case "alert":
        return "bg-red-50 dark:bg-red-900/20 border-red-200 dark:border-red-800 text-red-900 dark:text-red-100";
    }
  };

  const getNotificationBadgeColor = (type: Notification["type"]) => {
    switch (type) {
      case "warning":
        return "bg-orange-100 dark:bg-orange-900/30 text-orange-600 dark:text-orange-400";
      case "success":
        return "bg-green-100 dark:bg-green-900/30 text-green-600 dark:text-green-400";
      case "info":
        return "bg-blue-100 dark:bg-blue-900/30 text-blue-600 dark:text-blue-400";
      case "alert":
        return "bg-red-100 dark:bg-red-900/30 text-red-600 dark:text-red-400";
    }
  };

  const formatTime = (dateStr: string) => {
    const date = new Date(dateStr);
    const now = new Date();
    const diff = now.getTime() - date.getTime();

    const minutes = Math.floor(diff / 1000 / 60);
    const hours = Math.floor(diff / 1000 / 60 / 60);
    const days = Math.floor(diff / 1000 / 60 / 60 / 24);

    if (minutes < 1) return "للتو";
    if (minutes < 60) return `منذ ${minutes} دقيقة`;
    if (hours < 24) return `منذ ${hours} ساعة`;
    if (days < 7) return `منذ ${days} يوم`;
    return date.toLocaleDateString("ar-SA");
  };

  return (
    <div className="space-y-10 animate-in fade-in slide-in-from-bottom-4 duration-700 pb-20">
      {/* Header */}
      <div className="flex flex-col md:flex-row md:items-center justify-between gap-6">
        <div>
          <h1 className="text-3xl font-black text-gray-900 dark:text-white tracking-tight flex items-center gap-4">
            <Bell className="w-8 h-8" />
            مركز الإشعارات
          </h1>
          <p className="text-gray-500 dark:text-gray-400 mt-2 font-medium">
            متابعة تنبيهات الطلاب والأنشطة في الحلقة
          </p>
        </div>
      </div>

      {/* Stats */}
      <div className="grid md:grid-cols-4 gap-4">
        <div className="bg-white dark:bg-gray-900 border border-gray-200 dark:border-gray-800 rounded-2xl p-6">
          <p className="text-xs font-bold text-gray-500 uppercase mb-3">إجمالي الإشعارات</p>
          <p className="text-3xl font-black text-teal-600">{stats.total}</p>
        </div>
        <div className="bg-red-50 dark:bg-red-900/20 border border-red-200 dark:border-red-800 rounded-2xl p-6">
          <p className="text-xs font-bold text-red-600 uppercase mb-3">غير مقروءة</p>
          <p className="text-3xl font-black text-red-600">{stats.unread}</p>
        </div>
        <div className="bg-orange-50 dark:bg-orange-900/20 border border-orange-200 dark:border-orange-800 rounded-2xl p-6">
          <p className="text-xs font-bold text-orange-600 uppercase mb-3">تحذيرات</p>
          <p className="text-3xl font-black text-orange-600">{stats.warnings}</p>
        </div>
        <div className="bg-green-50 dark:bg-green-900/20 border border-green-200 dark:border-green-800 rounded-2xl p-6">
          <p className="text-xs font-bold text-green-600 uppercase mb-3">نجاحات</p>
          <p className="text-3xl font-black text-green-600">{stats.success}</p>
        </div>
      </div>

      {/* Filters */}
      <div className="flex flex-col md:flex-row md:items-center gap-4">
        <div className="flex items-center gap-2 flex-wrap">
          {(["all", "warning", "success", "info", "alert"] as const).map((type) => (
            <button
              key={type}
              onClick={() => setFilterType(type)}
              className={`px-6 py-2 rounded-full font-bold text-sm transition-all whitespace-nowrap ${
                filterType === type
                  ? "bg-gray-900 text-white dark:bg-white dark:text-gray-900"
                  : "bg-gray-100 text-gray-700 dark:bg-gray-800 dark:text-gray-300 hover:bg-gray-200 dark:hover:bg-gray-700"
              }`}
            >
              {type === "all" ? "الكل" : type === "warning" ? "تحذيرات" : type === "success" ? "نجاحات" : type === "info" ? "معلومات" : "تنبيهات"}
            </button>
          ))}
        </div>
        <button
          onClick={() => setShowArchived(!showArchived)}
          className="ml-auto px-6 py-2 bg-gray-100 dark:bg-gray-800 text-gray-700 dark:text-gray-300 rounded-full font-bold text-sm hover:bg-gray-200 dark:hover:bg-gray-700 transition-all flex items-center gap-2"
        >
          <Archive className="w-4 h-4" />
          {showArchived ? "جاري العرض: الأرشيف" : "جاري العرض: جديد"}
        </button>
      </div>

      {/* Notifications List */}
      <div className="space-y-3">
        {filteredNotifications.length === 0 ? (
          <div className="text-center py-12 bg-gray-50 dark:bg-gray-900 rounded-2xl border-2 border-dashed border-gray-300 dark:border-gray-700">
            <Bell className="w-16 h-16 text-gray-300 mx-auto mb-4" />
            <p className="text-gray-500 dark:text-gray-400 font-bold text-lg">
              {showArchived ? "لا توجد إشعارات مؤرشفة" : "لا توجد إشعارات جديدة"}
            </p>
          </div>
        ) : (
          filteredNotifications.map((notification) => (
            <div
              key={notification.id}
              className={`border-2 rounded-2xl p-4 md:p-6 transition-all hover:shadow-lg ${getNotificationColor(
                notification.type
              )} ${!notification.read ? "ring-2 ring-offset-2 ring-gray-300 dark:ring-gray-700" : ""}`}
            >
              <div className="flex items-start gap-4">
                <div className={`p-3 rounded-lg ${getNotificationBadgeColor(notification.type)} flex-shrink-0`}>
                  {getNotificationIcon(notification.type)}
                </div>

                <div className="flex-1 min-w-0">
                  <h3 className="font-black text-lg mb-1">{notification.title}</h3>
                  <p className="text-sm opacity-75 mb-2">{notification.message}</p>

                  {notification.relatedId && (
                    <div className="text-xs font-bold opacity-60 flex items-center gap-2 mt-2">
                      <Clock className="w-3 h-3" />
                      {formatTime(notification.date)}
                    </div>
                  )}
                </div>

                <div className="flex gap-2 flex-shrink-0 ml-4">
                  {!notification.read && (
                    <button
                      onClick={() =>
                        setNotifications(
                          notifications.map((n) =>
                            n.id === notification.id ? { ...n, read: true } : n
                          )
                        )
                      }
                      className="p-2 hover:bg-black/10 dark:hover:bg-white/10 rounded-lg transition-colors"
                      title="علّم كمقروء"
                    >
                      <Check className="w-5 h-5" />
                    </button>
                  )}
                  <button
                    onClick={() =>
                      setNotifications(notifications.filter((n) => n.id !== notification.id))
                    }
                    className="p-2 hover:bg-black/10 dark:hover:bg-white/10 rounded-lg transition-colors"
                    title="حذف"
                  >
                    <Trash2 className="w-5 h-5" />
                  </button>
                </div>
              </div>
            </div>
          ))
        )}
      </div>

      {/* Quick Actions */}
      {stats.unread > 0 && !showArchived && (
        <div className="flex gap-3 justify-center">
          <button
            onClick={() =>
              setNotifications(
                notifications.map((n) => ({ ...n, read: true }))
              )
            }
            className="px-8 py-3 bg-teal-600 text-white font-bold rounded-full hover:bg-teal-700 transition-all"
          >
            علّم الكل كمقروء
          </button>
        </div>
      )}
    </div>
  );
}
