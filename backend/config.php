<?php
/**
 * Central Configuration for BDApps PHP Proxy Backend
 * 
 * Update BDAPPS_APP_ID and BDAPPS_PASSWORD below with your credentials from dev.bdapps.com.
 * Alternatively, these will automatically read environment variables if set on your hosting server.
 */

define('BDAPPS_APP_ID', trim(getenv('BDAPPS_APP_ID') ?: 'APP_139363'));
define('BDAPPS_PASSWORD', trim(getenv('BDAPPS_PASSWORD') ?: 'y0e74fafba35bd80a3e484ca07ab43715'));
define('BDAPPS_APP_NAME', trim(getenv('BDAPPS_APP_NAME') ?: 'MediTrack'));
