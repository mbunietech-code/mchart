<?php

namespace App\Http\Requests;

use App\Enums\TaskPriority;
use Illuminate\Foundation\Http\FormRequest;
use Illuminate\Validation\Rule;

class UpdateTaskRequest extends FormRequest
{
    public function authorize(): bool
    {
        return true; // handled by the controller's authorize('update', $task)
    }

    /**
     * @return array<string, mixed>
     */
    public function rules(): array
    {
        return [
            'title' => ['sometimes', 'string', 'max:200'],
            'description' => ['nullable', 'string'],
            'priority' => ['sometimes', Rule::enum(TaskPriority::class)],
            'deadline' => ['nullable', 'date'],
            'assigned_to' => ['sometimes', 'exists:users,id'],
            'department_id' => ['sometimes', 'exists:departments,id'],
        ];
    }
}
