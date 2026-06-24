.PHONY: serve
serve:
	podman run --rm -it -p 1313:1313 -v "$(CURDIR):/src" -w /src quay.io/validatedpatterns/hugo:latest server --bind 0.0.0.0 --disableFastRender

.PHONY: build
build:
	podman run --rm -it -v "$(CURDIR):/src" -w /src quay.io/validatedpatterns/hugo:latest
