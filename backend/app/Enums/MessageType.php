<?php

namespace App\Enums;

enum MessageType: string
{
    case Text = 'text';
    case File = 'file';
    case Image = 'image';
    case Voice = 'voice';

    /** Body holds a sticker id from the app's built-in pack. */
    case Sticker = 'sticker';
}
