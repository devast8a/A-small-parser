local *

run = ->
    if #arg != 2
        help!
        return
    compile arg[1], arg[2]

help = ->
    print "Compiler for FRUC"
    print "#{arg[0]} <compiler> <file>"

compile = (compilerName, fileName)->
    -- Include the tools to compile
    Stream = require 'parser.Stream'
    AstTools = require 'AstTools'

    local grammar

    -- Compile the grammar
    if compilerName.match '%.moon$'
        print 'Compiling grammar with moonscript'
        moonscript = require 'moonscript.base'
        grammar = assert moonscript\loadfile compilerName
    elseif compilerName.match '%.lua$'
        print 'Compiling grammar with lua'
        grammar = assert loadfile compilerName
    else
        error "Unable to find a way to compile #{compilerName}"

    exported = {}
    exported._G = exported

    setfenv grammar, setmetatable exported,
        __index: _G
    grammar!

    -- Create a stream from the file
    file, msg = io\open fileName

    if not file
        print "Unable to open #{msg}"
        return

    stream = Stream file.read '*a'
    file.close!

    -- Set the tools up
    import LeftRecursive from require "parser.grammar.generator"

    exported.stream = stream
    exported.parser = exported

    stream.parser =
        after: LeftRecursive exported.After
        before: LeftRecursive exported.Before

    stream.handleError = (text)=>
        info = stream.getInfoFromOffset stream.farestPos or stream.pos

        for i = math\max(1, info.line-5), info.line-1
            print stream.getLine(i)

        print info.getContent!
        print (' ').rep(info.offsetToColumn(stream.farestPos) - 1) .. '^'

        line = info.line
        col = info.offsetToColumn stream.farestPos

        print "input(#{line}:#{col}) #{text}"

        -- What the parser was
        print "State:
    Longest: #{stream.farestParser}
    Last   : #{stream.lastParser}"

        -- State of the stack
        for v in *stream.tokenStack
            print v.token


    start = os\clock!
    success,ast = stream.match exported.Root
    print "Parsing took: #{(os\clock! - start) * 1000}ms"

    -- TODO: Write better error reporting
    if not success
        stream.handleError 'Unable to match input'
        return
    else
        start = os\clock!
        sast = AstTools\Standardize(ast)[1]
        print "Ast rewriting took: #{(os\clock! - start) * 1000}ms"

        start = os\clock!
        lua = AstTools\ToLua sast
        print "Ast target conversion: #{(os\clock! - start) * 1000}ms"

        assert(loadstring(lua))!

run!
