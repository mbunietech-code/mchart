<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::create('message_attachments', function (Blueprint $table) {
            $table->id();
            $table->foreignId('message_id')->constrained('messages')->cascadeOnDelete();
            $table->string('file_path', 255);           // storage path/URL
            $table->string('file_name', 255)->nullable();
            $table->string('file_type', 100)->nullable();   // MIME type
            $table->unsignedBigInteger('file_size')->nullable(); // bytes
            $table->unsignedInteger('duration_seconds')->nullable(); // for voice notes
            $table->timestamps();
        });
    }

    public function down(): void
    {
        Schema::dropIfExists('message_attachments');
    }
};
