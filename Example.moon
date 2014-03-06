import Any, BaseParser, Repeat, LeftRecursive, Optional, Not, Pattern, Sequence, Keyword, Token, Peek, EOF, INDENT, DEDENT from require 'parser.grammar.generator'
-- Export anything that begins with a capital letter
export ^

-- Major categories of parsers
Expression = Any {}     -- Anything that may return a result
Statement = Any {}      -- Anything that is allowed to be on its own
Assignable = Any {}     -- Anything that can be assigned to

---------------------------------------------------------------
-- Atoms ------------------------------------------------------
---------------------------------------------------------------
Identifier  = Pattern '[_%w][_%w%d]*',
    tag: 'Identifier'

Number      = Pattern '%d+',
    tag: 'Number'

String = Any {
    Pattern '".-"'
    Pattern '\'.-\''
},
    tag: 'String'

Block = Repeat Statement,
    tag: 'Block'

---------------------------------------------------------------
-- Assignment -------------------------------------------------
---------------------------------------------------------------
Assignment  = Sequence {Assignable, '=', Expression},
    tag: 'Assignment'
    builder: =>
        assignable, _, expr = unpack @
        {
            assignable: assignable
            expr: expr
        }

---------------------------------------------------------------
-- Binary Expressions -----------------------------------------
---------------------------------------------------------------
BinaryExpressionRHS = Any{}

BinaryOperator = Any {},
    tag: 'BinaryOperator'

BinaryExpression = Sequence {LeftRecursive(Expression), BinaryOperator, BinaryExpressionRHS},
    tag: 'BinaryExpression'
    builder: =>
        left, operator, right = unpack @
        {
            left: left
            operator: operator
            right: right
        }

BinaryExpressionRHS.add BinaryExpression
BinaryExpressionRHS.add Expression

---------------------------------------------------------------
-- Calling ----------------------------------------------------
---------------------------------------------------------------
Callable = Any {}

Call = Any {},
    tag: 'Call'

ExplicitCall = Any {},
    tag: 'Call'

Call.add Sequence {Callable, Repeat(Expression, separator: ',')},
    builder: =>
        name, expr = unpack @
        {
            name: name
            args: expr
        }

ExplicitCall.add Sequence {Callable, '(', Optional(Repeat(Expression, separator: ',')), ')'},
    builder: =>
        name, _, args = unpack @
        {
            name: name
            args: args
        }

---------------------------------------------------------------
-- Function Definition ----------------------------------------
---------------------------------------------------------------
Function = Any {}
FunctionParameter = Any {}

FunctionParameterList = Sequence {'(', Repeat(FunctionParameter, separator: ','), ')'},
    builder: =>
        _, args = unpack @
        return args

Function.add Sequence {Optional(FunctionParameterList), '->', '{', Block, '}'},
    tag: 'Function'
    builder: =>
        args, _, _, body = unpack @
        {
            args: args
            body: body
        }

FunctionParameter.add Identifier

---------------------------------------------------------------
-- Indexing ---------------------------------------------------
---------------------------------------------------------------
Indexable = Any {}
Index = Any {}
IndexWith = Any {}

Index.add Sequence {Indexable, '.', IndexWith},
    tag: 'Index'
    builder: =>
        left, _, right = unpack @
        {
            left: left
            right: right
        }

IndexWith.add Index
IndexWith.add Identifier

---------------------------------------------------------------
-- If ---------------------------------------------------------
---------------------------------------------------------------
If = Any {}

If.add Sequence {'if', Expression, '{', Block, '}'},
    tag: 'If'
    builder: =>
        _, condition, _, body = unpack @
        {
            condition: condition
            body: body
        }

---------------------------------------------------------------
-- Tables -----------------------------------------------------
---------------------------------------------------------------
TableContent = Any{}
TableKey = Any{}
TableValue = Any{}

TableKeyValue = Sequence {TableKey, ':', TableValue},
    tag: 'TableKeyValue'

    builder: =>
        key, _, value = unpack @

        {
            key: key
            value: value
        }

Table = Sequence {'{', Optional(Repeat(TableContent, separator: ',')), '}'},
    tag: 'Table'

    builder: =>
        _, content = unpack @

        {
            content: content
        }

TableKey.add    Identifier
TableValue.add  Expression
TableContent.add TableKeyValue
TableContent.add Expression

---------------------------------------------------------------
-- While ------------------------------------------------------
---------------------------------------------------------------
While = Any {}

While.add Sequence {'while', Expression, '{', Block, '}'},
    tag: 'While'
    builder: =>
        _, condition, _, body = unpack @
        {
            condition: condition
            body: body
        }

---------------------------------------------------------------
-- Set binary oeperator ---------------------------------------
---------------------------------------------------------------
BinaryOperator.add Any{
    '+'
    '-'
    '/'
    '*'
    '%'
    '..'
    '<'
    '>'
    '<='
    '>='
    '!='
    '=='
}

---------------------------------------------------------------
-- Set which groups a parser blongs to ------------------------
---------------------------------------------------------------
local A,C,E,S,X
A = => Assignable.add @
C = => Callable.add @
E = => Expression.add @
I = => Indexable.add @
S = => Statement.add @
__ = ->

__     E   S Assignment
__     E     BinaryExpression
__ A C E     Index
__     E   S ExplicitCall
__         S If
__         S While
__ A C E I   Identifier
__     E   S Call
__     E   S Function
__     E I   String
__     E I   Number
__     E I   Table

---------------------------------------------------------------
-- Comments ---------------------------------------------------
---------------------------------------------------------------
After = Any {}        -- A parser that is run anytime another parser fails to match a symbol
Before = Any {}        -- A parser that is run anytime another parser fails to match a symbol

-- Comments
After.add Sequence {'--[[', Repeat(Not(']]--')), ']]--'}
After.add Pattern'%-%-[^\r\n]+'

-- Setup the grammar to use INDENT/DEDENT
indentationLevel = {0}

-- Cleanup any other whitespace
After.add Pattern'[ \t]+' -- Whitespace
After.add Any {'\n','\r\n','\r'} -- Newline

-- The root parser
Root = Sequence{Block, EOF},
    builder: =>@[1]
