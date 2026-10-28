<?php

namespace App\Mail;

use App\Models\User;
use Illuminate\Bus\Queueable;
use Illuminate\Mail\Mailable;
use Illuminate\Mail\Mailables\Content;
use Illuminate\Mail\Mailables\Envelope;
use Illuminate\Queue\SerializesModels;

/**
 * Welcome email for an account an admin just created: where to get the
 * app, the username (their email) and a one-time temporary password.
 */
class UserInvitation extends Mailable
{
    use Queueable, SerializesModels;

    public function __construct(
        public User $user,
        public string $temporaryPassword,
        public string $invitedBy,
    ) {
    }

    public function envelope(): Envelope
    {
        return new Envelope(subject: 'You have been invited to MChart');
    }

    public function content(): Content
    {
        return new Content(
            markdown: 'mail.user-invitation',
            with: [
                'downloadUrl' => config('mchart.download_url'),
                'webUrl' => config('mchart.web_url'),
            ],
        );
    }
}
