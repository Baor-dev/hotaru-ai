import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:dio/dio.dart';
import '../api.dart'; // Sử dụng apiClient để có sẵn Token và baseUrl (localhost)

class ChatScreen extends StatefulWidget {
  final int notebookId;
  final String notebookTitle;

  const ChatScreen({
    super.key,
    required this.notebookId,
    required this.notebookTitle,
  });

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final _msgCtrl = TextEditingController();
  final _scrollCtrl = ScrollController();
  bool _isTyping = false;
  bool _isUploading = false;
  
  // 1. Thêm cờ loading để quản lý trạng thái tải tài liệu
  bool _isLoadingDocs = true; 

  // 2. Khởi tạo mảng rỗng thay vì dữ liệu giả
  List<_Doc> _docs = []; 
  List<int> _selectedDocIds = [];

  final List<_Msg> _messages = [
    _Msg(
      role: 'ai',
      content:
          'Chào bạn! Mình đã sẵn sàng phân tích các tài liệu bên dưới. Bạn muốn hỏi điều gì?',
    ),
  ];

  @override
  void initState() {
    super.initState();
    // 3. Gọi API lấy tài liệu thật ngay khi mở màn hình
    _fetchDocuments(); 
    _fetchChatHistory();
  }

  @override
  void dispose() {
    _msgCtrl.dispose();
    _scrollCtrl.dispose();
    super.dispose();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollCtrl.hasClients) {
        _scrollCtrl.animateTo(
          _scrollCtrl.position.maxScrollExtent + 80,
          duration: const Duration(milliseconds: 350),
          curve: Curves.easeOut,
        );
      }
    });
  }

  // ==========================================
  // LUỒNG 1: LẤY DANH SÁCH TÀI LIỆU (MỚI THÊM)
  // ==========================================
  Future<void> _fetchDocuments() async {
    setState(() => _isLoadingDocs = true);
    try {
      // Gọi API lấy tài liệu của notebook này
      final response = await apiClient.get('/notebooks/${widget.notebookId}/documents/');

      if (response.statusCode == 200) {
        setState(() {
          List<dynamic> rawList = [];

          // Safe Casting: Bắt cả trường hợp backend bọc trong key 'data', 'documents' hoặc trả thẳng mảng
          if (response.data is Map<String, dynamic>) {
             rawList = response.data['data'] ?? response.data['documents'] ?? [];
          } else if (response.data is List) {
             rawList = response.data;
          }

          // Map JSON sang object _Doc
          _docs = rawList.map((item) {
            final map = item as Map<String, dynamic>;
            return _Doc(
              // Ép kiểu an toàn cho ID (đề phòng backend trả String hoặc Int)
              id: map['id'] is int ? map['id'] : int.tryParse(map['id'].toString()) ?? 0,
              name: map['name'] ?? map['filename'] ?? map['title'] ?? 'Tài liệu không tên',
              type: map['type'] ?? map['extension'] ?? 'unknown',
            );
          }).toList();

          // Tự động chọn tất cả tài liệu vừa tải về (giống logic cũ của bạn)
          _selectedDocIds = _docs.map((d) => d.id).toList();
          _isLoadingDocs = false;
        });
      }
    } catch (e) {
      print("❌ LỖI TẢI DANH SÁCH TÀI LIỆU: $e");
      setState(() => _isLoadingDocs = false);
      _showError('Không thể tải danh sách tài liệu.');
    }
  }

  // ==========================================
  // LOGIC UPLOAD FILE (ĐÃ TỐI ƯU)
  // ==========================================
  Future<void> _pickAndUploadFile() async {
    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pdf', 'docx', 'txt', 'png', 'jpg', 'jpeg'],
        withData: true,
      );

      if (result == null) return;

      setState(() => _isUploading = true);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('⏳ Đang tải tài liệu lên AI...')),
      );

      final file = result.files.first;
      final formData = FormData.fromMap({
        'file': MultipartFile.fromBytes(
          file.bytes!,
          filename: file.name,
        ),
      });

      final response = await apiClient.post(
        '/notebooks/${widget.notebookId}/upload/',
        data: formData,
      );

      if (response.statusCode == 200) {
        if (response.data['error'] != null) {
          _showError(response.data['error']);
        } else {
          // THAY ĐỔI: Tải lại danh sách tài liệu từ server để lấy ID chuẩn thay vì fake ID
          await _fetchDocuments();
          
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('✅ Tải lên thành công: ${file.name}'),
              backgroundColor: Colors.green,
            ),
          );
        }
      }
    } on DioException catch (e) {
      final errorMsg = e.response?.data['detail'] ?? e.response?.data['error'] ?? 'Lỗi kết nối từ Backend!';
      _showError(errorMsg);
    } catch (e) {
      _showError('Đã xảy ra lỗi: $e');
    } finally {
      if (mounted) setState(() => _isUploading = false);
    }
  }

  void _showError(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('❌ $msg'), backgroundColor: Colors.red),
    );
  }

  // ==========================================
  // LUỒNG 3: GỬI TIN NHẮN THẬT LÊN AI
  // ==========================================
  Future<void> _sendMessage() async {
    final text = _msgCtrl.text.trim();
    if (text.isEmpty || _isTyping) return;

    // 1. Hiển thị tin nhắn của User ngay lập tức
    setState(() {
      _messages.add(_Msg(role: 'user', content: text));
      _msgCtrl.clear();
      _isTyping = true;
    });
    _scrollToBottom();

    // 2. Kiểm tra điều kiện chọn tài liệu
    if (_selectedDocIds.isEmpty) {
      await Future.delayed(const Duration(milliseconds: 600));
      setState(() {
        _messages.add(_Msg(
          role: 'ai',
          content: '⚠️ Bạn chưa chọn tài liệu nào. Vui lòng tích chọn ít nhất 1 tài liệu để mình có cơ sở trả lời nhé!',
        ));
        _isTyping = false;
      });
      _scrollToBottom();
      return;
    }

    // 3. Gọi API thật lên FastAPI
    try {
      // Sửa lại endpoint '/chat/' cho đúng với Router của Backend
      final response = await apiClient.post(
        '/chat/', 
        data: {
          'notebook_id': widget.notebookId, 
          'query': text, 
          'selected_docs': _selectedDocIds.map((id) => id.toString()).toList(),
        },
      );

      if (response.statusCode == 200) {
        final responseData = response.data;
        
        // Áp dụng linh hoạt: Check xem backend trả về key nào
        final aiContent = responseData['answer'] ?? responseData['reply'] ?? responseData['content'] ?? 'Xin lỗi, tôi không thể trả lời lúc này.';
        
        // Lấy danh sách nguồn (nếu có)
        List<String> sources = [];
        if (responseData['sources'] is List) {
          sources = (responseData['sources'] as List).map((e) => e.toString()).toList();
        }

        setState(() {
          _messages.add(_Msg(
            role: 'ai',
            content: aiContent,
            sources: sources,
          ));
          _isTyping = false;
        });
        _scrollToBottom();
      }
    } on DioException catch (e) {
      print("❌ LỖI API CHAT: ${e.response?.data}");
      setState(() {
        _messages.add(_Msg(
          role: 'ai',
          content: '❌ Mất kết nối đến Server AI. Chi tiết lỗi: ${e.response?.statusCode}',
        ));
        _isTyping = false;
      });
      _scrollToBottom();
    } catch (e) {
      print("❌ LỖI NGOẠI LỆ KHI CHAT: $e");
      setState(() {
        _messages.add(_Msg(role: 'ai', content: '❌ Đã xảy ra lỗi hệ thống cục bộ.'));
        _isTyping = false;
      });
      _scrollToBottom();
    }
  }

  Future<void> _fetchChatHistory() async {
    try {
      final response = await apiClient.get('/notebooks/${widget.notebookId}/history/');
      
      if (response.statusCode == 200) {
        // Vẫn giữ log để sau này dễ debug
        print("📥 LỊCH SỬ CHAT RAW: ${response.data}");
        
        // Kiểm tra xem backend có trả về đúng dạng Map và có key 'history' không
        if (response.data is Map<String, dynamic> && response.data['history'] is List) {
          final List<dynamic> historyList = response.data['history'];

          if (historyList.isNotEmpty) {
            setState(() {
              // Xóa câu chào mặc định
              _messages.clear(); 
              
              // Duyệt qua từng cặp câu hỏi - câu trả lời
              for (var item in historyList) {
                final map = item as Map<String, dynamic>;

                // 1. Tạo bong bóng chat cho câu hỏi của User
                if (map['question'] != null) {
                  _messages.add(_Msg(
                    role: 'user',
                    content: map['question'].toString(),
                    sources: [], // User thì không cần sources
                  ));
                }

                // 2. Bóc tách danh sách sources của AI (Lấy ra filename)
                List<String> parsedSources = [];
                if (map['sources'] is List) {
                  for (var sourceItem in map['sources']) {
                    if (sourceItem is Map<String, dynamic> && sourceItem['filename'] != null) {
                      parsedSources.add(sourceItem['filename'].toString());
                    }
                  }
                }

                // 3. Tạo bong bóng chat cho câu trả lời của AI
                if (map['answer'] != null) {
                  _messages.add(_Msg(
                    role: 'ai',
                    content: map['answer'].toString(),
                    sources: parsedSources,
                  ));
                }
              }
            });
            
            // Cuộn xuống cuối
            Future.delayed(const Duration(milliseconds: 300), () => _scrollToBottom());
          }
        }
      }
    } catch (e) {
      print("❌ LỖI TẢI LỊCH SỬ CHAT: $e");
    }
  }

  void _showDocPanel() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => _DocPanel(
        docs: _docs,
        selectedIds: List.from(_selectedDocIds),
        onChanged: (ids) => setState(() => _selectedDocIds = ids),
        onAdd: () {
          Navigator.pop(context);
          _pickAndUploadFile(); 
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF7F8FA),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        scrolledUnderElevation: 1,
        shadowColor: Colors.black12,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new,
              size: 18, color: Color(0xFF6B7280)),
          onPressed: () => Navigator.pop(context),
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              widget.notebookTitle,
              style: const TextStyle(
                fontSize: 14.5,
                fontWeight: FontWeight.w800,
                color: Color(0xFF111827),
                letterSpacing: -0.2,
              ),
            ),
            Row(
              children: [
                Container(
                  width: 7,
                  height: 7,
                  margin: const EdgeInsets.only(right: 5),
                  decoration: const BoxDecoration(
                    color: Color(0xFF4CAF50),
                    shape: BoxShape.circle,
                  ),
                ),
                const Text(
                  'Hotaru AI · Đang hoạt động',
                  style: TextStyle(fontSize: 11, color: Color(0xFF9CA3AF)),
                ),
              ],
            ),
          ],
        ),
        actions: [
          GestureDetector(
            onTap: _showDocPanel,
            child: Container(
              margin: const EdgeInsets.only(right: 14),
              padding:
                  const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: _selectedDocIds.isEmpty
                    ? const Color(0xFFFFF3E0)
                    : const Color(0xFFEFF6FF),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: _selectedDocIds.isEmpty
                      ? const Color(0xFFFFCC02)
                      : const Color(0xFFBFDBFE),
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    _selectedDocIds.isEmpty
                        ? Icons.warning_amber_rounded
                        : Icons.folder_open_outlined,
                    size: 13,
                    color: _selectedDocIds.isEmpty
                        ? const Color(0xFFF57C00)
                        : const Color(0xFF1976D2),
                  ),
                  const SizedBox(width: 4),
                  Text(
                    _selectedDocIds.isEmpty
                        ? 'Chưa chọn'
                        : '${_selectedDocIds.length} tài liệu',
                    style: TextStyle(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w600,
                      color: _selectedDocIds.isEmpty
                          ? const Color(0xFFF57C00)
                          : const Color(0xFF1976D2),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          if (_isUploading)
            const LinearProgressIndicator(color: Color(0xFF1976D2)),
          // Chat messages
          Expanded(
            child: ListView.builder(
              controller: _scrollCtrl,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
              itemCount: _messages.length + (_isTyping ? 1 : 0),
              itemBuilder: (context, i) {
                if (_isTyping && i == _messages.length) {
                  return const _TypingBubble();
                }
                return _MessageBubble(msg: _messages[i]);
              },
            ),
          ),

          // Input
          _ChatInput(
            controller: _msgCtrl,
            isTyping: _isTyping,
            onSend: _sendMessage,
            onDocTap: _showDocPanel,
          ),
        ],
      ),
    );
  }
}

// ─── MESSAGE BUBBLE ───────────────────────────────────────

class _MessageBubble extends StatelessWidget {
  final _Msg msg;
  const _MessageBubble({required this.msg});

  @override
  Widget build(BuildContext context) {
    final isUser = msg.role == 'user';
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        mainAxisAlignment:
            isUser ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (!isUser) ...[
            const CircleAvatar(
              radius: 16,
              backgroundColor: Color(0xFF1976D2),
              child: Text('AI',
                  style: TextStyle(
                      color: Colors.white,
                      fontSize: 10,
                      fontWeight: FontWeight.w800)),
            ),
            const SizedBox(width: 8),
          ],
          Flexible(
            child: Column(
              crossAxisAlignment:
                  isUser ? CrossAxisAlignment.end : CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 14, vertical: 11),
                  decoration: BoxDecoration(
                    gradient: isUser
                        ? const LinearGradient(
                            colors: [Color(0xFF1976D2), Color(0xFF1565C0)],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          )
                        : null,
                    color: isUser ? null : Colors.white,
                    borderRadius: BorderRadius.only(
                      topLeft: const Radius.circular(18),
                      topRight: const Radius.circular(18),
                      bottomLeft: Radius.circular(isUser ? 18 : 4),
                      bottomRight: Radius.circular(isUser ? 4 : 18),
                    ),
                    border: isUser
                        ? null
                        : Border.all(color: const Color(0xFFE8EAED)),
                    boxShadow: [
                      BoxShadow(
                        color: isUser
                            ? const Color(0xFF1976D2).withOpacity(0.2)
                            : Colors.black.withOpacity(0.04),
                        blurRadius: isUser ? 12 : 6,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Text(
                    msg.content,
                    style: TextStyle(
                      fontSize: 14,
                      height: 1.55,
                      color: isUser ? Colors.white : const Color(0xFF1F2937),
                    ),
                  ),
                ),
                // ==========================================
                // ĐÃ SỬA PHẦN NÀY: GẮN SỰ KIỆN BẤM VÀO SOURCE
                // ==========================================
                if (!isUser && msg.sources.isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Wrap(
                    spacing: 6,
                    runSpacing: 4,
                    children: msg.sources.map((s) {
                      return GestureDetector(
                        onTap: () {
                          // Hiện Pop-up xem trước khi bấm vào Nguồn
                          showDialog(
                            context: context,
                            builder: (BuildContext context) {
                              return DocumentPreviewPopup(
                                identifier: s.toString(), // Truyền tên file lên API
                              );
                            },
                          );
                        },
                        child: _SourceChip(label: s),
                      );
                    }).toList(),
                  ),
                ],
                // ==========================================
              ],
            ),
          ),
          if (isUser) ...[
            const SizedBox(width: 8),
            const CircleAvatar(
              radius: 16,
              backgroundColor: Color(0xFFF3F4F6),
              child: Icon(Icons.person, size: 16, color: Color(0xFF9CA3AF)),
            ),
          ],
        ],
      ),
    );
  }
}

class _SourceChip extends StatelessWidget {
  final String label;
  const _SourceChip({required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: const Color(0xFFEFF6FF),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFBFDBFE)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.link, size: 10, color: Color(0xFF1976D2)),
          const SizedBox(width: 4),
          Text(
            label.length > 20 ? '${label.substring(0, 18)}…' : label,
            style: const TextStyle(
                fontSize: 10.5,
                color: Color(0xFF1976D2),
                fontWeight: FontWeight.w500),
          ),
        ],
      ),
    );
  }
}

class _TypingBubble extends StatefulWidget {
  const _TypingBubble();

  @override
  State<_TypingBubble> createState() => _TypingBubbleState();
}

class _TypingBubbleState extends State<_TypingBubble>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 900))
      ..repeat();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          const CircleAvatar(
            radius: 16,
            backgroundColor: Color(0xFF1976D2),
            child: Text('AI',
                style: TextStyle(
                    color: Colors.white,
                    fontSize: 10,
                    fontWeight: FontWeight.w800)),
          ),
          const SizedBox(width: 8),
          Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(18),
                topRight: Radius.circular(18),
                bottomRight: Radius.circular(18),
                bottomLeft: Radius.circular(4),
              ),
              border: Border.all(color: const Color(0xFFE8EAED)),
              boxShadow: [
                BoxShadow(
                    color: Colors.black.withOpacity(0.04),
                    blurRadius: 6,
                    offset: const Offset(0, 2))
              ],
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: List.generate(3, (i) {
                return AnimatedBuilder(
                  animation: _ctrl,
                  builder: (_, __) {
                    final t = (_ctrl.value - i * 0.15).clamp(0.0, 1.0);
                    final scale = 0.6 + 0.4 * (0.5 - (t - 0.5).abs()) * 2;
                    return Container(
                      margin: const EdgeInsets.symmetric(horizontal: 3),
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: Color.lerp(
                            Colors.grey[300], const Color(0xFF1976D2), scale),
                      ),
                      transform: Matrix4.identity()
                        ..translate(0.0, -4.0 * (scale - 0.6)),
                    );
                  },
                );
              }),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── CHAT INPUT ───────────────────────────────────────────

class _ChatInput extends StatelessWidget {
  final TextEditingController controller;
  final bool isTyping;
  final VoidCallback onSend;
  final VoidCallback onDocTap;

  const _ChatInput({
    required this.controller,
    required this.isTyping,
    required this.onSend,
    required this.onDocTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        border: const Border(top: BorderSide(color: Color(0xFFEEEEEE))),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withOpacity(0.04),
              blurRadius: 10,
              offset: const Offset(0, -2))
        ],
      ),
      padding: EdgeInsets.only(
        left: 16,
        right: 16,
        top: 10,
        bottom: MediaQuery.of(context).padding.bottom + 10,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              // Attach doc btn
              GestureDetector(
                onTap: onDocTap,
                child: Container(
                  width: 40,
                  height: 40,
                  margin: const EdgeInsets.only(right: 8, bottom: 2),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF0F2F5),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.attach_file,
                      color: Color(0xFF9CA3AF), size: 18),
                ),
              ),

              // Text field
              Expanded(
                child: Container(
                  constraints: const BoxConstraints(maxHeight: 120),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF7F8FA),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: const Color(0xFFE5E7EB)),
                  ),
                  child: TextField(
                    controller: controller,
                    maxLines: null,
                    enabled: !isTyping,
                    style: const TextStyle(fontSize: 14),
                    textInputAction: TextInputAction.send,
                    onSubmitted: (_) => onSend(),
                    decoration: const InputDecoration(
                      hintText: 'Hỏi AI về tài liệu của bạn...',
                      hintStyle: TextStyle(
                          color: Color(0xFFD1D5DB), fontSize: 13.5),
                      border: InputBorder.none,
                      contentPadding: EdgeInsets.symmetric(
                          horizontal: 14, vertical: 10),
                    ),
                  ),
                ),
              ),

              // Send button
              const SizedBox(width: 8),
              GestureDetector(
                onTap: isTyping ? null : onSend,
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  width: 42,
                  height: 42,
                  margin: const EdgeInsets.only(bottom: 1),
                  decoration: BoxDecoration(
                    gradient: isTyping
                        ? null
                        : const LinearGradient(
                            colors: [Color(0xFF1976D2), Color(0xFF1565C0)],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                    color: isTyping ? const Color(0xFFF0F2F5) : null,
                    borderRadius: BorderRadius.circular(13),
                    boxShadow: isTyping
                        ? []
                        : [
                            BoxShadow(
                              color: const Color(0xFF1976D2).withOpacity(0.3),
                              blurRadius: 10,
                              offset: const Offset(0, 3),
                            ),
                          ],
                  ),
                  child: Icon(
                    Icons.send_rounded,
                    color: isTyping ? Colors.grey[400] : Colors.white,
                    size: 18,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          const Text(
            'Nhấn Enter để gửi · Chọn tài liệu qua nút 📎',
            style: TextStyle(fontSize: 10.5, color: Color(0xFFD1D5DB)),
          ),
        ],
      ),
    );
  }
}

// ─── DOC PANEL ────────────────────────────────────────────

class _DocPanel extends StatefulWidget {
  final List<_Doc> docs;
  final List<int> selectedIds;
  final ValueChanged<List<int>> onChanged;
  final VoidCallback onAdd;

  const _DocPanel({
    required this.docs,
    required this.selectedIds,
    required this.onChanged,
    required this.onAdd,
  });

  @override
  State<_DocPanel> createState() => _DocPanelState();
}

class _DocPanelState extends State<_DocPanel> {
  late List<int> _selected;

  @override
  void initState() {
    super.initState();
    _selected = List.from(widget.selectedIds);
  }

  void _toggle(int id) {
    setState(() {
      if (_selected.contains(id)) {
        _selected.remove(id);
      } else {
        _selected.add(id);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Center(
            child: Container(
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(2)),
            ),
          ),
          const SizedBox(height: 18),
          Row(
            children: [
              const Text('Tài liệu nguồn',
                  style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF111827))),
              const Spacer(),
              GestureDetector(
                onTap: widget.onAdd,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: const Color(0xFFEFF6FF),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: const Color(0xFFBFDBFE)),
                  ),
                  child: const Row(
                    children: [
                      Icon(Icons.add, size: 14, color: Color(0xFF1976D2)),
                      SizedBox(width: 4),
                      Text('Thêm',
                          style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: Color(0xFF1976D2))),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          ...widget.docs.map((doc) {
            final selected = _selected.contains(doc.id);
            // BỎ cái GestureDetector bọc ngoài cùng đi, giữ lại AnimatedContainer làm khung nền
            return AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
              decoration: BoxDecoration(
                color: selected ? const Color(0xFFEFF6FF) : const Color(0xFFF9FAFB),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: selected ? const Color(0xFFBFDBFE) : const Color(0xFFE5E7EB),
                  width: 1.5,
                ),
              ),
              child: Row(
                children: [
                  // ==========================================
                  // VÙNG 1: BẤM VÀO TÊN FILE -> MỞ POP-UP PREVIEW
                  // ==========================================
                  Expanded(
                    child: GestureDetector(
                      behavior: HitTestBehavior.opaque, // Giúp vùng bấm nhạy hơn
                      onTap: () {
                        // Gọi Pop-up Xem trước
                        showDialog(
                          context: context,
                          builder: (BuildContext context) {
                            return DocumentPreviewPopup(
                              identifier: doc.id.toString(), 
                            );
                          },
                        );
                      },
                      child: Row(
                        children: [
                          Icon(
                            doc.type == 'pdf'
                                ? Icons.picture_as_pdf
                                : doc.type == 'docx'
                                    ? Icons.description
                                    : Icons.text_snippet,
                            size: 18,
                            color: doc.type == 'pdf'
                                ? const Color(0xFFEF5350)
                                : const Color(0xFF1976D2),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  doc.name,
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                    color: selected
                                        ? const Color(0xFF1565C0)
                                        : const Color(0xFF374151),
                                  ),
                                ),
                                Text(
                                  doc.type.toUpperCase(),
                                  style: const TextStyle(
                                    fontSize: 10,
                                    color: Color(0xFF9CA3AF),
                                    letterSpacing: 0.5,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  
                  // ==========================================
                  // VÙNG 2: BẤM VÀO CHECKBOX -> CHỌN/BỎ CHỌN
                  // ==========================================
                  GestureDetector(
                    onTap: () => _toggle(doc.id), // Logic chọn file giữ nguyên ở đây
                    behavior: HitTestBehavior.opaque,
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 180),
                      width: 22,
                      height: 22,
                      decoration: BoxDecoration(
                        color: selected ? const Color(0xFF1976D2) : Colors.transparent,
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(
                          color: selected ? const Color(0xFF1976D2) : const Color(0xFFD1D5DB),
                          width: 1.5,
                        ),
                      ),
                      child: selected
                          ? const Icon(Icons.check, color: Colors.white, size: 14)
                          : null,
                    ),
                  ),
                ],
              ),
            );
          }),
          const SizedBox(height: 8),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () {
                widget.onChanged(_selected);
                Navigator.pop(context);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF1976D2),
                foregroundColor: Colors.white,
                elevation: 0,
                padding: const EdgeInsets.symmetric(vertical: 13),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
              child: Text(
                  'Xác nhận (${_selected.length}/${widget.docs.length})',
                  style: const TextStyle(fontWeight: FontWeight.w700)),
            ),
          ),
        ],
      ),
    );
  }
}

// Widget hiển thị Pop-up Xem trước Tài liệu
class DocumentPreviewPopup extends StatefulWidget {
  final String identifier;

  const DocumentPreviewPopup({super.key, required this.identifier});

  @override
  State<DocumentPreviewPopup> createState() => _DocumentPreviewPopupState();
}

class _DocumentPreviewPopupState extends State<DocumentPreviewPopup> {
  bool _isLoading = true;
  String _filename = 'Đang tải...';
  String _content = '';
  String _errorMessage = '';

  @override
  void initState() {
    super.initState();
    _fetchPreview();
  }

  Future<void> _fetchPreview() async {
    try {
      // Gọi API xem trước (Dùng apiClient của bạn)
      final response = await apiClient.get('/documents/${widget.identifier}');
      
      if (response.statusCode == 200) {
        setState(() {
          _filename = response.data['filename'] ?? 'Tài liệu không tên';
          _content = response.data['content'] ?? 'Không có nội dung văn bản.';
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'Đã xảy ra lỗi tải tài liệu.';
        _isLoading = false;
        _filename = 'Lỗi';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    // Dialog Pop-up
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 40),
      child: Container(
        // Giới hạn chiều cao tối đa bằng 80% màn hình để không bị lố
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.8,
        ),
        padding: const EdgeInsets.only(top: 16, left: 16, right: 16, bottom: 8),
        child: Column(
          mainAxisSize: MainAxisSize.min, // Tự co lại nếu text ngắn
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Dòng Tiêu đề + Nút Đóng
            Row(
              children: [
                const Icon(Icons.description, color: Colors.blue, size: 24),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    _filename,
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close, color: Colors.grey),
                  onPressed: () => Navigator.of(context).pop(), // Đóng pop-up
                ),
              ],
            ),
            const Divider(),
            
            // Phần Nội dung linh hoạt
            Flexible(
              child: _buildBody(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Padding(
        padding: EdgeInsets.all(32.0),
        child: Center(child: CircularProgressIndicator()),
      );
    }

    if (_errorMessage.isNotEmpty) {
      return Padding(
        padding: const EdgeInsets.all(32.0),
        child: Center(
          child: Text(
            _errorMessage,
            style: const TextStyle(color: Colors.red),
            textAlign: TextAlign.center,
          ),
        ),
      );
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.only(bottom: 16),
      child: SelectableText(
        _content,
        style: const TextStyle(
          fontSize: 14,
          height: 1.6,
          color: Colors.black87,
        ),
      ),
    );
  }
}

// ─── DATA MODELS ──────────────────────────────────────────

class _Doc {
  final int id;
  final String name;
  final String type;
  const _Doc({required this.id, required this.name, required this.type});
}

class _Msg {
  final String role;
  final String content;
  final List<String> sources;
  const _Msg({required this.role, required this.content, this.sources = const []});
}