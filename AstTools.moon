local *
import concat, insert, remove from table
moonscript = require'moonscript.base'

export inspect = (value, offset='', seen={})->
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

replace =
    '\n': '\\n'
    '\r': '\\r'
    '\t': '\\t'
    '\\': '\\\\'
    '\"': '\\\"'
    '\'': '\\\''

escape = (str)->
    for find,repl in pairs replace
        str = str.gsub find, repl
    return str

serialize = (input)->
    return switch type input
        when 'number'
            "#{input}"
        when 'string'
            "\"#{escape input}\""
        when 'table'
            content = for k,v in pairs input
                "[#{serialize k}]=#{serialize v}"
            '{' .. concat(content, ',') .. '}'
        else
            error 'Unable to serialize ' .. type input


-- Convert AST to lua
local nodes
T = (node)->
    f = nodes[node.tag]
    if not f
        print inspect node
        error "Could not find lua converter for #{node.tag}"
    f node

map = (func)=>
    [func v for v in *@]

nodes =
    String: => @[1]
    Number: => @[1]
    Identifier: => @[1]
    Ignore: => ""

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
        switch @[1]
            when '!='
                '~='
            else
                @[1]

    BinaryExpression: =>
        "(#{T @left} #{T @operator} #{T @right})\n"

    Index: =>
        "#{T @left}.#{T @right}"

    Table: =>
        content = concat map(@content, T), ','
        "{#{content}}"

    TableKeyValue: =>
        "#{T @key}=#{T @value}"

    If: =>
        "if #{T @condition} then #{T @body} end\n"

    While: =>
        "while #{T @condition} do #{T @body} end\n"

    Escape: =>
        serialize @content

    IndexB: =>
        "#{T @left}[#{T @right}]"

-- Convert the AST to be standard form
-- eg.
local standardForm
S = (node)->
    f = standardForm[node.tag]
    if not f
        print inspect node
        error "Could not find standardizer for #{node.tag}"
    f node

reduce = =>
    output = {}
    for t in *@
        for v in *t
            insert output, v
    return output

simple = {key, true for key in *{
    'String', 'Number', 'Identifier', 'Table', 'BinaryExpression', 'Function', 'Call'
}}
isSimple = (ast)->
    simple[ast.tag]

extractVariable = (ast)->
    switch ast.tag
        when 'Assignment'
            ast.assignable
        else
            error 'Could not extract variable from ' .. ast.tag

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

    IndexB: =>
        return {@}

    If: =>
        ins = S @condition
        last = ins[#ins]
        ins[#ins] = nil

        if not isSimple last
            insert ins, last
            last = extractVariable last

        insert ins, {
            tag: 'If'
            body: @body
            condition: last
        }
        return ins

    While: =>
        local condition
        ins = S @condition
        last = ins[#ins]
        ins = [ins[i] for i=1,#ins-1]

        if last.tag == 'Assignment'
            insert ins, last
            condition = last.assignable
        else
            condition = last

        body = reduce S @body
        body.tag = 'Block'

        for i=1,#ins
            insert body, ins[i]

        insert ins, {
            tag: 'While'
            body: body
            condition: condition
        }
        return ins

    Call: =>
        args = {}
        ins = {}

        if @self
            insert args, @self

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

        ins = S @expr
        last = ins[#ins]
        ins = [ins[i] for i=1,#ins-1]

        if not isSimple last
            insert ins, last
            expr = extractVariable last

        insert ins, {
            tag: 'Assignment'
            assignable: assignable[1]
            expr: last
        }
        ins

    Block: =>
        block = reduce map @, S
        block.tag = 'Block'
        return {block}

    Table: => {@}

DoAst = (ast, env, ...)=>
    assert ast
    assert env

    lua = T ast
    --print lua
    f = assert loadstring lua
    setfenv f, env
    f ...

LeftChainToTree = (tag, chain, extract)=>
    previous = {
        tag: tag
        left: extract chain[1]
    }

    length = #chain

    if length == 1
        return previous

    previous.right = extract chain[2]

    for i=3,#chain
        previous = {
            tag: 'Index'
            left: previous
            right: extract chain[3]
        }

    return {
        tag: tag
        left: previous
    }

return {
    Standardize: S
    ToLua: T
    LeftChainToTree: LeftChainToTree
    EscapeAst: (ast)=>
        {
            tag: 'Escape'
            content: ast
        }
    :DoAst
}
