export inspect
local *
import concat, insert, remove from table

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

replace =
    '\n': '\\n'
    '\r': '\\r'
    '\t': '\\t'
    '\\': '\\\\'
    '\"': '\\\"'
    '\'': '\\\''

table.pack = (...)->
    {n:select('#',...),...}

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
        if @right.tag == 'Number'
            "#{T @left}[#{T @right}]"
        else
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
    'String', 'Number', 'Identifier', 'Table', 'BinaryExpression', 'Function', 'Call', 'Index', 'Escape', 'IndexB'
}}
isSimple = (ast)->
    simple[ast.tag]

extractVariable = (ast)->
    switch ast.tag
        when 'Assignment'
            ast.assignable
        else
            error "Could not extract variable from #{ast.tag}"

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

    Function: => {{
        tag: 'Function'
        args: @args
        body: S(@body)[1]
    }}

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

    Escape: => {@}

tree = {
    right: {
        right: 'C'
        left: 'B'
    }
    left: 'A'
}

isTable = =>
    type(@) == 'table'

FlipRecursiveTree = (tree, recursive, leaf, selector=isTable)->
    newTree = tree[leaf]
    previousNode = tree[recursive]

    while selector previousNode
        -- When assigning leaf and recursive are reversed
        newTree = {
            [leaf]: newTree
            [recursive]: previousNode[leaf]
        }
        previousNode = previousNode[recursive]

    return {
        [leaf]: newTree
        [recursive]: previousNode
    }

LoadAst = (ast, options={})->
    assert ast, "Ast must not be nil"
    func, err = loadstring T(S(ast)[1]), options.name

    if func
        if options.env
            setfenv func, options.env

    return func, err

DoAst = (ast, options={})->
    f, msg = LoadAst ast, options
    if not f
        print T(S(ast)[1])
        error msg
    f!

RightToLeftRecursiveTree = (tree, selector)->
    FlipRecursiveTree tree, 'right', 'left', selector

LeftToRightRecursiveTree = (tree, selector)->
    FlipRecursiveTree tree, 'left', 'right', selector

LeftChainToTree = (tag, chain, extract)->
    newTree = extract chain[1]

    for i=2,#chain
        newTree = {
            tag: tag
            left: newTree
            right: extract chain[i]
        }

    return {
        tag: tag
        left: newTree
    }

local escapeastfuncs

EscapeAst = =>
    switch type @
        when 'string'
            return { "\"#{escape @}\"", tag: 'String' }

        when 'number'
            return { @, tag: 'Number' }

        when 'table'
            if type(@) == 'table'
                f = escapeastfuncs[@tag] or escapeastfuncs.default
                f @
            else
                escapeastfuncs\default @

        else
            error 'Unable to parse type ' .. type @


escapeastfuncs =
    default: =>
        content = [EscapeAst v for v in *@]

        for k,v in pairs @
            if type(k) != 'number'
                insert content,
                    key: {
                        k
                        tag: 'Identifier'
                    }
                    value: EscapeAst v
                    tag: 'TableKeyValue'

        return {
            content: content
            tag: 'Table'
        }

    Splice: => @content

return {
    Standardize: S
    ToLua: T
    :LeftChainToTree
    :EscapeAst

    :DoAst
    :LoadAst
}
