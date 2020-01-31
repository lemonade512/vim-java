setlocal foldmethod=expr
setlocal foldexpr=GetJavaFold(v:lnum)

function! IndentLevel(lnum)
    return indent(a:lnum) / &shiftwidth
endfunction

function! NextNonBlankLine(lnum)
    let numlines = line('$')
    let current = a:lnum + 1

    while current <= numlines
        if getline(current) =~? '\v\S'
            return current
        endif

        let current += 1
    endwhile

    return -2
endfunction

function! StartsClassOrEnum(lnum)
    return getline(a:lnum) =~? '\v(^|\s+)(class|enum)\s+'
endfunction

function! StartsFunction(lnum)
    let functionPattern = '\v^\s*[^=\(\.]+\('

    " Theoretically a function could have an annotation at the
    " beginning of the line, but I think that is unlikely enough that ignoring
    " that particular corner case won't be a huge issue.
    if getline(a:lnum) =~? '\v^\s*\@'
        return 0
    endif

    " If this line is a return statement, then this is not the start of a
    " function.
    if getline(a:lnum) =~? '\v^\s*return'
        return 0
    endif

    " If there is an '=' in the line before the first opening '(', we probably
    " aren't defining a function.
    if getline(a:lnum) =~? '\v[^\(]\='
        return 0
    endif

    " Should not fold while loops, if statements, etc.
    if getline(a:lnum) =~? '\v^\s*(if|while|for|case|switch|})'
        return 0
    endif

    " If the line ends with ';' it is unlikely to be a function
    if getline(a:lnum) =~? '\v.*;\s*$'
        return 0
    endif

    return getline(a:lnum) =~? functionPattern
endfunction

function! IsAnnotated(lnum)
    let startIndent = IndentLevel(a:lnum)
    let current = a:lnum - 1

    while current >= 1
        if !(getline(current) =~? '\v\S')
            return 0
        endif

        if IndentLevel(current) < startIndent
            return 0
        endif

        if IsAnnotation(current) || IsComment(current) || IsJavadoc(current)
            return 1
        endif

        let current -= 1
    endwhile

    return 0
endfunction

function! IsAnnotation(lnum)
    return getline(a:lnum) =~? '\v^\s*\@(\w|\.)+(\(.*\)?)?$'
endfunction

function! IsComment(lnum)
    return getline(a:lnum) =~? '\v^\s*//'
endfunction

function! IsJavadoc(lnum)
    return getline(a:lnum) =~? '\v^\s*/\*\*'
endfunction

" TODO (phillip): This should really be named
" EndsClassOrFunction
function! EndsClassOrFunction(lnum)
    " If this is not just a single '}', it doesn't end a block.
    if !(getline(a:lnum) =~? '\v^\s*}\s*$')
        return 0
    endif

    let startIndent = IndentLevel(a:lnum)
    let current = a:lnum - 1
    while current > 1
        if IndentLevel(current) <= startIndent && !(getline(current) =~? '\v^\s*$')
            break
        endif

        let current -= 1
    endwhile

    if StartsFunction(current) || StartsClassOrEnum(current)
        return 1
    endif

    return 0
endfunction

" I define 'attached' as a comment, javadoc, or annotation that is assocated
" with a function or class. By convention, this means it is at the same
" indentation as a function or class, and it is directly above that function
" or class, typically without blank lines in between.
function! AttatchedToFunctionOrClass(lnum)
    let numlines = line('$')
    let startIndent = IndentLevel(a:lnum)
    let current = a:lnum + 1

    while current <= numlines && IndentLevel(current) >= startIndent
        if StartsClassOrEnum(current) || StartsFunction(current)
            return 1
        endif
        let current += 1
    endwhile

    return 0
endfunction

" Pass in `1` as the second argument to enable verbose logging
function! GetJavaFold(lnum, ...)
    let verbose = get(a:, 1, 0)
    let blankLinePat = '\v^\s*$'
    let importPat = '\v^\s*import.*$'

    " All blank lines should take the lesser level from above/below
    if getline(a:lnum) =~? blankLinePat
        if verbose
            echom a:lnum . " is empty"
        endif

        " Make sure the last blank line in a file has a fold level of 0
        if a:lnum == line('$')
            return '0'
        endif
        return '-1'
    endif

    " Make sure you can fold import groups
    if getline(a:lnum) =~? importPat
        if verbose
            echom a:lnum . " is an import"
        endif

        if getline(a:lnum) == 1 || getline(a:lnum-1) =~? blankLinePat
            return '>' . (IndentLevel(a:lnum) + 1)
        else
            return IndentLevel(a:lnum) + 1
        endif
    endif

    if EndsClassOrFunction(a:lnum)
        if verbose
            echom a:lnum . " ends a class or function"
        endif

        return IndentLevel(a:lnum) + 1
    endif

    " Anything with an annotation above can just equal that annotation's fold
    if IsAnnotated(a:lnum)
        if verbose
            echom a:lnum . " is annotated"
        endif
        return '='
    endif

    if StartsClassOrEnum(a:lnum)
        if verbose
            echom a:lnum . " starts a class"
        endif

        return '>' . (IndentLevel(a:lnum) + 1)
    endif

    if IsAnnotation(a:lnum) || IsComment(a:lnum) || IsJavadoc(a:lnum)
        if verbose
            echom a:lnum . " is an annotation or comment"
        endif

        if AttatchedToFunctionOrClass(a:lnum)
            return '>' . (IndentLevel(a:lnum) + 1)
        endif

        return '='
    endif

    if StartsFunction(a:lnum)
        if verbose
            echom a:lnum . " starts a function"
        endif

        return '>' . (IndentLevel(a:lnum) + 1)
    endif

    " Statements should use fold above or below
    if getline(a:lnum) =~? '\v.*;\s*$'
        return -1
    endif

    if verbose
        echom a:lnum . " defaults to '='"
    endif
    return '='
endfunction
