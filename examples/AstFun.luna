-- Firstly import tools for working on ASTs
AstTools = require 'AstTools'

-- Compile the code inside this block
--  -but- instead of generating code, return the AST as an expression our program can use
ast = +{
    print "+{ } Will compile the code but return it as AST that our code can use."
}

-- Print out the AST
print inspect ast

-- Get the first instruction in the block
functionCall = ast[1]

-- Get the first argument
argument = functionCall.args[1]

-- Rewrite the data at this node
argument[1] = '"Because it is just data, I can alter it."'

-- Run the AST
AstTools::DoAst ast

-- Another example, this time compile this block of code
--  -but- run the code as soon as the parser finishes compiling this block
-{
    -- Again grab the AST
    ast = +{
        print 'Hello ' + 'World!'
        --[[ Here I did something silly
                In lua (what the parser runs on) the concat operator isn't "+" it's ".."
                This code -would- fail to run ]]
    }

    -- Print it out so you may inspect it
    print inspect ast

    -- Let's grab the function call
    functionCall = ast[1]

    -- And now the binary OP
    binaryOp = functionCall.args[1]

    -- And replace the data for the operator node
    binaryOp.operator[1] = ".."

    -- If we return from a compile time block.
    -- Whatever we return is inserted into the program
    --  as executable code.
    return ast
}

--[[
Output if you run this script

{
  2: {
    token: NEWLINE
    tag: Ignore
  }
  tag: Block
  1: {
    args: {
      1: {
        right: {
          tag: String
          1: 'World!'
        }
        operator: {
          tag: BinaryOperator
          1: +
        }
        left: {
          tag: String
          1: 'Hello '
        }
        tag: BinaryExpression
      }
    }
    name: {
      tag: Identifier
      1: print
    }
    tag: Call
  }
  4: {
    token: NEWLINE
    tag: Ignore
  }
  3: {
    token: NEWLINE
    tag: Ignore
  }
}
Parsing took: 191ms <<-- Compilation stops here, program execution begins here
{
  1: {
    args: {
      1: {
        tag: String
        1: "+{ } Will compile the code but return it as AST that our code can use."
      }
    }
    name: {
      tag: Identifier
      1: print
    }
    tag: Call
  }
  tag: Block
}
Because it is just data, I can alter it.
Hello World!
]]
