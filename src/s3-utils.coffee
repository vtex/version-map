Q = require('q')
###
Uploads a object to s3
###
exports.uploadObject = (obj, path, client, timeoutMillis = 1000*30, dryRun = false) =>
  json = JSON.stringify(obj)
  if dryRun
    console.log '\nWARNING: Running in dry run mode. No upload was actually made.\n'
    return Q(obj)

  deferred = Q.defer()
  headers = "Content-Length": json.length, "Content-Type": "application/json"
  req = client.put path, headers

  timeoutCallback = ->
    req.abort()
    deferred.reject new Error("Timeout exceeded when uploading #{path}")

  req.setTimeout timeoutMillis, timeoutCallback

  req.on "error", (err) ->
    deferred.reject new Error(err)

  req.on "response", (res) ->
    if 200 is res.statusCode
      console.log "Upload at #{req.url} successful."
      deferred.resolve obj
    else
      deferred.reject new Error("Failed to upload #{path}. Status: #{res.statusCode}")

  req.end json
  return deferred.promise

###
Returns a object from s3. If none is found at this path, an empty object is returned.
###
exports.downloadObject = (path, client, timeoutMillis = 1000*30) =>
  deferred = Q.defer()
  req = client.get(path)

  timeoutCallback = ->
    req.abort()
    deferred.reject new Error("Timeout exceeded when downloading #{path}")

  req.setTimeout timeoutMillis, timeoutCallback

  req.on "error", (err) ->
    deferred.reject err

  req.on "response", (res) =>
    data = ''
    if res.statusCode is 404
      console.warn "No object found at #{path}."
      deferred.resolve {}
    else if res.statusCode is 200
      res.on 'data', (chunk) ->
        data += chunk
      res.on 'end', ->
        try
          obj = JSON.parse(data)
          deferred.resolve obj
        catch e
          console.error e
          deferred.reject e
    else
      deferred.reject new Error("Failed to download #{path}. Status: #{res.statusCode}")

  req.end()
  return deferred.promise