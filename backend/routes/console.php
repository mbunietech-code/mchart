<?php

use Illuminate\Foundation\Inspiring;
use Illuminate\Support\Facades\Artisan;
use Illuminate\Support\Facades\Schedule;

Artisan::command('inspire', function () {
    $this->comment(Inspiring::quote());
})->purpose('Display an inspiring quote');

// Needs the hPanel cron: * * * * * php artisan schedule:run
Schedule::command('tasks:remind-deadlines')->hourly()->withoutOverlapping();

// Two-way task sync with mbuniehub.com (also pulled when the task screens load).
Artisan::command('tasks:sync-hub', function () {
    app(\App\Services\HubTaskSync::class)->pull();
})->purpose('Sync tasks with mbuniehub.com/admin/tasks');
Schedule::command('tasks:sync-hub')->everyMinute()->withoutOverlapping()
    ->when(fn () => \App\Services\HubTaskSync::enabled());
