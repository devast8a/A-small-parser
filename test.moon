local *
import insert, remove from table
moonscript = require'moonscript.base'

inspect = (value, offset='', seen={})->
    seen[0] = 0 if not seen[0]

    return seen[value] if seen[value]

    switch type(value)
        when 'table'
            seen[0] += 1
            n = 'Table: ' .. seen[0]
            seen[value] = n

            str = "{\n"

            for k, v in pairs value
                str ..= "#{offset}  #{k}: #{inspect(v, offset .. '  ', seen)}\n"
            str ..= "#{offset}}"
            return str
        else
            return value

import Any, BaseParser, List, Pattern, Sequence from require "parser.grammar.generator"
require 'Grammar'
Stream = require 'parser.Stream'

-- Convert AST to lua
local nodes
T = (node)->
    f = nodes[node.tag]
    if not f
        error "Could not find lua converter for #{node.tag}"
    f node

concat = table.concat

map = (func)=>
    [func v for v in *@]

nodes =
    String: => @[1]
    Number: => @[1]
    Identifier: => @[1]
    Ignore: =>

    Function: =>
        args = concat map(@args, T), ','
        "function(#{args})\n#{T @body}end\n"

    Call: =>
        args = concat map(@args, T), ','
        "#{T @name}(#{args})\n"

    Block: =>
        concat map @, T

    Assignment: =>
        "#{T @assignable} = #{T @expr}\n"

    BinaryOperator: =>
        @[1]

    BinaryExpression: =>
        "#{T @left} #{T @operator} #{T @right}\n"

    Index: =>
        "#{T @left}.#{T @right}"

    Table: =>
        content = concat map(@content, T), ','
        "{#{content}}"

    TableKeyValue: =>
        "#{T @key}=#{T @value}"

-- Convert the AST to be standard form
-- eg.
local standardForm
S = (node)->
    f = standardForm[node.tag]
    if not f
        error "Could not find standardizer for #{node.tag}"
    f node

reduce = =>
    output = {}
    for t in *@
        for v in *t
            insert output, v
    return output

standardForm =
    String: => {@}
    Number: => {@}
    Identifier: => {@}
    Ignore: => {}

    BinaryExpression: =>
        return {{
            left: @left
            right: @right
            operator: @operator
            tag: 'BinaryExpression'
        }}

    Index: =>
        return {@}

    Call: =>
        args = {}
        ins = {}

        for arg in *@args
            arg = S arg

            last = arg[#arg]

            for i=1,#arg-1
                insert ins, arg[i]

            if last.tag == 'Assignment'
                insert ins, last
                insert args, {
                    tag: 'Identifier',
                    last.assignable[1]
                }
            else
                insert args, last

        insert ins, {
            tag: 'Call'
            name: @name
            args: args
        }

        return ins

    Function: => {@}

    Assignment: =>
        assignable = S @assignable
        expr = S @expr

        {{
            tag: 'Assignment'
            assignable: assignable[1]
            expr: expr[1]
        }}

    Block: =>
        block = reduce map @, S
        block.tag = 'Block'
        return {block}

    Table: => {@}

f = io\open 'test.txt'
stream = Stream f.read'*a'
f.close!

p =
    -- Match ~*~*ANYWHERE*~*~
    any: Anytime
stream.parser = p
success,ast = Root.parse stream
if not success
    print 'Failed to parse input!'

print '-- AST --'
--print inspect ast
print '-- Slightly more standard form --'
sast = S(ast)[1]
--print inspect sast
print '-- LUA --'
print T sast

print '-- OUTPUT --'
assert(loadstring(T sast))!
