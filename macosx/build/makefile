
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

