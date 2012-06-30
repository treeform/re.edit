print = (args...) -> console.log(args...)
info = print
warn = print

OKEY = 79
SKEY = 83
SEARCHKEY = 186
GOTOKEY = 89
COMMANDKEY = 65
TAB = 9
ESC = 27
ENTER = 13
UP = 38
DOWN = 40

current_pad = undefined
base_dir = "/"
saved_pos = {}
marked = []
settings = null

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
    current_pad.focus()


# key handler
key_map =
    13: 'enter'
    38: 'up'
    40: 'down'
    27: 'esc'
    9: 'tab'
    219: '['
    221: ']'

key_string = (which) ->
    c = key_map[which]
    if not c?
        c = String.fromCharCode(which).toLowerCase()
    return c
stroke_map = {}
keys = (e) ->
    key_stroke = []
    if e.ctrlKey
        key_stroke.push("ctr")
    c = key_string(e.which)
    if c?
        key_stroke.push(c)
    key_stroke = key_stroke.join("-")
    fn = stroke_map[key_stroke]
    if fn?
        fn()
        # kill this event
        e.preventDefault()
        e.stopPropagation()
        return false

$(document).keydown(keys)
key = (str, fn) ->
    stroke_map[str] = fn


pads = []
resize = ->
    $win = $(window)
    width = $win.width()
    height = $win.height()
    if current_pad?
        $html = $(current_pad.container())
        $html.css
            position: "absolute"
            top: 0
            height: height
            left: 0
            width: width
        current_pad.refresh()

$(window).resize(resize)



set_settings = (settings) ->
    $.ajax "/settings",
        type: "POST"
        dataType: "text"
        data:
            set: settings
        error: (e) -> warn "error setting settings", e
        success: (s) -> return

# some commands here
window.cd = (dir) ->
    base_dir = dir
    set_settings
        "base_dir": base_dir
    esc()

window.indent = (i) -> current_pad.edit.setOption("indentUnit", i)
window.wrap = -> current_pad.edit.setOption("lineWrapping", true)
window.nowrap = -> current_pad.edit.setOption("lineWrapping", false)

window.font = ->


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


window.onpopstate = (event) ->
    load_from_url()

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
    cursor = editor.getSearchCursor(query)
    while cursor.findNext()
        t = editor.markText(cursor.from(), cursor.to(), "searched")
        marked.push(t)

    if e.which == ENTER
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

        editor.setSelection(cursor.from(), cursor.to())
        last_query = query
        last_pos = cursor.to()

$("#replace-input").keyup (e) ->
    editor = current_pad.edit
    m.clear() for m in marked
    marked = []
    $input = $(e.currentTarget)
    text = $("#search-input").val()
    replace = $input.val()

    return if not text

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

    if e.which == ESC
        $input.val("")
        $input.parent().hide()
        current_pad.edit.focus()

    else if e.which == ENTER
        input = $input.val()
        current_pad.open_file(input)
        current_pad.focus()
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
        suggest = (files) ->
            $sug.children().remove()
            for f in files
                f = f.replace(s,"<b>#{s}</b>")
                $sug.append("<div class='sug'>#{f}<div>")
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
    success: (data) ->
        settings = data
        print "started with settings", settings
        base_dir = settings.base_dir ? "/"
        current_pad = new Pad()
        load_from_url()
        current_pad.focus()
        resize()


load_from_url = ->
    path = location.pathname
    if path[0..5] == "/edit/"
        filepath = path[6..]
        print "load from url file", filepath

        current_pad.open_file(filepath)


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

window.onbeforeunload = ->
    current_pad.save_position()


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
            smartIndent: false
            matchBrackets: true
            onFocus: @focused
            theme: "midnight"
            indentWithTabs: false
            #keyMap: "re_edit"
            onScroll: @scrolled
            onCursorActivity: @moved

            onChange: @update_clones

        @edit.re_pad = @
        @edit.setOption("electricChars", false)
        @edit.setOption("onKeyEvent", @key_hook)


        #@current_line = @edit.setLineClass(0, "activeline");


        pads.push(@)

    focus: ->
        @update_url()
        @edit.focus()

    focused: =>
        @update_url()
        current_pad = @

    container: ->
        @edit.getScrollerElement()

    refresh: ->
        @update_url()
        @edit.refresh()

    move: (to_pad) ->
        # moving this pad right of pad
        pads.remove @
        c = pad_index(to_pad)
        if c
            pads.splice(c,0,@)
        else
            pads.push @

    update_url: =>
        path = @filename
        if not path
            return
        if path[0..base_dir.length] == base_dir
            path = path[base_dir.length..]
        document.title = path
        url = "/edit/"+@filename
        if location.pathname != url
            stateObj = {filename: @filename}
            history.pushState(stateObj, @filename, url)

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

    update_line: =>
        @edit.setLineClass(@current_line, null, null)
        @current_line = @edit.setLineClass(
             @edit.getCursor().line, null, "activeline")
        print @current_line

    open_file: (file_name) =>
        @save_pos()
        $.ajax "/open"
            dataType: "json"
            data:
                path: file_name
                r: Math.random()
            success: (json) =>
                saved_pos[@filename] = @edit.getCursor()
                @filename = file_name
                if json.error?
                    warn(json.error)
                    @edit.setOption("mode", json.mode)
                    @edit.setValue("")
                    #@update_url()
                else
                    @filename = json.path
                    print "mode", json.mode
                    json.mode = "text" if not json.mode?
                    @edit.setOption("mode", json.mode)
                    @edit.setValue(json.text)
                    @edit.clearHistory()
                    @edit.setOption("indentUnit", guess_indent(json.text))
                    if @filename of saved_pos
                        @edit.setCursor(saved_pos[@filename])
                    resize()
                    @update_url()

                    @edit.refresh()
                    print "settings", settings, @filename
                    if settings.files and
                       settings.files[@filename]
                        cursor = settings.files[@filename].cursor
                        scroll = settings.files[@filename].scroll
                        if cursor
                            @edit.setCursor(cursor.line, cursor.ch)
                        if scroll
                            @edit.scrollTo(0, scroll)

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

    scrolled: (e) =>
        #print @edit
        print @edit.getScrollInfo()

    moved: (e) =>
        #print @edit.getScrollInfo()


    save_pos: (e) =>

        if not settings.files?
            settings.files = {}
        if not settings.files[@filename]
            settings.files[@filename] = {}

        settings.files[@filename].cursor = @edit.getCursor()
        settings.files[@filename].scroll = @edit.getScrollInfo().y


        $.ajax "/settings_files"
            dataType: "json"
            type: "POST"
            data:
                path: @filename
                set: settings.files[@filename]
                r: Math.random()


goto_line = ->
    esc()
    $("#goto-box").show()
    $("#goto-input").focus()

open_file = ->
    esc()
    $("#open-box").show()
    $("#file-input").focus()

save_file = (pad) ->
    print "save"
    text = pad.edit.getValue()
    # strip trailing spaces

    tabsize = pad.edit.getOption('tabSize')
    space = (" " for _ in [0...tabsize]).join("")
    text = text.replace(/\t/g, space)
    text = text.replace(/[ \r]*\n/g,"\n").replace(/\s*$/g, "\n")
    $.ajax "/save",
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


resize()


key "ctr-l", -> open_file()
key "ctr-s", -> save_file(current_pad)
key "ctr-f", -> search(current_pad)
key "ctr-a", -> command()
key "ctr-y", -> goto_line()
key "esc", -> esc()

