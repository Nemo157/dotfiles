au BufRead,BufNewFile *.xaml setf xml
au BufRead,BufNewFile Guardfile setf ruby
au BufRead,BufNewFile *.ll\|*.llvm setf llvm

au FileType markdown\|rst\|tex\|plaintex setlocal textwidth=80
au FileType java\|glsl\|xml\|ps1\|vhdl\|mason setlocal tabstop=4 shiftwidth=4 noexpandtab
au FileType c\|cpp setlocal tabstop=4 shiftwidth=4

au BufWritePost vimrc source ~/.vimrc

