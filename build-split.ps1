$env:JAVA_HOME = 'D:\Android\jdk-17.0.20.1+1'
$env:Path = 'D:\flutter\bin;' + $env:JAVA_HOME + '\bin;' + $env:Path
$env:PUB_HOSTED_URL='https://pub.flutter-io.cn'
$env:FLUTTER_STORAGE_BASE_URL='https://storage.flutter-io.cn'
Set-Location 'D:\agent-projects\HellDivers_wiki'
flutter build apk --release '-Pkotlin.incremental=false' 2>&1 | Select-Object -Last 2
flutter build apk --release --split-per-abi '-Pkotlin.incremental=false' 2>&1 | Select-Object -Last 4