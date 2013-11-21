knox = require 'knox'
Q = require 'q'
_ = require 'underscore'

class VersionMap
  version: 'VERSION_NUMBER'
  constructor: (options) ->
    @key = options.key
    @secret = options.secret
    @bucket = options.bucket
    @s3Client = knox.createClient
      key: @key
      secret: @secret
      bucket: @bucket
    @registryIndexPath = "index.json"

  # Uploads this registryIndex object on the appropriate path, updating this project's key to the current version
  updateRegistryIndexJSON: (registryIndexJSON, packageJSON, tag) =>
    registryIndexObj = JSON.parse(registryIndexJSON)
    packageObj = JSON.parse(packageJSON)
    # Create the object for this project if not available
    registryIndexObj[packageObj.name] or= {}
    registryIndexObj[packageObj.name].tags or= {}
    registryIndexObj[packageObj.name].versions or= {}

    packageAtIndex = registryIndexObj[packageObj.name]
    packageAtIndex.name = packageObj.name
    packageAtIndex.paths = packageObj.paths
    packageAtIndex.hosts = packageObj.hosts
    packageAtIndex.main = packageObj.main
    packageAtIndex.tags[tag] = packageObj.version # e.g. "stable": "1.0.0"
    packageAtIndex.versions[packageObj.version] = {}
    packageAtIndex.versions[packageObj.version].created = new Date()

    return JSON.stringify(registryIndexObj)

  uploadRegistryIndex: (registryIndexJSON) =>
    deferred = Q.defer()
    req = @s3Client.put(@registryIndexPath,
      "Content-Length": registryIndexJSON.length
      "Content-Type": "application/json"
    )

    # Let's not wait for more than 30 seconds to fail the build if there is no response to the upload request
    timeoutMillis = 1000 * 30
    timeoutCallback = ->
      req.abort()
      deferred.reject new Error("Timeout exceeded when uploading registry index at #{@registryIndexPath}")

    req.setTimeout timeoutMillis, timeoutCallback

    req.on "error", (err) ->
      deferred.reject new Error(err)

    req.on "response", (res) ->
      if 200 is res.statusCode
        console.log "Version updated at #{req.url}"
        deferred.resolve registryIndexJSON
      else
        deferred.reject new Error("Failed to upload registry index at #{@registryIndexPath}")

    req.end registryIndexJSON
    return deferred.promise

  downloadRegistryIndex: =>
    deferred = Q.defer()
    req = @s3Client.get(@registryIndexPath)

    # Let's not wait for more than 30 seconds to fail the build if there is no response to the download request
    timeoutMillis = 1000 * 30
    timeoutCallback = ->
      req.abort()
      deferred.reject new Error("Timeout exceeded when downloading registry index at #{@registryIndexPath}")

    req.setTimeout timeoutMillis, timeoutCallback

    req.on "error", (err) ->
      deferred.reject err

    req.on "response", (res) ->
      if res.statusCode is 404
        console.warn "No such registry index file available: #{@registryIndexPath}. Creating one now."
        deferred.resolve "{}"
      else if res.statusCode is 200
        res.on 'data', (chunk) ->
          deferred.resolve chunk

    req.end()
    return deferred.promise

  updateVersion: (environmentType, packageJSON) =>
    @downloadRegistryIndex().then (registryIndexJSON) =>
      updatedRegistryIndexJSON = @updateRegistryIndexJSON(registryIndexJSON, packageJSON, environmentType)
      @uploadRegistryIndex(updatedRegistryIndexJSON)
    .fail (err) ->
      console.err "Could not update registry index!", err

module.exports = VersionMap