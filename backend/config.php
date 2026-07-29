<?php
/**
 * Central Configuration for BDApps PHP Proxy Backend
 * 
 * Update BDAPPS_APP_ID and BDAPPS_PASSWORD below with your credentials from dev.bdapps.com.
 * Alternatively, these will automatically read environment variables if set on your hosting server.
 */

define('BDAPPS_APP_ID', getenv('BDAPPS_APP_ID') ?: 'APP_000000');
define('BDAPPS_PASSWORD', getenv('BDAPPS_PASSWORD') ?: 'your_password_here');
define('BDAPPS_APP_NAME', getenv('BDAPPS_APP_NAME') ?: 'MediTrack');
