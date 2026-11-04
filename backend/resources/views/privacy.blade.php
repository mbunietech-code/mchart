<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="utf-8">
    <meta name="viewport" content="width=device-width, initial-scale=1">
    <title>MChat — Privacy Policy</title>
    <link rel="icon" type="image/png" href="{{ asset('favicon.png') }}">
    <style>
        body { margin: 0; background: #F8FAFC; color: #0F172A; font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, Helvetica, Arial, sans-serif; line-height: 1.6; }
        main { max-width: 760px; margin: 0 auto; padding: 40px 20px 64px; }
        h1 { font-size: 26px; margin: 0 0 4px; }
        h2 { font-size: 17px; margin: 28px 0 6px; }
        p, li { font-size: 15px; color: #334155; }
        .meta { color: #64748B; font-size: 13px; margin-bottom: 24px; }
        a { color: #1E40AF; }
    </style>
</head>
<body>
<main>
    <h1>MChat Privacy Policy</h1>
    <p class="meta">Last updated: 4 November 2026</p>

    <p>MChat is a workplace chat and task app operated by Mbunietech Technologies Limited ("we", "us"). It is used by staff of organisations that invite them. This policy explains what data MChat collects, why, and who it is shared with. It applies to the MChat apps for Android, Windows and the web, and to the service at chart.mbunie.tech.</p>

    <h2>Data we collect</h2>
    <ul>
        <li><strong>Account details:</strong> your name, work email address, job title or department, profile photo (optional) and a hashed password. These are usually set up by your organisation's administrator when you are invited.</li>
        <li><strong>Content you create:</strong> chat messages, voice notes, photos, files and stickers you send; tasks, comments, attachments and announcements.</li>
        <li><strong>Activity data:</strong> read receipts, reactions, when you were last active, and task status changes, so your team can see progress.</li>
        <li><strong>Device data:</strong> a push-notification token (Firebase Cloud Messaging) so we can notify you of new messages and tasks, and basic technical logs (IP address, app version, errors) to keep the service secure and working.</li>
    </ul>

    <h2>Device permissions</h2>
    <ul>
        <li><strong>Camera:</strong> only when you choose to take a photo to send.</li>
        <li><strong>Microphone:</strong> only while you record a voice note.</li>
        <li><strong>Notifications:</strong> to alert you of new messages and tasks.</li>
    </ul>
    <p>We do not collect your location, contacts, or advertising identifiers. An optional app PIN is stored only on your device, as a salted hash, and is never sent to us.</p>

    <h2>How we use data</h2>
    <p>Only to provide MChat: delivering messages and tasks to the right people, sending notifications and account emails (invitations, password resets), keeping the service secure, and fixing problems. We do not sell your data, use it for advertising, or build profiles of you.</p>

    <h2>Who we share data with</h2>
    <ul>
        <li><strong>Your organisation:</strong> members of your workspace see what you send them, and administrators can manage accounts and content.</li>
        <li><strong>Service providers</strong> that run parts of MChat for us: our hosting provider (Hostinger) stores the data, Google Firebase delivers push notifications, and our email provider sends account emails. They process data only on our instructions.</li>
        <li><strong>Authorities</strong>, only when the law requires it.</li>
    </ul>

    <h2>Security</h2>
    <p>Data is sent over encrypted connections (HTTPS). Passwords are stored hashed, and uploaded files are only reachable through signed, expiring links.</p>

    <h2>Retention and deletion</h2>
    <p>Data is kept while your account is active. You can delete your own messages, or clear a chat from your view, at any time in the app. When your organisation removes your account, or you ask us to delete it, we delete or anonymise your personal data within 30 days, except where the law requires us to keep it longer.</p>

    <h2>Your rights</h2>
    <p>You can ask to see, correct, export or delete your personal data. Contact your workspace administrator, or us at the address below.</p>

    <h2>Children</h2>
    <p>MChat is a workplace tool and is not meant for children under 16.</p>

    <h2>Changes</h2>
    <p>If we change this policy we will update the date above and, for significant changes, tell you in the app.</p>

    <h2>Contact</h2>
    <p>Mbunietech Technologies Limited<br>
        @if (config('mchart.privacy_email'))
            Email: <a href="mailto:{{ config('mchart.privacy_email') }}">{{ config('mchart.privacy_email') }}</a><br>
        @endif
        Website: <a href="https://chart.mbunie.tech">chart.mbunie.tech</a></p>
</main>
</body>
</html>
