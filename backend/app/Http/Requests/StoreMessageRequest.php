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
            'attachments' => ['nullable', 'array', 'max:10'],
            'attachments.*' => ['file', 'max:20480'],
            'attachment_meta' => ['nullable', 'array'],
            'attachment_meta.*.duration_seconds' => ['nullable', 'integer', 'min:0'],
        ];
    }
}
