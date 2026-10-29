<?php

namespace App\Http\Controllers\Api\V1;

use App\Http\Controllers\Controller;
use Illuminate\Http\JsonResponse;
use Illuminate\Support\Facades\Cache;

/**
 * What the apps poll to update themselves: the current release (config
 * mchart.app_version) and where to fetch it, with checksums so the client
 * can refuse a truncated or tampered download.
 */
class AppVersionController extends Controller
{
    public function __invoke(): JsonResponse
    {
        return response()->json([
            'version' => config('mchart.app_version'),
            'android' => $this->download('mchart.apk'),
            'windows' => $this->download('MChart-Setup.exe'),
        ]);
    }

    private function download(string $name): ?array
    {
        $path = public_path('downloads/'.$name);
        if (! is_file($path)) {
            return null;
        }

        // Hashing a 60 MB file per request is too slow; key on size+mtime so
        // a new upload gets a fresh hash.
        $key = 'app-download-sha:'.$name.':'.filesize($path).':'.filemtime($path);

        return [
            'url' => asset('downloads/'.$name),
            'size' => filesize($path),
            'sha256' => Cache::rememberForever($key, fn () => hash_file('sha256', $path)),
        ];
    }
}
