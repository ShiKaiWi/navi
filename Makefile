.PHONY: build release install run clean

build:
	swift build

release:
	swift build -c release

install: release
	@mkdir -p ~/Applications
	@rm -rf ~/Applications/Navi.app
	@mkdir -p ~/Applications/Navi.app/Contents/MacOS
	@cp .build/release/Navi ~/Applications/Navi.app/Contents/MacOS/Navi
	@cp Info.plist ~/Applications/Navi.app/Contents/Info.plist
	@echo "Installed to ~/Applications/Navi.app"

run:
	swift run

clean:
	swift package clean
