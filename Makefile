TARGET := iphone:clang:latest:16.0
INSTALL_TARGET_PROCESSES = Spotify
ARCHS = arm64

include $(THEOS)/makefiles/common.mk

TWEAK_NAME = EeveeSpotify

PANEL_SWIFT_FILES = $(shell find Sources/EeveeSpotify/Panel -name '*.swift')

SPOTIFY_SWIFT_FILES = $(filter-out \
	Sources/EeveeSpotify/TriggerConfiguration.swift \
	Sources/EeveeSpotify/TriggerPanelHost.swift \
	Sources/EeveeSpotify/TriggerTrackDetector.swift \
	Sources/EeveeSpotify/HostedPanelContext.swift \
	Sources/EeveeSpotify/PanelAppState.swift \
	$(PANEL_SWIFT_FILES), \
	$(shell find Sources/EeveeSpotify -name '*.swift'))

SPOTIFY_NATIVE_FILES = Sources/EeveeSpotifyC/Tweak.m

EeveeSpotify_FILES = $(SPOTIFY_SWIFT_FILES) $(SPOTIFY_NATIVE_FILES)
EeveeSpotify_SWIFTFLAGS = -ISources/EeveeSpotifyC/include -Osize
SWIFTPROTOBUF_VERSION ?= 1.29.0
EeveeSpotify_EXTRA_FRAMEWORKS = SwiftProtobuf
EeveeSpotify_FRAMEWORKS = MediaPlayer
EeveeSpotify_CFLAGS = -fobjc-arc -ISources/EeveeSpotifyC/include -Os -Wno-error -Wno-incompatible-pointer-types-discards-qualifiers -Wno-deprecated-declarations -Wno-unused-variable

include $(THEOS_MAKE_PATH)/tweak.mk

copy-swiftprotobuf:
	mkdir -p swiftprotobuf && cd swiftprotobuf ;\
	curl -OL https://github.com/whoeevee/EeveeSpotify/releases/download/swift2.0/org.swift.protobuf.swiftprotobuf_$(SWIFTPROTOBUF_VERSION)_iphoneos-arm.deb ;\
	ar -x org.swift.protobuf.swiftprotobuf_$(SWIFTPROTOBUF_VERSION)_iphoneos-arm.deb ;\
	tar -xvf data.tar.lzma ;\
	cp -r Library/Frameworks/SwiftProtobuf.framework "${THEOS}/lib" ;\
