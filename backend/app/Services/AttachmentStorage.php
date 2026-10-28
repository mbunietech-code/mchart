<?php

namespace App\Services;

use Illuminate\Http\UploadedFile;
use Illuminate\Support\Facades\Storage;
use Illuminate\Support\Str;

class AttachmentStorage
{
    /**
     * Store an uploaded file under the given folder and return the metadata
     * needed for a *_attachments row.
     *
     * @return array{file_path: string, file_name: string, file_type: string, file_size: int}
     */
    public function store(UploadedFile $file, string $folder): array
    {
        $path = $file->store($folder, config('filesystems.default'));

        return [
            'file_path' => $path,
            'file_name' => $file->getClientOriginalName(),
            'file_type' => $file->getClientMimeType(),
            'file_size' => $file->getSize(),
        ];
    }

    /**
     * Duplicate a stored file into another folder (forwarding), so deleting
     * the original message never breaks the copy.
     */
    public function copy(string $path, string $folder): string
    {
        $target = $folder.'/'.Str::random(40).'.'.pathinfo($path, PATHINFO_EXTENSION);
        Storage::copy($path, $target);

        return $target;
    }

    /**
     * Link to a stored file. Private disks (production's `local`) get a
     * signed URL Laravel serves itself; the expiry is pinned to the end of
     * tomorrow so the link stays identical all day and image caches hold
     * across the app's polling.
     */
    public static function url(string $path): string
    {
        if (config('filesystems.disks.'.config('filesystems.default').'.driver') !== 'local'
            || config('filesystems.default') === 'public') {
            return Storage::url($path);
        }

        // Signature in the path, not the query: Hostinger's CDN strips
        // query strings from image requests (FileController).
        $expires = now()->addDay()->endOfDay()->getTimestamp();

        return url("files/{$expires}/".self::signature($path, $expires).'/'.$path);
    }

    public static function signature(string $path, int $expires): string
    {
        return hash_hmac('sha256', "{$path}|{$expires}", (string) config('app.key'));
    }

    public function delete(?string $path): void
    {
        if ($path && Storage::exists($path)) {
            Storage::delete($path);
        }
    }
}
