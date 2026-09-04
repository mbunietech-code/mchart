<?php

namespace Database\Factories;

use App\Enums\TaskPriority;
use App\Enums\TaskStatus;
use App\Models\Task;
use App\Models\User;
use Illuminate\Database\Eloquent\Factories\Factory;

/**
 * @extends Factory<Task>
 */
class TaskFactory extends Factory
{
    /**
     * @return array<string, mixed>
     */
    public function definition(): array
    {
        return [
            'title' => fake()->sentence(4),
            'description' => fake()->paragraph(),
            'priority' => fake()->randomElement(TaskPriority::cases()),
            'status' => TaskStatus::Assigned,
            'deadline' => fake()->optional()->dateTimeBetween('+1 day', '+2 weeks'),
            'created_by' => fn () => User::factory()->manager(),
            'assigned_to' => fn () => User::factory()->staff(),
            'department_id' => null,
        ];
    }

    public function status(TaskStatus $status): static
    {
        return $this->state(fn () => ['status' => $status]);
    }

    public function assignedTo(User $user): static
    {
        return $this->state(fn () => [
            'assigned_to' => $user->id,
            'department_id' => $user->department_id,
        ]);
    }

    public function createdBy(User $user): static
    {
        return $this->state(fn () => ['created_by' => $user->id]);
    }
}
