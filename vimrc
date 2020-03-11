set nocompatible
let mapleader=";"

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
set wildignore+=*.DS_Store,*.d,*.mlast,*.cmi,*.cmj,*.cmt,*reast
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
nnoremap <leader>md :silent !open -a Marked\ 2 %<cr> " Open current md file in Marked

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
Plug 'lumiliet/vim-twig'
Plug 'posva/vim-vue'
Plug 'burner/vim-svelte'
Plug 'leafgarland/typescript-vim'
Plug 'reasonml-editor/vim-reason-plus'
Plug 'prettier/vim-prettier', {
    \ 'do': 'npm install',
    \ 'for': ['javascript', 'typescript', 'css', 'less', 'scss'] }
Plug 'scrooloose/nerdtree', { 'on':  'NERDTreeToggle' }
Plug 'w0rp/ale'
Plug 'ctrlpvim/ctrlp.vim'
" Plug 'SirVer/ultisnips'
Plug 'tpope/vim-commentary'
Plug 'neoclide/coc.nvim', {'branch': 'release'}
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
\  'typescript': ['tslint', 'eslint', 'typecheck'],
\  'svelte': ['stylelint', 'eslint'],
\}
" Added jsx fixer for client project
let g:ale_fixers = {
\   'javascript': ['eslint', 'prettier'],
\   'typescript': ['tslint', 'eslint', 'prettier'],
\   'jsx': ['eslint', 'prettier-standard'],
\   'json': ['prettier'],
\   'scss': ['prettier'],
\   'vue': ['eslint', 'prettier'],
\   'svelte': ['eslint', 'prettier'],
\   'reason': ['refmt']
\}
let g:ale_statusline_format = ['X %d', '? %d', '']
let g:ale_fix_on_save = 1
highlight clear ALEError "Don't highlight error on line, just in gutter
highlight clear ALEWarning "Don't highlight warning on line, just in gutter
let g:ale_javascript_prettier_use_local_config = 1
nmap <silent> <C-k> <Plug>(ale_previous_wrap)
nmap <silent> <C-j> <Plug>(ale_next_wrap)

" Ack settings
nmap <C-S-F> :Ack<space>

" Control-P settings
let g:ctrlp_map = '<C-p>' 
let g:ctrlp_cmd = 'CtrlP'
let g:ctrlp_working_path_mode = 'ra'
let g:ctrlp_custom_ignore = {
	\ 'dir':  'node_modules\|coverage\|rendered-*\|dist-*',
	\ }

" UltiSnips settings
" let g:UltiSnipsExpandTrigger="<tab>"
" let g:UltiSnipsEditSplit="vertical"
" let g:UltiSnipsSnippetsDir="~/.vim/UltiSnips"
" let g:UltiSnipsSnippetDirectors=["~/.vim/UltiSnips"]

" Conquer of Completion Settings
set hidden

" Better display for messages
set cmdheight=2

" You will have bad experience for diagnostic messages when it's default 4000.
set updatetime=300

" always show signcolumns
set signcolumn=yes

" Make Floating popups work with solarized
hi CoCFloating ctermbg=8

" Use tab for trigger completion with characters ahead and navigate.
" Use command ':verbose imap <tab>' to make sure tab is not mapped by other plugin.
inoremap <silent><expr> <TAB>
      \ pumvisible() ? "\<C-n>" :
      \ <SID>check_back_space() ? "\<TAB>" :
      \ coc#refresh()
inoremap <expr><S-TAB> pumvisible() ? "\<C-p>" : "\<C-h>"

function! s:check_back_space() abort
  let col = col('.') - 1
  return !col || getline('.')[col - 1]  =~# '\s'
endfunction

" Use <cr> to confirm completion, `<C-g>u` means break undo chain at current position.
" Coc only does snippet and additional edit on confirm.
inoremap <expr> <cr> pumvisible() ? "\<C-y>" : "\<C-g>u\<CR>"

" Use `[g` and `]g` to navigate diagnostics
nmap <silent> [g <Plug>(coc-diagnostic-prev)
nmap <silent> ]g <Plug>(coc-diagnostic-next)

" == AUTOCMD ================================
" by default .ts file are not identified as typescript and .tsx files are not
" identified as typescript react file, so add following
au BufNewFile,BufRead *.ts setlocal filetype=typescript
au BufNewFile,BufRead *.tsx setlocal filetype=typescript.tsx
" == AUTOCMD END ================================
