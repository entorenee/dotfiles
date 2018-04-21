
# Add RVM to PATH for scripting. Make sure this is the last PATH variable change.
export PATH="$PATH:$HOME/.rvm/bin"
. /usr/local/etc/profile.d/z.sh
export PATH="$(brew --prefix homebrew/php/php71)/bin:$PATH"
