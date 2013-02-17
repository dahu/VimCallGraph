
let erex = extended_regex#ExtendedRegex('SinLookup')
function! SinLookup(name)
  " echo 'looking up ''' . a:name . ''''
  return get(s:p, a:name)
endfunction

let s:p                   = {}
let s:p.word              = '\%(\s*\(\h\w\+\)\s*\)'
let s:p.optword           = s:p.word . '\?'
let s:p.inline_pattern    = '\%(:\(.*\)\)\?'
let s:p.sintax_group_name = s:p.word
let s:p.highlight         = '\%(\.' . s:p.word . '\)\?'
let s:p.sinargs           = '\([^:]*\)'
let s:p.sintax_args       = s:p.sintax_group_name . s:p.highlight . s:p.sinargs
                          \ . s:p.inline_pattern
let s:p.name_line         = '^name\s\+' . s:p.word
let s:p.case_line         = '^case\s\+' . s:p.word
let s:p.spell_line        = '^spell\s\+' . s:p.word
let s:p.keyword_line      = '^keyword\s\+' . s:p.sintax_args
let s:p.partial_line      = '^partial\s\+' . s:p.sintax_group_name . '\s*' . s:p.inline_pattern
let s:p.match_line        = '^match\s\+' . s:p.sintax_args
let s:p.region_args       = s:p.sintax_group_name . s:p.highlight . s:p.sinargs
let s:p.region_line       = '^region\s\+' . s:p.region_args
let s:p.start_line        = '^start\s*' . s:p.inline_pattern
let s:p.skip_line         = '^skip\s*' . s:p.inline_pattern
let s:p.end_line          = '^end\s*' . s:p.inline_pattern

function! Sintax(...)
  let sin = {}
  " when enabled, 'document' generates output with pre- and post-amble
  let sin.options = {'document' : 1}
  let sin.out = []
  let sin.highlights = []
  let sin.patterns = {}
  let sin.sinline = []
  let sin.in_region = 0
  let sin.region = {'start': 0, 'skip': 0, 'end': 0}
  let sin.region.parts = ['start', 'skip', 'end']
  let sin.preamble = join([
        \  '',
        \ '" Quit when a (custom) syntax file was already loaded',
        \ 'if exists("b:current_syntax")',
        \ '  finish',
        \ 'endif',
        \ '',
        \ '" Allow use of line continuation.',
        \ 'let s:save_cpo = &cpo',
        \ 'set cpo&vim',
        \ ''], "\n")
  let sin.postamble = join([
        \  'let b:current_syntax = "%name"',
        \ '',
        \ 'let &cpo = s:save_cpo',
        \ 'unlet s:save_cpo',
        \ '',
        \ '" vim: set sw=2 sts=2 et fdm=marker:'], "\n")

  func sin.append_preamble()
    if self.options.document
      call extend(self.out, [self.preamble])
    endif
  endfunc

  func sin.lookup(name) dict
    " echo 'looking up name="' . a:name . '", value="' . get(self.patterns, a:name) . '"'
    return get(self.patterns, a:name)
  endfunc

  let sin.erex = extended_regex#ExtendedRegex(eval('sin.lookup'), sin)

  func sin.prepare_output() dict
    let self.out = []
  endfunc

  func sin.passthrough(line) dict
    call self.prepare_sintax_line()
    call extend(self.out, [a:line])
  endfunc

  func sin.matches(string, pattern_name) dict
    return match(a:string, SinLookup(a:pattern_name)) != -1
  endfunc

  func sin.is_sin_line(line) dict
    let matched = 0
    let tokens = ['name', 'case', 'spell', 'keyword', 'partial', 'match', 'region']
    if self.in_region
      " Add the extra commands
      let tokens = self.region.parts + tokens
    endif
    for t in tokens
      if self.matches(a:line, t . '_line')
        let matched = 1
        break
      endif
    endfor
    return matched
  endfunc

  func sin.is_blank_or_comment(line)
    return a:line =~ '^\s*\("\|$\)'
  endfunc

  func sin.is_region_part(line)
    return index(self.region.parts, matchstr(a:line, '^\w\+')) > -1
  endfunc

  func sin.region_append(str)
    " Find the last syntax region
    let i = (match(reverse(copy(self.out)), '^syntax region') * -1) -1
    " now append the piece.
    let self.out[i] .= substitute(a:str, '\s*$', '', '')
  endfunc

  func sin.parse(file, ...) dict
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
      " pass through blank & comment lines (header)
      if self.is_blank_or_comment(line)
        if line != ''
          call self.passthrough(line)
        endif
      else
        break
      endif
      let self.curline += 1
    endwhile
    call self.append_preamble()
    while self.curline < self.eof
      let line = self.input[self.curline]
      " pass through blank, comment and explicit vim lines
      if self.is_blank_or_comment(line) || (! self.is_sin_line(line))
        if line != ''
          call self.passthrough(line)
        endif
        let self.curline += 1
        continue
      else
        call self.process(line)
      endif
    endwhile
    return self.output()
  endfunc

  func sin.warn(msg) dict
    echohl Warning
    echo "Warning: " . a:msg
    echohl None
  endfunc

  func sin.process_name(line) dict
    let [_, name ;__] = matchlist(join(a:line), SinLookup('name_line'))
    let self.postamble = substitute(self.postamble, '%name', name, 'g')
    return []
  endfunc

  func sin.process_case(line) dict
    let [_, case ;__] = matchlist(join(a:line), SinLookup('case_line'))
    if case !~# 'match\|ignore'
      call self.warn("Unknown 'case' argument : " . case)
    endif
    return ['syntax case ' . case]
  endfunc

  func sin.process_spell(line) dict
    let [_, spell ;__] = matchlist(join(a:line), SinLookup('spell_line'))
    if spell !~# 'toplevel\|notoplevel\|default'
      call self.warn("Unknown 'spell' argument : " . case)
    endif
    return ['syntax spell ' . spell]
  endfunc

  func sin.process_sinargs(line) dict
    let [_, _, name, highlight, args, pattern ;__] = matchlist(join(a:line), '^\(\w\+\)' . SinLookup('sintax_args'))
    let pattern = escape(self.erex.parse(pattern), '/')
    return [name, highlight, args, pattern]
  endfunc

  func sin.highlight(name, link) dict
    if a:link != ''
      call extend(self.highlights, ['hi def link ' . a:name . ' ' . a:link])
    endif
  endfunc

  func sin.process_keyword(line) dict
    let [_, _, name, highlight, args, pattern ;__] = matchlist(join(a:line), '^\(\w\+\)' . SinLookup('sintax_args'))
    call self.highlight(name, highlight)
    return ['syntax keyword ' . join([name, pattern, args], ' ')]
  endfunc

  func sin.process_partial(line) dict
    let [_, name, pattern ;__] = matchlist(join(a:line), SinLookup('partial_line'))
    let pattern = escape(self.erex.parse(pattern), '/')
    let self.patterns[name] = pattern
    return []
  endfunc

  func sin.process_match(line) dict
    let [name, highlight, args, pattern] = self.process_sinargs(a:line)
    call self.highlight(name, highlight)
    let self.patterns[name] = pattern
    return ['syntax match ' . name . ' /' . pattern . '/ ' . args]
  endfunc

  func sin.process_region(line) dict
    " No pattern here
    let [_, name, highlight, args; __] = matchlist(a:line, SinLookup('region_line'))
    call self.highlight(name, highlight)
    let self.region.args = args
    return ['syntax region ' . name]
  endfunc

  func sin.process_region_pat(name, line)
    let self.region[a:name] += 1
    let [_, pattern; __] = matchlist(join(a:line), SinLookup(a:name . '_line'))
    let pattern = escape(self.erex.parse(pattern), '/')
    return ' ' . a:name . '=/' . pattern . '/'
  endfunc

  func sin.process_start(line)
    return self.process_region_pat('start', a:line)
  endfunc

  func sin.process_skip(line)
    return self.process_region_pat('skip', a:line)
  endfunc

  func sin.process_end(line)
    return self.process_region_pat('end', a:line)
  endfunc

  func sin.process_sintax_block()
    let type = matchstr(self.sinline[0], '^\w\+')
    return call(eval('self.process_' . type), [self.sinline], self)
  endfunc

  func sin.flush_old_sintax_line()
    let output = self.process_sintax_block()
    if empty(output)
      return
    endif
    if self.in_region > 1
      call self.region_append(output)
    else
      call add(self.out, substitute(get(output, 0, ''), '\s*$', '', ''))
    endif
  endfunc

  func sin.prepare_sintax_line() dict
    call self.flush_old_sintax_line()
    let self.sinline = []
  endfunc

  func sin.append_sintax(line) dict
    call extend(self.sinline, [a:line])
  endfunc

  func sin.close_region()
    let self.in_region = 0
    if self.region.start == 0
      call self.warn('SinTax: There must be at least one "start" pattern.')
    elseif self.region.skip > 1
      call self.warn('SinTax: Only one optional "skip" pattern is allowed.')
    elseif self.region.end == 0
      call self.warn('SinTax: There must be at least one "end" pattern.')
    endif
    call self.region_append(' ' . remove(self.region, 'args'))
    let self.region.start = 0
    let self.region.skip = 0
    let self.region.end = 0
  endfunc

  " process a (single or multiline) sintax block
  func sin.process(line) dict
    call self.prepare_sintax_line()
    " non multiline patterns must be flush to first column
    let line = a:line
    if self.in_region && ! self.is_region_part(line)
      " the region commands are over
      call self.close_region()
    elseif self.in_region
      " Still mor region commands
      let self.in_region += 1
    endif
    if self.matches(line, 'region_line')
      " region commands start.
      let self.in_region = 1
    endif
    " TODO: ensure comment lines don't interfere
    while self.curline < self.eof
      " return to outer level parser on blank or comment-only lines
      if self.is_blank_or_comment(line)
        break
      endif
      call self.append_sintax(line)
      " are we still in the same sintax block?
      let self.curline += 1
      if self.curline >= self.eof
        break
      endif
      let line = self.input[self.curline]
      " return to outer level parser if input is back at the left edge
      if line =~ '^\S'
        break
      endif
    endwhile
  endfunc

  func sin.output() dict
    call self.flush_old_sintax_line()
    if has_key(self.region, 'args')
      call self.region_append(' ' . remove(self.region, 'args'))
    endif
    let inner = join(self.out, "\n")
    let highlights = join(self.highlights, "\n")
    if self.options.document
      let output = join([inner, highlights, self.postamble], "\n\n")
    else
      let output = join([inner, highlights], "\n\n")
    endif
    return output
  endfunc

  " process constructor

  return sin
endfunc

finish
" test
let sinner = Sintax()
call writefile(split(sinner.parse('vrs.sintax', {'document' : 0}), "\n"), 'vrs-syntax.vim')
let sinner = Sintax()
call writefile(split(sinner.parse('syn-region.txt'), "\n"), 'syn-region.vim')
