<?php

namespace App\Http\Requests;

use App\Enums\AnnouncementCategory;
use Illuminate\Foundation\Http\FormRequest;
use Illuminate\Validation\Rule;

/** Used for both create and update; update makes every field optional. */
class StoreAnnouncementRequest extends FormRequest
{
    public function authorize(): bool
    {
        return true; // the controller authorizes against the policy
    }

    /**
     * @return array<string, mixed>
     */
    public function rules(): array
    {
        $required = $this->isCreate() ? 'required' : 'sometimes';

        return [
            'category' => [$required, Rule::enum(AnnouncementCategory::class)],
            'title' => [$required, 'string', 'max:150'],
            'body' => [$required, 'string', 'max:5000'],
            'department_id' => ['nullable', 'integer', 'exists:departments,id'],
            'pinned' => ['sometimes', 'boolean'],
            'archived' => ['sometimes', 'boolean'],
            'expires_at' => ['nullable', 'date', 'after:now'],
            'image' => ['nullable', 'image', 'mimes:jpeg,png,gif,webp', 'max:5120'],
            'remove_image' => ['sometimes', 'boolean'],
        ];
    }

    public function withValidator($validator): void
    {
        $validator->after(function ($validator) {
            $actor = $this->user();
            if (! $actor || $actor->isAdmin() || ! $this->exists('department_id')) {
                return;
            }

            // Managers speak for their own department only, never company-wide.
            if ((int) $this->input('department_id') !== (int) $actor->department_id) {
                $validator->errors()->add('department_id', 'Managers can only post announcements to their own department.');
            }
        });
    }

    /** Updates also arrive as POST (multipart can't ride on PATCH in PHP). */
    private function isCreate(): bool
    {
        return $this->route('announcement') === null;
    }

    protected function prepareForValidation(): void
    {
        // A manager who doesn't pick an audience posts to their department.
        $actor = $this->user();
        if ($this->isCreate() && $actor?->isManager() && ! $this->filled('department_id')) {
            $this->merge(['department_id' => $actor->department_id]);
        }
    }
}
