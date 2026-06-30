.PHONY: build release install run clean icon

ICONSET := .build/AppIcon.iconset
ICNS := .build/AppIcon.icns
ICON_SRC := Sources/Navi/Assets.xcassets/AppIcon.appiconset

build:
	swift build

release:
	swift build -c release

# Build AppIcon.icns from the PNGs in the asset catalog. Uses iconutil/sips
# (Command Line Tools) so this works without full Xcode / actool.
icon:
	@rm -rf $(ICONSET)
	@mkdir -p $(ICONSET)
	@cp $(ICON_SRC)/icon_16x16.png     $(ICONSET)/icon_16x16.png
	@cp $(ICON_SRC)/icon_32x32.png     $(ICONSET)/icon_16x16@2x.png
	@cp $(ICON_SRC)/icon_32x32.png     $(ICONSET)/icon_32x32.png
	@cp $(ICON_SRC)/icon_64x64.png     $(ICONSET)/icon_32x32@2x.png
	@cp $(ICON_SRC)/icon_128x128.png   $(ICONSET)/icon_128x128.png
	@cp $(ICON_SRC)/icon_256x256.png   $(ICONSET)/icon_128x128@2x.png
	@cp $(ICON_SRC)/icon_256x256.png   $(ICONSET)/icon_256x256.png
	@cp $(ICON_SRC)/icon_512x512.png   $(ICONSET)/icon_256x256@2x.png
	@cp $(ICON_SRC)/icon_512x512.png   $(ICONSET)/icon_512x512.png
	@cp $(ICON_SRC)/icon_1024x1024.png $(ICONSET)/icon_512x512@2x.png
	@iconutil -c icns $(ICONSET) -o $(ICNS)
	@echo "Built $(ICNS)"

install: release icon
	@rm -rf ~/Applications/Navi.app
	@mkdir -p ~/Applications/Navi.app/Contents/MacOS
	@mkdir -p ~/Applications/Navi.app/Contents/Resources
	@cp .build/release/Navi ~/Applications/Navi.app/Contents/MacOS/Navi
	@cp Info.plist ~/Applications/Navi.app/Contents/Info.plist
	@cp $(ICNS) ~/Applications/Navi.app/Contents/Resources/AppIcon.icns
	@touch ~/Applications/Navi.app
	@echo "Installed to ~/Applications/Navi.app"

run:
	swift run

clean:
	swift package clean
	@rm -rf $(ICONSET) $(ICNS)
