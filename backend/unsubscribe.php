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

ini_set('display_errors', '0');
error_reporting(E_ALL & ~E_DEPRECATED & ~E_USER_DEPRECATED);

function callBdapps(string $url, array $requestData): array {
    $requestJson = json_encode($requestData);
    if ($requestJson === false) {
        return ['ok' => false, 'error' => 'Failed to encode request'];
    }

    $ch = curl_init();
    if ($ch === false) {
        return ['ok' => false, 'error' => 'Unable to initialize cURL'];
    }

    curl_setopt($ch, CURLOPT_URL, $url);
    curl_setopt($ch, CURLOPT_POST, true);
    curl_setopt($ch, CURLOPT_POSTFIELDS, $requestJson);
    curl_setopt($ch, CURLOPT_RETURNTRANSFER, true);
    curl_setopt($ch, CURLOPT_HTTPHEADER, array(
        "Content-Type: application/json",
        "Content-Length: " . strlen($requestJson)
    ));
    curl_setopt($ch, CURLOPT_TIMEOUT, 30);

    $responseJson = curl_exec($ch);
    $curlError = curl_error($ch);
    curl_close($ch);

    if ($responseJson === false) {
        return ['ok' => false, 'error' => "cURL failed: $curlError"];
    }

    $response = json_decode($responseJson, true);
    if (!is_array($response)) {
        return ['ok' => false, 'error' => 'Invalid response from BD Apps server', 'raw' => $responseJson];
    }

    return ['ok' => true, 'data' => $response, 'raw' => $responseJson];
}

// ---------------------------------------------------------------------
// Resolve the subscriberId to unregister.
//
// Preferred: the app sends the subscriberId / referenceNo that BDApps
// returned at registration time. Fallback: rebuild tel:88... from
// user_mobile for sandbox and for legacy installs.
// ---------------------------------------------------------------------

$storedSubscriberId = trim($_POST['subscriberId'] ?? $_POST['referenceNo'] ?? '');
$rawMobile = trim($_POST['user_mobile'] ?? '');

$subscriberId = null;

if ($storedSubscriberId !== '') {
    if (preg_match('/^tel:/i', $storedSubscriberId) === 1) {
        // Already a tel: address — pass through.
        $subscriberId = $storedSubscriberId;
    } elseif (preg_match('/^\d{10,15}$/', $storedSubscriberId) === 1) {
        // Bare MSISDN — add the tel: prefix.
        $subscriberId = 'tel:' . $storedSubscriberId;
    } else {
        // Masked ID / referenceNo (opaque token) — forward as-is.
        $subscriberId = $storedSubscriberId;
    }
}

if ($subscriberId === null) {
    if ($rawMobile === '') {
        http_response_code(400);
        echo json_encode([
            'success' => false,
            'error'   => 'Mobile number or subscriberId required',
        ]);
        exit;
    }

    $digits = preg_replace('/\D+/', '', $rawMobile);
    if (strlen($digits) === 13 && substr($digits, 0, 3) === '880') {
        $digits = '0' . substr($digits, 3);
    } elseif (strlen($digits) === 12 && substr($digits, 0, 2) === '88') {
        $digits = '0' . substr($digits, 2);
    }

    if (!preg_match('/^01[3-9][0-9]{8}$/', $digits)) {
        http_response_code(400);
        echo json_encode([
            'success' => false,
            'error'   => 'Invalid mobile format',
        ]);
        exit;
    }

    $subscriberId = 'tel:88' . $digits;
}

$requestData = array(
    'applicationId' => BDAPPS_APP_ID,
    'password'      => BDAPPS_APP_PASSWORD,
    'subscriberId'  => $subscriberId,
    'version'       => '1.0',
    'action'        => '0',
);

$result = callBdapps('https://developer.bdapps.com/subscription/send', $requestData);

if (!$result['ok']) {
    http_response_code(502);
    echo json_encode([
        'success'      => false,
        'error'        => $result['error'],
        'subscriberId' => $subscriberId,
        'action'       => '0',
    ]);
    exit;
}

$response = $result['data'];
$statusCode = strtoupper((string)($response['statusCode'] ?? ''));
$subscriptionStatus = $response['subscriptionStatus'] ?? 'UNKNOWN';

$success =
    $statusCode === 'S1000' ||
    strtoupper((string)$subscriptionStatus) === 'UNREGISTERED';

echo json_encode([
    'success'            => $success,
    'subscriberId'       => $subscriberId,
    'action'             => '0',
    'version'            => '1.0',
    'statusCode'         => $response['statusCode'] ?? null,
    'statusDetail'       => $response['statusDetail'] ?? null,
    'subscriptionStatus' => $subscriptionStatus,
    'rawResponse'        => $result['raw'] ?? null,
    'error'              => $success ? null : ($response['statusDetail'] ?? 'Unsubscription failed.'),
]);
