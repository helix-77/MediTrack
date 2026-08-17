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

define('BDAPPS_APP_ID', 'APP_139363');
define('BDAPPS_APP_PASSWORD', '0e74fafba35bd80a3e484ca07ab43715');


