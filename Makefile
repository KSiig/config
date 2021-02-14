test:
	find ./roles -maxdepth 1 -type d -exec make -C {} test \;
.PHONY: test