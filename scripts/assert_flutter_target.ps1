param(
  [Parameter(Mandatory = $true)]
  [ValidateSet('android-apk', 'ios-ipa', 'desktop', 'admin-web')]
  [string]$Profile,

  [Parameter(Mandatory = $true)]
  [string]$Target
)

$normalized = $Target.Replace('\\', '/').Trim()

switch ($Profile) {
  'admin-web' {
    if ($normalized -ne 'lib/main_admin_web.dart') {
      throw "Invalid target '$Target' for profile '$Profile'. Expected: lib/main_admin_web.dart"
    }
  }
  default {
    if ($normalized -ne 'lib/main.dart') {
      throw "Invalid target '$Target' for profile '$Profile'. Expected: lib/main.dart"
    }
  }
}

Write-Host "Target check passed for profile '$Profile' with target '$normalized'."
