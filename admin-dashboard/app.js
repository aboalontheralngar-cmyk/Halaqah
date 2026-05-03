// بيانات تجريبية للطلاب
let students = [
    {
        id: 1,
        name: "أحمد محمد",
        phone: "0501234567",
        attendance: "present",
        memorization: "completed",
        revision: "completed",
        plan: "5-ayahs",
        notes: ""
    },
    {
        id: 2,
        name: "فاطمة عبدالله",
        phone: "0502345678",
        attendance: "present",
        memorization: "completed",
        revision: "not-completed",
        plan: "10-ayahs",
        notes: ""
    },
    {
        id: 3,
        name: "خالد سعيد",
        phone: "0503456789",
        attendance: "absent",
        memorization: "not-completed",
        revision: "not-completed",
        plan: "half-page",
        notes: ""
    },
    {
        id: 4,
        name: "نورة إبراهيم",
        phone: "0504567890",
        attendance: "late",
        memorization: "completed",
        revision: "completed",
        plan: "5-ayahs",
        notes: ""
    },
    {
        id: 5,
        name: "محمود علي",
        phone: "0505678901",
        attendance: "present",
        memorization: "not-completed",
        revision: "completed",
        plan: "full-page",
        notes: ""
    }
];

// دوال حالة الطلاب
const attendanceStatuses = {
    present: { text: 'حاضر', class: 'status-present' },
    absent: { text: 'غائب', class: 'status-absent' },
    late: { text: 'متأخر', class: 'status-late' }
};

const completionStatuses = {
    completed: { text: 'منجز', class: 'completed' },
    'not-completed': { text: 'لم ينجز', class: 'not-completed' }
};

const planLabels = {
    '5-ayahs': '٥ آيات',
    '10-ayahs': '١٠ آيات',
    'half-page': 'نصف صفحة',
    'full-page': 'صفحة كاملة'
};

// عرض بيانات الطلاب في الجدول
function renderStudentsTable() {
    const tableBody = document.getElementById('studentsTableBody');
    
    tableBody.innerHTML = students.map(student => `
        <tr>
            <td><strong>${student.name}</strong></td>
            <td><span class="status-badge ${attendanceStatuses[student.attendance].class}" onclick="toggleAttendance(${student.id})">${attendanceStatuses[student.attendance].text}</span></td>
            <td><span class="completion-badge ${completionStatuses[student.memorization].class}" onclick="toggleTask(${student.id}, 'memorization')">${completionStatuses[student.memorization].text}</span></td>
            <td><span class="completion-badge ${completionStatuses[student.revision].class}" onclick="toggleTask(${student.id}, 'revision')">${completionStatuses[student.revision].text}</span></td>
            <td><span class="plan-badge">${planLabels[student.plan]}</span></td>
            <td><button class="message-btn action-btn" onclick="addNote(${student.id})">ملاحظة</button></td>
            <td>
                <button class="edit-btn action-btn" onclick="editStudent(${student.id})">تعديل</button>
                <button class="view-btn action-btn" onclick="viewStudent(${student.id})">عرض</button>
            </td>
        </tr>
    `).join('');
}

// تبديل حالة الحضور
function toggleAttendance(studentId) {
    const student = students.find(s => s.id === studentId);
    if (!student) return;
    
    const currentIndex = Object.keys(attendanceStatuses).indexOf(student.attendance);
    const nextIndex = (currentIndex + 1) % Object.keys(attendanceStatuses).length;
    const nextStatus = Object.keys(attendanceStatuses)[nextIndex];
    
    student.attendance = nextStatus;
    renderStudentsTable();
    
    console.log(`تم تغيير حالة حضور ${student.name} إلى ${attendanceStatuses[nextStatus].text}`);
}

// تبديل حالة المهمة (حفظ أو مراجعة)
function toggleTask(studentId, taskType) {
    const student = students.find(s => s.id === studentId);
    if (!student) return;
    
    const currentStatus = student[taskType];
    const nextStatus = currentStatus === 'completed' ? 'not-completed' : 'completed';
    
    student[taskType] = nextStatus;
    renderStudentsTable();
    
    console.log(`تم تغيير حالة ${taskType} للطالب ${student.name}`);
}

// إضافة ملاحظة
function addNote(studentId) {
    const student = students.find(s => s.id === studentId);
    if (!student) return;
    
    const note = prompt(`أضف ملاحظة لـ ${student.name}:`);
    if (note) {
        student.notes = note;
        alert('تم إضافة الملاحظة بنجاح');
        console.log(`تمت إضافة ملاحظة لـ ${student.name}: ${note}`);
    }
}

// تعديل بيانات الطالب
function editStudent(studentId) {
    const student = students.find(s => s.id === studentId);
    if (!student) return;
    
    alert(`تعديل بيانات الطالب: ${student.name}`);
    // هنا يمكن إضافة منطق أكثر تفصيلاً لتعديل البيانات
}

// عرض تفاصيل الطالب
function viewStudent(studentId) {
    const student = students.find(s => s.id === studentId);
    if (!student) return;
    
    const message = `
        اسم الطالب: ${student.name}
        رقم الجوال: ${student.phone}
        الخطة: ${planLabels[student.plan]}
        حالة الحفظ: ${completionStatuses[student.memorization].text}
        حالة المراجعة: ${completionStatuses[student.revision].text}
        ${student.notes ? `ملاحظات: ${student.notes}` : ''}
    `;
    
    alert(message);
}

// نافذة إضافة طالب جديد
function showAddStudentModal() {
    document.getElementById('addStudentModal').style.display = 'block';
}

function hideAddStudentModal() {
    document.getElementById('addStudentModal').style.display = 'none';
    document.getElementById('addStudentForm').reset();
}

// معالجة استمارة إضافة الطالب
document.getElementById('addStudentForm').addEventListener('submit', function(e) {
    e.preventDefault();
    
    const name = document.getElementById('studentName').value.trim();
    const phone = document.getElementById('studentPhone').value.trim();
    const plan = document.getElementById('dailyPlan').value;
    
    if (name && phone && plan) {
        // إضافة طالب جديد
        const newStudent = {
            id: students.length + 1,
            name: name,
            phone: phone,
            attendance: 'present',
            memorization: 'not-completed',
            revision: 'not-completed',
            plan: plan,
            notes: ''
        };
        
        students.push(newStudent);
        renderStudentsTable();
        
        hideAddStudentModal();
        
        alert(`تم إضافة الطالب ${name} بنجاح`);
    }
});

// إغلاق النافذة عند النقر خارجها
window.onclick = function(event) {
    const modal = document.getElementById('addStudentModal');
    if (event.target === modal) {
        hideAddStudentModal();
    }
}

// تحديث التاريخ
document.getElementById('dateSelector').addEventListener('change', function() {
    const selectedDate = this.value;
    console.log(`تم تغيير التاريخ إلى: ${selectedDate}`);
    // هنا يمكن إضافة منطق لتحميل بيانات اليوم المختار
});

// تحديث الإحصائيات
function updateStats() {
    const totalStudents = students.length;
    const presentStudents = students.filter(s => s.attendance === 'present').length;
    const completedMemorization = students.filter(s => s.memorization === 'completed').length;
    const supportRequests = students.filter(s => s.notes.includes('طلب')).length;
    
    // تحديث أرقام الإحصائيات في الواجهة
    document.querySelectorAll('.stat-number')[0].textContent = totalStudents;
    document.querySelectorAll('.stat-number')[1].textContent = presentStudents;
    document.querySelectorAll('.stat-number')[2].textContent = completedMemorization;
    document.querySelectorAll('.stat-number')[3].textContent = supportRequests;
}

// بدء التطبيق
document.addEventListener('DOMContentLoaded', function() {
    renderStudentsTable();
    updateStats();
    
    console.log('تم تحميل لوحة تحكم الحلقة القرآنية بنجاح');
});

// إشعار تذكير يومي (مثال)
function showDailyReminder() {
    const now = new Date();
    const hour = now.getHours();
    
    if (hour === 18) { // الساعة 6 مساءً
        const message = "تذكير: لا تنسَ مراجعة خطة الغد لطلاب الحلقة!";
        
        // إنشاء إشعار بسيط
        if ("Notification" in window) {
            Notification.requestPermission().then(permission => {
                if (permission === "granted") {
                    new Notification("الحلقة القرآنية", {
                        body: message,
                        icon: "data:image/svg+xml,<svg xmlns='http://www.w3.org/2000/svg' viewBox='0 0 24 24' fill='%234db6ac'><path d='M12 2C6.48 2 2 6.48 2 12s4.48 10 10 10 10-4.48 10-10S17.52 2 12 2zm-2 15l-5-5 1.41-1.41L10 14.17l7.59-7.59L19 8l-9 9z'/></svg>"
                    });
                }
            });
        }
        
        // رسالة في الكونسول
        console.log(`📱 ${message}`);
    }
}

// تشغيل التذكير كل ساعة
setInterval(showDailyReminder, 3600000); // كل ساعة

// تصدير الدوال للاستخدام العام
window.showAddStudentModal = showAddStudentModal;
window.hideAddStudentModal = hideAddStudentModal;