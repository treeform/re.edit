print = (args...) -> console.log(args...)

http = require("http")
express = require('express')
path = require("path")
fs = require("fs")
walk = require('walk')
events = require('events')
path = require('path')
child_process = require('child_process')

modes =
    '.js': "javascript"
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
    ls.stdout.on "data", (data) ->
        for line in data.split("\n")
            if line.length > 0
                files.push(line)
    ls.on "exit", -> ev.emit("end", files)
    return ev

recent_files = []
opened_files = []

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
    throw "steve!" if res.socket.remoteAddress != "127.0.0.1"
    print "exit"
    #node.exit(0)

app.get '/suggest', (req, res) ->
    throw "steve!" if res.socket.remoteAddress != "127.0.0.1"
    s = req.param("s")
    m = s.match("(.*)/([^/]*$)")
    if m
        dir = m[1]
        s = m[2]
    else
        dir = process.cwd()
    finder = findem(dir, s)
    finder.on 'end', (files) ->
        files = (f for f in files when not f.match ("\.pyc|~|\.git|\.bzr$"))
        files.sort (a, b) ->
            al = a.length
            bl = b.length
            al -= 20 if a in recent_files
            bl -= 20 if b in recent_files
            return al - bl
        files = files[0..10]
        res.send(files.reverse())

app.get '/open', (req, res) ->
    throw "steve!" if res.socket.remoteAddress != "127.0.0.1"
    filename = req.param("path")
    print "load", filename
    path.exists filename, (exists) ->
        if not exists
            res.send
                error: "file not found"
            return
        fs.readFile filename, "binary", (err, file) ->
            if err
                res.send
                    error: "reading file"
                return
            ext = filename.match(/\.[^\.]*$/)
            if filename not in recent_files
                recent_files.push(filename)
            opened_files.push(filename)
            res.send
                mode: modes[ext]
                path: filename
                text: file

app.get '/start', (req, res) ->
    throw "steve!" if res.socket.remoteAddress != "127.0.0.1"
    res.send
        "opened_files": opened_files

app.post '/save', (req, res) ->
    throw "steve!" if res.socket.remoteAddress != "127.0.0.1"
    filename = req.param("path")
    print "save", filename
    text = req.body.text
    fs.writeFile filename, text, (err) ->
        if err
            throw err

    m = filename.match("(.*)/([^/]*$)")
    if m
        dir = m[1]
        process.chdir(dir)
    res.send({"done":text})

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
app.listen(1988)
