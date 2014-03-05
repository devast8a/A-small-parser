import insert, remove from table
clone = =>
    [v for v in *@]

-- TODO: This class is one of two abominations that drive this entire thing, it needs urgent attention
class Stream
    length: 0
    pos: 1
    debug: false
    expecting: nil
    eof: false

    new: (@__source, @parser)=>
        @length = #@__source
        @stack = {}
        @tokenStack = {}

    advanceTo: (@pos)=>
    advance: (count)=>@pos+=count

    isEOF: =>
        @pos >= @length

    push: =>
        insert @stack, {
            pos: @pos
            debug: @debug
            expecting: @expecting
            eof: @eof
            tokenStack: @tokenStack
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

        @popRest state

    match: (parser)=>
        res, node = parser.parse @

        if res
            return res, node

        return if @inAny

        @inAny = true
        res = @parser.any.parse @

        @inAny = false

        if not res
            return

        return @match parser

    handleEOF: =>
        if @isEOF! and not @eof
            @pushToken {
                token: 'EOF'
            }
            @eof = true
        return @eof

    matchRegex: (pattern)=>
        if @eof or #@tokenStack > 0
            return

        return @__source.match pattern, @pos

    extract: (length)=>
        if @eof or #@tokenStack > 0
            return

        return @__source.sub @pos, @pos + length - 1

    peekToken: =>
        @tokenStack[#@tokenStack]

    pushToken: (token)=>
        @tokenStack = clone @tokenStack
        insert @tokenStack, token

    popToken: =>
        @tokenStack = clone @tokenStack
        remove @tokenStack, token
