<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::table('messages', function (Blueprint $table) {
            // enum -> string so new kinds (sticker) don't need an ALTER each
            // time; existing values carry over unchanged.
            $table->string('type', 20)->default('text')->change();
            $table->boolean('forwarded')->default(false)->after('reply_to_id');
            $table->timestamp('edited_at')->nullable()->after('read_by');
        });
    }

    public function down(): void
    {
        Schema::table('messages', function (Blueprint $table) {
            $table->dropColumn(['forwarded', 'edited_at']);
            $table->enum('type', ['text', 'file', 'image', 'voice'])->default('text')->change();
        });
    }
};
