ARCHIVE_PATH = /tmp/Frinder.xcarchive
EXPORT_PATH  = /tmp/FrinderExport

.PHONY: deploy-website bump-version serve-website archive upload

archive:
	xcodebuild archive \
		-project Frinder/Frinder.xcodeproj \
		-scheme Frinder \
		-destination "generic/platform=iOS" \
		-archivePath $(ARCHIVE_PATH) \
		-allowProvisioningUpdates
	@echo "Archive saved to $(ARCHIVE_PATH)"

upload: archive
	xcodebuild -exportArchive \
		-archivePath $(ARCHIVE_PATH) \
		-exportPath $(EXPORT_PATH) \
		-exportOptionsPlist ExportOptions.plist \
		-allowProvisioningUpdates
	xcrun altool --upload-app \
		-f $(EXPORT_PATH)/Frinder.ipa \
		-t ios \
		-u "$$APPLE_ID" \
		-p "$$APPLE_APP_PASSWORD" \
		--output-format xml
	@echo "Upload complete"

bump-version:
ifndef VERSION
	$(error Usage: make bump-version VERSION=1.2.0)
endif
	@echo "Updating Frinder/Frinder.xcodeproj/project.pbxproj (MARKETING_VERSION)"
	@sed -i '' 's/MARKETING_VERSION = .*;/MARKETING_VERSION = $(VERSION);/g' Frinder/Frinder.xcodeproj/project.pbxproj
	@echo "Updating Frinder/Frinder/Info.plist (CFBundleShortVersionString)"
	@plutil -replace CFBundleShortVersionString -string "$(VERSION)" Frinder/Frinder/Info.plist
	@echo "Updating Frinder/Frinder/Views/SettingsView.swift (version display)"
	@sed -i '' 's/Text("[0-9][0-9]*\.[0-9][0-9]*\.[0-9][0-9]*")/Text("$(VERSION)")/' Frinder/Frinder/Views/SettingsView.swift
	@echo "Version bumped to $(VERSION)"

serve-website:
	@lsof -ti:8080 | xargs kill -9 2>/dev/null; true
	@cd website && python3 -m http.server 8080 &
	@sleep 1 && open http://localhost:8080

deploy-website:
	cd /Users/youness/workspace/frinder && firebase deploy --only hosting 2>&1

deploy-functions:
	cd /Users/youness/workspace/frinder && firebase deploy --only functions 2>&1
