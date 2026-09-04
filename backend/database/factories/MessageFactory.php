<?php

namespace Database\Factories;

use App\Enums\MessageType;
use App\Models\Conversation;
use App\Models\Message;
use App\Models\User;
use Illuminate\Database\Eloquent\Factories\Factory;

/**
 * @extends Factory<Message>
 */
class MessageFactory extends Factory
{
    /**
     * @return array<string, mixed>
     */
    public function definition(): array
    {
        return [
            'conversation_id' => fn () => Conversation::factory(),
            'sender_id' => fn () => User::factory(),
            'body' => fake()->sentence(),
            'type' => MessageType::Text,
            'read_by' => [],
        ];
    }
}
