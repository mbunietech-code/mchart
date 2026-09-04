<?php

namespace App\Enums;

enum UserRole: string
{
    case Admin = 'admin';
    case Manager = 'manager';
    case Staff = 'staff';

    public function label(): string
    {
        return match ($this) {
            self::Admin => 'Admin',
            self::Manager => 'Manager',
            self::Staff => 'Staff',
        };
    }

    /** Higher number = more authority. */
    public function level(): int
    {
        return match ($this) {
            self::Admin => 3,
            self::Manager => 2,
            self::Staff => 1,
        };
    }

    public function atLeast(self $other): bool
    {
        return $this->level() >= $other->level();
    }

    public function isManagerOrAdmin(): bool
    {
        return $this === self::Admin || $this === self::Manager;
    }
}
