.PHONY: help


## Set Yubikey SSH access for Github
setup-yubikey-ssh:
	./scripts/setup-yubikey-ssh.sh

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
