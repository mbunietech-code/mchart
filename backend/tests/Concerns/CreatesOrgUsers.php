<?php

namespace Tests\Concerns;

use App\Enums\UserRole;
use App\Models\Department;
use App\Models\Role;
use App\Models\User;

trait CreatesOrgUsers
{
    protected function seedRoles(): void
    {
        foreach (UserRole::cases() as $role) {
            Role::firstOrCreate(['name' => $role->value], ['label' => $role->label()]);
        }
    }

    protected function makeUser(UserRole $role, ?Department $department = null, array $attributes = []): User
    {
        $this->seedRoles();

        return User::factory()
            ->role($role)
            ->state(array_merge(
                $department ? ['department_id' => $department->id] : [],
                $attributes,
            ))
            ->create();
    }

    protected function admin(array $attributes = []): User
    {
        return $this->makeUser(UserRole::Admin, null, $attributes);
    }

    protected function manager(?Department $department = null, array $attributes = []): User
    {
        return $this->makeUser(UserRole::Manager, $department ?? Department::factory()->create(), $attributes);
    }

    protected function staff(?Department $department = null, array $attributes = []): User
    {
        return $this->makeUser(UserRole::Staff, $department ?? Department::factory()->create(), $attributes);
    }
}
