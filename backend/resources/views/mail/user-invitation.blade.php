<x-mail::message>
# Karibu MChart, {{ $user->name }}!

{{ $invitedBy }} has created your MChart account — the Mbunietech workspace for team chat, tasks and announcements.

**1. Download the app**

<x-mail::button :url="$apkUrl">
Download MChart for Android (v{{ $version }})
</x-mail::button>

On a Windows PC: [download the installer (v{{ $version }})]({{ $windowsUrl }}). All downloads: [{{ $downloadUrl }}]({{ $downloadUrl }})

@if ($webUrl)
On a computer you can also use it in the browser: [{{ $webUrl }}]({{ $webUrl }})
@endif

**2. Sign in with**

<x-mail::panel>
Username: **{{ $user->email }}**<br>
Temporary password: **{{ $temporaryPassword }}**
</x-mail::panel>

**3. Choose your own password**

For your security, the app will ask you to set a new password the first time you sign in. The temporary password stops working after that.

If you were not expecting this email, you can ignore it.

Thanks,<br>
{{ config('app.name') }}
</x-mail::message>
