set nocompatible
" Plugin Configuration
call plug#begin('~/.local/share/nvim/plugged')

Plug 'fatih/vim-go'
Plug 'ternjs/tern_for_vim'

" Advanced File Explorer
Plug 'scrooloose/nerdtree', { 'on':  'NERDTreeToggle' }

" Provides Syntax Highlighting
Plug 'ksiig/vim-polyglot'

" Powerline at Bottom
Plug 'vim-airline/vim-airline'
Plug 'vim-airline/vim-airline-themes'

" Set Dracula as theme
Plug 'dracula/vim', { 'as': 'dracula' }

" Visualizes Tab Indents
Plug 'Yggdroot/indentLine'

" Adds Extra Support for File Searching
Plug 'ctrlpvim/ctrlp.vim', { 'on': '<Plug>CtrlP' }

" Automatically Creates Pairs
Plug 'jiangmiao/auto-pairs'

" Rainbow Parenthases
Plug 'luochen1990/rainbow'

" Disables h,j,k & l Including other keys
Plug 'wikitopian/hardmode'

" Autocompletion
Plug 'ncm2/ncm2'
Plug 'roxma/nvim-yarp'
Plug 'davidhalter/jedi-vim'

" Tags for python
Plug 'majutsushi/tagbar'
Plug 'w0rp/ale'
let g:jedi#auto_vim_configuration = 0 
" IMPORTANT: :help Ncm2PopupOpen for more information
set completeopt=menuone

call plug#end()

" UI Configuration
syntax on
syntax enable

" GUI Colors Configuration
if has("termguicolors")
    set termguicolors
endif
if has("gui_running")
  set guicursor=n-v-c-sm:block,i-ci-ve:block,r-cr-o:blocks
endif

colorscheme dracula

" Basic Vim Configuration
let mapleader = " "
set number

" Turn Off Backup
set nobackup
set noswapfile
set nowritebackup

" Search Configuration
set ignorecase                    " ignore case when searching
set smartcase                     " turn on smartcase

" Tab and Indent Configuration
set tabstop=4
set softtabstop=0 expandtab
set shiftwidth=2 smarttab

" Leader Configurations
nnoremap <Leader>q  :q<CR>
nnoremap <Leader>wq :wq<CR>
nnoremap <Leader>f  :NERDTreeToggle<CR><C-W><C-L>
nnoremap <Leader>p  <C-]>
nnoremap <Leader>h  <C-W>h
nnoremap <Leader>j  <C-W>j
nnoremap <Leader>k  <C-W>k
nnoremap <Leader>l  <C-W>l
nnoremap <Leader>t  <C-T>
nnoremap <Leader>o  <C-O>
nnoremap <Leader>c  :ALEFix<CR>

" Closes NERDTree When Last
autocmd bufenter * if (winnr("$") == 1 && exists("b:NERDTree") && b:NERDTree.isTabTree()) | q | endif

" Enables Ncm2 Autocomplete
autocmd BufEnter * call ncm2#enable_for_buffer()

" Airline Configuration
let g:airline#extensions#tabline#enabled = 1
let g:airline#extensions#tabline#formatter = 'unique_tail'
let g:airline_powerline_fonts = 1

" File Searching Configuration
set wildignore+=*node_modules*
set conceallevel=1
let g:indentLine_conceallevel=1
let g:rainbow_active = 1
noremap <Up> <NOP>
noremap <Down> <NOP>
noremap <Left> <NOP>
noremap <Right> <NOP>

" 80 Charactor Color Column
set textwidth=120
set colorcolumn=+1

" Saves on Enter in Normal mode
nnoremap <silent><expr> <CR> empty(&buftype) ? ":w\<CR>" : "\<CR>"

" Remaps completion
inoremap <C-space> <C-n>
inoremap <expr> <Tab> pumvisible() ? "\<C-n>" : "\<Tab>"
inoremap <expr> <S-Tab> pumvisible() ? "\<C-p>" : "\<S-Tab>"

" Code Fixers
let g:ale_fixers = {
\   'python': [
\       'autopep8'
\   ]
\}
