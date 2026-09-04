<?php

namespace App\Http\Requests;

use Illuminate\Foundation\Http\FormRequest;
use Illuminate\Validation\Rule;

class StoreDepartmentRequest extends FormRequest
{
    public function authorize(): bool
    {
        return $this->user()?->isAdmin() ?? false;
    }

    /**
     * @return array<string, mixed>
     */
    public function rules(): array
    {
        $id = $this->route('department')->id ?? $this->route('department');

        return [
            'name' => ['required', 'string', 'max:100', Rule::unique('departments', 'name')->ignore($id)],
            'description' => ['nullable', 'string'],
        ];
    }
}
