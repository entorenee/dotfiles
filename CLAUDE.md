# Dotfiles Project Overview

## Project Description
Personal dotfiles managed with Nix Darwin, including comprehensive configurations for development tools, window management, and shell environment.

## Architecture
- **Nix-based configuration management** using Darwin modules
- **Home Manager integration** for user-space configurations
- **Modular structure** with separate modules for each tool/service
- **Profile-based separation** (personal vs work configurations)

## Key Components

### Core System
- **Nix Darwin** - System-level macOS configuration
- **Home Manager** - User environment and dotfile management
- **Profiles** - Separate configurations for personal/work environments

### Development Tools
- **Neovim** - Primary editor with LSP, formatting, linting via Mason
- **Tmux** - Terminal multiplexer with custom theme and keybindings
- **Git** - Version control with profile-specific configurations
- **Shell** - Zsh with Starship prompt

### Applications & Services
- **Ghostty** - Terminal emulator
- **Karabiner** - Keyboard customization
- **Homebrew integration** - GUI applications and system tools
- **Launch Agents** - Background services and automation

## Directory Structure
```
├── nix/
│   ├── flake.nix                 # Main flake configuration
│   ├── system/darwin.nix         # macOS system configuration
│   └── module/                   # Individual tool modules
│       ├── home-manager.nix      # Main home-manager config
│       ├── nvim/                 # Neovim configuration
│       ├── tmux/                 # Tmux configuration
│       ├── git/                  # Git configuration
│       └── [tool]/               # Other tool configurations
├── templates/                    # Configuration templates
└── .claude/                      # Claude AI memory files
```

## Management Commands
- **Build system:** `make darwin-build` / `make home-build`
- **Switch configurations:** `make darwin-switch` / `make home-switch`
- **Profile management:** Controlled via `profile` variable in flake

## Claude AI Memory Files

### Neovim Configuration
- **File:** [.claude/nvim-language-patterns.md](.claude/nvim-language-patterns.md)
- **Purpose:** Documents patterns for language-specific neovim configurations
- **When to reference:** Making changes to language support, LSP, formatting, or linting

### Guidelines for Claude
1. **Always check memory files first** before making configuration changes
2. **Follow established patterns** documented in memory files
3. **Update memory files** when patterns change or new patterns emerge
4. **Maintain consistency** with existing configuration style and structure

## Configuration Principles
- **Modularity** - Each tool has its own module
- **Profile awareness** - Configurations adapt to personal/work contexts  
- **Declarative** - All configurations are explicitly defined
- **Version controlled** - Everything is tracked in git
- **Reproducible** - Configurations can be applied to new machines

## Key Features
- **Automatic tool installation** via Nix packages and Homebrew
- **Cross-profile consistency** with profile-specific overrides
- **Integrated development environment** with LSP, formatting, linting
- **Custom keybindings** and shortcuts across all tools
- **Backup and sync** via git repository

## Getting Started
1. Clone repository
2. Review profile settings in `flake.nix`
3. Run `make darwin-switch` to apply configurations
4. Customize individual modules as needed

## Maintenance Notes
- **Regular updates:** Keep flake.lock updated
- **Profile testing:** Test changes in both personal/work profiles
- **Documentation:** Update memory files when patterns change
- **Backup:** Configurations are version controlled but consider additional backups for sensitive data