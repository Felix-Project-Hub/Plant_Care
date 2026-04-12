from __future__ import annotations

from email.message import EmailMessage
import smtplib

from app.core.config import settings


def send_reset_password_email(*, to_email: str, temp_password: str) -> None:
    backend = (settings.email_backend or "").strip().lower()
    if backend in {"", "disabled", "off", "false", "0"}:
        return
    if backend == "console":
        print(f"EMAIL_RESET_PASSWORD to={to_email}")
        return
    if backend != "smtp":
        raise ValueError("Invalid EMAIL_BACKEND")

    subject = f"{settings.app_name} 密碼重設"
    body = "\n".join(
        [
            f"你正在重設 {settings.app_name} 的密碼。",
            "",
            "臨時密碼：",
            temp_password,
            "",
            "請使用此臨時密碼重新登入後，務必立即修改密碼。",
            "",
            "若此操作非你本人發起，請忽略此郵件。",
        ]
    )

    msg = EmailMessage()
    msg["Subject"] = subject
    from_email = (settings.smtp_from or settings.smtp_username or "").strip()
    if not from_email:
        raise ValueError("SMTP_FROM is required")
    from_name = (settings.smtp_from_name or settings.app_name or "").strip()
    msg["From"] = f"{from_name} <{from_email}>" if from_name else from_email
    msg["To"] = to_email
    msg.set_content(body)

    if settings.smtp_use_ssl:
        with smtplib.SMTP_SSL(
            host=settings.smtp_host,
            port=settings.smtp_port,
            timeout=settings.smtp_timeout_seconds,
        ) as server:
            _smtp_login(server)
            server.send_message(msg)
            print("EMAIL_SENT via=smtp_ssl")
        return

    with smtplib.SMTP(
        host=settings.smtp_host,
        port=settings.smtp_port,
        timeout=settings.smtp_timeout_seconds,
    ) as server:
        if settings.smtp_use_tls:
            server.starttls()
        _smtp_login(server)
        server.send_message(msg)
        print("EMAIL_SENT via=smtp")


def _smtp_login(server: smtplib.SMTP) -> None:
    username = (settings.smtp_username or "").strip()
    password = (settings.smtp_password or "").strip()
    if not username:
        return
    server.login(username, password)
