<?php

/**
 * MO/MT SMS gateway endpoint for MediTrack.
 *
 * Carriers deliver inbound MO SMS here. We log the message and reply with a
 * generic MT acknowledging receipt. The actual delivery of medicine
 * reminders is scheduled from the Flutter client (notifications_service)
 * rather than this gateway, so the MT reply is intentionally minimal.
 */

require_once 'config.php';

$logger = fopen('sms_log.txt', 'a');

try {
    $receiver = new SMSReceiver();
    $sender   = new SMSSender(
        'https://developer.bdapps.com/sms/send',
        BDAPPS_APP_ID,
        BDAPPS_APP_PASSWORD
    );
    $sender->setencoding('8');

    $address    = $receiver->getAddress();
    $rawMessage = trim($receiver->getMessage());

    $parts   = explode(' ', $rawMessage);
    array_shift($parts);
    $message = trim(implode(' ', $parts));

    // Reply with an acknowledgement so the carrier stops retrying.
    $sender->sms(
        'MT: MediTrack received your message. We will get back to you shortly. [' . $message . '(MO)]',
        $address
    );

    fwrite($logger, date('Y-m-d') . ' | ' . $address . ' | ' . $message . "\n");
} catch (SMSServiceException $e) {
    // Surface the SDK error to the log; never echo a non-S1000 reply so the
    // carrier treats the delivery as failed.
    fwrite($logger, date('Y-m-d H:i:s') . ' | ERROR ' . $e->getErrorCode() . ' ' . $e->getErrorMessage() . "\n");
}

fclose($logger);
