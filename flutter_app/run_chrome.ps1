$env:Path = "C:\Users\WHOME!~1\flutter\bin;$env:Path"
$env:PUB_CACHE = "C:\dukaanZone\flutter_app\.pub-cache"

flutter pub get
flutter run -d chrome --no-web-resources-cdn
