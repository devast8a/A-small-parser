import insert, remove from table

clone = => [v for v in *@]
-- TODO: This class is one of two abominations that drive this entire thing, it needs urgent attention
--  It does both what a root level parser should be doing and deals with stream level stuff
class Stream extends require 'parser.Linemap'
    length: 0
    pos: 1
    debug: false
    expecting: nil
    eof: false
    farestPos: 0
    lastParser: nil

    new: (@__source, @parser)=>
        super @__source
        @length = #@__source
        @stack = {}
        @tokenStack = {}
        @indentationLevel = {0}

    advanceTo: (@pos)=>
    advance: (count)=>@pos+=count

    isEOF: =>
        @pos >= @length

    -- How we unwind the parser state
    push: =>
        insert @stack, {
            pos: @pos
            debug: @debug
            expecting: @expecting
            eof: @eof
            tokenStack: @tokenStack
            indentationLevel: @indentationLevel
        }

    popContinue: =>
        state = remove @stack
        @popRest state

    popRest: (state)=>
        @debug = state.debug
        @expecting = state.expecting

    popRestore: =>
        state = remove @stack
        @pos = state.pos
        @eof = state.eof
        @tokenStack = state.tokenStack
        @lastParser = state.lastParser
        @indentationLevel = state.indentationLevel

        @popRest state

    currentParser: 0

    runBefore: =>
        res, ast = @parser.before.parse @
        return res, ast

    runAfter: =>
        res, ast = @parser.after.parse @
        return res, ast

    updateParserStat: =>
        if @pos > @farestPos
            @farestPos = @pos
            @farestParser = parser

    match: (parser)=>
        @runBefore!
        res, node = parser.parse @

        if res
            @updateParserStat!
            return res, node

        return if not @runAfter!

        return @match parser

    handleEOF: =>
        if @isEOF! and not @eof
            @pushToken {
                token: 'EOF'
            }
            @eof = true
        return @eof

    matchRegex: (pattern)=>
        return if @eof or #@tokenStack > 0
        return @__source.match pattern, @pos

    extract: (length)=>
        return if @eof or #@tokenStack > 0
        return @__source.sub @pos, @pos + length - 1

    peekToken: =>
        @tokenStack[#@tokenStack]

    pushToken: (token)=>
        @tokenStack = clone @tokenStack
        insert @tokenStack, token

    popToken: =>
        @tokenStack = clone @tokenStack
        remove @tokenStack, token
