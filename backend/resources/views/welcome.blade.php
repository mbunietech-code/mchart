<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="utf-8">
    <meta name="viewport" content="width=device-width, initial-scale=1">
    <title>MChart — Mbunietech Workspace</title>
    <meta name="description" content="Download MChart for Windows and Android, or open the web app.">
    <link rel="icon" type="image/png" href="{{ asset('favicon.png') }}">

    <style>
        :root {
            --primary: #1E40AF;
            --dark: #0F172A;
            --amber: #F59E0B;
            --slate: #64748B;
            --slate-light: #94A3B8;
            --success: #10B981;
            --bg: #F8FAFC;
            --card-bg: #FFFFFF;
            --border: #E2E8F0;
        }
        * { box-sizing: border-box; }
        body {
            margin: 0;
            background: var(--bg);
            color: var(--dark);
            font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, Helvetica, Arial, sans-serif;
            min-height: 100vh;
            display: flex;
            flex-direction: column;
            align-items: center;
            padding: 48px 20px;
        }
        .brand { display: flex; align-items: center; gap: 12px; margin-bottom: 8px; }
        .brand .mark {
            width: 44px; height: 44px; border-radius: 12px; background: #fff;
            border: 1px solid var(--border); display: flex; align-items: center; justify-content: center;
            box-shadow: 0 1px 2px rgba(15, 23, 42, 0.06);
        }
        .brand .name { font-size: 22px; font-weight: 700; letter-spacing: -0.02em; }
        .brand .name span { color: var(--slate); font-weight: 500; font-size: 14px; display: block; margin-top: -2px; }
        h1 { font-size: 15px; font-weight: 500; color: var(--slate); margin: 4px 0 40px; text-align: center; }
        .cards {
            display: grid;
            grid-template-columns: repeat(auto-fit, minmax(260px, 1fr));
            gap: 20px;
            width: 100%;
            max-width: 880px;
        }
        .card {
            background: var(--card-bg);
            border: 1px solid var(--border);
            border-radius: 14px;
            padding: 28px 24px;
            display: flex;
            flex-direction: column;
            box-shadow: 0 1px 2px rgba(15, 23, 42, 0.04);
        }
        .card .icon {
            width: 40px; height: 40px; border-radius: 10px;
            display: flex; align-items: center; justify-content: center;
            margin-bottom: 16px;
        }
        .card .icon svg { width: 22px; height: 22px; }
        .card h2 { font-size: 16px; margin: 0 0 4px; }
        .card p.desc { font-size: 13px; color: var(--slate); margin: 0 0 20px; line-height: 1.5; flex-grow: 1; }
        .card p.meta { font-size: 12px; color: var(--slate-light); margin: 10px 0 0; }
        .btn {
            display: inline-flex; align-items: center; justify-content: center; gap: 8px;
            padding: 10px 16px; border-radius: 8px; font-size: 14px; font-weight: 600;
            text-decoration: none; transition: opacity 0.15s;
        }
        .btn:hover { opacity: 0.88; }
        .btn-primary { background: var(--primary); color: #fff; }
        .btn-disabled { background: var(--bg); color: var(--slate-light); border: 1px solid var(--border); cursor: not-allowed; pointer-events: none; }
        .icon-web { background: #EFF6FF; color: var(--primary); }
        .icon-android { background: #ECFDF5; color: var(--success); }
        .icon-windows { background: #FFFBEB; color: var(--amber); }
        footer { margin-top: 56px; font-size: 12px; color: var(--slate-light); text-align: center; }
        footer a { color: var(--slate); }
    </style>
</head>
<body>
    <div class="brand">
        <div class="mark">
            <svg width="26" height="26" viewBox="0 0 512 512" xmlns="http://www.w3.org/2000/svg">
                <g transform="translate(64, 64)">
                    <path d="M 192 48 C 96 48 24 116 24 204 C 24 254 48 298 88 326 C 96 332 98 344 94 354 L 78 392 C 74 402 84 412 94 408 L 148 386 C 158 382 170 384 178 390 C 206 400 236 404 268 400 C 254 380 248 356 252 332 C 254 322 262 312 272 312 C 284 312 292 322 290 334 C 286 358 296 376 312 390 C 342 368 360 334 360 296 C 360 208 288 48 192 48 Z" fill="none" stroke="#1B2A6B" stroke-width="30" stroke-linecap="round" stroke-linejoin="round"/>
                    <path d="M 112 210 L 168 266 C 174 272 184 272 190 266 L 314 128" fill="none" stroke="#1B2A6B" stroke-width="30" stroke-linecap="round" stroke-linejoin="round"/>
                    <circle cx="314" cy="128" r="15" fill="#1B2A6B"/>
                </g>
            </svg>
        </div>
        <div class="name">MChart<span>Mbunietech Workspace</span></div>
    </div>
    <h1>Chat, tasks and notifications for the whole team — pick your platform.</h1>

    @php
        $apkPath = public_path('downloads/mchart.apk');
        $msiPath = public_path('downloads/mchart-setup.msi');
        $apkExists = file_exists($apkPath);
        $msiExists = file_exists($msiPath);
        $fmtSize = fn ($bytes) => number_format($bytes / 1048576, 1) . ' MB';
    @endphp

    <div class="cards">
        <div class="card">
            <div class="icon icon-web">
                <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><circle cx="12" cy="12" r="10"/><line x1="2" y1="12" x2="22" y2="12"/><path d="M12 2a15.3 15.3 0 0 1 4 10 15.3 15.3 0 0 1-4 10 15.3 15.3 0 0 1-4-10 15.3 15.3 0 0 1 4-10z"/></svg>
            </div>
            <h2>Web App</h2>
            <p class="desc">No install needed — open MChart straight in your browser. Works on any computer.</p>
            <a class="btn btn-primary" href="https://cha.mbuniehub.com" target="_blank" rel="noopener">Open Web App →</a>
            <p class="meta">cha.mbuniehub.com</p>
        </div>

        <div class="card">
            <div class="icon icon-android">
                <svg viewBox="0 0 24 24" fill="currentColor"><path d="M17.6 9.48l1.84-3.18c.16-.31.04-.69-.26-.85-.29-.15-.65-.06-.83.22l-1.88 3.24a11.43 11.43 0 0 0-8.94 0L5.65 5.67a.637.637 0 0 0-.87-.2c-.28.16-.38.53-.22.83L6.4 9.48A10.78 10.78 0 0 0 1 18h22a10.78 10.78 0 0 0-5.4-8.52zM7 15.25a1.25 1.25 0 1 1 0-2.5 1.25 1.25 0 0 1 0 2.5zm10 0a1.25 1.25 0 1 1 0-2.5 1.25 1.25 0 0 1 0 2.5z"/></svg>
            </div>
            <h2>Android</h2>
            <p class="desc">Download the APK and install directly on your phone or tablet.</p>
            @if ($apkExists)
                <a class="btn btn-primary" href="{{ asset('downloads/mchart.apk') }}">Download APK ↓</a>
                <p class="meta">{{ $fmtSize(filesize($apkPath)) }} · v{{ config('mchart.app_version', '1.0.0') }}</p>
            @else
                <a class="btn btn-disabled">Coming soon</a>
            @endif
        </div>

        <div class="card">
            <div class="icon icon-windows">
                <svg viewBox="0 0 24 24" fill="currentColor"><path d="M3 5.5L10.5 4.4V11.4H3V5.5M11.5 4.3L21 3V11.3H11.5V4.3M3 12.4H10.5V19.5L3 18.4V12.4M11.5 12.4H21V20.9L11.5 19.6V12.4Z"/></svg>
            </div>
            <h2>Windows</h2>
            <p class="desc">Run the installer and choose where MChart gets installed on your PC.</p>
            @if ($msiExists)
                <a class="btn btn-primary" href="{{ asset('downloads/mchart-setup.msi') }}">Download Installer ↓</a>
                <p class="meta">{{ $fmtSize(filesize($msiPath)) }} · v{{ config('mchart.app_version', '1.0.0') }}</p>
            @else
                <a class="btn btn-disabled">Coming soon</a>
            @endif
        </div>
    </div>

    <footer>
        &copy; {{ date('Y') }} Mbunietech Technologies Limited. All rights reserved.
    </footer>
</body>
</html>
