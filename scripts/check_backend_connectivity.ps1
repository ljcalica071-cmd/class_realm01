$ErrorActionPreference = 'Stop'

$projectRoot = Split-Path -Parent $PSScriptRoot
$envFile = Join-Path $projectRoot '.env'

if (-not (Test-Path -LiteralPath $envFile)) {
  Write-Error 'Missing .env file in the project root.'
  exit 1
}

$config = @{}
foreach ($line in Get-Content -LiteralPath $envFile) {
  if ($line -match '^\s*([^#=\s]+)\s*=\s*(.*?)\s*$') {
    $config[$matches[1]] = $matches[2].Trim().Trim('"').Trim("'")
  }
}

$failed = $false
$supabaseUrl = $config['SUPABASE_URL']
$supabaseKey = $config['SUPABASE_ANON_KEY']

if ([string]::IsNullOrWhiteSpace($supabaseUrl) -or
    [string]::IsNullOrWhiteSpace($supabaseKey)) {
  Write-Output 'FAIL Supabase: SUPABASE_URL or SUPABASE_ANON_KEY is missing.'
  $failed = $true
} else {
  try {
    $uri = "$($supabaseUrl.TrimEnd('/'))/rest/v1/subjects?select=id&limit=1"
    $headers = @{
      apikey = $supabaseKey
      Authorization = "Bearer $supabaseKey"
    }
    $null = Invoke-WebRequest -UseBasicParsing -Uri $uri -Headers $headers `
      -Method Get -TimeoutSec 20
    Write-Output 'PASS Supabase: read-only database request succeeded.'
  } catch {
    $status = if ($_.Exception.Response) {
      [int]$_.Exception.Response.StatusCode
    } else {
      'network/error'
    }
    Write-Output "FAIL Supabase: request failed (HTTP $status). Credentials and response body hidden."
    $failed = $true
  }
}

$firebaseKey = $config['FIREBASE_WEB_API_KEY']
if ([string]::IsNullOrWhiteSpace($firebaseKey)) {
  $firebaseKey = $config['FIREBASE_ANDROID_API_KEY']
}

if ([string]::IsNullOrWhiteSpace($firebaseKey)) {
  Write-Output 'FAIL Firebase Auth: web/android API key is missing.'
  $failed = $true
} else {
  try {
    $body = @{
      identifier = 'copilot-connectivity-check@example.invalid'
      continueUri = 'http://localhost'
    } | ConvertTo-Json -Compress
    $uri = "https://identitytoolkit.googleapis.com/v1/accounts:createAuthUri?key=$firebaseKey"
    $null = Invoke-RestMethod -Uri $uri -Method Post `
      -ContentType 'application/json' -Body $body -TimeoutSec 20
    Write-Output 'PASS Firebase Auth: Identity Toolkit request succeeded; no account was created.'
  } catch {
    $status = if ($_.Exception.Response) {
      [int]$_.Exception.Response.StatusCode
    } else {
      'network/error'
    }
    Write-Output "FAIL Firebase Auth: request failed (HTTP $status). Credentials and response body hidden."
    $failed = $true
  }
}

if ($failed) {
  exit 1
}
