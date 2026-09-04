<?php

namespace App\Http\Requests;

use Illuminate\Foundation\Http\FormRequest;

class UploadAttachmentRequest extends FormRequest
{
    public function authorize(): bool
    {
        return true; // controller authorizes on the parent resource
    }

    /**
     * @return array<string, mixed>
     */
    public function rules(): array
    {
        return [
            'file' => [
                'required',
                'file',
                'max:20480', // 20 MB
                'mimetypes:image/jpeg,image/png,image/gif,image/webp,application/pdf,'
                    .'audio/mpeg,audio/mp4,audio/aac,audio/ogg,audio/webp,audio/wav,audio/x-wav,'
                    .'text/plain,application/zip,application/msword,'
                    .'application/vnd.openxmlformats-officedocument.wordprocessingml.document,'
                    .'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
            ],
            'duration_seconds' => ['nullable', 'integer', 'min:0', 'max:86400'],
        ];
    }
}
