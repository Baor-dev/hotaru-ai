import 'package:flutter/material.dart';
import 'package:dio/dio.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../api.dart'; 
import 'dashboard_screen.dart';

class AuthScreen extends StatefulWidget {
  const AuthScreen({super.key});

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final _emailCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  final _nameCtrl = TextEditingController();
  bool _obscurePass = true;
  bool _isLoading = false;
  int _tabIndex = 0;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _tabController.addListener(() {
      setState(() => _tabIndex = _tabController.index);
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    _emailCtrl.dispose();
    _passwordCtrl.dispose();
    _nameCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final email = _emailCtrl.text.trim();
    final password = _passwordCtrl.text;
    final name = _nameCtrl.text.trim();

    if (email.isEmpty || password.isEmpty) {
      _showError('Vui lòng nhập đầy đủ thông tin!');
      return;
    }

    if (_tabIndex == 1 && name.isEmpty) {
      _showError('Vui lòng nhập Họ và tên!');
      return;
    }

    setState(() => _isLoading = true);

    try {
      if (_tabIndex == 0) {
        // ==========================================
        // 1. CALL API ĐĂNG NHẬP (CHUẨN JSON)
        // ==========================================
        final response = await apiClient.post(
          '/login', 
          data: {
            'email': email,
            'password': password,
          },
        );

        if (response.statusCode == 200) {
          final token = response.data['access_token']; 
          
          final prefs = await SharedPreferences.getInstance();
          await prefs.setString('access_token', token);

          _goToDashboard();
        }
      } else {
        // ==========================================
        // 2. CALL API ĐĂNG KÝ
        // ==========================================
        final response = await apiClient.post('/register', data: {
          'email': email,
          'password': password,
          'full_name': name,
        });

        if (response.statusCode == 200 || response.statusCode == 201) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('🎉 Đăng ký thành công! Vui lòng đăng nhập.'),
              backgroundColor: Colors.green,
            ),
          );
          _passwordCtrl.clear();
          _tabController.animateTo(0);
        }
      }
    } on DioException catch (e) {
      String errorMessage = 'Lỗi kết nối đến máy chủ AI!';
      
      if (e.response?.data != null) {
        final detail = e.response?.data['detail'];
        if (detail is List && detail.isNotEmpty) {
          errorMessage = detail[0]['msg'] ?? 'Sai định dạng dữ liệu (422)';
        } else if (detail is String) {
          errorMessage = detail;
        } else if (e.response?.data['error'] != null) {
          errorMessage = e.response?.data['error']?.toString() ?? 'Lỗi không xác định';
        }
      }
      _showError(errorMessage);
    } catch (e) {
      _showError('Đã xảy ra lỗi hệ thống: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showError(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('❌ $msg'), backgroundColor: Colors.red),
    );
  }

  void _goToDashboard() {
    if (!mounted) return;
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => const DashboardScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF0F2F5),
      body: Stack(
        children: [
          Positioned(top: -100, right: -80, child: const _Blob(color: Color(0xFF1976D2), size: 320)),
          Positioned(bottom: -120, left: -80, child: const _Blob(color: Color(0xFF0288D1), size: 260)),
          SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 32),
              child: Column(
                children: [
                  const SizedBox(height: 24),
                  Container(
                    width: 68,
                    height: 68,
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFF1976D2), Color(0xFF1565C0)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [
                        BoxShadow(color: const Color(0xFF1976D2).withOpacity(0.38), blurRadius: 20, offset: const Offset(0, 8)),
                      ],
                    ),
                    child: const Icon(Icons.auto_awesome, color: Colors.white, size: 30),
                  ),
                  const SizedBox(height: 16),
                  const Text('HOTARU AI', style: TextStyle(fontSize: 26, fontWeight: FontWeight.w900, color: Color(0xFF1565C0), letterSpacing: -0.5)),
                  const SizedBox(height: 4),
                  const Text('Trợ lý học tập thông minh', style: TextStyle(fontSize: 13, color: Color(0xFF9E9E9E))),
                  const SizedBox(height: 36),
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.93),
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(color: Colors.white, width: 1.5),
                      boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.09), blurRadius: 40, offset: const Offset(0, 8))],
                    ),
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      children: [
                        Container(
                          decoration: BoxDecoration(color: const Color(0xFFF0F2F5), borderRadius: BorderRadius.circular(12)),
                          padding: const EdgeInsets.all(4),
                          child: Row(
                            children: [
                              _TabBtn(label: 'Đăng Nhập', active: _tabIndex == 0, onTap: () => _tabController.animateTo(0)),
                              _TabBtn(label: 'Đăng Ký', active: _tabIndex == 1, onTap: () => _tabController.animateTo(1)),
                            ],
                          ),
                        ),
                        const SizedBox(height: 24),
                        SizedBox(
                          height: _tabIndex == 1 ? 290 : 230,
                          child: TabBarView(
                            controller: _tabController,
                            children: [
                              Column(
                                children: [
                                  _AuthField(controller: _emailCtrl, label: 'Email', hint: 'you@example.com', icon: Icons.mail_outline, keyboardType: TextInputType.emailAddress),
                                  const SizedBox(height: 14),
                                  _AuthField(
                                    controller: _passwordCtrl, label: 'Mật khẩu', hint: '••••••••', icon: Icons.lock_outline, obscure: _obscurePass,
                                    suffixIcon: IconButton(
                                      icon: Icon(_obscurePass ? Icons.visibility_off : Icons.visibility, color: Colors.grey[400], size: 18),
                                      onPressed: () => setState(() => _obscurePass = !_obscurePass),
                                    ),
                                  ),
                                  const SizedBox(height: 20),
                                  _SubmitBtn(label: 'Đăng Nhập', loading: _isLoading, onTap: _submit),
                                ],
                              ),
                              Column(
                                children: [
                                  _AuthField(controller: _nameCtrl, label: 'Họ và tên', hint: 'Nguyễn Văn A', icon: Icons.person_outline),
                                  const SizedBox(height: 14),
                                  _AuthField(controller: _emailCtrl, label: 'Email', hint: 'you@example.com', icon: Icons.mail_outline, keyboardType: TextInputType.emailAddress),
                                  const SizedBox(height: 14),
                                  _AuthField(
                                    controller: _passwordCtrl, label: 'Mật khẩu', hint: '••••••••', icon: Icons.lock_outline, obscure: _obscurePass,
                                    suffixIcon: IconButton(
                                      icon: Icon(_obscurePass ? Icons.visibility_off : Icons.visibility, color: Colors.grey[400], size: 18),
                                      onPressed: () => setState(() => _obscurePass = !_obscurePass),
                                    ),
                                  ),
                                  const SizedBox(height: 20),
                                  _SubmitBtn(label: 'Tạo tài khoản', loading: _isLoading, onTap: _submit),
                                ],
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 16),
                        Text('Bằng cách tiếp tục, bạn đồng ý với\nĐiều khoản sử dụng của Hotaru AI', textAlign: TextAlign.center, style: TextStyle(fontSize: 11, color: Colors.grey[400], height: 1.6)),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Blob extends StatelessWidget {
  final Color color; final double size;
  const _Blob({required this.color, required this.size});
  @override Widget build(BuildContext context) => Container(width: size, height: size, decoration: BoxDecoration(shape: BoxShape.circle, color: color.withOpacity(0.22)));
}

class _TabBtn extends StatelessWidget {
  final String label; final bool active; final VoidCallback onTap;
  const _TabBtn({required this.label, required this.active, required this.onTap});
  @override Widget build(BuildContext context) => Expanded(child: GestureDetector(onTap: onTap, child: AnimatedContainer(duration: const Duration(milliseconds: 200), padding: const EdgeInsets.symmetric(vertical: 9), decoration: BoxDecoration(color: active ? Colors.white : Colors.transparent, borderRadius: BorderRadius.circular(9), boxShadow: active ? [BoxShadow(color: Colors.black.withOpacity(0.08), blurRadius: 8, offset: const Offset(0, 2))] : []), child: Text(label, textAlign: TextAlign.center, style: TextStyle(fontSize: 13.5, fontWeight: active ? FontWeight.w700 : FontWeight.w500, color: active ? const Color(0xFF1976D2) : Colors.grey[500])))));
}

class _AuthField extends StatelessWidget {
  final TextEditingController controller; final String label; final String hint; final IconData icon; final bool obscure; final Widget? suffixIcon; final TextInputType? keyboardType;
  const _AuthField({required this.controller, required this.label, required this.hint, required this.icon, this.obscure = false, this.suffixIcon, this.keyboardType});
  @override Widget build(BuildContext context) => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(label, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF4B5563))), const SizedBox(height: 6), TextField(controller: controller, obscureText: obscure, keyboardType: keyboardType, style: const TextStyle(fontSize: 14), decoration: InputDecoration(hintText: hint, hintStyle: TextStyle(color: Colors.grey[400], fontSize: 14), prefixIcon: Icon(icon, color: Colors.grey[400], size: 18), suffixIcon: suffixIcon, filled: true, fillColor: const Color(0xFFF9FAFB), contentPadding: const EdgeInsets.symmetric(vertical: 13, horizontal: 14), border: OutlineInputBorder(borderRadius: BorderRadius.circular(11), borderSide: const BorderSide(color: Color(0xFFE5E7EB))), enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(11), borderSide: const BorderSide(color: Color(0xFFE5E7EB))), focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(11), borderSide: const BorderSide(color: Color(0xFF1976D2), width: 1.8))))]);
}

class _SubmitBtn extends StatelessWidget {
  final String label; final bool loading; final VoidCallback onTap;
  const _SubmitBtn({required this.label, required this.loading, required this.onTap});
  @override Widget build(BuildContext context) => SizedBox(width: double.infinity, height: 48, child: ElevatedButton(onPressed: loading ? null : onTap, style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF1976D2), foregroundColor: Colors.white, elevation: 0, shadowColor: Colors.transparent, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(13))), child: loading ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2.2, color: Colors.white)) : Text(label, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700))));
}