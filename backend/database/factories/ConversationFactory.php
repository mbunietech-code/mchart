<?php

namespace Database\Factories;

use App\Enums\ConversationType;
use App\Models\Conversation;
use App\Models\User;
use Illuminate\Database\Eloquent\Factories\Factory;

/**
 * @extends Factory<Conversation>
 */
class ConversationFactory extends Factory
{
    /**
     * @return array<string, mixed>
     */
    public function definition(): array
    {
        return [
            'type' => ConversationType::Group,
            'name' => fake()->words(2, true),
            'created_by' => fn () => User::factory(),
        ];
    }

    public function direct(): static
    {
        return $this->state(fn () => ['type' => ConversationType::Direct, 'name' => null]);
    }

    public function channel(?int $departmentId = null): static
    {
        return $this->state(fn () => [
            'type' => ConversationType::Channel,
            'department_id' => $departmentId,
        ]);
    }

    /**
     * @param  array<int, User>  $users
     */
    public function withParticipants(array $users): static
    {
        return $this->afterCreating(function (Conversation $conversation) use ($users) {
            foreach ($users as $user) {
                $conversation->participants()->create([
                    'user_id' => $user->id,
                    'joined_at' => now(),
                ]);
            }
        });
    }
}
