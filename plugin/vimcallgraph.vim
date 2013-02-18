
function! VimCallGraph()
  let vcg = {}
  let vcg.function_pattern = '^\s*fu\%[nction]!\?\s\+\([^(]\+\)('
  let vcg.end_function_pattern = '^\s*endfu\%[nction]'
  let vcg.function_call_pattern = '\(\h[#.a-zA-Z0-9_{}]\+\)('
  let vcg.function_object_pattern = '^\([^.]\+\.\)'

  func vcg.parse(file, ...) dict
    if a:0
      " user supplied options
      call extend(self.options, a:1)
    endif
    call self.prepare_output()
    " Allow a list as argument
    let self.input = type(a:file) == type('') ? readfile(a:file) : a:file
    let self.curline = 0
    let self.eof = len(self.input)
    while self.curline < self.eof
      let line = self.input[self.curline]
      let self.curline += 1
      " skip blank & comment lines
      if self.is_blank_or_comment(line)
        continue
      else
        call self.process(line)
      endif
    endwhile
    return self.output()
  endfunc

  func vcg.prepare_output() dict
    let self.function_stack = ['__GLOBAL__']  " global scope
    let self.functions = {}
    call self.add_function(self.top_function())
    " let self.current_object = ''
    let self.vim_functions = readfile('vimfuncs.txt')
    let self.out = []
  endfunc

  func vcg.add_function(name) dict
    let name = a:name
    if ! has_key(self.functions, name)
      let self.functions[name] = []
    endif
  endfunc

  func vcg.push_function(name) dict
    let name = a:name
    call add(self.function_stack, name)
      echo 'name=' . name
    if match(name, self.function_object_pattern) != -1
      echo 'name=' . name
      let self.current_object = matchlist(name, self.function_object_pattern)[1]
    endif
  endfunc

  func vcg.top_function() dict
    if len(self.function_stack) > 1
      return self.function_stack[-1]
    else
      return self.function_stack[0]
    endif
  endfunc

  func vcg.pop_function() dict
    " if len(self.function_stack) > 1
      call remove(self.function_stack, -1)
    " endif
  endfunc

  func vcg.is_blank_or_comment(line)
    return a:line =~ '^\s*\%("\|$\)'
  endfunc

  func vcg.process(line) dict
    " TODO: strip out actual comments
    let line = a:line
    let new_function = ''
    if match(line, self.function_pattern) != -1
      let new_function = matchlist(line, self.function_pattern)[1]
      call self.add_function(new_function)
    elseif match(line, self.end_function_pattern) != -1
      call self.pop_function()
    endif
    call self.collect_function_calls(line)
    if new_function != ''
      call self.push_function(new_function)
    endif
  endfunc

  func vcg.collect_function_calls(line) dict
    let line = a:line
    while match(line, self.function_call_pattern) != -1
      let name = matchlist(line, self.function_call_pattern)[1]
      " TODO: hack - collect the self -> dict from the top_function()
      " let name = substitute(name, 'self\.', 'sin.', 'g')
      if match(name, 'self\.') != -1
        let name = substitute(name, 'self\.', self.current_object, 'g')
      endif
      call self.add_function_call(name)
      let line = substitute(line, self.function_call_pattern, '', '')
    endwhile
  endfunc

  func vcg.add_function_call(name) dict
    let name = a:name
    call add(self.functions[self.top_function()], name)
  endfunc

  func vcg.output() dict
    let output = ['digraph V {', 'rankdir=LR']
    for [fn, fcs] in items(self.functions)
      for fc in fcs
        if index(self.vim_functions, fc) == -1
          call add(output, '"' . fn . '" -> "' . fc . '";')
        endif
      endfor
    endfor
    call add(output, '}')
    return output
  endfunc

  return vcg
endfunction

" finish
" test
let vcg = VimCallGraph()
call writefile(vcg.parse('sintax.vim'), 'sintax.dot')
