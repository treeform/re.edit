print = (args...) -> console.log(args...)
info = print
warn = print

ENTER = 13
UP = 38
DOWN = 40
OKEY = 79
SKEY = 83
SEARCHKEY = 186
GOTOKEY = 89
ESC = 27
COMMANDKEY = 65
TAB = 9
LEFT_WINDOW = 74
RIGHT_WINDOW = 76


current_pad = undefined
base_dir = "/"
saved_pos = {}
marked = []


Array::remove = (elem) ->
  for i in [0...@length]
      if @[i] == elem
          @splice(i,1);

esc = ->
    # remove any selections
    if marked
        m.clear() for m in marked
        marked = []
    # remove popups
    $("div.popup").hide()
    # focus on the editor
    current_pad.edit.focus()

keys = (e) ->
    ###
    if e.ctrlKey
        if e.which == LEFT_WINDOW
            pads[0].focus()
        if e.which == RIGHT_WINDOW
            pads[1].focus()
    ###
    if e.which == ESC
        esc()
    else
        return
        #current_pad.keys(e)

$(document).keydown(keys).keyup(keys).keypress(keys)

pads = []
resize = ->
    print "resize"
    $win = $(window)
    width = $win.width()
    height = $win.height()

    n = pads.length
    columns = 2
    if n > columns
        n = columns
    w = Math.floor(width/n)
    current_pad ?= pads[0]
    for pad, i in pads
        if pad == current_pad
            offset = i
    if pads.length >= columns and offset > pads.length - columns
        offset = pads.length - columns
    print "offset is", offset
    for pad, i in pads
        $html = $(pad.edit.getScrollerElement())
        $html.css
            position: "absolute"
            top: 0
            height: height
            left: (i-offset)*w
            width: w
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

set_settings = (settings) ->
    $.ajax "/settings",
        type: "POST"
        dataType: "text"
        data:
            set: settings
        error: (e) -> warn "error setting settings", e
        success: (s) -> return

set_pads = ->
    c = 0
    for pad, i in pads
        if pad == current_pad
            c = i
    set_settings
        "pads": ({"filename":pad.filename} for pad in pads)
        "current_pad": c

# some commands here
window.cd = (dir) ->
    base_dir = dir
    set_settings
        "base_dir": base_dir
    esc()

window.indent = (i) -> current_pad.edit.setOption("indentUnit", i)
window.wrap = -> current_pad.edit.setOption("lineWrapping", true)
window.nowrap = -> current_pad.edit.setOption("lineWrapping", false)

# makes sure the selection accupies full lines
window.boxsel = ->
    edit = current_pad.edit
    if edit.somethingSelected()
        start = edit.getCursor(true)
        start.ch = 0
        end = edit.getCursor(false)
        end.ch = edit.getLine(end.line).length
        edit.setSelection(start, end)

# adds a string to each line
window.place = (c) ->
    boxsel()
    sel = current_pad.edit.getSelection()
    sel = c + sel.split("\n").join("\n" + c)
    current_pad.edit.replaceSelection(sel)

# removes a string from each line
window.unplace = (c) ->
    boxsel()
    sel = current_pad.edit.getSelection()
    final = []
    for line in sel.split("\n")
        if line.substr(0, c.length) == c
            line = line.substr(c.length)
        final.push line
    current_pad.edit.replaceSelection(final.join("\n"))

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
        esc()

last_pos = null
last_query = null
$("#search-box").hide()
$("#search-input").keyup (e) ->
    editor = current_pad.edit
    m.clear() for m in marked
    marked = []

    $input = $(e.currentTarget)
    query = $input.val()
    if not query or query.length == 1
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

$("#replace-input").keyup (e) ->
    print "replace"
    editor = current_pad.edit
    m.clear() for m in marked
    marked = []
    $input = $(e.currentTarget)
    text = $("#search-input").val()
    replace = $input.val()

    print "replace", text, replace
    return if not text

    print e.which
    if false and e.which == ENTER
        # replace all
        cursor = editor.getSearchCursor(text)
        while cursor.findNext()
            cursor.replace(replace)

    if e.which == ENTER
        # replace all
        cursor = editor.getSearchCursor(text, off, false)
        if e.shiftKey
            c = cursor.findPrevious()
        else
            c = cursor.findNext()
        if c
            cursor.replace(replace)
            editor.setSelection(cursor.from(), cursor.to())


$("#open-box").hide()
$("#file-input").keyup (e) ->
    $input = $(e.currentTarget)
    $sug = $input.prev()
    s = $input.val()
    m = s.match("(.*)/([^/]*$)")
    if m
        dir = m[1]
        s = m[2]
    else
        dir = base_dir
    print "dir", dir, "file", s

    if e.which == ESC
        $input.val("")
        $input.parent().hide()
        current_pad.edit.focus()
    else if e.which == ENTER

        input = $input.val()
        if input[0...5] == "open "
            input = input[5...]
            old_current = current_pad
            current_pad = new Pad()
            current_pad.open_file(input)
            current_pad.focus()
            current_pad.move(old_current)

        else if input[0...5] == "goto "
            input = input[5...]
            for pad in pads
                if pad.filename == input
                    current_pad = pad
                    current_pad.focus()
                    break
        resize()

        $input.val("")
        esc()
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
        suggest = (files) ->
            $sug.children().remove()
            for f in files
                f = f.replace(s,"<b>#{s}</b>")
                $sug.append("<div class='sug'>open #{f}<div>")

             for pad in pads
                f = pad.filename
                m = f.match("(.*)/([^/]*$)")
                i = m[2].indexOf(s)
                print "local", m, s, i
                if i != -1
                    f = f.replace(s,"<b>#{s}</b>")
                    $sug.append("<div class='sug local'>goto #{f}<div>")


            #$sug.children().last().addClass("highlight")
        if s != ""
            $.ajax "/suggest",
                dataType: "json"
                data:
                    "s": s
                    "dir": dir
                error: (e) -> warn "error", e
                success: suggest
        else
            suggest([])

$.ajax "/start",
    dataType: "json"
    error: (e) -> warn "error getting start data", e
    success: (settings) ->
        print "settings", settings
        base_dir = settings.base_dir ? "/"
        if settings.pads
            for spad in settings.pads
                pad = new Pad()
                pad.open_file(spad.filename)
        else
            new Pad()

        current_pad = pads[settings.current_pad]
        current_pad ?= pads[0]
        current_pad.focus()
        resize()

common_str = (strs) ->
    return "" if strs.length == 0
    return strs[0] if strs.length == 1
    first = strs[0]
    common = ""
    fail = false
    for c,i in first
        for str in strs
            if str[i] != c
                fail = true
                break
        break if fail
        common += c
    return common


gcd = (a, b) ->
    while b
        [a, b] = [b, a % b]
    return a

guess_indent = (text) ->
    indents = {}
    for line in text.split("\n")
        indent = line.match(/^\s*/)[0].length
        continue if indent == 0
        if indent of indents
            indents[indent] += 1
        else
            indents[indent] = 1
    indents = ([k*1,v] for k,v of indents)
    indents = indents.sort (a,b) -> b[1] - a[1]
    indents = (i[0] for i in indents)
    if indents.length == 1
        return indents[0]
    if indents.length == 0
        return 4
    indent = gcd(indents[0], indents[1])
    #print "indents", indents, indent
    return indent

pad_index = (pad) ->
    for pad, i in pads
        if pad == pad
            return i

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
            theme: "midnight"
            keyMap: "re_edit"
            onChange: @update_clones
        @edit.re_pad = @
        pads.push(@)

    focus: ->
        @edit.focus()

    focused: =>
        current_pad = @

    move: (to_pad) ->
        # moving this pad right of pad
        pads.remove @
        c = pad_index(to_pad)
        if c
            pads.splice(c,0,@)
        else
            pads.push @

    update_clones: =>
        if current_pad != @
            return
        for pad in pads
            if pad != current_pad and pad.filename == current_pad.filename
                c = pad.edit.getCursor()
                $elem = $(pad.edit.getScrollerElement())
                #top = $elem.css("top")
                pad.edit.setValue(current_pad.edit.getValue())
                pad.edit.setCursor(c)
                #$elem.css("top", top)



    open_file: (file_name) =>
        $.ajax "open"
            dataType: "json"
            data:
                path: file_name
            success: (json) =>
                saved_pos[@filename] = @edit.getCursor()
                @filename = file_name
                print json
                if json.error?
                    warn(json.error)
                    @edit.setOption("mode", json.mode)
                    @edit.setValue("")
                else
                    @filename = json.path
                    print "mode", json.mode
                    json.mode = "text" if not json.mode?
                    @edit.setOption("mode", json.mode)
                    @edit.setValue(json.text)
                    @edit.clearHistory()
                    @edit.setOption("indentUnit", guess_indent(json.text))
                    @edit.setOption("electricChars", false)
                    @edit.setOption("onKeyEvent", @key_hook)
                    if @filename of saved_pos
                        @edit.setCursor(saved_pos[@filename])
                    set_pads()
                    resize()
                    #tools(@edit)
            error: (e) -> warn "could not open", @filename, e

    key_hook: (e, key) =>
        # auto complete on tab if tabbing after a word
        if key.which == TAB and key.type == "keydown"
            pos = @edit.getCursor()
            line = @edit.getLine(pos.line)
            next = line[pos.ch]
            if next == undefined or next.match(/\W/)
                string = line.substr(0, pos.ch)
                string = string.match(/\w+$/)
                if string
                    options = {}
                    words = @edit.getValue().split(/\W+/).sort()
                    if words
                        for word in words
                            word_match = word.match("^" + string + "(.+)")
                            if word_match and word_match[1] != ""
                                options[word_match[1]] = true
                        add = common_str(k for k of options)
                        if add.length > 0
                            @edit.replaceSelection(add)
                            @edit.setCursor(pos.line, pos.ch + add.length)
                    key.stop()
                    return true

        #quick_tool()
        return false

open_file = ->
    esc()
    $("#open-box").show()
    $("#file-input").focus()

save_file = (pad) ->
    print "save"
    text = pad.edit.getValue()
    # strip trailing spaces
    text = text.replace(/[ \t\r]*\n/g,"\n")
    $.ajax "save",
        type: "POST"
        data:
            path: pad.filename
            text: text
        dataType: "json"
        success: => info "saved", pad.filename
        error: => warn "could not save", pad.filename

search = (pad) ->
    esc()
    $("#search-box").show()
    $("#search-input").focus()
    selected_word = pad.edit.getSelection()
    if selected_word
        $("#search-input").val(selected_word)

command = ->
    $("#command-box").show()
    $("#command-input").focus()

goto = ->
    esc()
    $("#goto-box").show()
    $("#goto-input").focus()


terminal = ->
    # changes current pain to a terminal
    esc()

prev_pad = ->
    prev = false
    for pad in pads
        if current_pad == pad and prev
            current_pad = prev
            current_pad.focus()
            resize()
            set_pads()
            return true
        prev = pad
    return false

next_pad = ->
    next = false
    for pad in pads
        if next == true
            current_pad = pad
            current_pad.focus()
            resize()
            set_pads()
            return true
        if current_pad == pad
            next = true
    return false

close_pad = ->
    print "close pad", current_pad
    if pads.length <= 1
        return
    x_pad = current_pad
    x_pad.edit.toTextArea()
    x_pad.textarea.remove()
    prev_pad() or next_pad()
    pads.remove(x_pad)
    print "pads", pads
    resize()
    set_pads()

###
tools_on = true
last_timeout = false
quick_tool = ->
    return
    if last_timeout
        clearTimeout(last_timeout)
    last_timeout = setTimeout(tools, 10000)


messages = []
clear_tools = ->
    for m in messages
        m.remove()
    messages = []

tools_key = ->
    tools_on = not tools_on
    tools()

tools = (edit) ->
    return
    clear_tools()
    return if not tools_on
    last_timeout = false

    console.log "running tools..."
    if not edit?
        edit = current_pad.edit
    mode = edit.getOption("mode")
    text = edit.getValue()
    console.log mode
    if mode == "coffeescript"

        try
            CoffeeScript.compile(text)
        catch e
            m = e.message.match(/Parse error on line (\d*): (.*)/)
            if m
                [full, line, msg] = m
                console.log line, msg
                msg = "^ "+msg
                error = $("<div class='error'><div class='msg'>#{msg}</div></div>")
                messages.push(error)
                line = parseInt(line)-1
                l = edit.getLine(line)
                console.log l
                [full, space] = l.match(/(\s*).*$/)
                error.css("width", l.trim().length*8+"px")
                edit.addWidget({line:line, ch:space.length}, error[0])
                return
        return
        # now lint
        configuration =
          "indentation":
              "value": edit.getOption("indentUnit"),
              "level": "error"
          "no_implicit_braces":
              "level": "error"
          "no_trailing_semicolons":
              "level": "error"
          "no_plusplus" :
              "level": "error"
          "no_trailing_whitespace":
              "level": "ignore"

        for hint in coffeelint.lint(text, configuration).reverse()
            console.log hint, hint.message
            msg = "^ " + hint.message
            error = $("<div class='hint'><div class='msg'>#{msg}</div></div>")
            messages.push(error)
            l = edit.getLine(hint.lineNumber-1)
            [full, space] = l.match(/(\s*).*$/)
            error.css("width", l.trim().length*8+"px")
            edit.addWidget({line:hint.lineNumber-1, ch: space.length}, error[0])
###



CodeMirror.keyMap.re_edit =

    "Ctrl-L": (cm) -> open_file()
    "Ctrl-S": (cm) -> save_file(cm.re_pad)
    "Ctrl-F": (cm) -> search(cm.re_pad)
    "Ctrl-Y": (cm) -> goto()
    "Ctrl-A": (cm) -> command()

    "Ctrl-T": (cm) -> terminal()

    "Ctrl-[": (cm) -> prev_pad()
    "Ctrl-]": (cm) -> next_pad()

    "Ctrl-{": (cm) -> console.log "expand"
    "Ctrl-}": (cm) -> console.log "shrink"

    "Ctrl-N": (cm) -> close_pad()


    #"Ctrl-W": (cm) -> tools_key()

    "Esc": (cm) -> esc()
    fallthrough: ["default"]


resize()
