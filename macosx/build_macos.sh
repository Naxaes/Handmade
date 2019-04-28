#!/usr/bin/env bash

# Get dependencies.
# otool -L build/main

# Look into building Apps with bash
# https://www.cocoawithlove.com/2010/11/deployment-script-for-generic-cocoa-mac.html


SHARED_COMPILER_FLAGS="-g"
SHARED_LINKER_FLAGS=""

# -fno-threadsafe-statics is just to not get Undefined symbols '___cxa_guard_acquire' and '___cxa_guard_release'
MACOS_PLATFORM_COMPILER_FLAGS="-fno-threadsafe-statics"
MACOS_PLATFORM_LINKER_FLAGS="-framework AppKit -framework AudioToolbox"
MACOS_PLATFORM_OUTPUT_FILE="main"
MACOS_PLATFORM_SOURCE_FILES="../source/main_macos.mm"

GAME_COMPILER_FLAGS="-dynamiclib -current_version 1.0 -compatibility_version 1.0 -fvisibility=hidden"
GAME_LINKER_FLAGS=""
GAME_OUTPUT_FILE="libGame.A.dylib"
GAME_SOURCE_FILES="../../main.cpp"

APP_MAKEFILE='
APPNAME=Main
APPBUNDLE=$(APPNAME).app
APPBUNDLECONTENTS=$(APPBUNDLE)/Contents
APPBUNDLEEXE=$(APPBUNDLECONTENTS)/MacOS
APPBUNDLERESOURCES=$(APPBUNDLECONTENTS)/Resources
APPBUNDLEICON=$(APPBUNDLECONTENTS)/Resources
EXECUTABLE=main

appbundle: ../appdata/$(APPNAME).icns
	rm -rf $(APPBUNDLE)
	mkdir  $(APPBUNDLE)
	mkdir  $(APPBUNDLE)/Contents
	mkdir  $(APPBUNDLE)/Contents/MacOS
	mkdir  $(APPBUNDLE)/Contents/Resources
	cp ../appdata/Info.plist $(APPBUNDLECONTENTS)/
	cp ../appdata/$(APPNAME).icns $(APPBUNDLEICON)/
	cp $(EXECUTABLE) $(APPBUNDLEEXE)/$(APPNAME)

../appdata/$(APPNAME).icns: ../appdata/$(APPNAME)Icon.png
	rm -rf ../appdata/$(APPNAME).iconset
	mkdir ../appdata/$(APPNAME).iconset
	sips -z 16 16     ../appdata/$(APPNAME)Icon.png --out ../appdata/$(APPNAME).iconset/icon_16x16.png
	sips -z 32 32     ../appdata/$(APPNAME)Icon.png --out ../appdata/$(APPNAME).iconset/icon_16x16@2x.png
	sips -z 32 32     ../appdata/$(APPNAME)Icon.png --out ../appdata/$(APPNAME).iconset/icon_32x32.png
	sips -z 64 64     ../appdata/$(APPNAME)Icon.png --out ../appdata/$(APPNAME).iconset/icon_32x32@2x.png
	sips -z 128 128   ../appdata/$(APPNAME)Icon.png --out ../appdata/$(APPNAME).iconset/icon_128x128.png
	sips -z 256 256   ../appdata/$(APPNAME)Icon.png --out ../appdata/$(APPNAME).iconset/icon_128x128@2x.png
	sips -z 256 256   ../appdata/$(APPNAME)Icon.png --out ../appdata/$(APPNAME).iconset/icon_256x256.png
	sips -z 512 512   ../appdata/$(APPNAME)Icon.png --out ../appdata/$(APPNAME).iconset/icon_256x256@2x.png
	sips -z 512 512   ../appdata/$(APPNAME)Icon.png --out ../appdata/$(APPNAME).iconset/icon_512x512.png
	cp ../appdata/$(APPNAME)Icon.png appdata/$(APPNAME).iconset/icon_512x512@2x.png
	iconutil -c icns -o ../appdata/$(APPNAME).icns ../appdata/$(APPNAME).iconset
	rm -r ../appdata/$(APPNAME).iconset
'


build_game()
{
	if clang ${GAME_COMPILER_FLAGS}                                           \
			 ${SHARED_COMPILER_FLAGS}                                         \
			 ${GAME_LINKER_FLAGS}                                             \
			 ${SHARED_LINKER_FLAGS}                                           \
			 -I ../../                                                        \
			 -o ${GAME_OUTPUT_FILE}                                           \
			 ${GAME_SOURCE_FILES}                                             \
			 &> game_build_log.txt;
	then echo "Compiled game successfully!";
	else echo "Game compilation failure. Check build log.";
	fi
}

build_platform()
{
	if clang ${MACOS_PLATFORM_COMPILER_FLAGS}                         		  \
			 ${SHARED_COMPILER_FLAGS}                                         \
			 ${MACOS_PLATFORM_LINKER_FLAGS}                                   \
			 ${SHARED_LINKER_FLAGS}                                           \
			 -I ../../                                                        \
			 -o ${MACOS_PLATFORM_OUTPUT_FILE}                                 \
			 ${MACOS_PLATFORM_SOURCE_FILES}                                   \
			 &> platform_build_log.txt;
	then echo "Compiled platform successfully!";
	else echo "Platform compilation failure. Check build log.";
	fi
}

build_app()
{
	echo "${APP_MAKEFILE}" > makefile;
	if make &> make_log.txt;
	then echo "Built App successfully!";
	else echo "Failed building App. Check make log.";
	fi
}


# TODO(ted): It seems like clang waits until the files are free before continuing.
# We might have to check for it in case we're accidentally compiling the platforms while
# running it.

# TODO(ted): Might parse these and pass in flags to compile.

if [[ "$1" = "game" ]]; then
	if pushd ./build > /dev/null; then
		build_game
		popd > /dev/null
	else
		echo "Cannot update. Missing build file";
	fi
elif [[ "$1" = "platform" ]]; then
	if pushd ./build > /dev/null; then
		build_platform
		popd > /dev/null
	else
		echo "Cannot update. Missing build file";
	fi
elif [[ "$1" = "app" ]]; then
	if pushd ./build > /dev/null; then
		build_app
		popd > /dev/null
	else
		echo "Cannot update. Missing build file";
	fi
elif [[ "$1" = "all" ]]; then
	rm -r build
	mkdir -p ./build  > /dev/null
	pushd    ./build  > /dev/null

	build_game
	build_platform
	build_app

	popd > /dev/null
else
	echo "Unknown command $1";
fi


