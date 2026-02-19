.PHONY: deploy-website bump-version serve-website

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
	rm -rf /tmp/frinder-website
	cp -r website /tmp/frinder-website
	cd /tmp/frinder-website && npx wrangler pages deploy . --project-name frinder-website --commit-dirty=true
