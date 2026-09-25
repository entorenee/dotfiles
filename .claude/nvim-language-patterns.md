# Neovim Language Configuration Patterns

## Overview

This document captures the established patterns for language-specific configurations in the nvim setup after refactoring to a hybrid approach.

## Architecture

### Centralized vs Language-Specific

- **Centralized (in main files):**
  - LSP servers — Mason `ensure_installed` (`lua/plugins/lsp.lua`, mason-lspconfig)
  - Editor-only formatters/linters — Mason `ensure_installed` (`lua/plugins/lsp.lua`, mason-tool-installer). **Not every formatter lives here** — see "Where a tool is installed" below.
  - Which formatter/linter runs on which filetype (`lua/plugins/editor.lua`)
  - Base TreeSitter configuration (`lua/plugins/ui.lua`)
  - LSP server configurations (`lua/plugins/lsp.lua`)

- **Language-Specific (in language files):**
  - Language-specific plugins
  - Custom settings/options per language
  - Language-specific keymaps
  - Buffer-local autocmds

### Where a tool is installed — Nix or Mason

`lsp.lua` holds two separate `ensure_installed` lists, and a third install source sits outside nvim entirely:

| Tool kind                                      | Installed by                 | Where                                                                                   |
| ---------------------------------------------- | ---------------------------- | --------------------------------------------------------------------------------------- |
| LSP servers                                    | Mason (mason-lspconfig)      | `lsp.lua` `ensure_installed`                                                            |
| Formatters/linters the repo's own tooling runs | **Nix**                      | `modules/home/formatters/`, `modules/home/yamlfmt/` — on PATH via `roles/home/base.nix` |
| Every other formatter/linter                   | Mason (mason-tool-installer) | `lsp.lua` `ensure_installed`                                                            |

**The dividing line is whether `make fmt` or `make lint` runs it.** Those two go through the pre-commit hook and CI, neither of which has Mason — a Mason-only tool leaves the hook and CI unable to rely on it existing, and drifts in version between machines. So the six `make fmt` runs (`alejandra`, `prettier`, `shfmt`, `stylua`, `taplo`, `yamlfmt`) are Nix-declared and **must not** be added back to Mason.

`actionlint` is in **both**, deliberately: `make lint` needs it in the devShell, and `editor.lua`'s autocmd calls `try_lint("actionlint")` on `.github/workflows/*.yml`, which needs it on `PATH` in every checkout. Dropping it from Mason on the grounds that `linters_by_ft` has no yaml entry has been tried and was wrong — that autocmd bypasses the table.

## Language File Pattern

### File Structure

```lua
-- [Language] language specific configuration
vim.api.nvim_create_autocmd("FileType", {
	pattern = "[filetype(s)]",
	callback = function()
		-- Language-specific settings
		vim.opt_local.setting = value

		-- Language-specific keymaps
		local opts = { buffer = true, silent = true }
		vim.keymap.set("n", "<leader>xx", function() ... end, opts)

		-- Any language-specific setup
	end,
})

return {}
```

### Key Points

1. **Use direct autocmds** - Don't wrap in plugin definitions
2. **Return empty table** - `return {}` so Lazy.nvim sees it as valid
3. **Buffer-local keymaps** - Always use `{ buffer = true, silent = true }`
4. **Pattern matching** - Single string or array for multiple filetypes

## Current Language Files

### nix.lua

- **Pattern:** `"nix"`
- **Keymaps:**
  - `<leader>nf` - nix flake check
  - `<leader>nu` - nix flake update
- **Helper function:** `run_nix_flake_command(command)` for DRY flake operations
- **Logic:** Finds nearest flake.nix and runs from that directory

### typescript-javascript.lua

- **Pattern:** `{ "javascript", "typescript", "typescriptreact", "javascriptreact" }`
- **Keymaps:**
  - `<leader>ji` - Insert eslint-disable comment
  - `<leader>je` - Insert eslint-enable comment

### markdown.lua

- **Pattern:** `"markdown"`
- **Settings:**
  - Spell checking enabled (`vim.opt_local.spell = true`)
  - Text width 80 with line wrapping
- **Keymaps:**
  - `<leader>mp` - Preview with glow
  - `<leader>mt` - Add todo item
  - `<leader>mc` - Toggle checkbox (proper toggle function)
- **Abbreviations:**
  - `--` → `—` (em dash)
  - ```→ code block with cursor in middle

    ```

### graphql.lua

- **Just contains:** `vim-graphql` plugin for syntax support
- **No autocmds needed** - uses global defaults

## Global Defaults

### Tab Settings

- **Global default:** 2 spaces, expandtab (set in `config/options.lua`)
- **Language override:** Only add tabwidth settings if different from global default

### TreeSitter Languages

- **Base languages** in `ui.lua`: lua, nix, html, css, json, yaml, markdown, bash, sql, javascript, typescript, tsx
- **Language files:** Don't duplicate TreeSitter config, it's handled globally

## Best Practices

### Adding New Language Support

1. **Check existing tools:** See if formatters/linters are already configured in `editor.lua`
2. **Install the tool where it belongs:** if `make fmt`/`make lint` will run it, declare it in `modules/home/formatters/` (Nix); otherwise add it to `ensure_installed` in `lsp.lua`. See "Where a tool is installed" above — do not reach for Mason by default.
3. **Wire it to a filetype:** add it to `formatters_by_ft` or `linters_by_ft` in `editor.lua`
4. **Create language file:** Use the established pattern above
5. **Import in init.lua:** Add to `languages/init.lua`

### Common Patterns

- **Helper functions:** For repeated logic (like nix flake commands)
- **Proper toggle functions:** Use actual toggle logic, not just one-way operations
- **Meaningful keymaps:** Use logical leader key combinations
- **Buffer-local everything:** Settings and keymaps should be buffer-specific

### Naming Conventions

- **File names:** `[language].lua` (e.g., `python.lua`, `rust.lua`)
- **Keymap prefixes:** Use first letter of language (`<leader>n` for nix, `<leader>j` for javascript)
- **Functions:** Descriptive names that indicate their purpose

## Troubleshooting

### Common Issues

1. **Keymaps not working:** Check if autocmd is firing with debug prints
2. **Plugin conflicts:** Don't wrap autocmds in plugin definitions
3. **Loading order:** Language files load when imported, autocmds fire on FileType

### Debug Pattern

```lua
vim.api.nvim_create_autocmd("FileType", {
	pattern = "...",
	callback = function()
		print("Language autocmd triggered!")  -- Remove after debugging
		-- ... rest of config
	end,
})
```

## File Locations

- **Language files:** `lua/plugins/languages/[name].lua`
- **Import registry:** `lua/plugins/languages/init.lua`
- **Main configs:** `lua/plugins/lsp.lua`, `lua/plugins/editor.lua`, `lua/plugins/ui.lua`
