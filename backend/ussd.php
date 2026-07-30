<?php

/**
 * USSD entry point for MediTrack.
 *
 * bdapps will dial *XXX# and forward the session here. Users on the
 * REGISTERED path see an unsubscribe menu; everyone else is offered a
 * subscribe flow that forwards to the carrier's confirmation popup.
 *
 * We log every session so the team can audit how many users land in each
 * branch (registered vs. fresh).
 */

require_once 'config.php';

date_default_timezone_set("Asia/Dhaka");

try {
    $receiver      = new UssdReceiver();
    $ussdSender    = new UssdSender(
        'https://developer.bdapps.com/ussd/send',
        BDAPPS_APP_ID,
        BDAPPS_APP_PASSWORD
    );
    $subscription  = new Subscription(
        'https://developer.bdapps.com/subscription/send',
        BDAPPS_APP_PASSWORD,
        BDAPPS_APP_ID
    );

    $address       = $receiver->getAddress();
    $sessionId     = $receiver->getSessionId();
    $ussdOperation = $receiver->getUssdOperation();

    $status = $subscription->getStatus($address);

    file_put_contents(
        'ussd_log.txt',
        date('Y-m-d H:i:s') . " | $address | Status:$status\n",
        FILE_APPEND
    );

    if ($ussdOperation == 'mo-init') {
        try {
            if ($status == 'REGISTERED') {
                $ussdSender->ussd(
                    $sessionId,
                    '1. Unsubscribe from MediTrack',
                    $address
                );
            } else {
                $ussdSender->ussd(
                    $sessionId,
                    'Please wait for the confirmation pop-up to subscribe to MediTrack.',
                    $address,
                    'mt-fin'
                );
                $subscription->subscribe($address);
            }
        } catch (Exception $e) {
            $ussdSender->ussd(
                $sessionId,
                'Sorry, an error occurred. Please try again.',
                $address
            );
        }
    }
} catch (Exception $e) {
    file_put_contents(
        'ussd_error.log',
        date('Y-m-d H:i:s') . ' | ' . $e->getMessage() . "\n",
        FILE_APPEND
    );
}
