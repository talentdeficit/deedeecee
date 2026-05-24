BUNDLE   = deedeecee.app
BINARY   = .build/release/deedeecee
CONTENTS = $(BUNDLE)/Contents

.PHONY: build install clean

build:
	swift build -c release
	mkdir -p $(CONTENTS)/MacOS
	cp $(BINARY) $(CONTENTS)/MacOS/deedeecee
	cp Resources/Info.plist $(CONTENTS)/Info.plist
	codesign --sign - --force $(BUNDLE)

install: build
	rm -rf ~/Applications/$(BUNDLE)
	cp -r $(BUNDLE) ~/Applications/

clean:
	rm -rf $(BUNDLE) .build
