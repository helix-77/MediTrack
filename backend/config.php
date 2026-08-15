<?php

/**
 * MediTrack - BD Apps API configuration.
 *
 * Configure these values in the deployment environment. Do not commit
 * production credentials to this repository.
 */
$appId = getenv('BDAPPS_APP_ID');
$appPassword = getenv('BDAPPS_APP_PASSWORD');

if ($appId === false || $appId === '' || $appPassword === false || $appPassword === '') {
    http_response_code(500);
    header('Content-Type: application/json');
    echo json_encode([
        'status' => 'ERROR',
        'message' => 'BD Apps service is not configured.',
    ]);
    exit;
}

define('BDAPPS_APP_ID', $appId);
define('BDAPPS_APP_PASSWORD', $appPassword);
