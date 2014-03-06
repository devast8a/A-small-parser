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
    require compilerName
    Stream = require 'parser.Stream'
    AstTools = require 'AstTools'

    -- Create a stream from the file
    file, msg = io\open fileName

    if not file
        print "Unable to open #{msg}"
        return

    stream = Stream file.read '*a'
    file.close!

    -- Set the tools up
    import LeftRecursive from require "parser.grammar.generator"

    stream.parser =
        after: LeftRecursive After
        before: LeftRecursive Before

    success,ast = stream.match Root

    -- TODO: Write better error reporting
    if not success
        line, col, pos = stream.getLineInfo stream.farestPos

        p = math\min stream.farestPos, 10
        area = stream.__source.sub(stream.farestPos - p, stream.farestPos + p * 2).gsub('[\r\t\n]',' ')

        text = "Parse error: input(#{line}:#{col})"
        padding = (' ').rep(#text+p+2)
        print "#{text} '#{area}'"

        -- The little cursor showing where the error occured
        print "#{padding}^"

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
