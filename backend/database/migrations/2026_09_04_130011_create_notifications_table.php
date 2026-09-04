<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::create('notifications', function (Blueprint $table) {
            $table->id();
            $table->foreignId('user_id')->constrained('users')->cascadeOnDelete(); // recipient
            $table->string('type', 50);                     // task_completed, task_approved, new_message, ...
            $table->string('title', 150);
            $table->string('body', 255)->nullable();
            $table->string('reference_type', 30)->nullable();   // 'task' or 'message'
            $table->unsignedBigInteger('reference_id')->nullable();
            $table->json('data')->nullable();               // extra payload for deep-linking
            $table->boolean('is_read')->default(false);
            $table->timestamp('read_at')->nullable();
            $table->timestamps();

            $table->index(['user_id', 'is_read']);
        });
    }

    public function down(): void
    {
        Schema::dropIfExists('notifications');
    }
};
