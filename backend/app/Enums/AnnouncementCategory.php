<?php

namespace App\Enums;

enum AnnouncementCategory: string
{
    case Meeting = 'meeting';
    case Notice = 'notice';
    case Event = 'event';
    case Reminder = 'reminder';
    case Urgent = 'urgent';

    public function label(): string
    {
        return match ($this) {
            self::Meeting => 'Meeting',
            self::Notice => 'Notice',
            self::Event => 'Event',
            self::Reminder => 'Reminder',
            self::Urgent => 'Urgent',
        };
    }
}
