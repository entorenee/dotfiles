-- Plugin manager setup and plugin loading
local uv = vim.uv or vim.loop

local lazypath = vim.fn.stdpath("data") .. "/lazy/lazy.nvim"
if not uv.fs_stat(lazypath) then
  vim.fn.system({
    "git",
    "clone",
    "--filter=blob:none",
    "https://github.com/folke/lazy.nvim.git",
    "--branch=stable",
    lazypath,
  })
end
vim.opt.rtp:prepend(lazypath)

-- On immutable hosts ~/.config/nvim is a read-only Nix store path, so lazy
-- cannot write its lockfile beside the config. Keep it in the state dir there,
-- seeded from the repo copy (which is 0444 in the store) so the pins carry over.
local configdir = vim.fn.stdpath("config")
local lockfile = configdir .. "/lazy-lock.json"
if not uv.fs_access(configdir, "W") then
  local statedir = vim.fn.stdpath("state")
  local statelock = statedir .. "/lazy-lock.json"
  if not uv.fs_stat(statelock) then
    vim.fn.mkdir(statedir, "p")
    if uv.fs_copyfile(lockfile, statelock) then
      uv.fs_chmod(statelock, tonumber("644", 8))
    end
  end
  lockfile = statelock
end

-- Load all plugin configurations
require("lazy").setup({
  { import = "plugins.lsp" },
  { import = "plugins.ui" },
  { import = "plugins.editor" },
  { import = "plugins.completion" },
  { import = "plugins.languages" },
}, {
  lockfile = lockfile,
})

vim.cmd('colorscheme tokyonight-night')
