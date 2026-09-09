TARGET = iphone:clang:16.5:18.0
ARCHS = arm64
INSTALL_TARGET_PROCESSES = YumiStorage

# Public release with iOS 26 Liquid Glass tab bar requires Xcode 26 on macOS — see docs/BUILD.md.
# WSL/Theos uses iPhoneOS16.5.sdk because Apple SDK 18+/26+ needs Apple Clang, not Linux clang.

include $(THEOS)/makefiles/common.mk

APPLICATION_NAME = YumiStorage

YumiStorage_FILES = \
	YumiStorage/YumiStorageApp.swift \
	YumiStorage/Views/LiquidGlass.swift \
	YumiStorage/Views/RootView.swift \
	YumiStorage/Views/AppListView.swift \
	YumiStorage/Views/AppDetailView.swift \
	YumiStorage/Views/FileBrowserView.swift \
	YumiStorage/Views/FileViewerView.swift \
	YumiStorage/Views/HexEditorView.swift \
	YumiStorage/Views/FilePropertiesView.swift \
	YumiStorage/Views/BackupView.swift \
	YumiStorage/Views/BackupsListView.swift \
	YumiStorage/Views/LimitsDisclaimer.swift \
	YumiStorage/Views/ReclaimAppView.swift \
	YumiStorage/Views/ReclaimTabView.swift \
	YumiStorage/Engine/ZipReader.swift \
	YumiStorage/Engine/BackupPaths.swift \
	YumiStorage/Engine/RestoreService.swift \
	YumiStorage/Engine/SandboxEscape.swift \
	YumiStorage/Engine/FileKind.swift \
	YumiStorage/Engine/FileClipboard.swift \
	YumiStorage/Engine/FileService.swift \
	YumiStorage/Engine/AppDiscovery.swift \
	YumiStorage/Engine/BackupService.swift \
	YumiStorage/Engine/ZipWriter.swift \
	YumiStorage/Engine/ZipPassword.swift \
	YumiStorage/Engine/SevenZipAES.swift \
	YumiStorage/Engine/ArchiveExtractor.swift \
	YumiStorage/Engine/ReclaimService.swift \
	YumiStorage/Engine/zip_crypto.c \
	YumiStorage/Engine/bad_query.c \
	YumiStorage/Tunnel/TunnelContext.m \
	YumiStorage/Tunnel/applist.m \
	YumiStorage/Tunnel/heartbeat.m

YumiStorage_FILES += $(shell find vendor/BitByteData/Sources vendor/SWCompression/Sources -name '*.swift' \
	! -name 'TarWriter.swift' ! -name 'TarReader.swift' ! -name 'TarCreateError.swift' \
	! -name 'ZlibArchive.swift' ! -name 'ZlibError.swift' ! -name 'ZlibHeader.swift' \
	! -name 'BigEndianByteReader.swift')

YumiStorage_SWIFT_BRIDGING_HEADER = YumiStorage/Engine/YumiStorage-Bridging-Header.h
YumiStorage_CFLAGS = -IYumiStorage/Engine -IYumiStorage/Tunnel
YumiStorage_OBJCFLAGS = -IYumiStorage/Engine -IYumiStorage/Tunnel -fobjc-arc

# Link the Rust idevice FFI static library and its system dependencies.
YumiStorage_LDFLAGS = -LYumiStorage/Tunnel -lidevice_ffi -lresolv -framework Security -framework Network -framework SystemConfiguration -framework QuickLook -framework PDFKit -framework AVKit -framework AVFoundation
YumiStorage_CODESIGN_FLAGS = -SYumiStorage.entitlements

include $(THEOS_MAKE_PATH)/application.mk
