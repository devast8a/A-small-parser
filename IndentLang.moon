-- Export anything that begins with a capital letter
AstTools = require 'AstTools'
export ^
import INDENT, DEDENT, Any, On, Run, BaseParser, Repeat, LeftRecursive, Optional, Not, Pattern, Sequence, Keyword, Token, Peek, EOF, T from require 'parser.grammar.generator'
NEWLINE = Token 'NEWLINE'

Expression = Any {}     -- Anything that may return a result
Statement = Any {}      -- Anything that is allowed to be on its own
Assignable = Any {}     -- Anything that can be assigned to
DotIndexable = Any {}   -- Anything that can be on the left hand side of a dot index expression

Block = Any {},
    tag: 'Block'

Block.add Sequence {INDENT, Repeat(Statement), DEDENT},
    builder: =>
        @[2]

Newline = Keyword '\n'
SpaceTab = Pattern '[ \t]+'
EmptyLine = Sequence {Newline, Optional(SpaceTab), Peek Newline}
LuaComment = Pattern '%-%-[^\r\n]+'
LuaBlockComment = Sequence {'--[[', Repeat(Not(']]')), ']]'}

DotIndexChain = Any {}

--------------------------------------------------
-- Atoms -----------------------------------------
--------------------------------------------------
String = Any {
    Pattern '".-"'
    Pattern '\'.-\''
},
    tag: 'String'

Number = Pattern '[0-9]+',
    tag: 'Number'

Identifier  = Pattern '[_a-zA-Z][_a-zA-Z0-9]*',
    tag: 'Identifier'

--------------------------------------------------
-- Assignment ------------------------------------
--------------------------------------------------
Assignment = Any{},
    tag: 'Assignment'

Assignment.add Sequence{Assignable, '=', Expression},
    builder: =>
        assignable, _, expression = unpack @
        {
            assignable: assignable
            expr: expression
        }

--------------------------------------------------
-- Binary Expression -----------------------------
--------------------------------------------------
BinaryOperator = Any{},
    tag: 'BinaryOperator'

BinaryExpression = Sequence {LeftRecursive(Expression), BinaryOperator, Expression},
    tag: 'BinaryExpression'
    builder: =>
        left, operator, right = unpack @
        {
            left: left
            operator: operator
            right: right
        }

BinaryOperator.add Any{
    '+'
    '-'
    Keyword '/'
    '*'
    '%'
    '..'
    '>'
    '<'
    '>='
    '<='
    '=='
    '!='
}

--------------------------------------------------
-- Bracket Indexing ------------------------------
--------------------------------------------------
BracketIndexable = Any {}

BracketIndex = Sequence {BracketIndexable, '[', Expression, ']'},
    tag: 'IndexB'
    builder: =>
        {
            left: @[1]
            right: @[3]
        }

--------------------------------------------------
-- Brackets - Order of Operations ----------------
--------------------------------------------------
BracketedExpression = Sequence {'(', Expression, ')'},
    builder: =>
        @[2]

--------------------------------------------------
-- Calling ---------------------------------------
--------------------------------------------------
Call = Any {},
    tag: 'Call'
Callable = Any {}
CallArgument = Any {}
CallArgumentList = Any {}
CallArgumentSeparator = Any {}

CallArgumentList.add Sequence{'(', Repeat(CallArgument, separator: CallArgumentSeparator), ')'},
    builder: =>
        return @[2]
CallArgumentList.add Repeat(CallArgument, separator: CallArgumentSeparator)

Call.add Sequence {Optional(DotIndexChain), Identifier, CallArgumentList},
    builder: =>
        chain, tail, args = unpack @

        if chain.tag != 'Ignore'
            chain = AstTools\LeftChainToTree 'Index', chain, (item)->
                item[1]
            chain.right = tail

            return {
                self: chain.left
                args: args
                name: chain
            }
        else
            return {
                args: args
                name: tail
            }

Call.add Sequence {Identifier, '::', Identifier, CallArgumentList},
    builder: =>
        {
            name: {
                tag: 'Index'
                left: @[1]
                right: @[3]
            }
            args: @[4]
        }

Call.add Sequence {Callable, '!'},
    builder: =>
        name = unpack @
        {
            args: {tag: 'Ignore'}
            name: name
        }

CallArgument.add Expression
CallArgumentSeparator.add Keyword ','

--------------------------------------------------
-- Dot Indexing ----------------------------------
--------------------------------------------------
DotIndex = Any {},
    tag: 'Index'

DotIndexWith = Any {}

DotIndex.add Sequence {DotIndexChain, DotIndexWith},
    builder: =>
        index = AstTools\LeftChainToTree 'Index', @[1], (item)->
            item[1]

        index.right = @[2]
        index

DotIndexChain.add Repeat(Sequence {DotIndexable, '.'})

DotIndexWith.add Identifier
DotIndexWith.add Number

--------------------------------------------------
-- For -------------------------------------------
--------------------------------------------------
For = Any {}

For.add Sequence {'for', Identifier, '=', Expression, ',', Expression, ',', Expression, Block},
    tag: 'For'
    builder: =>
        {
            iterator: @[2]
            start: @[4]
            end: @[6]
            step: @[8]
            body: @[9]
        }

For.add Sequence {'for', Identifier, '=', Expression, ',', Expression, Block},
    tag: 'For'
    builder: =>
        {
            iterator: @[2]
            start: @[4]
            end: @[6]
            body: @[7]
        }

--------------------------------------------------
-- Function Definition ---------------------------
--------------------------------------------------
Function = Any {}
FunctionParameter = Any {}

FunctionParameterList = Sequence {'(', Repeat(FunctionParameter, separator:','), ')'},
    builder: => @[2]

Function.add Sequence{Optional(FunctionParameterList), '/([-=])>/', Block},
    tag: 'Function'
    builder: =>
        args, arrow, body = unpack @

        if arrow[2] == '='
            table\insert args, 1, {
                tag: 'Identifier'
                'self'
            }

        {
            args: args
            body: body
        }

FunctionParameter.add Identifier

--------------------------------------------------
-- If --------------------------------------------
--------------------------------------------------
If = Any {},
    tag: 'If'

Else = Any {}

If.add Sequence {'if', Expression, Block, Optional(Else)},
    builder: =>
        _, condition, body, tail = unpack @

        {
            condition: condition
            body: body
            tail: tail
        }

Else.add Sequence {'else if', Expression, Block, Optional(Else)}
    tag: 'ElseIf'
    builder: =>
        _, condition, body, tail = unpack @

        {
            condition: condition
            body: body
            tail: tail
        }

Else.add Sequence {'else', Block}
    tag: 'Else'
    builder: =>
        _, body = unpack @

        {
            body: body
        }

--------------------------------------------------
-- Length Operator -------------------------------
--------------------------------------------------
Length = Any {},
    tag: 'Length'

Length.add Sequence{'#', Expression},
    builder: =>

        {
            expression: @[2]
        }

--------------------------------------------------
-- Metalevel Shift Return Ast --------------------
--------------------------------------------------
MetalevelShiftReturnAst = Any {}

mlr_before = => stream.inMetaquote = true
mlr_after = => stream.inMetaquote = false

MetalevelShiftReturnAst.add Sequence {'+{', Run(Block, before: mlr_before, after: mlr_after), '}'},
    builder: =>
        AstTools\EscapeAst @[2]

MetalevelShiftReturnAst.add Sequence {'+{', Expression ,'}'},
    builder: =>
        AstTools\EscapeAst @[2]

--------------------------------------------------
-- Metalevel Shift Run Code ----------------------
--------------------------------------------------
MetalevelShiftRunCode = Any {}

MetalevelShiftRunCode.add Sequence {'-{', Block, '}'},
    builder: (stream)=>
        if stream.inMetaquote
            return {
                tag: 'Splice'
                content: @[2]
            }
        else
            AstTools\DoAst @[2],
                env: _G

MetalevelShiftRunCode.add Sequence {'-{', Expression, '}'},
    builder: =>
        if stream.inMetaquote
            return {
                tag: 'Splice'
                content: @[2]
            }
        else
            AstTools\DoAst @[2],
                env: _G

--------------------------------------------------
-- Self Index ------------------------------------
--------------------------------------------------
SelfIndex = Pattern '@([_a-zA-Z0-9]*)',
    tag: 'Index'
    builder: =>
        {
            left: {
                tag: 'Identifier'
                'self'
            }
            right: {
                tag: 'Identifier'
                @[2]
            }
        }

--------------------------------------------------
-- Table -----------------------------------------
--------------------------------------------------
Table = Any {},
    tag: 'Table'

TableContent = Any {}
TableKey = Any {}
TableValue = Any {}

TableKeyValue = Sequence {TableKey, ':', TableValue},
    tag: 'TableKeyValue'
    builder: =>
        key, _, value = unpack @
        {
            key: key
            value: value
        }

Table.add Sequence {'{', Optional(Repeat(TableContent, separator: ',')), '}'},
    builder: =>
        _, content, _ = unpack @

        {
            content: content
        }

TableContent.add TableKeyValue
TableContent.add Expression
TableKey.add Identifier
TableValue.add Expression

--------------------------------------------------
-- While -----------------------------------------
--------------------------------------------------
While = Any {},
    tag: 'While'

While.add Sequence {'while', Expression, Block},
    builder: =>
        _, condition, body = unpack @

        {
            condition: condition
            body: body
        }

--------------------------------------------------
-- Other -----------------------------------------
--------------------------------------------------
-- This is hacky way of delineating statements
Statement.add Any{NEWLINE}, tag: 'Ignore'

--------------------------------------------------
-- Set parser categories -------------------------
--------------------------------------------------
local *
__ = ->
A = => Assignable.add @
B = => BracketIndexable.add @
D = => DotIndexable.add @
C = => Callable.add @
E = => Expression.add @
S = => Statement.add @
export ^

-- A B C D E S Parser
__         E S Assignment
__           S While
__           S If
__           S For
__         E S Call
__         E   BinaryExpression
__         E   Function
__         E   BracketedExpression
__   B   D E   Table
__   B   D E   String
__   B   D E   Number
__ A       E   BracketIndex
__ A B     E   DotIndex
__ A B   D E   SelfIndex
__ A B C D E   Identifier
__         E   Length
__         E S MetalevelShiftRunCode
__         E S MetalevelShiftReturnAst

enableFor = (parserName)->
    mls = Any {}

    mls.add Sequence {"-{#{parserName}:", Block, '}'},
        builder: (stream)=>
            if stream.inMetaquote
                return {
                    tag: 'Splice'
                    content: @[2]
                }
            else
                AstTools\DoAst @[2],
                    env: _G

    mls.add Sequence {"-{#{parserName}:", Expression, '}'},
        builder: =>
            if stream.inMetaquote
                return {
                    tag: 'Splice'
                    content: @[2]
                }
            else
                AstTools\DoAst @[2],
                    env: _G

    _G[parserName].add mls

enableFor 'Assignable'


--------------------------------------------------
-- Parser Configuration --------------------------
--------------------------------------------------
-- Before
Before = Any{}

-- Enable indentation for this grammar
Before.add require'parser.grammar.Indentation'.GenerateAndAutoDedent

-- After
After = Any {}
After.add SpaceTab
After.add EmptyLine
After.add LuaBlockComment
After.add LuaComment

-- Root
Root = Sequence {Optional(Repeat(Statement)), EOF},
    tag: 'Block'
    builder: => @[1]
