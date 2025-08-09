.PHONY: help

## Run Darwin rebuild for Personal profile
pRebuild:
	sudo darwin-rebuild --impure switch --flake nix/#personal

## Run Darwin rebuild for Work profile
wRebuild:
	sudo darwin-rebuild --impure switch --flake nix/#work

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

## Cleanup generations older than 7 days
cleanup:
	nix-collect-garbage --delete-older-than 7d

## Switch to local Karabiner setup for easier UI editing
kb-edit:
	unlink ~/.config/karabiner; \
		cp -r nix/module/karabiner/config ~/.config/karabiner/

## Pull local Karabiner config from UI editing into Nix
kb-pull:
	rsync -av --exclude='automatic_backups' \
  ~/.config/karabiner/ \
  ~/dotfiles/nix/module/karabiner/config/; \
	rm -rf ~/.config/karabiner.backup;

## Decrypt private font files
decrypt-fonts:
	cd fonts; \
		mkdir -p private-fonts; \
		gpg --decrypt private-fonts.tar.gz.asc | \
		tar -xf - -C private-fonts; \
		echo "Private fonts available in fonts/private-fonts"

## Copy fonts to Mac user fonts
import-fonts:
	find fonts \( -name '*.otf' -o -name '*.ttf' \) -exec cp {} ~/Library/Fonts \;

help:
	@awk '/^## / \
        { if (c) {print c}; c=substr($$0, 4); next } \
         c && /(^[[:alpha:]][[:alnum:]_-]+:)/ \
        {print $$1, "\t", c; c=0} \
         END { print c }' $(MAKEFILE_LIST)
