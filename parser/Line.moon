class Line
    new: (@map, @start, @newline)=>

    getContent: =>
        if not @content
            @content = @map.string.sub self.start, self.end - 1
        return @content

    offsetToColumn: (offset)=>
        offset - @start + 1

    columnToOffset: (column)=>
        column + @start - 1

    characterAt: (column)=>
        @getContent!.sub column, column

    characterAtOffset: (offset)=>
        column = @offsetToColumn offset
        @getContent!.sub column, column
