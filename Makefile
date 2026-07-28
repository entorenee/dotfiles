.PHONY: help claude-sessions

PROFILE ?= $(shell [ "$$(id -un)" = "fw-skylerlemay" ] && echo work || echo personal)

## List running Claude Code sessions (PID, start time, working directory)
claude-sessions:
	@pids=$$(pgrep -x claude 2>/dev/null); \
	if [ -z "$$pids" ]; then \
		echo "No Claude Code sessions running."; \
	else \
		echo "Running Claude Code sessions:"; \
		for p in $$pids; do \
			started=$$(ps -o lstart= -p "$$p" 2>/dev/null | sed 's/^ *//;s/ *$$//'); \
			cwd=$$(lsof -a -p "$$p" -d cwd -Fn 2>/dev/null | sed -n 's/^n//p'); \
			printf '  pid %-7s started %s\n            cwd %s\n' "$$p" "$${started:-unknown}" "$${cwd:-unknown}"; \
		done; \
	fi

## Rebuild and switch the system configuration (auto-detects OS and profile)
rebuild:
	@if pgrep -x claude >/dev/null 2>&1 && [ -z "$(FORCE)" ]; then \
		echo "Refusing to rebuild while Claude Code is running."; \
		echo "A rebuild that changes settings.json deletes ~/.claude/settings.json"; \
		echo "out from under a live session, taking every permission rule with it"; \
		echo "(see the 'Quit Claude sessions before rebuilding' section of CLAUDE.md)."; \
		echo; \
		$(MAKE) --no-print-directory claude-sessions; \
		echo; \
		echo "Quit them and retry, or override with: make rebuild FORCE=1"; \
		exit 1; \
	fi
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
