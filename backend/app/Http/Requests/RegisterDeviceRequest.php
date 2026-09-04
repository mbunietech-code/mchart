<?php

namespace App\Http\Requests;

use Illuminate\Foundation\Http\FormRequest;
use Illuminate\Validation\Rule;

class RegisterDeviceRequest extends FormRequest
{
    public function authorize(): bool
    {
        return true;
    }

    /**
     * @return array<string, mixed>
     */
    public function rules(): array
    {
        return [
            'platform' => ['required', Rule::in(['windows', 'macos', 'android'])],
            'push_token' => ['required', 'string', 'max:255'],
            'device_name' => ['nullable', 'string', 'max:150'],
        ];
    }
}
