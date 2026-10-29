<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

/**
 * Links tasks and their comments to their copies in mbuniehub.com's
 * admin_tasks / admin_task_comments (see App\Services\HubTaskSync).
 */
return new class extends Migration
{
    public function up(): void
    {
        Schema::table('tasks', function (Blueprint $table) {
            $table->unsignedBigInteger('hub_task_id')->nullable()->unique();
        });
        Schema::table('task_comments', function (Blueprint $table) {
            $table->unsignedBigInteger('hub_comment_id')->nullable()->unique();
        });
    }

    public function down(): void
    {
        Schema::table('task_comments', fn (Blueprint $table) => $table->dropColumn('hub_comment_id'));
        Schema::table('tasks', fn (Blueprint $table) => $table->dropColumn('hub_task_id'));
    }
};
