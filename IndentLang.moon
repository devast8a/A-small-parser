-- Export anything that begins with a capital letter
AstTools = require 'AstTools'
export ^
import INDENT, DEDENT, Any, On, BaseParser, Repeat, LeftRecursive, Optional, Not, Pattern, Sequence, Keyword, Token, Peek, EOF, T from require 'parser.grammar.generator'
NEWLINE = Token 'NEWLINE'

Expression = Any {}     -- Anything that may return a result
Statement = Any {}      -- Anything that is allowed to be on its own
Assignable = Any {}     -- Anything that can be assigned to
DotIndexable = Any {}   -- Anything that can be on the left hand side of a dot index expression

Block = Repeat Statement,
    tag: 'Block'

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

CallArgumentList.add Repeat(CallArgument, separator: CallArgumentSeparator)
CallArgumentList.add Sequence{'(', Repeat(CallArgument, separator: CallArgumentSeparator), ')'},
    builder: =>
        return @[2]

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

Call.add Sequence {Callable, '(', Repeat(CallArgument, separator: CallArgumentSeparator), ')'},
    builder: =>
        name, args = unpack @
        {
            args: args
            name: name
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
-- Function Definition ---------------------------
--------------------------------------------------
Function = Any {}
FunctionParameter = Any {}

FunctionParameterList = Sequence {'(', Repeat(FunctionParameter, separator:','), ')'},
    builder: => @[2]

Function.add Sequence{Optional(FunctionParameterList), '/([-=])>/', INDENT, Block, DEDENT},
    tag: 'Function'
    builder: =>
        args, arrow, _, body = unpack @

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

If.add Sequence {'if', Expression, INDENT, Block, DEDENT},
    builder: =>
        _, condition, _, body = unpack @

        {
            condition: condition
            body: body
        }

--------------------------------------------------
-- Metalevel Shift Return Ast --------------------
--------------------------------------------------
MetalevelShiftReturnAst = Any {}

MetalevelShiftReturnAst.add Sequence {'+{', INDENT, Block, DEDENT, '}'},
    builder: =>
        AstTools\EscapeAst @[3]

--------------------------------------------------
-- Metalevel Shift Run Code ----------------------
--------------------------------------------------
MetalevelShiftRunCode = Any {}

MetalevelShiftRunCode.add Sequence {'-{', INDENT, Block, DEDENT, '}'},
    builder: =>
        AstTools\DoAst @[3], _G

MetalevelShiftRunCode.add Sequence {'-{', Statement, '}'},
    builder: =>
        error 'Not implemented yet'

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

While.add Sequence {'while', Expression, INDENT, Block, DEDENT},
    builder: =>
        _, condition, _, body = unpack @

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
__         E S MetalevelShiftRunCode
__         E   MetalevelShiftReturnAst

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
Root = Sequence {Block, EOF},
    builder: => @[1]
