# بنية قاعدة البيانات المبسطة

## 🔧 Firebase Firestore Structure

### المجلدات الرئيسية:

#### 1. Collection: `students`
```javascript
{
  studentId: {
    name: "أحمد محمد",
    phone: "+966501234567",
    createdAt: timestamp,
    plan: "5-ayahs", // خطة الحفظ اليومية
    totalMemorized: 150, // عدد الآيات المحفوظة الإجمالي
    totalRevisions: 45, // عدد المراجعات
    attendanceRate: 85, // نسبة الحضور
    status: "active",
    lastActive: timestamp
  }
}
```

#### 2. Collection: `daily_plans` (sub-collection)
```javascript
{
  studentId → daily_plans → YYYY-MM-DD: {
    date: "2024-01-27",
    newMemorization: "5 آيات",
    surah: "الفاتحة",
    memorizationCompleted: false,
    revision: "10 آيات",
    revisionSurah: "البقرة",
    revisionCompleted: false,
    attendance: "present", // present, absent, late
    notes: "",
    updatedAt: timestamp
  }
}
```

#### 3. Collection: `notes`
```javascript
{
  noteId: {
    studentId: "student123",
    content: "الطالب يحتاج إلى دعم إضافي في الحفظ",
    status: "pending", // pending, resolved
    timestamp: timestamp,
    author: "teacher456"
  }
}
```

#### 4. Collection: `teachers`
```javascript
{
  teacherId: {
    name: "الأستاذ أحمد",
    email: "teacher@halaqah.com",
    role: "admin",
    createdAt: timestamp
  }
}
```

### 🔍 القواعد الأمنية (Security Rules):
```javascript
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {
    // الطلاب يمكنهم قراءة بياناتهم فقط
    match /students/{studentId} {
      allow read: if request.auth != null && request.auth.uid == studentId;
      allow write: if false; // يتم التحديث عبر وظائف خادنية
    }
    
    // المعلمين يمكنهم قراءة وكتابة جميع البيانات
    match /students/{document=**} {
      allow read, write: if request.auth != null && 
        get(/databases/$(database)/documents/teachers/$(request.auth.uid)).data.role == 'admin';
    }
    
    match /teachers/{teacherId} {
      allow read, write: if request.auth != null && request.auth.uid == teacherId;
    }
  }
}
```

### ⚡ Cloud Functions (وظائف خادنية):

#### 1. دالة إنشاء خطة يومية تلقائية:
```javascript
exports.createDailyPlan = functions.pubsub
  .schedule('every day 00:00')
  .timeZone('Asia/Riyadh')
  .onRun(async (context) => {
    // إنشاء خطة يومية لكل طالب بناءً على خطته الأساسية
  });
```

#### 2. دالة إرسال الإشعارات:
```javascript
exports.sendDailyReminder = functions.pubsub
  .schedule('every day 18:00')
  .timeZone('Asia/Riyadh')
  .onRun(async (context) => {
    // إرسال إشعارات للطلاب الغير منتهين من مهامهم
  });
```

### 📊 مؤشرات الأداء:
- **تسجيل الدخول**: أقل من 1 ثانية
- **تحديث البيانات**: فوري (real-time)
- **عرض التقارير**: أقل من 2 ثانية
- **إشعارات مشغولة**: نجاح 99%+

### 🔒 الإعدادات المقترحة:
```javascript
// خطة افتراضية للطلاب الجدد
defaultPlan = {
  '5-ayahs': '٥ آيات يومياً',
  '10-ayahs': '١٠ آيات يومياً',
  'half-page': 'نصف صفحة يومياً',
  'full-page': 'صفحة كاملة يومياً'
};

// نوع التقويم (يمكن تعديله من الإعدادات)
calendarType = 'hijri'; // 'gregorian' أو 'hijri'
```