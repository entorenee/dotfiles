.PHONY: help

PROFILE ?= $(shell [ "$$(id -un)" = "fw-skylerlemay" ] && echo work || echo personal)

## Rebuild and switch the system configuration (auto-detects OS and profile)
rebuild:
	@if [ "$$(uname)" = "Darwin" ]; then \
		sudo darwin-rebuild switch --flake "nix/#$(PROFILE)"; \
	else \
		nix run home-manager -- --extra-experimental-features 'nix-command flakes' \
			switch -b hm-backup --flake "nix/#$(PROFILE)@linux"; \
	fi

## Update the flake.lock file
update:
	nix flake update --flake ./nix

## View previous generations of Nix configuration
generations:
	nix run home-manager generations

## Switch to a different generation
switch-gen:
	@read -p "Enter generation number: " gen; \
	home-manager switch --switch-generation $$gen

## Cleanup generations older than 7 days (user + system profiles on Darwin)
cleanup:
	nix-collect-garbage --delete-older-than 7d
	@if [ "$$(uname)" = "Darwin" ]; then \
		sudo nix-collect-garbage --delete-older-than 7d; \
	fi

help:
	@awk '/^## / \
        { if (c) {print c}; c=substr($$0, 4); next } \
         c && /(^[[:alpha:]][[:alnum:]_-]+:)/ \
        {print $$1, "\t", c; c=0} \
         END { print c }' $(MAKEFILE_LIST)
