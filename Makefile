.PHONY: help

## Run Darwin rebuild for Personal profile
rebuildP:
	sudo darwin-rebuild switch --flake nix/#personal

## Run Darwin rebuild for Work profile
rebuildW:
	sudo darwin-rebuild switch --flake nix/#work

## Update the flake.lock file
update:
	nix flake update --flake ./nix

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
