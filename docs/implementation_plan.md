# خطة عمل: ضوابط حماية ونظافة قاعدة البيانات (أقصى حد للمراكز وتنظيف المهمل)

تهدف هذه الخطة إلى تفصيل وتصميم ضوابط برمجية لحماية قاعدة البيانات من Bloat (التضخم غير المبرر) وضمان نظافتها من خلال وضع حد أقصى لإنشاء المراكز لكل مستخدم، والتنظيف التلقائي للمراكز المهملة.

---

## User Review Required

> [!IMPORTANT]
> **1. الحد الأقصى للمراكز (4 مراكز لكل مستخدم):**
> * سنقوم بتطبيق هذا القيد على مستوى قاعدة البيانات مباشرة (Database Level) باستخدام **Trigger** في PostgreSQL. 
> * هذا يضمن حظر الإنشاء بأي وسيلة (سواء من موقع الويب أو من تطبيق الجوال) بمجرد وصول حساب المستخدم إلى 4 مراكز.
> * عند محاولة إنشاء المركز الخامس، سيرفع النظام خطأ واضحاً باللغة العربية يمنع العملية.
>
> **2. التنظيف التلقائي للمراكز المهملة (أكبر من 10 أيام وبدون أي حلقة):**
> * سنقوم بإنشاء دالة سحابية متخصصة في قاعدة البيانات: `cleanup_empty_centers()`.
> * ستبحث الدالة عن أي مركز تم إنشاؤه منذ أكثر من 10 أيام ولم يتم ربط أو إنشاء أي حلقة بداخله، ثم تقوم بحذفه تلقائياً مع كافة البيانات التابعة له (إن وجدت).
> * سنقوم بتفعيل امتداد `pg_cron` في PostgreSQL وجدولته لتشغيل هذه الدالة تلقائياً مرة واحدة كل يوم في منتصف الليل.

---

## Proposed Changes

### [Component] Database Schema & Functions (قاعدة البيانات والوظائف)

#### [MODIFY] [database_schema_extensions.sql](file:///c:/Users/salman/Documents/flutter_App/Halaqah/website/database_schema_extensions.sql)

*   **إضافة وظيفة تحديد عدد المراكز لـ 4 كحد أقصى وترجر الحظر**:
    ```sql
    CREATE OR REPLACE FUNCTION limit_centers_per_user()
    RETURNS TRIGGER AS $$
    DECLARE
        center_count INTEGER;
    BEGIN
        SELECT COUNT(*) INTO center_count
        FROM centers
        WHERE owner_id = NEW.owner_id;
        
        IF center_count >= 4 THEN
            RAISE EXCEPTION 'لا يمكنك إنشاء أكثر من 4 مراكز كحد أقصى للساب الواحد. يرجى حذف أحد المراكز الحالية أولاً.';
        END IF;
        
        RETURN NEW;
    END;
    $$ LANGUAGE plpgsql;

    DROP TRIGGER IF EXISTS trigger_limit_centers ON centers;
    CREATE TRIGGER trigger_limit_centers
    BEFORE INSERT ON centers
    FOR EACH ROW
    EXECUTE FUNCTION limit_centers_per_user();
    ```

*   **إضافة وظيفة تنظيف المراكز المهملة وجدولتها**:
    ```sql
    CREATE OR REPLACE FUNCTION cleanup_empty_centers()
    RETURNS void SECURITY DEFINER AS $$
    BEGIN
        DELETE FROM centers
        WHERE created_at < NOW() - INTERVAL '10 days'
          AND NOT EXISTS (
            SELECT 1 FROM halaqat WHERE halaqat.center_id = centers.id
          );
    END;
    $$ LANGUAGE plpgsql;

    -- تفعيل امتداد pg_cron للجدولة التلقائية
    CREATE EXTENSION IF NOT EXISTS pg_cron;
    
    -- جدولة دالة التنظيف يومياً الساعة 12:00 بعد منتصف الليل
    SELECT cron.schedule(
      'cleanup-empty-centers-daily',
      '0 0 * * *',
      'SELECT cleanup_empty_centers()'
    );
    ```

---

## Verification Plan

### Automated Tests
* لا توجد اختبارات مؤتمتة، التحقق سيكون يدويًا أو عبر تشغيل جمل الفحص في قاعدة البيانات.

### Manual Verification
1. محاولة إنشاء أكثر من 4 مراكز من خلال واجهة مستخدم الويب والتأكد من إرجاع رسالة الخطأ العربية وحظر العملية.
2. استدعاء الدالة `SELECT cleanup_empty_centers();` يدوياً بعد إنشاء مركز وهمي وتغيير تاريخ إنشائه إلى ما قبل 11 يوماً دون ربطه بحلقات، والتأكد من حذفه تلقائياً.
