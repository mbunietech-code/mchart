<?php

namespace App\Http\Controllers;

use App\Services\AttachmentStorage;
use Illuminate\Support\Facades\Storage;
use Symfony\Component\HttpFoundation\Response;

/**
 * Serves private uploads behind a path-embedded signature (see
 * AttachmentStorage::url). Hostinger's CDN drops query strings on image
 * requests, so Laravel's ?signature= links 404'd for photos.
 */
class FileController extends Controller
{
    public function show(int $expires, string $signature, string $path): Response
    {
        abort_if(
            $expires < now()->getTimestamp()
                || ! hash_equals(AttachmentStorage::signature($path, $expires), $signature)
                || str_contains($path, '..'),
            404,
        );

        $disk = Storage::disk();
        abort_unless($disk->exists($path), 404);

        return $disk->response($path, null, [
            // The URL already changes daily; let the CDN and phones cache it.
            'Cache-Control' => 'private, max-age=86400',
        ]);
    }
}
