import INDENT, DEDENT, Any, On, BaseParser, Repeat, LeftRecursive, Optional, Not, Pattern, Sequence, Keyword, Token, Peek, EOF, T from require 'parser.grammar.generator'
NEWLINE = Token 'NEWLINE'

-- Export anything that begins with a capital letter
export ^

Expression = Any {}     -- Anything that may return a result
Statement = Any {}      -- Anything that is allowed to be on its own
Assignable = Any {}     -- Anything that can be assigned to

Block = Repeat Statement,
    tag: 'Block'

Newline = Keyword '\n'
SpaceTab = Pattern '[ \t]+'
EmptyLine = Sequence {Newline, Optional(SpaceTab), Peek Newline}
LuaComment = Pattern '%-%-[^\r\n]+'
LuaBlockComment = Sequence {'--[[', Repeat(Not(']]')), ']]'}

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
    '/'
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

Call.add Sequence {Callable, Repeat(CallArgument, separator: CallArgumentSeparator)},
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
-- Function Definition ---------------------------
--------------------------------------------------
Function = Any {}
FunctionParameter = Any {}

FunctionParameterList = Sequence {'(', Repeat(FunctionParameter, separator:','), ')'},
    builder: => @[2]

Function.add Sequence{Optional(FunctionParameterList), '->', INDENT, Block, DEDENT},
    tag: 'Function'
    builder: =>
        args, _, _, body = unpack @
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
-- Indexing --------------------------------------
--------------------------------------------------
Index = Any {},
    tag: 'Index'

-- Anything that can be on the left hand side of an Index expression
Indexable = Any {}

-- Anything that can be on the right hand side of an Index expression
IndexRHS = Any {}

Index.add Sequence {LeftRecursive(Indexable), '.', IndexRHS},
    builder: =>
        left, _, right = unpack @

        {
            left: left
            right: right
        }

IndexRHS.add Index
IndexRHS.add Identifier

--------------------------------------------------
-- Metalevel Shift Return Ast --------------------
--------------------------------------------------
MetalevelShiftReturnAst = Any {}

MetalevelShiftReturnAst.add Sequence {'+{', INDENT, Statement, DEDENT, '}'},
    builder: =>
        require'AstTools'\EscapeAst @[3]

--------------------------------------------------
-- Metalevel Shift Run Code ----------------------
--------------------------------------------------
MetalevelShiftRunCode = Any {}

MetalevelShiftRunCode.add Sequence {'-{', INDENT, Block, DEDENT, '}'},
    builder: =>
        require'AstTools'.do_ast @[3], _G

MetalevelShiftRunCode.add Sequence {'-{', Statement, '}'},
    builder: =>
        require'AstTools'\do_ast @[2][1]

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
C = => Callable.add @
E = => Expression.add @
I = => Indexable.add @
S = => Statement.add @
export ^

-- A C E I S - Calling Flags
__     E   S Assignment
__         S While
__         S If
__     E   S Call
__ A C E I   Index
__     E     BinaryExpression
__     E     Function
__     E     BracketedExpression
__     E     Table
__ A C E I   Identifier
__     E     String
__     E     Number
__     E   S MetalevelShiftRunCode
__     E     MetalevelShiftReturnAst

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
