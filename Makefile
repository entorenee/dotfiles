.PHONY: help

## Decrypt private font files
decrypt-fonts:
	cd fonts; \
		mkdir -p private-fonts; \
		gpg --decrypt private-fonts.tar.gz.asc | \
		tar -xf - -C private-fonts; \
		echo "Private fonts available in fonts/private-fonts"

help:
	@awk '/^## / \
        { if (c) {print c}; c=substr($$0, 4); next } \
         c && /(^[[:alpha:]][[:alnum:]_-]+:)/ \
        {print $$1, "\t", c; c=0} \
         END { print c }' $(MAKEFILE_LIST)
