<?php

return [
    // Shown on the public downloads page next to the APK/MSI links. Bump
    // this (and the pubspec.yaml version in app/) together on each release.
    'app_version' => env('MCHART_APP_VERSION', '1.0.10'),

    // Where invitation emails send people to install the app: the public
    // downloads page (resources/views/welcome.blade.php) by default.
    'download_url' => env('MCHART_DOWNLOAD_URL', rtrim((string) env('APP_URL'), '/').'/'),

    // Optional browser version of the app; omitted from emails when empty.
    'web_url' => env('MCHART_WEB_URL'),
];
