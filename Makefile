.PHONY: help claude-sessions friction-remote fmt fmt-check lint check hooks

# Hostname or IP of the uptime-kuma Pi Zero, used by uptime-switch.
UPTIME_HOST ?= uptime

# The friction log's checkout and the ssh alias that reaches it with the agenix
# deploy key rather than the Yubikey. Both restate
# modules/home/claude/friction-log/default.nix — `services.git-sync` cannot set
# either one: its `uri` is consulted only when cloning a missing directory, and
# on Darwin not at all, since the launchd agent just runs `git-sync` in a
# WorkingDirectory that must already exist.
FRICTION_ROOT ?= $(HOME)/claude-friction
FRICTION_URI ?= git@claude-friction.github.com:entorenee/claude-friction.git

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

# --- Formatting and linting -------------------------------------------------

# Two lists because the linters are devShell-only, while the formatters are also
# on PATH via roles/home/base.nix. `nix develop` provides both.
FMT_TOOLS = alejandra yamlfmt shfmt stylua taplo prettier
LINT_TOOLS = statix deadnix actionlint

# Fail once with the fix, rather than with a "command not found" per tool.
define require_tools
@missing=""; \
for t in $(1); do \
	command -v "$$t" >/dev/null 2>&1 || missing="$$missing $$t"; \
done; \
if [ -n "$$missing" ]; then \
	echo "Missing tooling:$$missing"; \
	echo "Run 'nix develop' for a shell with all of it, or 'make rebuild' for the formatters."; \
	exit 1; \
fi
endef

# Tracked files only, matching what a flake can actually see. A bare '*.sh'
# would miss the extensionless scripts, hence SH_FILES' three pathspecs.
#
# Both exclusions stop `make fmt` dying outright: shfmt hard-errors on zsh, and
# these lists are word-split, so the Obsidian vault — the only tracked markdown
# with spaces in its filenames — cannot be passed at all. There is no .json
# list for a related reason: Karabiner, OrcaSlicer and Obsidian rewrite theirs.
NIX_FILES := $(shell git ls-files '*.nix')
YAML_FILES := $(shell git ls-files '*.yml' '*.yaml')
LUA_FILES := $(shell git ls-files '*.lua')
TOML_FILES := $(shell git ls-files '*.toml')
MD_FILES := $(shell git ls-files '*.md' ':!templates/obsidian/*')
SH_FILES := $(shell git ls-files '*.sh' 'modules/home/bins/bin/*' '.githooks/*' \
	':!modules/home/bins/bin/dot-apply' \
	':!modules/home/bins/bin/dot-clean' \
	':!modules/home/bins/bin/dot-update' \
	':!modules/home/bins/bin/update-all')

# Recipes are silenced because each file list runs to seventy-odd paths.

## Format every tracked file in place
fmt:
	$(call require_tools,$(FMT_TOOLS))
	@alejandra --quiet $(NIX_FILES)
	@yamlfmt $(YAML_FILES)
	@shfmt -w $(SH_FILES)
	@stylua $(LUA_FILES)
	@taplo fmt $(TOML_FILES)
	@prettier --write --log-level warn $(MD_FILES)

## Check formatting without writing (what CI and the pre-commit hook run)
fmt-check:
	$(call require_tools,$(FMT_TOOLS))
	@alejandra --check $(NIX_FILES)
	@yamlfmt -lint $(YAML_FILES)
	@shfmt -d $(SH_FILES)
	@stylua --check $(LUA_FILES)
	@taplo fmt --check $(TOML_FILES)
	@prettier --check --log-level warn $(MD_FILES)

## Lint Nix sources and GitHub workflows (needs `nix develop`)
lint:
	$(call require_tools,$(LINT_TOOLS))
	@statix check .
	@deadnix --fail $(NIX_FILES)
	@# actionlint hard-errors rather than no-opping when there is nothing to lint.
	@if [ -d .github/workflows ]; then actionlint; fi

## Run every check CI runs
check: fmt-check lint

## Point git at .githooks so the pre-commit check runs (one-time, per clone)
hooks:
	git config core.hooksPath .githooks
	@echo "core.hooksPath = .githooks — pre-commit will now check staged files."

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

## Clone the friction log, or re-point an existing checkout at the deploy-key alias
friction-remote:
	@if [ -d "$(FRICTION_ROOT)/.git" ]; then \
		git -C "$(FRICTION_ROOT)" remote set-url origin "$(FRICTION_URI)"; \
	else \
		git clone "$(FRICTION_URI)" "$(FRICTION_ROOT)"; \
	fi
	@echo "origin -> $$(git -C "$(FRICTION_ROOT)" remote get-url origin)"


help:
	@awk '/^## / \
        { if (c) {print c}; c=substr($$0, 4); next } \
         c && /(^[[:alpha:]][[:alnum:]_-]+:)/ \
        {print $$1, "\t", c; c=0} \
         END { print c }' $(MAKEFILE_LIST)
