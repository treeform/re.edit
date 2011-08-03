print = (args...) -> console.log(args...)
info = print
warn = print

ENTER = 13
UP = 38
DOWN = 40
IUP = 73
IDOWN = 75
OKEY = 79
SKEY = 83
SEARCHKEY = 186
GOTOKEY = 89
ESC = 27
COMMANDKEY = 65

current_pad = undefined

saved_pos = {}

esc = ->
    $("div.popup").hide()
    current_pad.edit.focus()

keys = (e) ->
    if e.which == ESC
        esc()
    else
        current_pad.keys(e)
$(document).keydown(keys).keyup(keys).keypress(keys)

pads = []
resize = ->
    print "resize"
    $win = $(window)
    width = $win.width()
    height = $win.height()
    w = Math.floor(width/pads.length)

    for pad, i in pads
        print i,pad
        $html = $(pad.edit.getScrollerElement())
        $html.css
            position: "absolute"
            top: 0
            left: i*w
            width: w
            height: height
        pad.edit.refresh()

$(window).resize(resize)


$("#goto-box").hide()
$("#goto-input").keyup (e) ->
    editor = current_pad.edit
    $input = $(e.currentTarget)
    line = parseInt($input.val())
    if line > 0
        editor.setCursor(line)
    if e.which == ENTER
        esc()

$("#command-box").hide()
$("#command-input").keyup (e) ->
    editor = current_pad.edit
    if e.which == ENTER
        $input = $(e.currentTarget)
        query = $input.val()
        if not query
            return
        js = CoffeeScript.compile(query)
        print js
        eval(js)

marked = []
last_pos = null
last_query = null
$("#search-box").hide()
$("#search-input").keyup (e) ->
    editor = current_pad.edit
    m() for m in marked
    marked = []

    $input = $(e.currentTarget)
    query = $input.val()
    if not query
        return
    print "looking for", query, current_pad.edit
    cursor = editor.getSearchCursor(query)
    while cursor.findNext()
        t = editor.markText(cursor.from(), cursor.to(), "searched")
        marked.push(t)

    if e.which == ENTER
        print "next", query
        cur_pos = editor.getCursor()
        if last_query != query
            last_pos = null

        if e.shiftKey
            cursor = editor.getSearchCursor(query, last_pos-1 or cur_pos-1)
            # backwards
            if not cursor.findPrevious()
                # wrap lines
                cursor = editor.getSearchCursor(query)
                if not cursor.findPrevious()
                    return
        else
            cursor = editor.getSearchCursor(query, last_pos or cur_pos)
            # forward
            if not cursor.findNext()
                #warp lines
                cursor = editor.getSearchCursor(query)
                if not cursor.findNext()
                    return

        print "set selection",e, cursor.from(), cursor.to()
        editor.setSelection(cursor.from(), cursor.to())
        last_query = query
        last_pos = cursor.to()


$("#open-box").hide()
$("#file-input").keyup (e) ->
    $input = $(e.currentTarget)
    $sug = $input.prev()

    if e.which == ESC
        $input.val("")
        $input.parent().hide()
        current_pad.edit.focus()
    else if e.which == ENTER
        current_pad.open_file($input.val())
        $input.val("")
        $input.parent().hide()
        current_pad.edit.focus()
    else if e.which == UP or e.which == DOWN
        chosen = $sug.find(".highlight")
        if chosen.size() == 0
            chosen = $sug.children().last()
        else
            if e.which == UP
                next = chosen.prev()
            else
                next = chosen.next()
            if next.size() > 0
                chosen.removeClass("highlight")
                next.addClass("highlight")
                chosen = next
        chosen.addClass("highlight")
        $input.val(chosen.text())
    else
        print "do suggestions"
        $.ajax "/suggest",
            dataType: "json"
            data:
                s: $input.val()
            error: (e) -> warn "error", e
            success: (files) ->
                $sug.children().remove()
                for f in files
                    $sug.append("<div class='sug'>#{f}<div>")
                #$sug.children().last().addClass("highlight")


$.ajax "/start",
    dataType: "json"
    error: (e) -> warn "error getting start data", e
    success: (data) ->
        opened_files = data.opened_files
        i = opened_files.length - 1
        for pad in pads
            pad.open_file(opened_files[i])
            i -= 1

class Pad
    # global vars?
    filename: ""

    constructor: () ->
        @textarea = $("<textarea></textarea>")
        $(document.body).append(@textarea)
        # print @textarea[0]
        # @textarea = $("#code")
        @edit = CodeMirror.fromTextArea @textarea[0],
            mode:  "javascript"
            tabMode: "shift"
            matchBrackets: true
            onFocus: @focused
        pads.push(@)


    focused: =>
        current_pad = @

    open_file: (file_name) =>
        $.ajax "open"
            dataType: "json"
            data:
                path: file_name
            success: (json) =>
                saved_pos[@filename] = @edit.getCursor()
                @filename = file_name
                if json.error?
                    warn(json.error)
                    @edit.setOption("mode", null)
                    @edit.setValue("")
                else
                    @filename = json.path
                    print "mode", json.mode
                    json.mode = "text" if not json.mode?
                    @edit.setOption("mode", json.mode)
                    @edit.setValue(json.text)
                    if @filename of saved_pos
                        @edit.setCursor(saved_pos[@filename])
            error: (e) -> warn "could not open", @filename, e

    keys: (args...) =>
        key = args.pop()
        if not key.ctrlKey
            return null
        print "meta", key.which
        # save
        if key.which == SKEY
            print "save"
            text = @edit.getValue()
            # strip trailing spaces
            text = text.replace(/[ \t\r]*\n/g,"\n")
            $.ajax "save",
                type: "POST"
                data:
                    path: @filename
                    text: text
                dataType: "json"
                success: => info "saved", @filename
                error: => warn "could not save", @filename

        else if key.which == IUP
            pos = @edit.getCursor()
            pos.line -= 5
            @edit.setCursor(pos)
        else if key.which == IDOWN
            pos = @edit.getCursor()
            pos.line += 5
            @edit.setCursor(pos)
        # open
        else if key.which == OKEY
            print "open"
            $("#open-box").show()
            $("#file-input").focus()
        else if key.which == SEARCHKEY
            print "open"
            $("#search-box").show()
            $("#search-input").focus()
        else if key.which == COMMANDKEY
            print "command"
            $("#command-box").show()
            $("#command-input").focus()
        else if key.which == GOTOKEY
            print "goto"
            $("#goto-box").show()
            $("#goto-input").focus()
        key.stopPropagation()
        return false

for i in [0..1]
    current_pad = new Pad("code")

resize()