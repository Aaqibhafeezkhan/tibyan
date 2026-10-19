"""Confirmation emails for the altibyan.app forms (best effort, sent in the
background so a slow SMTP never delays the page)."""
from __future__ import annotations

import logging
import smtplib

from .config import settings
from .mail import send_mail
from .push import utcnow

logger = logging.getLogger(__name__)

PLAY_TEST_URL = "https://play.google.com/apps/internaltest/4701465992904267136"
TESTFLIGHT_URL = "https://testflight.apple.com/join/gxJ4rrdd"
TESTFLIGHT_APP_URL = "https://apps.apple.com/app/testflight/id899247664"
BETA_PAGE_URL = "https://altibyan.app/beta"


def _send(subject: str, body: str, to: str) -> None:
    try:
        if not send_mail(subject=subject, body=body, to=to):
            logger.info("SMTP not configured; confirmation to a signup was skipped.")
    except (OSError, smtplib.SMTPException, ValueError):
        logger.exception("Failed to send a launch-form confirmation email.")


def send_notify_confirmation(email: str, lang: str) -> None:
    if lang == "ar":
        subject = "تبيان: سجّلنا بريدك"
        body = (
            "السلام عليكم،\n\n"
            "شكرًا لاهتمامك بتبيان. سجّلنا بريدك، وسنرسل إليك رسالة واحدة عند الإطلاق.\n"
            "لن نشارك بريدك مع أي جهة.\n\n"
            f"إن أردت تجربة النسخة التجريبية قبل الإطلاق: {BETA_PAGE_URL}\n\n"
            "إن لم تطلب ذلك فتجاهل هذه الرسالة.\n\nفريق تبيان\nhttps://altibyan.app"
        )
    else:
        subject = "Tibyan: you are on the list"
        body = (
            "Hello,\n\n"
            "Thank you for your interest in Tibyan. We saved your address and will send you\n"
            "one message at launch. We never share your address.\n\n"
            f"Want to try the beta before launch? {BETA_PAGE_URL}\n\n"
            "If you did not ask for this, ignore this message.\n\nThe Tibyan team\nhttps://altibyan.app"
        )
    _send(subject, body, email)


def send_beta_confirmation(email: str, lang: str, platforms: list[str]) -> None:
    ar = lang == "ar"
    parts = []
    if "android" in platforms:
        parts.append(
            "أندرويد:\n"
            f"1. افتح هذا الرابط على هاتفك وأنت مسجّل بحساب Google المرتبط بهذا البريد: {PLAY_TEST_URL}\n"
            "2. اضغط «أصبح مختبِرًا».\n3. اضغط «تنزيل من Google Play»، ثم ثبّت التطبيق أو حدّثه.\n"
            "إن ظهر أن الرابط غير متاح، فانتظر حتى نضيف بريدك إلى قائمة المختبِرين ثم أعد فتحه."
            if ar else
            "Android:\n"
            f"1. Open this link on your phone, signed in with the Google account for this address: {PLAY_TEST_URL}\n"
            "2. Tap «Become a tester».\n3. Tap «Download it on Google Play», then install or update.\n"
            "If the link says it is unavailable, wait until we add your address to the testers list, then open it again."
        )
    if "ios" in platforms or "mac" in platforms:
        parts.append(
            "آيفون وآيباد وماك:\n"
            f"1. ثبّت تطبيق TestFlight من App Store (أو Mac App Store على الماك): {TESTFLIGHT_APP_URL}\n"
            f"2. افتح هذا الرابط على الجهاز نفسه: {TESTFLIGHT_URL}\n3. اضغط «Accept» ثم «Install»."
            if ar else
            "iPhone, iPad and Mac:\n"
            f"1. Install Apple's TestFlight app from the App Store (Mac App Store on a Mac): {TESTFLIGHT_APP_URL}\n"
            f"2. Open this link on the same device: {TESTFLIGHT_URL}\n3. Tap «Accept», then «Install»."
        )
    steps = "\n\n".join(parts)
    if ar:
        subject = "تبيان: طلب الانضمام لاختبار النسخة التجريبية"
        body = (
            "السلام عليكم،\n\nشكرًا لانضمامك إلى مختبِري تبيان. ستصلك الإصدارات الأولى قبل إطلاقها،\n"
            "ونرجو أن ترسل ملاحظاتك من داخل التطبيق عبر «الإبلاغ عن مشكلة».\n\n"
            f"{steps}\n\nالخطوات مصوّرة في: {BETA_PAGE_URL}\n\nفريق تبيان"
        )
    else:
        subject = "Tibyan: your beta test request"
        body = (
            "Hello,\n\nThank you for joining Tibyan's testers. You will get early versions before\n"
            "launch; please send feedback from inside the app with «Report a problem».\n\n"
            f"{steps}\n\nIllustrated steps: {BETA_PAGE_URL}\n\nThe Tibyan team"
        )
    _send(subject, body, email)


def signup_alert_recipients() -> list[str]:
    return [a.strip() for a in settings.signup_notify_emails.split(",") if a.strip()]


def send_signup_alert(kind: str, email: str, lang: str, platforms: list[str] | None = None) -> None:
    """Tell the team about a new signup (kind: notify | beta)."""
    to = signup_alert_recipients()
    if not to:
        return
    label = "Beta tester request" if kind == "beta" else "Notify-me signup"
    tab = "beta" if kind == "beta" else "notify"
    body = (
        f"{label} on altibyan.app\n\n"
        f"Email:     {email}\n"
        f"Platforms: {', '.join(platforms) if platforms else '-'}\n"
        f"Language:  {lang}\n"
        f"Time:      {utcnow():%Y-%m-%d %H:%M} UTC\n\n"
        f"Admin: https://train.altibyan.app/admin/requests?tab={tab}\n"
    )
    _send(f"[Tibyan] {label}: {email}", body, ", ".join(to))
