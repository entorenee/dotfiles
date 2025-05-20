set nocompatible
let mapleader=";"
let maplocalleader=";"
let g:python3_host_prog = '/opt/homebrew/bin/python3'

" Editor settings
color slate
set tabstop=2
set softtabstop=2
set shiftwidth=2
set expandtab
set autoindent
set number
set relativenumber
set ruler
set hlsearch
set ignorecase
set smartcase
set backspace=indent,eol,start
set visualbell
set t_vb=
set wildignore+=*.DS_Store,*.d,*.mlast,*.cmi,*.cmj,*.cmt,*reast,*.ast
nnoremap <CR> :noh<CR> " Clear highlighting

" Autocloser highlighting tag maps
inoremap {{ {}<left>
inoremap (( ()<left>
inoremap [[ []<left>
inoremap '' ''<left>
inoremap "" ""<left>
inoremap `` ``<left>

" File management
nnoremap <leader>w :w<cr>
nnoremap <leader>q :q!<cr>
nnoremap <leader>z ZZ
command! CopyBuffer let @+ = expand('%')
nnoremap <leader>c :let @+=expand('%')<CR>


" Tab management
noremap <leader>1 1gt
noremap <leader>2 2gt
noremap <leader>3 3gt
noremap <leader>4 4gt
noremap <leader>5 5gt
noremap <leader>6 6gt
noremap <leader>7 7gt
noremap <leader>8 8gt
noremap <leader>9 9gt
noremap <leader>0 :tablast<cr>
noremap <leader>h gT
noremap <leader>l gt

" Pane navigation
noremap <leader>j <C-W>j
noremap <leader>k <C-W>k
noremap <leader>h <C-W>h
noremap <leader>l <C-W>l

" Indentation
nnoremap <leader><Tab> >>
nnoremap <leader><S-Tab> <<
inoremap <leader><Tab> >
inoremap <leader><S-Tab> <

" End Editor Settings

" Plugin settings 

" Vim Plug

" Install Vim Plug if not already installed
if empty(glob('~/.vim/autoload/plug.vim'))
  silent !curl -fLo ~/.vim/autoload/plug.vim --create-dirs
    \ https://raw.githubusercontent.com/junegunn/vim-plug/master/plug.vim
  autocmd VimEnter * PlugInstall --sync | source $MYVIMRC
endif

call plug#begin('~/.vim/plugged')
Plug 'pangloss/vim-javascript'
Plug 'mxw/vim-jsx'
Plug 'jparise/vim-graphql'
Plug 'leafgarland/typescript-vim'
Plug 'prettier/vim-prettier', {
    \ 'do': 'npm install',
    \ 'for': ['javascript', 'typescript', 'css', 'json', 'graphql', 'markdown', 'yaml'] }
Plug 'scrooloose/nerdtree', { 'on':  'NERDTreeToggle' }
Plug 'w0rp/ale'
Plug 'ctrlpvim/ctrlp.vim'
Plug 'tpope/vim-commentary'
Plug 'https://github.com/ngmy/vim-rubocop'
Plug 'https://github.com/vim-ruby/vim-ruby'
Plug 'https://github.com/tpope/vim-rails'
Plug 'github/copilot.vim', {'branch': 'release'}
Plug 'nvim-lua/plenary.nvim'
Plug 'CopilotC-Nvim/CopilotChat.nvim', {'branch': 'main'}
" LSP configuration
Plug 'neovim/nvim-lspconfig'
Plug 'hrsh7th/cmp-nvim-lsp', {'branch': 'main'}
Plug 'hrsh7th/cmp-buffer', {'branch': 'main'}
Plug 'hrsh7th/cmp-path', {'branch': 'main'}
Plug 'hrsh7th/cmp-cmdline', {'branch': 'main'}
Plug 'hrsh7th/nvim-cmp', {'branch': 'main'}
" Plug 'SirVer/ultisnips'
" Plug 'quangnguyen30192/cmp-nvim-ultisnips', {'branch': 'main'}
call plug#end()

let g:jsx_ext_required = 0 "Allows vim-jsx to parse jsx in js files
let g:javascript_plugin_flow = 1

" NerdTree settings
map <C-n> :NERDTreeToggle<CR>
let g:NERDTreeDirArrowExpandable = '▸'
let g:NERDTreeDirArrowCollapsible = '▾'
let NERDTreeShowHidden=1
let NERDTreeRespectWildIgnore=1

" Ale settings
let g:ale_linter_aliases = {
\  'svelte': ['css', 'javascript'],
\}
let g:ale_linters = {
\  'javascript': ['flow', 'eslint'],
\  'typescript': ['eslint', 'typecheck'],
\  'svelte': ['stylelint', 'eslint'],
\}
" Added jsx fixer for client project
let g:ale_fixers = {
\   'javascript': ['eslint', 'prettier'],
\   'typescript': ['eslint', 'prettier'],
\   'jsx': ['eslint', 'prettier-standard'],
\   'json': ['prettier'],
\   'ruby': ['rubocop']
\}
let g:ale_statusline_format = ['X %d', '? %d', '']
let g:ale_fix_on_save = 1
highlight clear ALEError "Don't highlight error on line, just in gutter
highlight clear ALEWarning "Don't highlight warning on line, just in gutter
let g:ale_javascript_prettier_use_local_config = 1
nmap <silent> <C-k> <Plug>(ale_previous_wrap)
nmap <silent> <C-j> <Plug>(ale_next_wrap)

" Control-P settings
let g:ctrlp_map = '<C-p>' 
let g:ctrlp_cmd = 'CtrlP'
let g:ctrlp_working_path_mode = 'ra'
let g:ctrlp_custom_ignore = {
	\ 'dir':  'node_modules\|coverage\|rendered-*\|dist-*\|.bundle\|vendor\|tmp\|public\|themes\|.git',
	\ }

" UltiSnips settings
" let g:UltiSnipsExpandTrigger="<tab>"
" let g:UltiSnipsEditSplit="vertical"
" let g:UltiSnipsSnippetsDir="~/.vim/UltiSnips"
" let g:UltiSnipsSnippetDirectors=["~/.vim/UltiSnips"]
