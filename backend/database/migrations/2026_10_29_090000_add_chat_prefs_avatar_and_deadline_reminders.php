<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        // Per-person chat list preferences, like WhatsApp.
        Schema::table('conversation_participants', function (Blueprint $table) {
            $table->timestamp('pinned_at')->nullable()->after('last_read_at');
            $table->timestamp('archived_at')->nullable()->after('pinned_at');
            $table->boolean('muted')->default(false)->after('archived_at');
        });

        Schema::table('users', function (Blueprint $table) {
            $table->string('avatar_path')->nullable()->after('phone');
        });

        // So the hourly reminder runs once per task, not every hour.
        Schema::table('tasks', function (Blueprint $table) {
            $table->timestamp('deadline_reminded_at')->nullable()->after('deadline');
        });
    }

    public function down(): void
    {
        Schema::table('conversation_participants', function (Blueprint $table) {
            $table->dropColumn(['pinned_at', 'archived_at', 'muted']);
        });
        Schema::table('users', function (Blueprint $table) {
            $table->dropColumn('avatar_path');
        });
        Schema::table('tasks', function (Blueprint $table) {
            $table->dropColumn('deadline_reminded_at');
        });
    }
};
