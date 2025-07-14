# Skyler Lemay dotfiles

This repository contains dotfiles shared across multiple computer systems, differentiating between work and personal profiles in terms of package installation and configuration. Under the hood it uses [Nix](https://nixos.org/) for package management and system configuration. [Nix Darwin](https://github.com/nix-darwin/nix-darwin) is also utilized to handle MacOS specific configuration.

Most files are public and can be shared across systems. Some files are private and are consequently encrypted with the unencrypted versions placed in gitignore. This may be due to licensing restrictions, paid products including fonts, or sensitive/confidential information. These files are encrypted using GPG with the respective public keys of one or more of my profiles. They will not be accessible to others using the repository.

This configuration is highly opinionated and tailored to my preferences. Various aspects of it can be broken out into separate flows and scripts. This is not a plug and play solution for other engineers, though aspects of it may be used and adjusted to fit your needs. Strong preferences include:

* The use of Oh my ZSH for shell configuration
* The use of Nix for package management and system configuration, including a hybrid approach with Homebrew, discussed below.
* A strong preference for assymetric encryption utilizing GPG for encryption, signing, and authentication
* The use of Yubikey as a hardware security key eliminating the storage of private keys on a networked computer
* The use of Neovim as a code editor solution with plugins managed via Lazyvim.

## Setup

Feel free to clone or fork the repo and store the dotfiles in your **home** directory.
```
$ cd ~
$ git clone https://github.com/entorenee/dotfiles
```

### Install Nix

Install Nix using the Determinate Systems installer:
```
curl --proto '=https' --tlsv1.2 -sSf -L https://install.determinate.systems/nix | sh -s -- install
```

### Install nix-darwin

Install nix-darwin to manage system configuration:
```
nix run nix-darwin -- switch --flake ~/dotfiles/nix#[personal|work]
```

### Maintenance scripts

Several Makefile commands have been created to help manage the Nix configuration after the initial install:

* **[p|w]Rebuild**: This command with the corresponded `p` or `w` prefix will rebuild the configuration file for the personal or work flake targets.
* **update**: This updates the `flake.lock` file which corresponds to the Nix package inputs. The lock file can be committed, and a rebuild should be run after the lock file changes.
* **generations**: Nix creates generations each time there is a change in configuration. This is great in the aspect that it allows Nix to rollback to a previous version of the configuration for debugging or temporarily unblocking a broken step. This comman lists the generations of builds available on the machine.
* **cleanup**: This will perform Nix's garbage collection and delete all generations which are older than 7 days. Keeping old generations around when they are no longer necessary results in extra storage space being utilized.

## Managing Packages with Nix and Homebrew

Overall, Nix is preferred for package installation whenever possible. However, by default Nix installs applications in `~/Applications` rather than `/Applications` which is annoying and complicates the Finder search. Nix also does not support as many of the MacOS specific GUI applications. This has resulted in a hybrid approach. The general principles of this are:

* If a package can be installed with Nix and Home-Manager without negative side effects that is preferred.
* Homebrew is installed via Nix and can be used to install additional apps for Mac targets. Nix is cross-platform including Linux, but Homebrew will only work on MacOS targets.
* Nix is the source of truth for what packages are installed via Homebrew. **NOTE:** If a package is installed via the `brew` CLI it will be uninstalled the next time Nix is rebuilt. This is an opinionated approach to force the convention of setting packages for machines in config.
* However, Nix is only responsible for determining which packages are installed via Homebrew. Managing the versions, and potential compatability or breaking changes of a package, are the responsibility of the end user through the typical `brew update|outdated|upgrade` commands.

TLDR: Nix determines what Homebrew installs, and the end user manages the upgrade maintenances of the binaries on the host computer.

If the repository is forked, or updated for a different use case the Homebrew cleanup can be altered within `nix/module/homebrew/default.nix` in the `onActivation.cleanup` setting. Allowed settings are:

* `none`: Nix does nothing to manage Homebrew outside of brews and casks it has installed. Ie removing a brew from the Nix configuration will uninstall it. However, items installed via the brew CLI directly will not be uninstalled.
* `uninstall`: This is the current setting which uninstalls anything not specified in the Nix Homebrew configuration. This is the moderate setting.
* `zap`: This setting is more aggressive than uninstall. It will also delete all settings associated with the app for the most aggressive cleanup. This can result in user data loss from accidentally forgetting to install via Nix and I have opted out of that setting.

## Tmuxinator

This repository also ships with [tmuxinator](https://github.com/tmuxinator/tmuxinator) for quick templating of different tmux sessions. The blog template really only makes sense for myself. Hopefully seeing that and the generic code example give some insight into how this tool can be used. I separately have private encrypted project configs that I can quickly spin up all of the commands to work in private repositories I commonly work in. A quick highlight of the usage (see the referenced repository above for more detailed docs):

* Run `tmux start code [workspace=~/project-path]`. This will spin up a tmux session with a `main-vertical` pane arrangement. Neovim will be open in the main pane and two terminal windows are horizontally split for the second vertical section.
  * `workspace` is an optional settings variable in the template. Setting it will dictate the working directory the tmux session is initiated with. If it is omitted, it will fall back to `~/`.
  * Optionally include `-n [name]` to provide a distinct name for the session on creation.
* There is also an alias `tx` configured to abbreviate typing out `tmuxinator` because ADHD.
* You can create your own configuration by typing `tx new [project-name]` using the name you want to reference with `tmux start` as mentioned above.
* Set the configuration as you would like and save for future use.

## Manual configuration

### Iterm (likely to be deprecated)

After copying the dotfiles, several pieces need to be manually set in Iterm's preferences.

- Set the preference backup to `~/dotfiles/iterm2`. Make sure to ignore local settings when first selecting this to avoid overwriting the settings.
- Set iTerm2 to save the settings on exit.
- The zsh theme uses Powerline fonts and will not render correctly without setting the display font to a Powerline based font. I currently use Dank Mono.

## Optional App Templates

Not all apps allow global configuration 😔. Template configuration for these apps are namespaced under the `templates/* folder. Depending on the use case, these can either be copied into the appropriate locations, or manually symlinked in certain cases. Specific instructions for each template live in their respective READMEs.

