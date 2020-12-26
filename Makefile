TAG := "crops:poky-ubuntu18.04"

image:
	docker build . -t ${TAG}

shell:
	docker run --rm -it \
		-v $(POKY_WORKDIR):/workdir \
		-v $(POKY_DLDIR):/workdir/downloads \
		-v $(POKY_SSTATE_DIR):/workdir/sstate-cache \
		${TAG}

build:
	docker run --rm -it \
		-v $(POKY_WORKDIR):/workdir \
		-v $(POKY_DLDIR):/workdir/downloads \
		-v $(POKY_SSTATE_DIR):/workdir/sstate-cache \
		${TAG} \
		$(POKY_BUILD_CMD)

clean:
	docker rmi ${TAG}

help:
	@echo "targets:"
	@echo "    image: build ${TAG} image"
	@echo "    shell: run bash on poky-container"
	@echo "    build: run build.sh on poky-container"
	@echo "    clean: remove ${TAG} image"
