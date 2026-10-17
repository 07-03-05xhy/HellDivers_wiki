$env:JAVA_HOME = 'D:\Android\jdk-17.0.20.1+1'
$env:Path = 'D:\flutter\bin;' + $env:JAVA_HOME + '\bin;' + $env:Path
$env:PUB_HOSTED_URL='https://pub.flutter-io.cn'
$env:FLUTTER_STORAGE_BASE_URL='https://storage.flutter-io.cn'
Set-Location 'D:\agent-projects\HellDivers_wiki'
flutter clean 2>&1 | Select-Object -Last 1
flutter pub get 2>&1 | Select-Object -Last 1
flutter build apk --release '-Pkotlin.incremental=false' *>&1 | Tee-Object -FilePath 'D:\agent-projects\HellDivers_wiki\build.log'