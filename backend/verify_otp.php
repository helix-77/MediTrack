<?php

require_once __DIR__ . '/config.php';

header("Access-Control-Allow-Origin: *");
header("Access-Control-Allow-Methods: POST, GET, OPTIONS");
header("Access-Control-Allow-Headers: Content-Type");
header("Content-Type: application/json; charset=utf-8");

if ($_SERVER['REQUEST_METHOD'] == 'OPTIONS') {
    http_response_code(200);
    exit();
}

$otp         = trim($_POST['otp'] ?? $_POST['Otp'] ?? '');
$referenceNo = trim($_POST['referenceNo'] ?? '');

if ($otp === '' || $referenceNo === '') {
    http_response_code(400);
    echo json_encode([
        'success'      => false,
        'error'        => 'Missing OTP code or reference number',
        'statusCode'   => 'E1000',
        'statusDetail' => 'OTP and reference number are required'
    ]);
    exit;
}

$requestData = [
    'applicationId' => BDAPPS_APP_ID,
    'password'      => BDAPPS_APP_PASSWORD,
    'referenceNo'   => $referenceNo,
    'otp'           => $otp
];

$ch = curl_init('https://developer.bdapps.com/subscription/otp/verify');
curl_setopt($ch, CURLOPT_POST, true);
curl_setopt($ch, CURLOPT_POSTFIELDS, json_encode($requestData));
curl_setopt($ch, CURLOPT_RETURNTRANSFER, true);
curl_setopt($ch, CURLOPT_TIMEOUT, 30);
curl_setopt($ch, CURLOPT_HTTPHEADER, ['Content-Type: application/json']);

$responseJson = curl_exec($ch);
$curlError = curl_error($ch);
curl_close($ch);

if ($responseJson === false) {
    http_response_code(502);
    echo json_encode([
        'success'      => false,
        'error'        => 'Connection failed: ' . $curlError,
        'statusCode'   => 'E1000',
        'statusDetail' => 'Unable to connect to BD Apps server'
    ]);
    exit;
}

$response = json_decode($responseJson, true);
if (!is_array($response)) {
    echo json_encode([
        'success'      => false,
        'error'        => 'Invalid server response from BD Apps',
        'statusCode'   => 'E1000',
        'statusDetail' => 'Failed to parse response'
    ]);
    exit;
}

$statusCode         = $response['statusCode'] ?? 'FAILED';
$statusDetail       = $response['statusDetail'] ?? '';
$subscriptionStatus = $response['subscriptionStatus'] ?? '';
$isSubscribed       = (strtoupper((string)$subscriptionStatus) === 'REGISTERED' || $statusCode === 'S1000');

echo json_encode([
    'success'            => $statusCode === 'S1000',
    'isSubscribed'       => $isSubscribed,
    'statusCode'         => $statusCode,
    'statusDetail'       => $statusDetail,
    'subscriptionStatus' => $subscriptionStatus !== '' ? $subscriptionStatus : ($isSubscribed ? 'REGISTERED' : 'UNREGISTERED'),
    'subscriberId'       => $response['subscriberId'] ?? null,
    'version'            => $response['version'] ?? '1.0'
]);
