import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:dio/dio.dart';
import '../api.dart';           // Import your API client
import 'auth_screen.dart';
import 'chat_screen.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  List<Map<String, dynamic>> _notebooks = [];
  bool _isLoading = true;

  final List<List<Color>> _gradients = [
    [const Color(0xFF1976D2), const Color(0xFF1565C0)],
    [const Color(0xFF0288D1), const Color(0xFF0277BD)],
    [const Color(0xFF00838F), const Color(0xFF006064)],
    [const Color(0xFF5C6BC0), const Color(0xFF3949AB)],
    [const Color(0xFF1E88E5), const Color(0xFF0D47A1)],
  ];

  @override
  void initState() {
    super.initState();
    _fetchNotebooks();
  }

  // Fetch notebooks from real backend
  Future<void> _fetchNotebooks() async {
    setState(() => _isLoading = true);
    try {
      final response = await apiClient.get('/notebooks/');

      if (response.statusCode == 200) {
        setState(() {
          if (response.data is Map<String, dynamic>) {
            final dynamic extractedList = response.data['data'] ??
                response.data['items'] ??
                response.data['notebooks'] ??
                response.data;

            if (extractedList is List) {
              _notebooks = extractedList.map((item) => item as Map<String, dynamic>).toList();
            }
          } else if (response.data is List) {
            _notebooks = (response.data as List)
                .map((item) => item as Map<String, dynamic>)
                .toList();
          }
          _isLoading = false;
        });
      }
    } catch (e) {
      print("❌ LỖI TẢI NOTEBOOK: $e");
      if (e is DioException) {
        print("❌ CHI TIẾT: ${e.response?.data}");
      }

      setState(() {
        _notebooks = [];
        _isLoading = false;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Lỗi tải danh sách: ${e.toString().split('\n')[0]}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _logout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('access_token');

    if (!mounted) return;
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (_) => const AuthScreen()),
      (route) => false,
    );
  }

  void _createNotebook() {
    final ctrl = TextEditingController();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _CreateNotebookSheet(
        controller: ctrl,
        onConfirm: (title) async {
          if (title.trim().isEmpty) return;
          try {
            await apiClient.post('/notebooks', data: {'title': title.trim()});
            _fetchNotebooks(); // Refresh after create
          } catch (e) {
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Không thể tạo notebook')),
              );
            }
          }
        },
      ),
    );
  }

  void _renameNotebook(int index) {
    final nb = _notebooks[index];
    final ctrl = TextEditingController(text: nb['title'] ?? '');

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _CreateNotebookSheet(
        controller: ctrl,
        title: 'Đổi tên Notebook',
        hint: 'Tên mới...',
        confirmLabel: 'Lưu',
        onConfirm: (title) async {
          if (title.trim().isEmpty) return;
          try {
            await apiClient.put('/notebooks/${nb['id']}', data: {'title': title.trim()});
            _fetchNotebooks();
          } catch (e) {
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Không thể đổi tên')),
              );
            }
          }
        },
      ),
    );
  }

  void _deleteNotebook(int index) {
    final nb = _notebooks[index];
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Xóa vĩnh viễn?',
            style: TextStyle(fontWeight: FontWeight.w700, fontSize: 17)),
        content: Text(
          'Notebook "${nb['title'] ?? 'Này'}" và toàn bộ dữ liệu sẽ bị xóa.',
          style: const TextStyle(fontSize: 13.5, color: Color(0xFF6B7280)),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Hủy', style: TextStyle(color: Color(0xFF9E9E9E))),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context);
              try {
                await apiClient.delete('/notebooks/${nb['id']}');
                _fetchNotebooks();
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Không thể xóa notebook')),
                  );
                }
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFEF5350),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              elevation: 0,
            ),
            child: const Text('Xóa', style: TextStyle(fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF0F2F5),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        scrolledUnderElevation: 1,
        shadowColor: Colors.black12,
        titleSpacing: 20,
        title: Row(
          children: [
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF1976D2), Color(0xFF1565C0)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(9),
              ),
              child: const Icon(Icons.auto_awesome, color: Colors.white, size: 16),
            ),
            const SizedBox(width: 10),
            const Text(
              'HOTARU AI',
              style: TextStyle(
                color: Color(0xFF1565C0),
                fontWeight: FontWeight.w900,
                fontSize: 17,
                letterSpacing: -0.3,
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout, color: Color(0xFFBDBDBD), size: 20),
            tooltip: 'Đăng xuất',
            onPressed: _logout,
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header row
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 24, 20, 0),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Không gian học tập',
                              style: TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.w800,
                                color: Color(0xFF111827),
                                letterSpacing: -0.4,
                              ),
                            ),
                            const SizedBox(height: 3),
                            Text(
                              '${_notebooks.length} notebook đang hoạt động',
                              style: const TextStyle(
                                  fontSize: 12.5, color: Color(0xFF9CA3AF)),
                            ),
                          ],
                        ),
                      ),
                      GestureDetector(
                        onTap: _createNotebook,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 9),
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              colors: [Color(0xFF1976D2), Color(0xFF1565C0)],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                            borderRadius: BorderRadius.circular(11),
                            boxShadow: [
                              BoxShadow(
                                color: const Color(0xFF1976D2).withOpacity(0.3),
                                blurRadius: 12,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          child: const Row(
                            children: [
                              Icon(Icons.add, color: Colors.white, size: 16),
                              SizedBox(width: 5),
                              Text('Tạo mới',
                                  style: TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.w700,
                                      fontSize: 13)),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 20),

                // Grid or Empty State
                Expanded(
                  child: _notebooks.isEmpty
                      ? _EmptyState(onTap: _createNotebook)
                      : GridView.builder(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: 2,
                            crossAxisSpacing: 12,
                            mainAxisSpacing: 12,
                            childAspectRatio: 0.82,
                          ),
                          itemCount: _notebooks.length,
                          itemBuilder: (context, i) {
                            final nb = _notebooks[i];
                            final grad = _gradients[(nb['colorIdx'] ?? i) % 5];

                            return _NotebookCard(
                              title: nb['title'] ?? 'Không tên',
                              date: nb['date'] ?? '',
                              gradient: grad,
                              animDelay: Duration(milliseconds: i * 60),
                              onTap: () => Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => ChatScreen(
                                    notebookId: nb['id'],
                                    notebookTitle: nb['title'] ?? '',
                                  ),
                                ),
                              ),
                              onRename: () => _renameNotebook(i),
                              onDelete: () => _deleteNotebook(i),
                            );
                          },
                        ),
                ),
              ],
            ),
    );
  }
}

// ─── NOTEBOOK CARD ────────────────────────────────────────
class _NotebookCard extends StatefulWidget {
  final String title;
  final String date;
  final List<Color> gradient;
  final Duration animDelay;
  final VoidCallback onTap;
  final VoidCallback onRename;
  final VoidCallback onDelete;

  const _NotebookCard({
    required this.title,
    required this.date,
    required this.gradient,
    required this.animDelay,
    required this.onTap,
    required this.onRename,
    required this.onDelete,
  });

  @override
  State<_NotebookCard> createState() => _NotebookCardState();
}

class _NotebookCardState extends State<_NotebookCard>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _opacity;
  late Animation<Offset> _slide;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 350));
    _opacity = Tween<double>(begin: 0, end: 1).animate(
        CurvedAnimation(parent: _ctrl, curve: Curves.easeOut));
    _slide = Tween<Offset>(begin: const Offset(0, 0.18), end: Offset.zero)
        .animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeOut));
    Future.delayed(widget.animDelay, () {
      if (mounted) _ctrl.forward();
    });
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _opacity,
      child: SlideTransition(
        position: _slide,
        child: GestureDetector(
          onTap: widget.onTap,
          child: Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: const Color(0xFFE8EAED), width: 1.5),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 10,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Banner
                Container(
                  height: 88,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: widget.gradient,
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: const BorderRadius.vertical(
                        top: Radius.circular(17)),
                  ),
                  child: Stack(
                    children: [
                      const Center(
                        child: _IconBox(),
                      ),
                      Positioned(
                        top: 6,
                        right: 4,
                        child: PopupMenuButton<String>(
                          icon: const Icon(Icons.more_vert,
                              color: Colors.white70, size: 18),
                          color: Colors.white,
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12)),
                          onSelected: (val) {
                            if (val == 'rename') widget.onRename();
                            if (val == 'delete') widget.onDelete();
                          },
                          itemBuilder: (_) => [
                            const PopupMenuItem(
                              value: 'rename',
                              child: Row(children: [
                                Icon(Icons.edit_outlined,
                                    size: 16, color: Color(0xFF6B7280)),
                                SizedBox(width: 10),
                                Text('Đổi tên',
                                    style: TextStyle(
                                        fontSize: 13.5,
                                        fontWeight: FontWeight.w500)),
                              ]),
                            ),
                            const PopupMenuItem(
                              value: 'delete',
                              child: Row(children: [
                                Icon(Icons.delete_outline,
                                    size: 16, color: Color(0xFFEF5350)),
                                SizedBox(width: 10),
                                Text('Xóa',
                                    style: TextStyle(
                                        fontSize: 13.5,
                                        fontWeight: FontWeight.w500,
                                        color: Color(0xFFEF5350))),
                              ]),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),

                // Content
                Padding(
                  padding: const EdgeInsets.fromLTRB(12, 10, 12, 0),
                  child: Text(
                    widget.title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF111827),
                      height: 1.35,
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(12, 5, 12, 0),
                  child: Row(
                    children: [
                      const Icon(Icons.schedule,
                          size: 11, color: Color(0xFFD1D5DB)),
                      const SizedBox(width: 4),
                      Text(widget.date,
                          style: const TextStyle(
                              fontSize: 11, color: Color(0xFFD1D5DB))),
                    ],
                  ),
                ),
                const Spacer(),
                Padding(
                  padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: const Color(0xFFEFF6FF),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: const Color(0xFFBFDBFE)),
                        ),
                        child: const Row(
                          children: [
                            Icon(Icons.folder_open_outlined,
                                size: 11, color: Color(0xFF1976D2)),
                            SizedBox(width: 4),
                            Text('Mở notebook',
                                style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.w600,
                                    color: Color(0xFF1976D2))),
                          ],
                        ),
                      ),
                      const Spacer(),
                      const Icon(Icons.chevron_right,
                          size: 16, color: Color(0xFFD1D5DB)),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _IconBox extends StatelessWidget {
  const _IconBox();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 48,
      height: 48,
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.18),
        borderRadius: BorderRadius.circular(13),
      ),
      child: const Icon(Icons.menu_book, color: Colors.white, size: 24),
    );
  }
}

// ─── EMPTY STATE ──────────────────────────────────────────
class _EmptyState extends StatelessWidget {
  final VoidCallback onTap;
  const _EmptyState({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              color: const Color(0xFFE3F0FF),
              borderRadius: BorderRadius.circular(24),
            ),
            child: const Icon(Icons.library_books_outlined,
                size: 38, color: Color(0xFF90CAF9)),
          ),
          const SizedBox(height: 16),
          const Text('Chưa có Notebook nào',
              style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF6B7280))),
          const SizedBox(height: 6),
          const Text('Tạo notebook đầu tiên để bắt đầu học',
              style: TextStyle(fontSize: 13, color: Color(0xFFD1D5DB))),
          const SizedBox(height: 20),
          ElevatedButton.icon(
            onPressed: onTap,
            icon: const Icon(Icons.add, size: 16),
            label: const Text('Tạo ngay',
                style: TextStyle(fontWeight: FontWeight.w700)),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF1976D2),
              foregroundColor: Colors.white,
              elevation: 0,
              padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 12),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── CREATE NOTEBOOK SHEET ─────────────────────────────────────────
class _CreateNotebookSheet extends StatelessWidget {
  final TextEditingController controller;
  final String title;
  final String hint;
  final String confirmLabel;
  final void Function(String) onConfirm;

  const _CreateNotebookSheet({
    required this.controller,
    required this.onConfirm,
    this.title = 'Tạo Notebook mới',
    this.hint = 'VD: Tài liệu Odoo, Đề cương C++...',
    this.confirmLabel = 'Tạo',
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        padding: const EdgeInsets.fromLTRB(24, 20, 24, 28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 20),
            Text(title,
                style: const TextStyle(
                    fontSize: 17, fontWeight: FontWeight.w800,
                    color: Color(0xFF111827))),
            const SizedBox(height: 14),
            TextField(
              controller: controller,
              autofocus: true,
              style: const TextStyle(fontSize: 14),
              decoration: InputDecoration(
                hintText: hint,
                hintStyle: TextStyle(color: Colors.grey[400], fontSize: 14),
                filled: true,
                fillColor: const Color(0xFFF9FAFB),
                contentPadding: const EdgeInsets.symmetric(
                    horizontal: 14, vertical: 13),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(11),
                  borderSide: const BorderSide(color: Color(0xFFE5E7EB)),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(11),
                  borderSide: const BorderSide(color: Color(0xFFE5E7EB)),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(11),
                  borderSide:
                      const BorderSide(color: Color(0xFF1976D2), width: 1.8),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.pop(context),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.grey[600],
                      side: BorderSide(color: Colors.grey[300]!),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(11)),
                      padding: const EdgeInsets.symmetric(vertical: 13),
                    ),
                    child: const Text('Hủy'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () {
                      onConfirm(controller.text);
                      Navigator.pop(context);
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF1976D2),
                      foregroundColor: Colors.white,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(11)),
                      padding: const EdgeInsets.symmetric(vertical: 13),
                    ),
                    child: Text(confirmLabel,
                        style: const TextStyle(fontWeight: FontWeight.w700)),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}