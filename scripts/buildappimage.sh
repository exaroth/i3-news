#!/bin/sh

if [ -f ./tmp/appimagetool.AppImage ]; then
    echo "appimagetool already exists, skipping download..."
else
	curl -# -L -o ./tmp/appimagetool.AppImage https://github.com/AppImage/AppImageKit/releases/download/continuous/appimagetool-x86_64.AppImage
    chmod +x ./tmp/appimagetool.AppImage 
fi

zig build --global-cache-dir ./vendor -Dtarget=x86_64-linux-musl

mkdir -p build
cp -Rf AppDir build
mkdir -p build/AppDir/usr/local/bin

cp scripts/bscroll build/AppDir/usr/local/bin
cp scripts/paginate build/AppDir/usr/local/bin
cp zig-out/bin/i3_news build/AppDir/usr/local/bin
cp VERSION build/AppDir
wget -O build/AppDir/usr/local/bin/zscroll https://raw.githubusercontent.com/noctuid/zscroll/master/zscroll
chmod +x build/AppDir/usr/local/bin/zscroll

./tmp/appimagetool.AppImage ./build/AppDir ./build/i3_news.AppImage

