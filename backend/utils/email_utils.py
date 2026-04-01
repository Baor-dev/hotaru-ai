import smtplib
import ssl # Bổ sung thư viện này
from email.mime.text import MIMEText
from email.mime.multipart import MIMEMultipart

from sqlalchemy import true

# ==========================================
# CẤU HÌNH (LẤY CHUẨN TỪ FILE .env CỦA NODE.JS CŨ)
# ==========================================
# Mở file .env của dự án Node.js cũ ra và copy y nguyên 4 thông số này sang:
SMTP_HOST = "mail.cecomtech.com.vn"
SMTP_PORT = 465 # Hoặc 465, lấy đúng số trong file Node.js
SENDER_EMAIL = "no-reply@cecomtech.com.vn" 
SENDER_PASSWORD = "Cecomtech@2026"

def send_verification_email(receiver_email: str, token: str):
    msg = MIMEMultipart()
    msg['From'] = SENDER_EMAIL
    msg['To'] = receiver_email
    msg['Subject'] = "Xác thực tài khoản Hệ thống RAG"

    verify_link = f"http://localhost/verify/{token}"

    body = f"""
    <!DOCTYPE html>
    <html>
    <head>
        <meta charset="UTF-8">
        <meta name="viewport" content="width=device-width, initial-scale=1.0">
    </head>
    <body style="margin: 0; padding: 0; font-family: 'Segoe UI', Tahoma, Geneva, Verdana, sans-serif; background-color: #f4f7f6; color: #333333;">
        <table width="100%" cellpadding="0" cellspacing="0" style="background-color: #f4f7f6; padding: 40px 0;">
            <tr>
                <td align="center">
                    <table width="600" cellpadding="0" cellspacing="0" style="background-color: #ffffff; border-radius: 8px; overflow: hidden; box-shadow: 0 4px 15px rgba(0,0,0,0.05); max-width: 90%;">
                        
                        <tr>
                            <td align="center" style="background-color: #1a73e8; padding: 35px 20px; border-bottom: 3px solid #155dbb;">
                                <h1 style="color: #ffffff; margin: 0; font-size: 28px; letter-spacing: 2px;">HOTARU AI</h1>
                                <p style="color: #e8f0fe; margin: 5px 0 0 0; font-size: 14px;">Trợ lý học tập thông minh</p>
                            </td>
                        </tr>
                        
                        <tr>
                            <td style="padding: 40px 30px;">
                                <h2 style="margin-top: 0; color: #2c3e50; font-size: 22px; text-align: center;">Xác Thực Tài Khoản</h2>
                                <p style="font-size: 16px; line-height: 1.6; color: #555555;">
                                    Chào bạn,<br><br>
                                    Cảm ơn bạn đã đăng ký tài khoản tại hệ thống <strong>Hotaru AI</strong>. Để hoàn tất quá trình thiết lập và đảm bảo tính bảo mật, vui lòng xác thực địa chỉ email của bạn bằng cách nhấn vào nút bên dưới:
                                </p>
                                
                                <table width="100%" cellpadding="0" cellspacing="0">
                                    <tr>
                                        <td align="center" style="padding: 30px 0;">
                                            <a href="{verify_link}" style="background-color: #2ecc71; color: #ffffff; text-decoration: none; padding: 15px 35px; border-radius: 5px; font-size: 16px; font-weight: bold; display: inline-block; box-shadow: 0 4px 6px rgba(46, 204, 113, 0.2);">XÁC THỰC EMAIL NGAY</a>
                                        </td>
                                    </tr>
                                </table>
                                
                                <p style="font-size: 14px; color: #888888; margin-top: 10px; text-align: center;">
                                    <em>Lưu ý: Liên kết này sẽ tự động hết hạn sau 24 giờ.</em>
                                </p>
                            </td>
                        </tr>
                        
                        <tr>
                            <td style="background-color: #f8f9fa; padding: 25px 30px; border-top: 1px solid #eeeeee; text-align: center;">
                                <p style="font-size: 13px; color: #999999; margin: 0; line-height: 1.6;">
                                    Nếu bạn không yêu cầu tạo tài khoản, vui lòng bỏ qua email này.<br>
                                    &copy; 2026 Hotaru AI - Cecomtech. All rights reserved.
                                </p>
                            </td>
                        </tr>
                        
                    </table>
                </td>
            </tr>
        </table>
    </body>
    </html>
    """
    
    msg.attach(MIMEText(body, 'html'))

    try:
        # ==========================================
        # ĐÂY CHÍNH LÀ "REJECT UNAUTHORIZED: FALSE" CỦA PYTHON
        # ==========================================
        context = ssl.create_default_context()
        context.check_hostname = False
        context.verify_mode = ssl.CERT_NONE

        if SMTP_PORT == 465:
            # Nếu dùng cổng 465 (Secure)
            server = smtplib.SMTP_SSL(SMTP_HOST, SMTP_PORT, context=context)
            server.login(SENDER_EMAIL, SENDER_PASSWORD)
        else:
            # Nếu dùng cổng 587 hoặc 25
            server = smtplib.SMTP(SMTP_HOST, SMTP_PORT)
            server.starttls(context=context) # Ép dùng context bỏ qua SSL
            server.login(SENDER_EMAIL, SENDER_PASSWORD)
        
        server.sendmail(SENDER_EMAIL, receiver_email, msg.as_string())
        server.quit()
        print(f"📧 Đã gửi email xác thực thành công tới {receiver_email}")
        return True
    except Exception as e:
        print(f"❌ Lỗi gửi mail: {str(e)}")
        return False