<?php

namespace App\Enums;

enum TaskStatus: string
{
    case Assigned = 'assigned';
    case InProgress = 'in_progress';
    case Completed = 'completed';
    case Approved = 'approved';
    case Revision = 'revision';

    public function label(): string
    {
        return match ($this) {
            self::Assigned => 'Assigned',
            self::InProgress => 'In Progress',
            self::Completed => 'Completed',
            self::Approved => 'Approved',
            self::Revision => 'Needs Revision',
        };
    }

    /**
     * Allowed next states from the current one.
     *
     * @return list<self>
     */
    public function allowedTransitions(): array
    {
        return match ($this) {
            self::Assigned => [self::InProgress],
            self::InProgress => [self::Completed],
            self::Completed => [self::Approved, self::Revision],
            self::Revision => [self::InProgress],
            self::Approved => [],
        };
    }

    public function canTransitionTo(self $target): bool
    {
        return in_array($target, $this->allowedTransitions(), true);
    }

    public function isTerminal(): bool
    {
        return $this === self::Approved;
    }
}
