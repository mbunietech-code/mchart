<?php

namespace App\Http\Requests;

use App\Enums\ConversationType;
use Illuminate\Foundation\Http\FormRequest;
use Illuminate\Validation\Rule;

class StoreConversationRequest extends FormRequest
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
            'type' => ['required', Rule::enum(ConversationType::class)],
            'name' => ['nullable', 'required_unless:type,direct', 'string', 'max:150'],
            'department_id' => ['nullable', 'exists:departments,id'],
            'participant_ids' => ['required', 'array', 'min:1'],
            'participant_ids.*' => ['integer', 'distinct', 'exists:users,id'],
        ];
    }

    public function withValidator($validator): void
    {
        $validator->after(function ($validator) {
            if ($this->input('type') === ConversationType::Direct->value
                && count($this->input('participant_ids', [])) !== 1) {
                $validator->errors()->add('participant_ids', 'A direct conversation must have exactly one other participant.');
            }
        });
    }
}
