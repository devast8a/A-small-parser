local *
import insert, remove from table

Stream = require 'parser.Stream'

replace = {
    '\n': '\\n'
    '\r': '\\r'
    '\t': '\\t'
}
escape = =>
    @gsub '([\n\t\r])', =>
        replace[@]

-- Helper method that acts as nice syntax for creating parsers in grammar files
--  Used by parsers on parameters they take
toParser = (input)->
    if type(input) == 'table' and input.isParser
        input
    else if type(input) == 'string'
        if input.sub(1,1) == '/'
            Pattern input.sub(2,-2)
        else
            Keyword input
    else
        error 'Unable to turn input into a parser'

-- Helper method that acts as nice syntax for creating parsers in grammar files
--  Used by parsers on parameters they take
toParserTable = (table)->
    -- Passing in nil should throw an error
    max = 0
    for k,v in pairs table
        max = math\max k, max

    [toParser table[i] for i = 1, max]

-- The base class for all parsers
-- TODO: This class is one of two abominations that drive this entire thing, it needs urgent attention
class BaseParser
    new: (options={})=>
        @builder = options.builder
        @tag = options.tag
        @debug = options.debug
        @replaceWith = options.replaceWith

    isParser: true

    -- The abomination that gets the damned thing to run
    -- See todo.txt for what needs to be changed
    parse: (stream)=>
        if @debug != nil
            stream.debug = @debug

        -- Emits the EOF token if EOF has been reached
        stream.handleEOF!

        -- How we can handle rudimentry backtracking and peeking
        -- See Stream
        stream.push!

        print "> #{@}" if stream.debug

        -- Actually execute the parser
        res, ast = @exec stream

        if res
            stream.lastParser = @

            if @builder
                ast = @\builder ast, stream

                -- TODO: Improve the API or remove the ability for builders to manipulate the parser
                if ast == 'FAIL'
                    stream.popRestore!
                    return false

                ast = ast or {
                    tag: 'Ignore'
                }

            if @tag
                ast.tag = @tag

            -- Replaces the matched sequence with a token
            if @replaceWith
                stream.pushToken @replaceWith

            print "< C #{@}" if stream.debug
            stream.popContinue!
        else
            print "< R #{@}" if stream.debug
            stream.popRestore!

        return res, ast

    exec: =>
        error 'You must implement "exec" in child classes'

    parseString: (string)=>
        parser = {
            before: Any {}
            after: Any {}
        }
        Stream(string, parser).match @

-- Match against a specific piece of text
class Keyword extends BaseParser
    new: (@name)=>
        @length = #@name

    exec: (stream)=>
        if stream.extract(@length) == @name
            -- Move the stream offset @length characters
            stream.advance @length

            return true, {
                @name
            }

    __tostring: =>
        "#{@@__name} #{escape @name}"

class Any extends BaseParser
    new: (parsers, options)=>
        super options
        @parsers = toParserTable parsers

    exec: (stream)=>
        for parser in *@parsers
            res,node = stream.match parser

            if res
                return res,node

    add: (parser)=>
        parser = toParser parser
        insert @parsers, parser
        return parser

    insert: (parser, offset)=>
        parser = toParser parser
        insert @parsers, offset, parser
        return parser

    __tostring: =>
        "#{@@__name} #{@tag}"

class Sequence extends BaseParser
    new: (parsers, options)=>
        super options
        @parsers = toParserTable parsers

    exec: (stream)=>
        -- Assign to a temporary variable
        --  The for loop will otherwise get encapsulated in a function
        --  and returns inside the loop will not work
        output = for i= 1,#@parsers
            if i < #@parsers
                stream.expecting = @parsers[i+1]

            res,node = stream.match @parsers[i]

            if not res
                return

            node

        return true, output

    __tostring: =>
        "#{@@__name} #{@tag}"


class Repeat extends BaseParser
    new: (item, options = {})=>
        @item = toParser item
        super options

        if options.separator
            @separator = toParser options.separator

    exec: (stream)=>
        if @separator
            res,node = stream.match @item
            if not res
                return
            output = {node}

            while true
                if not stream.match @separator
                    break

                res,node = stream.match @item
                if res
                    insert output, node
                else
                    -- Parse error
                    print 'Parser error'

            return true, output
        else
            output = while true
                res,node = stream.match @item
                if res
                    node
                else
                    break
            return #output > 0, output

    __tostring: =>
        "#{@@__name} #{@tag}"

-- Use lua pattern to match input
class Pattern extends BaseParser
    new: (pattern, options)=>
        super options
        @pattern = "^(#{pattern})"

    exec: (stream)=>
        content = {stream.matchRegex @pattern}

        if #content > 0
            stream.advance #content[1]
            return true, content

    __tostring: =>
        "Pattern #{@tag or escape @pattern}"

-- Hacky method of avoding left recursion, look into a better way of doing it
class LeftRecursive extends BaseParser
    new: (parser, options)=>
        super options
        @parser = toParser parser

    exec: (stream)=>
        return if @LOCKED
        @LOCKED = true
        res, ast = stream.match @parser
        @LOCKED = false
        return res, ast

    __tostring: => "#{@@__name} #{@parser}"

-- Tries matching with the given parser and return a successful result
--  or return an empty result
class Optional extends BaseParser
    new: (parser)=>
        @parser = toParser parser

    exec: (stream)=>
        res, ast = stream.match @parser
        if not res
            return true, {
                tag: 'Ignore'
            }
        return res, ast

    __tostring: => "#{@@__name} #{@parser}"

--TODO: Not is kind of slow, especially in the common usecase of it
class Not extends BaseParser
    new: (...)=>
        @parsers = toParserTable {...}

    exec: (stream)=>
        for parser in *@parsers
            stream.push!
            res, ast = stream.match parser
            stream.popRestore!

            if res
                return nil

        stream.advance 1
        return true, {
            tag: 'Ignore'
        }

    __tostring: =>
        parsers = table\concat ["(#{parser})" for parser in *@parsers], ','
        "#{@@__name} #{parsers}"

-- Peek takes a parser and will still match the input but not advance the stream offsets
class Peek extends BaseParser
    new: (parser, options)=>
        super options
        @parser = toParser parser

    exec: (stream)=>
        stream.push!
        res, ast = stream.match @parser
        stream.popRestore!

        if res
            return true, {
                tag: 'Ignore'
            }
        return nil, {
            tag: 'Ignore'
        }

    __tostring: => "#{@@__name} #{@parser}"

class On extends BaseParser
    new: (@parserName, options)=>
        super options

    exec: (stream)=>
        if stream.lastParser and stream.lastParser.tag
            return stream.lastParser.tag == @parserName

-- Match a token
class Token extends BaseParser
    new: (matcher, options)=>
        super options
        @name = matcher

        if type(matcher)=='string'
            @matcher = (token)->
                token.token == matcher
        else
            @matcher = matcher

    exec: (stream)=>
        token = stream.peekToken!

        if token
            if @\matcher token
                return true, stream.popToken!

    __tostring: =>
        "#{@@__name} #{@name}"

return {
    :Any
    :BaseParser
    :LeftRecursive
    :Optional
    :On
    :Not
    :Pattern
    :Peek
    :Repeat
    :Sequence
    :Token
    :Keyword

    -- Token matchers
    EOF: Token 'EOF'
    INDENT: Token 'INDENT'
    DEDENT: Token 'DEDENT'

    -- Quick token creation function
    T: (tokenName)->
        {
            token: tokenName
        }
}
