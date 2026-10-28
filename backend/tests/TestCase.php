<?php

namespace Tests;

use Illuminate\Foundation\Testing\TestCase as BaseTestCase;

abstract class TestCase extends BaseTestCase
{
    /**
     * A cached config ignores phpunit.xml's env, so RefreshDatabase would
     * wipe whatever database .env points at. Refuse to run instead.
     */
    public function createApplication()
    {
        if (is_file(dirname(__DIR__).'/bootstrap/cache/config.php')) {
            throw new \RuntimeException(
                'Config is cached (bootstrap/cache/config.php); tests would run against the real database. '
                .'Run `php artisan config:clear` first.'
            );
        }

        return parent::createApplication();
    }
}
