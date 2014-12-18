{_, child_process, async, SSHConnection} = app.libs
{config, logger} = app
{available_plugins} = config.plugin

module.exports = class Node
  name: ''
  master: false
  available_components: []

  @nodes = {}

  @initNodes: ->
    for name, info of config.nodes
      @nodes[name] = new Node _.extend info,
        name: name

    return @nodes

  @get: (name) ->
    return @nodes[name]

  constructor: (@info) ->
    _.extend @, info

    for component_type in @available_components
      unless component_type in available_plugins
        err = new Error "Node:#{@name} include unknown Component:#{component_type}"
        logger.fatal err
        throw err

  # @param callback(err, stdout, stderr)
  runCommand: (command, callback) ->
    unless @master
      return @runCommandRemote command, callback

    child_process.exec command, (err, stdout, stderr) ->
      callback err, stdout, stderr

  # @param options: args, stdin
  # @param callback(err, stdout, stderr)
  exec: (command, options, callback) ->
    {args, stdin} = options
    args ?= []

    stdout = ''
    stderr = ''
    error = null

    proc = child_process.spawn command, args

    if stdin
      proc.stdin.end stdin

    proc.on 'error', (err) ->
      error = err

    proc.stdout.on 'data', (data) ->
      stdout += data

    proc.stderr.on 'data', (data) ->
      stderr += data

    proc.on 'exit', ->
      callback error, stdout, stderr

  # @param options: mode, owner
  writeFile: (filename, body, options, callback) ->
    unless @master
      return @writeFileRemote filename, body, options, callback

    {mode, owner} = options

    async.auto
      touch: (callback) ->
        child_process.exec "sudo touch #{filename}", (err) ->
          callback err

      chmod: ['touch', (callback) ->
        unless mode
          return callback()

        child_process.exec "sudo chmod #{mode} #{filename}", (err) ->
          callback err
      ]

      chown: ['touch', (callback) ->
        unless owner
          return callback()

        child_process.exec "sudo chown #{owner}:#{owner} #{filename}", (err) ->
          callback err
      ]

      tee: ['chmod', 'chown', (callback) =>
        @exec 'sudo',
          args: ['tee', filename]
          stdin: body
        , callback
      ]

    , callback

  # @param callback(err, body)
  readFile: (filename, callback) ->
    unless @master
      return @readFileRemote filename, callback

    @runCommand "sudo cat #{filename}", (err, stdout) ->
      callback err, stdout

  connectRemote: (callback) ->
    connection = new SSHConnection()

    connection.on 'ready', ->
      callback connection

    connection.connect
      host: @info.host
      username: 'rpadmin'
      privateKey: fs.readFileSync '/home/rpadmin/.ssh/id_rsa'

  runCommandRemote: (command, callback) ->
    @execRemote command, {}, callback

  execRemote: (command, options, callback) ->
    {args, stdin} = options
    args ?= []

    command = "#{command} #{args.join(' ')}"

    stdout = ''
    stderr = ''

    @connectRemote (connection) ->
      connection.exec command, (err, stream) ->
        return callback err if err

        if stdin
          stream.end stdin

        stream.on 'data', (data) ->
          stdout += data

        stream.stderr.on 'data', (data) ->
          stderr += data.toString()

        stream.on 'close', ->
          connection.end()
          callback err, stdout, stderr

  writeFileRemote: (filename, body, options, callback) ->
    {mode, owner} = options

    async.auto
      touch: (callback) =>
        @runCommandRemote "sudo touch #{filename}", (err) ->
          callback err

      chmod: ['touch', (callback) =>
        unless mode
          return callback()

        @runCommandRemote "sudo chmod #{mode} #{filename}", (err) ->
          callback err
      ]

      chown: ['touch', (callback) =>
        unless owner
          return callback()

        @runCommandRemote "sudo chown #{owner}:#{owner} #{filename}", (err) ->
          callback err
      ]

      tee: ['chmod', 'chown', (callback) =>
        @execRemote 'sudo',
          args: ['tee', filename]
          stdin: body
        , callback
      ]

    , callback

  readFileRemote: (filename, callback) ->
    @runCommandRemote "sudo cat #{filename}", (err, stdout) ->
      callback err, stdout
