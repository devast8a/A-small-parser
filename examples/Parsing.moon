gg = require 'parser.grammar.generator'

-- Test matcher function
testMatcher = (matcher,input)->
    print input, matcher.parseString input

-- Keyword, The simplest matcher.
-- Compares a string you give it to the input
keyMatcher = gg::Keyword 'test'

testMatcher keyMatcher, 'test'
testMatcher keyMatcher, 'fail'
print '----------------------------------------------'


-- Pattern, Uses lua patterns to match input.
patternMatcher = gg::Pattern '[a-z]+[0-9]+'

testMatcher patternMatcher, 'hello12345'
testMatcher patternMatcher, '12345hello'
print '----------------------------------------------'


-- Now onto combinators
-- Any will take a list of matchers and will match against ANY of the matchers.
--  A few shortcuts, if you specify a string it is assumed to be a Keyword matcher
--  unless it begins and ends with / in which case it's assumed to be a Pattern matcher
anyMatcher = gg::Any {'World', '/[0-9]+/'}

testMatcher anyMatcher, '1000'
testMatcher anyMatcher, 'ABC'
testMatcher anyMatcher, 'No match'

-- You can add new matchers to Any after construction
anyMatcher.add '/[a-zA-Z]+/'
testMatcher anyMatcher, 'No match'
print '----------------------------------------------'

-- Sequence will take a list of matchers and will match them one AFTER the other
seqMatcher = gg::Sequence {'Hello: ', anyMatcher}

testMatcher seqMatcher, 'HelloWorld'
testMatcher seqMatcher, 'Hello: World'
print '----------------------------------------------'

-- Repeat will take a matcher and repeatedly match it
--  You can specify an optional separation matcher that must separate each match
repeatMatcher = gg::Repeat gg::Any({'A','B','C'}), {separator: ','}

testMatcher repeatMatcher, 'A,B,C,A'
testMatcher repeatMatcher, 'Not'
print '----------------------------------------------'

-- Optional will take a matcher and will attempt to match the input but
--  will be successful even if the matcher fails. Best used in Sequences.
optionalMatcher = gg::Sequence{gg::Optional('!'), 'word'}

testMatcher optionalMatcher, '!word'
testMatcher optionalMatcher, 'word'
print '----------------------------------------------'

-- Not will take a matcher and will attempt to match the input only
--   if the passed in matcher does NOT match the input.
-- Try to use other methods of matching input before using Not as
--   not isn't very well implemented and may take a while to match
optionalMatcher = gg::Sequence{'--[[', gg::Not(']]'), ']]'}

testMatcher optionalMatcher, '--[[ whatever is in here is ignored ]]'
print '----------------------------------------------'

--[[
    This isn't all of the operations you can do on matchers,
        I'll probably give example usages of the rest at a later time.

    LeftRecursive (soon to be renamed to Lock)
        Essentially locks the matcher while it is matching causing any recursions to fail

    On
        Matches the name of the last matcher to run. (Not really working well, needs to be fixed)

    Peek
        Matches input but does not advance stream position, useful for matching up to a certain point
        without matching the delineating character

    Token
        Matches a token on the token stack.
        The parser contains the current position in the string it is parsing as well as a stack of
        tokens, little bits of identifying information useful for specifying things like EOF.
        Matchers can only match against the string if the token stack is empty.

    EOF
    INDENT
    DEDENT
        Shortcuts for matching the EOF,INDENT and DEDENT tokens respectively.
]]
