<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        // A role is now a job title (label) on top of one of the three
        // permission levels; the three built-in roles keep their names.
        Schema::table('roles', function (Blueprint $table) {
            $table->string('level', 20)->default('staff')->after('label');
        });

        DB::table('roles')->whereIn('name', ['admin', 'manager', 'staff'])->update(['level' => DB::raw('name')]);
    }

    public function down(): void
    {
        Schema::table('roles', function (Blueprint $table) {
            $table->dropColumn('level');
        });
    }
};
