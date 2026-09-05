<?php

namespace App\Http\Requests;

use App\Enums\MessageType;
use Illuminate\Foundation\Http\FormRequest;
use Illuminate\Validation\Rule;

class StoreMessageRequest extends FormRequest
{
    public function authorize(): bool
    {
        return true; // controller authorizes 'sendMessage'
    }

    /**
     * @return array<string, mixed>
     */
    public function rules(): array
    {
        return [
            'body' => ['nullable', 'required_without:attachments', 'string', 'max:10000'],
            'type' => ['nullable', Rule::enum(MessageType::class)],
            'reply_to_id' => ['nullable', 'integer', 'exists:messages,id'],
            'attachments' => ['nullable', 'array', 'max:10'],
            'attachments.*' => [
                'file',
                'max:51200', // 50 MB — stays under Cloudflare's free-tier 100MB body limit.
                'mimetypes:image/jpeg,image/png,image/gif,image/webp,application/pdf,'
                    .'audio/mpeg,audio/mp4,audio/aac,audio/ogg,audio/webp,audio/wav,audio/x-wav,'
                    .'video/mp4,video/webm,video/quicktime,video/3gpp,video/x-msvideo,'
                    .'text/plain,application/zip,application/msword,'
                    .'application/vnd.openxmlformats-officedocument.wordprocessingml.document,'
                    .'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
            ],
            'attachment_meta' => ['nullable', 'array'],
            'attachment_meta.*.duration_seconds' => ['nullable', 'integer', 'min:0'],
        ];
    }
}
