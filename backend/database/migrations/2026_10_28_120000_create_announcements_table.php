<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::create('announcements', function (Blueprint $table) {
            $table->id();
            $table->foreignId('author_id')->constrained('users')->cascadeOnDelete();
            // Audience: null = the whole company, otherwise one department.
            $table->foreignId('department_id')->nullable()->constrained('departments')->nullOnDelete();
            $table->string('category', 20);                 // meeting, notice, event, reminder, urgent
            $table->string('title', 150);
            $table->text('body');
            $table->string('image_path')->nullable();
            $table->boolean('pinned')->default(false);
            $table->timestamp('expires_at')->nullable();    // past = treated as archived
            $table->timestamp('archived_at')->nullable();
            $table->timestamps();

            $table->index(['archived_at', 'pinned', 'created_at']);
        });

        Schema::create('announcement_reads', function (Blueprint $table) {
            $table->foreignId('announcement_id')->constrained('announcements')->cascadeOnDelete();
            $table->foreignId('user_id')->constrained('users')->cascadeOnDelete();
            $table->timestamp('read_at');

            $table->primary(['announcement_id', 'user_id']);
            $table->index('user_id');
        });
    }

    public function down(): void
    {
        Schema::dropIfExists('announcement_reads');
        Schema::dropIfExists('announcements');
    }
};
