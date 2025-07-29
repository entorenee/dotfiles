-- Key mappings
local keymap = vim.keymap.set

-- General mappings
keymap('n', '<CR>', ':noh<CR>', { desc = 'Clear search highlighting' })
keymap('n', '<leader>w', ':w<cr>', { desc = 'Save file' })
keymap('n', '<leader>q', ':q!<cr>', { desc = 'Quit without saving' })
keymap('n', '<leader>z', 'ZZ', { desc = 'Save and quit' })

-- Auto-closer mappings
keymap('i', '{{', '{}<left>')
keymap('i', '((', '()<left>')
keymap('i', '[[', '[]<left>')
keymap('i', "''", "''<left>")
keymap('i', '""', '""<left>')
keymap('i', '``', '``<left>')

-- Tab management
keymap('n', '<leader>1', '1gt', { desc = 'Go to tab 1' })
keymap('n', '<leader>2', '2gt', { desc = 'Go to tab 2' })
keymap('n', '<leader>3', '3gt', { desc = 'Go to tab 3' })
keymap('n', '<leader>4', '4gt', { desc = 'Go to tab 4' })
keymap('n', '<leader>5', '5gt', { desc = 'Go to tab 5' })
keymap('n', '<leader>6', '6gt', { desc = 'Go to tab 6' })
keymap('n', '<leader>7', '7gt', { desc = 'Go to tab 7' })
keymap('n', '<leader>8', '8gt', { desc = 'Go to tab 8' })
keymap('n', '<leader>9', '9gt', { desc = 'Go to tab 9' })
keymap('n', '<leader>0', ':tablast<cr>', { desc = 'Go to last tab' })

-- Pane navigation
keymap('n', '<leader>j', '<C-W>j', { desc = 'Move to pane below' })
keymap('n', '<leader>k', '<C-W>k', { desc = 'Move to pane above' })
keymap('n', '<leader>h', '<C-W>h', { desc = 'Move to left pane' })
keymap('n', '<leader>l', '<C-W>l', { desc = 'Move to right pane' })

-- Indentation
keymap('n', '<leader><Tab>', '>>', { desc = 'Indent line' })
keymap('n', '<leader><S-Tab>', '<<', { desc = 'Unindent line' })

-- Copy buffer path
keymap('n', '<leader>c', function()
  vim.fn.setreg('+', vim.fn.expand('%'))
end, { desc = 'Copy current file path' })

-- Git blame toggle
keymap('n', '<leader>gb', ':GitBlameToggle<CR>', { desc = 'Toggle git blame' })
