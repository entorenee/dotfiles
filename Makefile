.PHONY: help claude-sessions

# Hostname or IP of the uptime-kuma Pi Zero, used by uptime-switch.
UPTIME_HOST ?= uptime

# PIDs of running Claude Code sessions. `pgrep -x claude` does NOT work: the
# package is a Nix binary wrapper whose bin/claude execve's .claude-wrapped in
# place, so the surviving process's name is never "claude" and the match
# silently comes back empty. argv[0] is still "claude", which is why
# `pgrep -f` looks fine and `pgrep -x` does not. Matched on the basename
# because macOS ps reports comm as a full path. ps/awk only — procps is not
# declared in this config, and a missing pgrep would fail open.
CLAUDE_PIDS = ps -eo pid=,comm= | awk '{n=split($$2,a,"/"); if (a[n]=="claude" || a[n]==".claude-wrapped") print $$1}'

## List running Claude Code sessions (PID, start time, working directory)
claude-sessions:
	@pids=$$($(CLAUDE_PIDS)); \
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

## Rebuild and switch the system configuration (auto-detects OS and host by hostname)
rebuild:
	@if [ -n "$$($(CLAUDE_PIDS))" ] && [ -z "$(FORCE)" ]; then \
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
	@host="$$(hostname -s)"; \
	if [ "$$(uname)" = "Darwin" ]; then \
		sudo darwin-rebuild switch --flake ".#$$host"; \
	else \
		nix run home-manager -- --extra-experimental-features 'nix-command flakes' \
			switch -b hm-backup --flake ".#$$host"; \
	fi

## Update the flake.lock file
update:
	nix flake update --flake .

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

## Build a flashable SD image for the airgapped Pi Zero (run on the hub)
airgap-image:
	nix build ".#nixosConfigurations.airgap.config.system.build.sdImage" --out-link result-airgap-image

## Rebuild and switch the hub's own NixOS system (run on the hub)
hub-switch:
	sudo nixos-rebuild switch --flake ".#hub"

## Build a flashable SD image for the uptime-kuma Pi Zero (run on the hub)
uptime-image:
	nix build ".#nixosConfigurations.uptime.config.system.build.sdImage" --out-link result-uptime-image

## Deploy the uptime host (run on the hub; the Zero cannot rebuild itself)
uptime-switch:
	nixos-rebuild switch --flake ".#uptime" --target-host "uptime@$(UPTIME_HOST)" --sudo



help:
	@awk '/^## / \
        { if (c) {print c}; c=substr($$0, 4); next } \
         c && /(^[[:alpha:]][[:alnum:]_-]+:)/ \
        {print $$1, "\t", c; c=0} \
         END { print c }' $(MAKEFILE_LIST)
