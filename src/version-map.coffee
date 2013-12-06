knox = require 'knox'
Q = require 'q'
_ = require 'underscore'
semver = require 'semver'

class VersionMap
  constructor: (options) ->
    @key = options.key
    @secret = options.secret
    @bucket = options.bucket
    @dryRun = options.dryRun
    console.log '\nWARNING: VersionMap running in dry run mode. No changes will actually be made.\n' if @dryRun
    @s3Client = knox.createClient
      key: @key
      secret: @secret
      bucket: @bucket
    @registryIndexPath = "index.json"

  # Uploads this registryIndex object on the appropriate path, updating this project's key to the current version
  # packageJSON has two required properties: name and version
  updateRegistryIndexJSON: (registryIndexJSON, packageJSON, tag) =>
    registry = JSON.parse(registryIndexJSON)
    pkg = JSON.parse(packageJSON)

    throw new Error("Required property name not found") unless pkg.name
    throw new Error("Required property version not found") unless pkg.version
    throw new Error("Required property for creation backend not found") if not pkg.backend and pkg.hosts and pkg.paths

    # Check whether this project already exists
    unless registry[pkg.name]
      # Create this project
      registry[pkg.name] =
        name: pkg.name
        tags: {}
        versions: {}

    # Add updatable properties - these may be changed by future versions for the root project
    registry[pkg.name].backend = pkg.backend if pkg.backend
    registry[pkg.name].paths = pkg.paths if pkg.paths
    registry[pkg.name].hosts = pkg.hosts if pkg.hosts
    registry[pkg.name].main = pkg.main if pkg.main

    # Add new version to versions map
    registry[pkg.name].versions[pkg.version] = {}
    registry[pkg.name].versions[pkg.version].version = pkg.version
    registry[pkg.name].versions[pkg.version].created = new Date()
    registry[pkg.name].versions[pkg.version].rootRewrite = @versionDirectory(pkg)

    # Add or change tag, if available
    if tag
      registry[pkg.name].tags[tag] = pkg.version # e.g. "stable": "1.0.0"

    return JSON.stringify(registry)

  uploadRegistryIndex: (registryIndexJSON) =>
    if @dryRun
      console.log '\nWARNING: VersionMap running in dry run mode. No changes were actually made.\n'
      return Q(registryIndexJSON)

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

  ###
  Returns a buffer with the index contents. You should JSON.parse() it.
  ###
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
      else
        deferred.reject new Error("Failed to download registry index at #{@registryIndexPath}. Status: #{res.statusCode}")

    req.end()
    return deferred.promise

  getRegistryJSON: =>
    @downloadRegistryIndex().then (registryIndexBuffer) -> JSON.parse registryIndexBuffer

  getRegistryAsArray: =>
    @getRegistryJSON().then (registryMap) => @registryMapToArray(registryMap)

  ###
  Convert a registryMap to an array of products
  ###
  registryMapToArray: (registry) =>
    _.chain(registry)
      # Create an array with each product's object value
      .map((project) ->
        project.versionsArray = _.map(project.versions, (v) -> v).sort((v1, v2) -> semver.rcompare(v1.version, v2.version))
        project.tagsArray = _.chain(project.tags).map((v, k) -> {tag: k, version: v}).sortBy((v) -> v.tag.replace('stable', 'a').replace('next', 'ab').replace('beta', 'b').replace('alpha', 'c')).value()
        project
      )
      # Sort By most recent version in each project, and insert this information in the project object
      .sortBy((project) -> project.mostRecentVersionDate = (_.max(project.versions, (version) ->  new Date(version.created)).created))
      # Extract value from chain
      .value()
      # Sort by gives us ascending order, we need descending
      .reverse()

  ###
  Updates version at the index, changing the provided tag, if any.
  ###
  updateVersion: (packageJSON, tag) =>
    @downloadRegistryIndex().then (registryIndexBuffer) =>
      updatedRegistryIndexJSON = @updateRegistryIndexJSON(registryIndexBuffer, packageJSON, tag)
      @uploadRegistryIndex(updatedRegistryIndexJSON)
    .fail (err) ->
      console.log "Could not update registry index!", err
      err

  ###
  Returns the version name for the given package
  ###
  versionName: (packageObj) ->
    packageObj.version

  ###
  Returns the version directory for the given package
  ###
  versionDirectory: (packageObj) =>
    packageObj.name + "/" +  @versionName(packageObj)

module.exports = VersionMap