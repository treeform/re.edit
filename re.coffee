print = (args...) -> console.log(args...)

http = require("http")
express = require('express')
path = require("path")
fs = require("fs")
walk = require('walk')
events = require('events')
path = require('path')
child_process = require('child_process')

settings =
    base_dir: "/"

modes =
    '.js': "javascript"
    '.c': "text/x-csrc"
    '.tree': "scheme"
    '.py': "python"
    '.css': "css"
    '.scss': "css"
    '.mako': "htmlmixed"
    '.html': "htmlmixed"
    '.coffee': "coffeescript"

findem = (dir, s) ->
    ev = new events.EventEmitter
    if s.length > 0
        s = "-name '*#{s}*'"
    ls = child_process.exec(
        "find #{dir} #{s} -maxdepth 5")
    files = []
    ls.data = ""
    ls.stdout.on "data", (data) ->
        ls.data += data
    ls.on "exit", ->
        for line in ls.data.split("\n")
            if line.length > 0
                files.push(line)
        ev.emit("end", files)
    return ev

run_command = (cmd) ->
    ev = new events.EventEmitter
    op =
        maxBuffer: 1
    process = child_process.exec(cmd, op)
    print process.pid
    lines = []
    process.data = ""
    print process.stdout
    process.stdout.on "data", (data) ->
        print "next chunk"
        process.data += data
    process.on "exit", (code) ->
        process.code = code
        ev.emit("end", process)
    return ev

recent_files = []
opened_files = []


auth = (res) ->
    if res.socket.remoteAddress != "127.0.0.1"
        throw "steve!"

app = express.createServer()

app.configure ->
    app.use(express.methodOverride())
    app.use(express.bodyParser())
    app.use(app.router)

app.configure 'development', ->
    app.use express.static(__dirname + '/')
    app.use express.errorHandler
        dumpExceptions: true
        showStack: true

app.get '/exit', (req, res) ->
    auth(res)
    print "exit"
    #node.exit(0)

app.get '/suggest', (req, res) ->
    auth(res)
    s = req.param("s")
    dir = req.param("dir")
    print "s", s, "dir", dir
    finder = findem(dir, s)
    finder.on 'end', (files) ->
        files = (f for f in files when not f.match ("\.pyc|~|\.git|\.bzr$"))
        files.sort (a, b) ->
            al = a.length
            bl = b.length
            al -= 20 if a in recent_files
            bl -= 20 if b in recent_files
            return al - bl
        files = files[0..30]
        res.send(files.reverse())

app.get '/open', (req, res) ->
    auth(res)
    filename = req.param("path")
    print "load", filename
    if not filename
        return
    path.exists filename, (exists) ->
        ext = filename.match(/\.[^\.]*$/)
        mode = modes[ext]
        if not exists
            res.send
                mode: mode
                error: "file not found"
            return
        fs.readFile filename, "binary", (err, file) ->
            if err
                res.send
                    error: "reading file"
                return
            if filename not in recent_files
                recent_files.push(filename)
            opened_files.push(filename)
            res.send
                mode: mode
                path: filename
                text: file


app.post '/cmd', (req, res) ->
    auth(res)
    cmd = req.param("cmd")
    p = run_command(cmd)
    print ">", cmd
    p.on 'end', (p) ->
        print "exist code", p.code
        res.send
            text: p.data
            code: p.code

app.get '/start', (req, res) ->
    auth(res)
    res.send(settings)

app.post '/save', (req, res) ->
    auth(res)
    filename = req.param("path")
    print "save", filename
    text = req.body.text
    fs.writeFile filename, text, (err) ->
        if err
            throw err
    res.send({"done":text})

app.post '/settings', (req, res) ->
    auth(res)
    set = req.param("set")
    for name of set
        settings[name] = set[name]
    res.send("ok")
    print "set", set
    print " ->", settings

app.post '/settings_files', (req, res) ->
    auth(res)
    set = req.param("set")
    filename = req.param("path")

    if not settings.files?
        settings.files = {}

    if not settings.files[filename]?
        settings.files[filename] = {}

    for name of set
        settings.files[filename][name] = set[name]
    res.send("ok")
    print "set", set
    print " ->", settings


app.get /edit\/.*/, (req, res) ->
    print "here", req.url
    #path = req.url[6..]
    res.sendfile("index.html")

###
opts =
    host: 'localhost'
    port: 1988
    path: "/exit"

req = http.get(opts, (-> app.listen(1988)))
req.on 'error', ->
    print "error"
    app.listen(1988)
###

print "app listen"
app.listen(1989)

