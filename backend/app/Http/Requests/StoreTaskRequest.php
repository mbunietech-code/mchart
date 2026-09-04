<?php

namespace App\Http\Requests;

use App\Enums\TaskPriority;
use App\Models\User;
use Illuminate\Foundation\Http\FormRequest;
use Illuminate\Validation\Rule;

class StoreTaskRequest extends FormRequest
{
    public function authorize(): bool
    {
        return $this->user()?->isManagerOrAdmin() ?? false;
    }

    /**
     * @return array<string, mixed>
     */
    public function rules(): array
    {
        return [
            'title' => ['required', 'string', 'max:200'],
            'description' => ['nullable', 'string'],
            'priority' => ['nullable', Rule::enum(TaskPriority::class)],
            'deadline' => ['nullable', 'date'],
            'assigned_to' => ['required', 'exists:users,id'],
            'department_id' => ['nullable', 'exists:departments,id'],
        ];
    }

    protected function prepareForValidation(): void
    {
        if (! $this->filled('department_id') && $this->filled('assigned_to')) {
            $assignee = User::find($this->input('assigned_to'));
            if ($assignee?->department_id) {
                $this->merge(['department_id' => $assignee->department_id]);
            }
        }
    }

    public function withValidator($validator): void
    {
        $validator->after(function ($validator) {
            $actor = $this->user();

            if ($actor && $actor->isManager() && $this->filled('department_id')
                && (int) $this->input('department_id') !== (int) $actor->department_id) {
                $validator->errors()->add('department_id', 'Managers can only create tasks within their own department.');
            }
        });
    }
}
