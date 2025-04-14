.PHONY: help

## Initialize Mac environment
initialize-mac:
	./scripts/macos-setup.sh

## Complete initial GPG setup
gpg-setup:
	./scripts/gpg-setup.sh

## Set Yubikey SSH access for Github
setup-yubikey-ssh:
	./scripts/setup-yubikey-ssh.sh

## Set Git Signing Key
set-git-signing:
	./scripts/set-git-signing-key.sh

## Decrypt private font files
decrypt-fonts:
	cd fonts; \
		mkdir -p private-fonts; \
		gpg --decrypt private-fonts.tar.gz.asc | \
		tar -xf - -C private-fonts; \
		echo "Private fonts available in fonts/private-fonts"

## Copy fonts to Mac user fonts
import-fonts:
	find fonts/ -type f | grep -i otf$ | xargs -i cp {} $HOME/Library/Fonts

help:
	@awk '/^## / \
        { if (c) {print c}; c=substr($$0, 4); next } \
         c && /(^[[:alpha:]][[:alnum:]_-]+:)/ \
        {print $$1, "\t", c; c=0} \
         END { print c }' $(MAKEFILE_LIST)
