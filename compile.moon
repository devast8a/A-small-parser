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
    moonscript = require 'moonscript.base'
    Stream = require 'parser.Stream'
    AstTools = require 'AstTools'

    -- Load the grammar
    func = assert moonscript\loadfile compilerName
    exported = {}
    exported._G = exported

    setfenv func, setmetatable exported,
        __index: _G
    func!

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
    stream.parser =
        after: LeftRecursive exported.After
        before: LeftRecursive exported.Before

    success,ast = stream.match exported.Root

    -- TODO: Write better error reporting
    if not success
        info = stream.getInfoFromOffset stream.farestPos

        for i = math\max(1, info.line-5), info.line-1
            print stream.getLine(i)

        print info.getContent!
        print (' ').rep(info.offsetToColumn(stream.farestPos) - 1) .. '^'

        line = info.line
        col = info.offsetToColumn stream.farestPos

        print "Parse error: input(#{line}:#{col})"

        -- What the parser was
        print "State:
    Longest: #{stream.farestParser}
    Last   : #{stream.lastParser}"

        -- State of the stack
        for v in *stream.tokenStack
            print v.token

        return
    else
        sast = AstTools\Standardize(ast)[1]
        lua = AstTools\ToLua sast

        print '------- Lua'
        print lua
        print '------- Output'
        assert(loadstring(lua))!

run!
