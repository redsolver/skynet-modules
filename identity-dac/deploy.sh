flutter pub global run webdev build
mkdir build/public
cp build/main.dart.js build/public
skydeploy build/public
