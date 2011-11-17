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
    throw "steve!" if res.socket.remoteAddress != "127.0.0.1"
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
