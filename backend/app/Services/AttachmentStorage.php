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

    public function delete(?string $path): void
    {
        if ($path && Storage::exists($path)) {
            Storage::delete($path);
        }
    }
}
