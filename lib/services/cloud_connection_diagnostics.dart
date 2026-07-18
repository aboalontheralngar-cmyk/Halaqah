import 'dart:async';
import 'dart:io';

enum CloudConnectionStatus {
  healthy,
  dnsFailure,
  timeout,
  tlsFailure,
  networkFailure,
  serverFailure,
  configurationFailure,
  unknownFailure,
}

typedef CloudHostLookup = Future<List<InternetAddress>> Function(String host);
typedef CloudEndpointProbe = Future<int> Function(
  Uri endpoint,
  Duration timeout,
);

class CloudConnectionDiagnostic {
  final CloudConnectionStatus status;
  final String host;
  final Duration elapsed;
  final int? httpStatus;
  final String? technicalDetails;

  const CloudConnectionDiagnostic({
    required this.status,
    required this.host,
    required this.elapsed,
    this.httpStatus,
    this.technicalDetails,
  });

  bool get isHealthy => status == CloudConnectionStatus.healthy;

  String get title => switch (status) {
        CloudConnectionStatus.healthy => 'الاتصال بالسحابة سليم',
        CloudConnectionStatus.dnsFailure => 'تعذر العثور على نطاق Supabase',
        CloudConnectionStatus.timeout => 'انتهت مهلة الاتصال',
        CloudConnectionStatus.tlsFailure => 'تعذر إنشاء اتصال آمن',
        CloudConnectionStatus.networkFailure => 'تعذر الوصول إلى الشبكة',
        CloudConnectionStatus.serverFailure => 'خدمة Supabase غير متاحة مؤقتًا',
        CloudConnectionStatus.configurationFailure => 'إعداد رابط Supabase غير صالح',
        CloudConnectionStatus.unknownFailure => 'تعذر إكمال فحص الاتصال',
      };

  String get message => switch (status) {
        CloudConnectionStatus.healthy =>
          'وصل التطبيق إلى خادم Supabase. يمكن الآن تجربة الرفع أو التنزيل.',
        CloudConnectionStatus.dnsFailure =>
          'الهاتف لم يستطع تحويل اسم النطاق إلى عنوان شبكة. بيانات الجهاز المحلية لم تتأثر.',
        CloudConnectionStatus.timeout =>
          'الشبكة متصلة لكن الخادم لم يرد خلال المهلة المحددة.',
        CloudConnectionStatus.tlsFailure =>
          'تعذر التحقق من الاتصال المشفر. تحقق من تاريخ الجهاز وأي VPN أو مرشح شبكة.',
        CloudConnectionStatus.networkFailure =>
          'فشل الاتصال بعد العثور على النطاق. جرّب شبكة أخرى ثم أعد الفحص.',
        CloudConnectionStatus.serverFailure =>
          'استجاب النطاق بخطأ خادمي. تحقق من حالة المشروع في لوحة Supabase.',
        CloudConnectionStatus.configurationFailure =>
          'يلزم أن يكون رابط المشروع HTTPS صحيحًا قبل استعمال المزامنة.',
        CloudConnectionStatus.unknownFailure =>
          'حدث خطأ غير متوقع أثناء الفحص، ولم تُنفذ أي مزامنة.',
      };

  List<String> get recommendations => switch (status) {
        CloudConnectionStatus.healthy => const [
          'ابدأ بالرفع فقط عند وجود أحدث البيانات على هذا الجهاز.',
          'استخدم التنزيل فقط بعد إنشاء نسخة حماية محلية.',
        ],
        CloudConnectionStatus.dnsFailure => const [
          'اجعل DNS الخاص في الهاتف تلقائيًا.',
          'أوقف VPN أو مانع الإعلانات مؤقتًا.',
          'بدّل بين Wi-Fi وبيانات الهاتف.',
        ],
        CloudConnectionStatus.timeout || CloudConnectionStatus.networkFailure =>
          const [
            'تحقق من ثبات الإنترنت ثم أعد الفحص.',
            'جرّب شبكة أخرى أو أعد تشغيل الراوتر.',
          ],
        CloudConnectionStatus.tlsFailure => const [
          'فعّل التاريخ والوقت التلقائيين في الهاتف.',
          'أوقف أدوات فحص HTTPS أو VPN مؤقتًا.',
        ],
        CloudConnectionStatus.serverFailure => const [
          'افتح لوحة Supabase وتأكد أن المشروع غير متوقف.',
          'قارن Project URL بالرابط المسجل في التطبيق.',
        ],
        CloudConnectionStatus.configurationFailure => const [
          'راجع SUPABASE_URL المستخدم عند بناء التطبيق.',
        ],
        CloudConnectionStatus.unknownFailure => const [
          'أعد تشغيل التطبيق ثم أعد الفحص.',
          'احتفظ بنسخة محلية قبل أي محاولة تنزيل.',
        ],
      };
}

class CloudConnectionDiagnostics {
  final Uri endpoint;
  final Duration timeout;
  final CloudHostLookup _lookup;
  final CloudEndpointProbe _probe;

  CloudConnectionDiagnostics({
    required this.endpoint,
    this.timeout = const Duration(seconds: 8),
    CloudHostLookup? lookup,
    CloudEndpointProbe? probe,
  })  : _lookup = lookup ?? _defaultLookup,
        _probe = probe ?? _defaultProbe;

  Future<CloudConnectionDiagnostic> run() async {
    final stopwatch = Stopwatch()..start();
    final host = endpoint.host;

    if (endpoint.scheme != 'https' || host.isEmpty) {
      return _result(
        CloudConnectionStatus.configurationFailure,
        host,
        stopwatch,
      );
    }

    try {
      final addresses = await _lookup(host).timeout(timeout);
      if (addresses.isEmpty) {
        return _result(CloudConnectionStatus.dnsFailure, host, stopwatch);
      }
    } on TimeoutException catch (error) {
      return _result(
        CloudConnectionStatus.timeout,
        host,
        stopwatch,
        details: error.toString(),
      );
    } on SocketException catch (error) {
      return _result(
        CloudConnectionStatus.dnsFailure,
        host,
        stopwatch,
        details: error.message,
      );
    } catch (error) {
      return _result(
        CloudConnectionStatus.unknownFailure,
        host,
        stopwatch,
        details: error.toString(),
      );
    }

    try {
      final statusCode = await _probe(endpoint, timeout).timeout(timeout);
      return _result(
        statusCode < 500
            ? CloudConnectionStatus.healthy
            : CloudConnectionStatus.serverFailure,
        host,
        stopwatch,
        httpStatus: statusCode,
      );
    } on TimeoutException catch (error) {
      return _result(
        CloudConnectionStatus.timeout,
        host,
        stopwatch,
        details: error.toString(),
      );
    } on HandshakeException catch (error) {
      return _result(
        CloudConnectionStatus.tlsFailure,
        host,
        stopwatch,
        details: error.message,
      );
    } on SocketException catch (error) {
      return _result(
        CloudConnectionStatus.networkFailure,
        host,
        stopwatch,
        details: error.message,
      );
    } catch (error) {
      return _result(
        CloudConnectionStatus.unknownFailure,
        host,
        stopwatch,
        details: error.toString(),
      );
    }
  }

  static Future<List<InternetAddress>> _defaultLookup(String host) =>
      InternetAddress.lookup(host);

  static Future<int> _defaultProbe(Uri endpoint, Duration timeout) async {
    final client = HttpClient()..connectionTimeout = timeout;
    try {
      final request = await client.getUrl(endpoint).timeout(timeout);
      request.followRedirects = false;
      request.headers.set(HttpHeaders.acceptHeader, 'application/json');
      final response = await request.close().timeout(timeout);
      await response.drain<void>().timeout(timeout);
      return response.statusCode;
    } finally {
      client.close(force: true);
    }
  }

  CloudConnectionDiagnostic _result(
    CloudConnectionStatus status,
    String host,
    Stopwatch stopwatch, {
    int? httpStatus,
    String? details,
  }) {
    stopwatch.stop();
    return CloudConnectionDiagnostic(
      status: status,
      host: host,
      elapsed: stopwatch.elapsed,
      httpStatus: httpStatus,
      technicalDetails: details,
    );
  }
}
