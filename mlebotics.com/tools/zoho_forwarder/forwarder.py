#!/usr/bin/env python3
"""
zoho_forwarder.py
-----------------
Polls Zoho IMAP (imap.zohocloud.ca) for UNSEEN emails and forwards them
to a Gmail address via Zoho SMTP. Marks each email as SEEN after forwarding
so it is never forwarded twice.

Run via Windows Task Scheduler or GitHub Actions every 5 minutes.
"""
import email
import imaplib
import os
import smtplib
import ssl
import sys
from datetime import datetime
from email.message import EmailMessage
from pathlib import Path

# ── Config ────────────────────────────────────────────────────────────────────
ZOHO_USER     = os.environ.get("ZOHO_USER", "eddie@mlebotics.com")
ZOHO_PASSWORD = os.environ.get("ZOHO_APP_PASSWORD", "z2QrYAUDycwn")
IMAP_HOST     = "imap.zohocloud.ca"
IMAP_PORT     = 993
SMTP_HOST     = "smtp.zohocloud.ca"
SMTP_PORT     = 465
FORWARD_TO    = os.environ.get("FORWARD_TO", "eddie7ch@gmail.com")
LOG_FILE      = Path(__file__).parent / "forwarder.log"
# ─────────────────────────────────────────────────────────────────────────────


def log(msg: str) -> None:
    ts = datetime.now().strftime("%Y-%m-%d %H:%M:%S")
    entry = f"[{ts}] {msg}\n"
    sys.stdout.write(entry)
    with open(LOG_FILE, "a", encoding="utf-8") as f:
        f.write(entry)


def main() -> None:
    ctx = ssl.create_default_context()

    try:
        imap = imaplib.IMAP4_SSL(IMAP_HOST, IMAP_PORT, ssl_context=ctx)
        imap.login(ZOHO_USER, ZOHO_PASSWORD)
        imap.select("INBOX")

        status, data = imap.search(None, "UNSEEN")
        if status != "OK" or not data[0].strip():
            log("No new messages.")
            imap.logout()
            return

        nums = data[0].split()
        log(f"Found {len(nums)} unread message(s) — forwarding to {FORWARD_TO}")

        smtp = smtplib.SMTP_SSL(SMTP_HOST, SMTP_PORT, context=ctx)
        smtp.login(ZOHO_USER, ZOHO_PASSWORD)

        for num in nums:
            status, raw = imap.fetch(num, "(RFC822)")
            if status != "OK":
                log(f"Fetch failed for msg {num}")
                continue

            raw_bytes = raw[0][1]
            original  = email.message_from_bytes(raw_bytes)
            subject   = original.get("Subject", "(no subject)")
            from_addr = original.get("From", "(unknown)")
            to_addr   = original.get("To", "")
            date_str  = original.get("Date", "")

            fwd = EmailMessage()
            fwd["From"]    = ZOHO_USER
            fwd["To"]      = FORWARD_TO
            fwd["Subject"] = (
                "Fwd: " + subject
                if not subject.lower().startswith("fwd:")
                else subject
            )
            fwd.set_content(
                f"---------- Forwarded message ----------\n"
                f"From: {from_addr}\n"
                f"To: {to_addr}\n"
                f"Date: {date_str}\n"
                f"Subject: {subject}\n"
            )
            fwd.add_attachment(
                raw_bytes,
                maintype="message",
                subtype="rfc822",
                filename="original.eml",
            )

            smtp.send_message(fwd)
            imap.store(num, "+FLAGS", "\\Seen")
            log(f"Forwarded: {subject!r} from {from_addr}")

        smtp.quit()
        imap.logout()

    except Exception as exc:
        log(f"ERROR: {exc}")
        sys.exit(1)


if __name__ == "__main__":
    main()
