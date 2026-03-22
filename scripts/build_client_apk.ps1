$ErrorActionPreference = 'Stop'

$target = 'lib/main.dart'

pwsh -NoProfile -File "./scripts/assert_flutter_target.ps1" -Profile android-apk -Target $target
flutter build apk --release --target=$target
