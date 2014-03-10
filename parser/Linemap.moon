Line = require 'parser.Line'

class Linemap
    new: (@string)=>
        @lines = {
            Line @, 1, ''
        }

        -- Find all newlines in a file
        for newline, pos in @string.gmatch '(\n)()'
            table\insert @lines, Line @, pos, newline

        table\sort @lines, (a,b)->
            a.start < b.start

        -- Set extra data about the line
        totalLines = #@lines

        for i=1,totalLines-1
            @lines[i].line = i
            @lines[i].end = @lines[i+1].start - #@lines[i+1].newline

        @lines[totalLines].line = totalLines
        @lines[totalLines].end = #@string

    getLine: (line)=>
        line = @lines[line]
        if not line
            return
        line.getContent!

    getInfo: (line)=>
        return @lines[line]

    getLineFromOffset: (pos)=>
        line = @getInfoFromOffset(pos)
        if not line
            return
        line.getContent!

    getInfoFromOffset: (pos)=>
        -- Work out which line this is on
        for i=1,#@lines
            if pos < @lines[i].start
                line = @lines[i - 1]
                return line
        return nil
