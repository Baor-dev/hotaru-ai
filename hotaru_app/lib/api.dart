import 'package:dio/dio.dart';
import 'package:shared_preferences/shared_preferences.dart';

// Khởi tạo trạm gọi API dùng chung
// Đổi 127.0.0.1 thành IP mạng LAN hoặc 10.0.2.2 nếu chạy máy ảo Android
final Dio apiClient = Dio(BaseOptions(baseUrl: 'http://localhost'));

void setupApiConfig() {
  apiClient.interceptors.add(
    InterceptorsWrapper(
      onRequest: (options, handler) async {
        // Lấy Token từ bộ nhớ điện thoại
        final prefs = await SharedPreferences.getInstance();
        final token = prefs.getString('access_token');
        
        // Nếu có Token, nhét nó vào Header của request
        if (token != null) {
          options.headers['Authorization'] = 'Bearer $token';
        }
        return handler.next(options);
      },
      onError: (DioException e, handler) {
        // Có thể xử lý văng ra màn hình đăng nhập nếu token hết hạn (401)
        return handler.next(e);
      }
    ),
  );
}