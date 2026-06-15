import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../services/supabase_service.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _emailFormKey = GlobalKey<FormState>();
  final _codeFormKey = GlobalKey<FormState>();
  
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  
  final _codeController = TextEditingController();
  final _newPasswordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  
  final _supabase = SupabaseService.instance;

  int _activeTab = 0; // 0 = Email, 1 = Code
  bool _isObscure = true;
  bool _isLoading = false;
  
  bool _codeVerified = false;
  Map<String, dynamic>? _verifiedMemberInfo;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _codeController.dispose();
    _newPasswordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> _loginByEmail() async {
    if (!_emailFormKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      await _supabase.signIn(
        _emailController.text.trim(),
        _passwordController.text,
      );

      // Perform initial sync after successful login
      try {
        await _supabase.synchronizeData();
      } catch (syncError) {
        print('Initial sync failed: $syncError');
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('تم تسجيل الدخول ومزامنة البيانات بنجاح'),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.pop(context, true);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('فشل تسجيل الدخول: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _verifyCode() async {
    if (!_codeFormKey.currentState!.validate()) return;
    
    final code = _codeController.text.trim();
    if (code.isEmpty) return;

    setState(() => _isLoading = true);

    try {
      final member = await _supabase.verifyInvitationCode(code);
      if (member == null) {
        throw Exception('كود المعلم غير صحيح أو غير مسجل بالنظام السحابي');
      }

      // Check if user is already linked
      if (member['user_id'] != null) {
        throw Exception('هذا الكود تم تفعيله مسبقاً للبريد: ${member['email']}. يرجى تسجيل الدخول بالبريد.');
      }

      // Check if email already exists in auth.users
      if (member['is_registered'] == true) {
        throw Exception('البريد (${member['email']}) مسجل مسبقاً في النظام. يرجى تسجيل الدخول مباشرة بتبويب البريد الإلكتروني لتفعيل حسابك.');
      }

      setState(() {
        _verifiedMemberInfo = member;
        _codeVerified = true;
      });
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('تم التحقق من الكود بنجاح! يرجى تعيين كلمة المرور لتفعيل حسابك.'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(e.toString().replaceAll('Exception: ', '')),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _activateAccount() async {
    if (!_codeFormKey.currentState!.validate()) return;
    if (_verifiedMemberInfo == null) return;
    
    final email = _verifiedMemberInfo!['email'];
    final code = _codeController.text.trim();
    final password = _newPasswordController.text;

    setState(() => _isLoading = true);

    try {
      // 1. Sign up and link code using RPC
      await _supabase.signUpAndLinkCode(
        email: email,
        password: password,
        code: code,
      );

      // 2. Log in automatically after registration
      await _supabase.signIn(email, password);

      // 3. Sync data
      try {
        await _supabase.synchronizeData();
      } catch (syncError) {
        print('Initial sync failed: $syncError');
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('تم تفعيل حسابك وتسجيل الدخول بنجاح!'),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.pop(context, true);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('فشل تفعيل الحساب: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _resetCodeVerification() {
    setState(() {
      _codeVerified = false;
      _verifiedMemberInfo = null;
      _newPasswordController.clear();
      _confirmPasswordController.clear();
    });
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          'تسجيل دخول المعلم',
          style: GoogleFonts.tajawal(fontWeight: FontWeight.bold),
        ),
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Icon(
                Icons.cloud_queue_outlined,
                size: 70,
                color: Color(0xFF0D9488),
              ),
              const SizedBox(height: 12),
              Text(
                'ربط السحابة والمزامنة ☁️',
                style: GoogleFonts.tajawal(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: isDark ? Colors.white : const Color(0xFF0F172A),
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 6),
              Text(
                'سجل دخولك بحساب معلم المقرأة لمزامنة بيانات الطلاب وتسميعهم أوفلاين',
                style: GoogleFonts.tajawal(
                  fontSize: 13,
                  color: Colors.grey[600],
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),

              // Custom Tab Selector
              Container(
                decoration: BoxDecoration(
                  color: isDark ? Colors.grey[900] : Colors.grey[200],
                  borderRadius: BorderRadius.circular(16),
                ),
                padding: const EdgeInsets.all(4),
                child: Row(
                  children: [
                    Expanded(
                      child: GestureDetector(
                        onTap: () => setState(() => _activeTab = 0),
                        child: Container(
                          decoration: BoxDecoration(
                            color: _activeTab == 0
                                ? const Color(0xFF0D9488)
                                : Colors.transparent,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          alignment: Alignment.center,
                          child: Text(
                            'تسجيل بالبريد',
                            style: GoogleFonts.tajawal(
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                              color: _activeTab == 0
                                  ? Colors.white
                                  : (isDark ? Colors.grey[400] : Colors.grey[700]),
                            ),
                          ),
                        ),
                      ),
                    ),
                    Expanded(
                      child: GestureDetector(
                        onTap: () => setState(() => _activeTab = 1),
                        child: Container(
                          decoration: BoxDecoration(
                            color: _activeTab == 1
                                ? const Color(0xFF0D9488)
                                : Colors.transparent,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          alignment: Alignment.center,
                          child: Text(
                            'تفعيل كود المعلم',
                            style: GoogleFonts.tajawal(
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                              color: _activeTab == 1
                                  ? Colors.white
                                  : (isDark ? Colors.grey[400] : Colors.grey[700]),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // Form content according to the selected tab
              _activeTab == 0 ? _buildEmailLoginForm(isDark) : _buildCodeActivationForm(isDark),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildEmailLoginForm(bool isDark) {
    return Form(
      key: _emailFormKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Email Field
          TextFormField(
            controller: _emailController,
            keyboardType: TextInputType.emailAddress,
            decoration: InputDecoration(
              labelText: 'البريد الإلكتروني',
              prefixIcon: const Icon(Icons.email_outlined),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
              ),
            ),
            validator: (value) {
              if (value == null || value.trim().isEmpty) {
                return 'يرجى إدخال البريد الإلكتروني';
              }
              if (!RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(value.trim())) {
                return 'يرجى إدخال بريد إلكتروني صالح';
              }
              return null;
            },
          ),
          const SizedBox(height: 16),

          // Password Field
          TextFormField(
            controller: _passwordController,
            obscureText: _isObscure,
            decoration: InputDecoration(
              labelText: 'كلمة المرور',
              prefixIcon: const Icon(Icons.lock_outline),
              suffixIcon: IconButton(
                icon: Icon(_isObscure ? Icons.visibility_off : Icons.visibility),
                onPressed: () => setState(() => _isObscure = !_isObscure),
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
              ),
            ),
            validator: (value) {
              if (value == null || value.isEmpty) {
                return 'يرجى إدخال كلمة المرور';
              }
              return null;
            },
          ),
          const SizedBox(height: 24),

          // Login Button
          ElevatedButton(
            onPressed: _isLoading ? null : _loginByEmail,
            style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 14),
              backgroundColor: const Color(0xFF0D9488),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
            ),
            child: _isLoading
                ? const SizedBox(
                    height: 20,
                    width: 20,
                    child: CircularProgressIndicator(
                      color: Colors.white,
                      strokeWidth: 2,
                    ),
                  )
                : Text(
                    'تسجيل الدخول والمزامنة',
                    style: GoogleFonts.tajawal(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildCodeActivationForm(bool isDark) {
    return Form(
      key: _codeFormKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (!_codeVerified) ...[
            // Enter Code
            TextFormField(
              controller: _codeController,
              decoration: InputDecoration(
                labelText: 'كود دعوة المعلم (مثال: HAL-SEC-XXXX)',
                prefixIcon: const Icon(Icons.vpn_key_outlined),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'يرجى إدخال كود المعلم';
                }
                return null;
              },
            ),
            const SizedBox(height: 24),

            ElevatedButton(
              onPressed: _isLoading ? null : _verifyCode,
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 14),
                backgroundColor: const Color(0xFF0D9488),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
              child: _isLoading
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(
                        color: Colors.white,
                        strokeWidth: 2,
                      ),
                    )
                  : Text(
                      'التحقق من الكود',
                      style: GoogleFonts.tajawal(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
            ),
          ] else ...[
            // Code Verified - Show details and password activation
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFF0F766E).withOpacity(0.08),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFF0D9488).withOpacity(0.3)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.check_circle, color: Color(0xFF0D9488), size: 20),
                      const SizedBox(width: 8),
                      Text(
                        'كود المعلم صالح ومرتبط بالبيانات التالية:',
                        style: GoogleFonts.tajawal(
                          fontWeight: FontWeight.bold,
                          color: const Color(0xFF0F766E),
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                  const Divider(height: 16),
                  Text(
                    'البريد الإلكتروني: ${_verifiedMemberInfo!['email']}',
                    style: GoogleFonts.tajawal(fontSize: 13, fontWeight: FontWeight.w500),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'الدور: ${_verifiedMemberInfo!['role'] == 'admin' ? 'مدير مركز' : 'معلم حلقة'}',
                    style: GoogleFonts.tajawal(fontSize: 13, fontWeight: FontWeight.w500),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // New Password field
            TextFormField(
              controller: _newPasswordController,
              obscureText: _isObscure,
              decoration: InputDecoration(
                labelText: 'تعيين كلمة مرور جديدة',
                prefixIcon: const Icon(Icons.lock_outline),
                suffixIcon: IconButton(
                  icon: Icon(_isObscure ? Icons.visibility_off : Icons.visibility),
                  onPressed: () => setState(() => _isObscure = !_isObscure),
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'يرجى إدخال كلمة مرور جديدة';
                }
                if (value.length < 6) {
                  return 'يجب أن لا تقل كلمة المرور عن 6 أحرف';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),

            // Confirm Password field
            TextFormField(
              controller: _confirmPasswordController,
              obscureText: _isObscure,
              decoration: InputDecoration(
                labelText: 'تأكيد كلمة المرور',
                prefixIcon: const Icon(Icons.lock_reset_outlined),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
              validator: (value) {
                if (value != _newPasswordController.text) {
                  return 'كلمتا المرور غير متطابقتين';
                }
                return null;
              },
            ),
            const SizedBox(height: 24),

            ElevatedButton(
              onPressed: _isLoading ? null : _activateAccount,
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 14),
                backgroundColor: const Color(0xFF0D9488),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
              child: _isLoading
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(
                        color: Colors.white,
                        strokeWidth: 2,
                      ),
                    )
                  : Text(
                      'تفعيل الحساب وتسجيل الدخول',
                      style: GoogleFonts.tajawal(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
            ),
            const SizedBox(height: 8),

            TextButton(
              onPressed: _isLoading ? null : _resetCodeVerification,
              child: Text(
                'العودة وتغيير الكود',
                style: GoogleFonts.tajawal(
                  color: Colors.grey[600],
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ]
        ],
      ),
    );
  }
}
