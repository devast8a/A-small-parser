func = (expr)->
    -- Just to dick about let's splice together to ASTs
    return +{
        some_variable = "Splicing. " .. -{expr}
    }

-- Let's call func
ast = func +{"This expression " .. "into func."}

-- Run the AST
AstTools = require 'AstTools'
print inspect ast
AstTools::DoAst ast

print some_variable

--[[
{
  1: {
    expr: {
      right: {
        right: {
          1: "into func."
          tag: String
        }
        operator: {
          1: ..
          tag: BinaryOperator
        }
        left: {
          1: "This expression "
          tag: String
        }
        tag: BinaryExpression
      }
      operator: {
        1: ..
        tag: BinaryOperator
      }
      left: {
        1: "Splicing. "
        tag: String
      }
      tag: BinaryExpression
    }
    assignable: {
      1: some_variable
      tag: Identifier
    }
    tag: Assignment
  }
  tag: Block
}
]]
