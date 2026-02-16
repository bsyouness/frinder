.PHONY: deploy-website

deploy-website:
	rm -rf /tmp/frinder-website
	cp -r website /tmp/frinder-website
	cd /tmp/frinder-website && npx wrangler pages deploy . --project-name frinder-website --commit-dirty=true
