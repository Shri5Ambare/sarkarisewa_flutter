$ErrorActionPreference = 'Stop'

$target = 'lib/main_admin_web.dart'

pwsh -NoProfile -File "./scripts/assert_flutter_target.ps1" -Profile admin-web -Target $target
flutter build web --release --target=$target
