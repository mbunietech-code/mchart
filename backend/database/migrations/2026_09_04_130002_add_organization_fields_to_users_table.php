<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::table('users', function (Blueprint $table) {
            $table->string('phone', 30)->nullable()->after('email');
            $table->foreignId('role_id')->nullable()->after('password')
                ->constrained('roles')->nullOnDelete();
            $table->foreignId('department_id')->nullable()->after('role_id')
                ->constrained('departments')->nullOnDelete();
            $table->enum('status', ['active', 'inactive'])->default('active')->after('department_id');
            $table->timestamp('last_seen_at')->nullable()->after('status');

            $table->index(['department_id', 'status']);
        });
    }

    public function down(): void
    {
        Schema::table('users', function (Blueprint $table) {
            $table->dropForeign(['role_id']);
            $table->dropForeign(['department_id']);
            $table->dropIndex(['department_id', 'status']);
            $table->dropColumn(['phone', 'role_id', 'department_id', 'status', 'last_seen_at']);
        });
    }
};
