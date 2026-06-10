.PHONY: all
all:
	$(MAKE) fmt
	$(MAKE) lint

.PHONY: fmt
fmt:
	shfmt -w track-branch-heads.sh
	yamlfmt .

.PHONY: lint
lint:
	shellcheck track-branch-heads.sh
	actionlint
	yamllint --no-warnings .
	zizmor .
	ghalint run
	ghalint run-action
