<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::create('conversations', function (Blueprint $table) {
            $table->id();
            $table->enum('type', ['direct', 'group', 'channel']);
            $table->string('name', 150)->nullable();         // null for direct chats
            $table->foreignId('department_id')->nullable()   // set for department channels
                ->constrained('departments')->nullOnDelete();
            $table->foreignId('created_by')->nullable()
                ->constrained('users')->nullOnDelete();
            $table->timestamp('last_message_at')->nullable();
            $table->timestamps();

            $table->index(['type', 'department_id']);
        });
    }

    public function down(): void
    {
        Schema::dropIfExists('conversations');
    }
};
