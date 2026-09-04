<?php

use Illuminate\Support\Facades\Route;

// API-only backend. Keep this closure-free so `route:cache` works.
Route::view('/', 'welcome');
