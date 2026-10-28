<!doctype html>
<html lang="en">
<head>
    <meta charset="utf-8">
    <meta name="viewport" content="width=device-width, initial-scale=1">
    <title>Reset password · MChart</title>
    <style>
        :root { --brand: #1E40AF; --text: #0F172A; --muted: #64748B; --border: #E2E8F0; --danger: #EF4444; --ok: #10B981; }
        * { box-sizing: border-box; }
        body { margin: 0; min-height: 100vh; display: grid; place-items: center; background: #EEF1F6;
               font-family: system-ui, -apple-system, Segoe UI, Roboto, sans-serif; color: var(--text); padding: 16px; }
        .card { width: 100%; max-width: 400px; background: #fff; border: 1px solid var(--border); border-radius: 16px; padding: 28px; }
        h1 { font-size: 20px; margin: 0 0 6px; }
        p { color: var(--muted); font-size: 14px; margin: 0 0 18px; }
        label { display: block; font-size: 12px; font-weight: 600; margin: 14px 0 6px; }
        input { width: 100%; padding: 11px 12px; border: 1px solid var(--border); border-radius: 8px; font-size: 15px; }
        button { width: 100%; margin-top: 20px; padding: 12px; border: 0; border-radius: 8px; background: var(--brand);
                 color: #fff; font-size: 15px; font-weight: 600; cursor: pointer; }
        .err { color: var(--danger); font-size: 13px; margin-top: 10px; }
        .ok { color: var(--ok); font-weight: 600; }
    </style>
</head>
<body>
<div class="card">
    @if (! empty($done))
        <h1>Password changed</h1>
        <p class="ok">Your new password is set. Open the MChart app and sign in with it.</p>
    @else
        <h1>Choose a new password</h1>
        <p>For {{ $email }}</p>
        <form method="post" action="{{ url('reset-password') }}">
            @csrf
            <input type="hidden" name="token" value="{{ $token }}">
            <input type="hidden" name="email" value="{{ $email }}">
            <label for="password">New password</label>
            <input id="password" name="password" type="password" minlength="8" required autocomplete="new-password">
            <label for="password_confirmation">Confirm new password</label>
            <input id="password_confirmation" name="password_confirmation" type="password" minlength="8" required autocomplete="new-password">
            @if (! empty($error))
                <div class="err">{{ $error }}</div>
            @endif
            @if ($errors->any())
                <div class="err">{{ $errors->first() }}</div>
            @endif
            <button type="submit">Save new password</button>
        </form>
    @endif
</div>
</body>
</html>
