<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        // "Delete chat" for one person: messages up to this moment are gone
        // from their view, and the chat leaves their list until a new one.
        Schema::table('conversation_participants', function (Blueprint $table) {
            $table->timestamp('cleared_at')->nullable()->after('muted');
        });
    }

    public function down(): void
    {
        Schema::table('conversation_participants', function (Blueprint $table) {
            $table->dropColumn('cleared_at');
        });
    }
};
