DOCKER_WRAPPER_IMAGE ?= ghcr.io/ksiig/utility-images:ansible-latest

test:
	find ./roles -maxdepth 1 -type d -exec make -C {} test \;
.PHONY: test

docker_%:
	@docker run --rm \
	-v /var/run/docker.sock:/var/run/docker.sock \
	-v $(shell pwd):/app \
	-w /app \
	-e CR_PAT=${CR_PAT} \
	${DOCKER_WRAPPER_IMAGE} $(MAKE) $*