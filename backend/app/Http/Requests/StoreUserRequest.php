<?php

namespace App\Http\Requests;

use App\Enums\UserRole;
use Illuminate\Foundation\Http\FormRequest;
use Illuminate\Validation\Rule;
use Illuminate\Validation\Rules\Password;

class StoreUserRequest extends FormRequest
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
        return [
            'name' => ['required', 'string', 'max:150'],
            'email' => ['required', 'email', 'max:150', 'unique:users,email'],
            'phone' => ['nullable', 'string', 'max:30'],
            // Empty = generate a temporary password and email it.
            'password' => ['nullable', 'confirmed', Password::defaults()],
            'role' => ['required_without:role_id', 'nullable', Rule::enum(UserRole::class)],
            // A specific job title; wins over 'role' (a bare level).
            'role_id' => ['nullable', 'integer', 'exists:roles,id'],
            'department_id' => ['nullable', 'exists:departments,id'],
            'status' => ['nullable', Rule::in(['active', 'inactive'])],
        ];
    }
}
