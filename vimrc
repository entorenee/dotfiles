set nocompatible
let mapleader="\<space>"

" Editor settings
set tabstop=2
set softtabstop=2
set shiftwidth=2
set expandtab
set autoindent
set number
set relativenumber
set ruler
set backspace=indent,eol,start
set visualbell
set t_vb=

" Autoclose tag maps
inoremap {{ {}<left>
inoremap (( ()<left>
inoremap [[ []<left>
inoremap '' ''<left>
inoremap "" ""<left>
inoremap `` ``<left>

" Leader key remaps
nnoremap <leader><leader> :w<cr>

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
Plug 'posva/vim-vue'
Plug 'prettier/vim-prettier', {
    \ 'do': 'npm install',
    \ 'for': ['javascript', 'typescript', 'css', 'less', 'scss'] }
Plug 'scrooloose/nerdtree', { 'on':  'NERDTreeToggle' }
Plug 'w0rp/ale'
Plug 'ctrlpvim/ctrlp.vim'
call plug#end()

let g:jsx_ext_required = 0 "Allows vim-jsx to parse jsx in js files

" NerdTree settings
map <C-n> :NERDTreeToggle<CR>
let g:NERDTreeDirArrowExpandable = '▸'
let g:NERDTreeDirArrowCollapsible = '▾'
let NERDTreeShowHidden=1

" Ale settings
let g:ale_linters = {'jsx': 'eslint'}
let g:ale_fixers = {
\   'javascript': ['eslint'],
\}
let g:ale_fix_on_save = 1
nmap <silent> <C-k> <Plug>(ale_previous_wrap)
nmap <silent> <C-j> <Plug>(ale_next_wrap)

" Control-P settings
let g:ctrlp_map = '<C-p>' 
let g:ctrlp_cmd = 'CtrlP'
let g:ctrlp_working_path_mode = 'ra'
let g:ctrlp_custom_ignore = {
	\ 'dir':  'node_modules\|coverage',
	\ }

" Prettier settings
let g:prettier#autoformat = 0
let g:prettier#config#print_width = 80
let g:prettier#config#bracket_spacing = 'true'
let g:prettier#config#jsx_bracket_same_line = 'false'
autocmd BufWritePre *.js,*.css,*.scss,*.less Prettier

