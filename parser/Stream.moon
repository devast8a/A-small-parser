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
    currentParser: 0

    lastAfter: -1
    lastBefore: -1
    stateNumber: 0
    inMetaquote: false

    new: (@__source, @parser)=>
        super @__source
        @length = #@__source
        @stack = {}
        @tokenStack = {}
        @indentationLevel = {0}

    advanceTo: (@pos)=>
        @stateNumber+=1
    advance: (count)=>
        @pos+=count
        @stateNumber+=1

    isEOF: =>
        @pos >= @length

    -- How we unwind the parser state
    push: =>
        insert @stack, {
            stateNumber: @stateNumber
            pos: @pos
            debug: @debug
            expecting: @expecting
            eof: @eof
            tokenStack: @tokenStack
            indentationLevel: @indentationLevel
            lastAfter: @lastAfter
            lastBefore: @lastBefore
            thisParser: @thisParser
            inMetaquote: @inMetaquote
        }

    popContinue: =>
        state = remove @stack
        @popRest state

    popRest: (state)=>
        @debug = state.debug
        @expecting = state.expecting
        @thisParser = state.thisParser

    popRestore: =>
        state = remove @stack
        @pos = state.pos
        @eof = state.eof
        @tokenStack = state.tokenStack
        @lastParser = state.lastParser
        @indentationLevel = state.indentationLevel
        @stateNumber = state.stateNumber
        @lastAfter = state.lastAfter
        @lastBefore = state.lastBefore
        @inMetaquote = state.inMetaquote

        @popRest state

    currentParser: 0

    doDebug: =>
        -- Go through the stack
        offset = ''
        for v in *@stack
            print "#{offset}#{v.thisParser}"
            offset ..= '  '

        -- get current line info
        info = @getInfoFromOffset @pos
        print "State/B/A: #{@stateNumber}/#{@lastBefore}/#{@lastAfter} Current: #{@currentParser}"
        print "Line: #{info.line} Col: #{info.offsetToColumn @pos} Off: #{@pos}"

        print 'Input:'
        print info.getContent!
        print (" ").rep(info.offsetToColumn(@pos) - 1) .. '^'

        if #@tokenStack > 0
            print 'Tokens: '
            for v in *@tokenStack
                print '    ' .. v.token

        io\read!
        print '------------------------------'

    runBefore: =>
        return if @currentParser != 0
        return if @lastBefore == @stateNumber
        @lastBefore = @stateNumber
        @currentParser = 1
        res, ast = @parser.before.parse @
        @currentParser = 0
        return res, ast
    
    runAfter: =>
        return if @currentParser != 0
        return if @lastAfter == @stateNumber
        @lastAfter = @stateNumber
        @currentParser = 2
        @stateNumber
        res, ast = @parser.after.parse @
        @currentParser = 0
        return res, ast

    updateParserStat: =>
        if @pos > @farestPos and @currentParser == 0
            @farestPos = @pos
            @farestParser = parser

    match: (parser)=>
        @runBefore!
        @thisParser = parser
        res, node = parser.parse @

        if res
            @updateParserStat!
            return res, node

        return false if not @runAfter!

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
        @stateNumber+=1
        @tokenStack = clone @tokenStack
        insert @tokenStack, token

    popToken: =>
        @stateNumber+=1
        @tokenStack = clone @tokenStack
        remove @tokenStack, token
