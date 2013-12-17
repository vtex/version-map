knox = require 'knox'
Q = require 'q'
_ = require 'underscore'
semver = require 'semver'
utils = require './s3-utils'

class VersionMap
  constructor: (options) ->
    @key = options.key
    @secret = options.secret
    @bucket = options.bucket or 'vtex-versioned'
    @dryRun = options.dryRun
    console.log '\nWARNING: VersionMap running in dry run mode. No changes will actually be made.\n' if @dryRun
    @s3Client = knox.createClient
      key: @key
      secret: @secret
      bucket: @bucket
    @registryPath = "registry/1/registry.json"
    @tagsPath = "registry/1/tags.json"

  # Updates the registry with the pkg package informations
  # Package has two required properties: name and version
  updateRegistry: (registry, pkg) =>
    throw new Error("Required property name not found") unless pkg.name
    throw new Error("Required property version not found") unless pkg.version
    throw new Error("Required property for creation backend not found") if not pkg.backend and pkg.hosts and pkg.paths

    # Check whether this project already exists
    unless registry[pkg.name]
      registry[pkg.name] =
        name: pkg.name
        versions: {}

    # Add updatable properties - these may be changed by future versions for the root project
    registry[pkg.name].backend = pkg.backend if pkg.backend
    registry[pkg.name].paths = pkg.paths if pkg.paths
    registry[pkg.name].hosts = pkg.hosts if pkg.hosts
    registry[pkg.name].main = pkg.main if pkg.main

    # Add new version to version map
    registry[pkg.name].versions[pkg.version] = {}
    registry[pkg.name].versions[pkg.version].version = pkg.version
    registry[pkg.name].versions[pkg.version].created = new Date()
    registry[pkg.name].versions[pkg.version].rootRewrite = @versionDirectory(pkg)

    return registry

  # Updates the tags map with the provided informations
  updateTags: (tags, name, version, tag) =>
    throw new Error("Required property name is null or undefined") unless name
    throw new Error("Required property version is null or undefined") unless version
    throw new Error("Required property tag is null or undefined") unless tag
    throw new Error("Tag must be one of: stable, next, beta, alpha") unless tag in ["stable", "next", "beta", "alpha"]

    # Check whether this project already exists
    unless tags[name]
      tags[name] =
        name: name
        stable: {}
        next: {}
        beta: {}
        alpha: {}

    major = semver(version).major
    tags[name][tag][major] = version
    tags[name][tag].latest = version

    return tags

  # Updates the tags map with the latest versions from the registry
  updateTagsFromRegistry: (tags, registry) =>
    for projectName, project of registry
      tagNames = _.groupBy project.versions, (v) -> semver(v.version).prerelease[0] or 'stable'
      for tagName of tagNames
        majors = _.groupBy tagNames[tagName], (v) -> semver(v.version).major
        for majorName of majors
          biggest = majors[majorName].sort((a,b) -> semver.rcompare(a.version, b.version))[0]
          tags = @updateTags(tags, projectName, biggest.version, tagName)

    return tags

  ###
  Uploads a registry object to s3
  ###
  uploadRegistry: (registry) =>
    utils.uploadObject(registry, @registryPath, @s3Client, 1000*30, @dryRun)

  ###
  Returns a registry object.
  ###
  downloadRegistry: =>
    utils.downloadObject(@registryPath, @s3Client)

  ###
  Uploads a tags object to s3
  ###
  uploadTags: (tags) =>
    utils.uploadObject(tags, @tagsPath, @s3Client, 1000*30, @dryRun)

  ###
  Returns a tags object.
  ###
  downloadTags: =>
    utils.downloadObject(@tagsPath, @s3Client)

  ###
  Convert a registry map to an array of packages with registry info
  ###
  registryMapToArray: (registry) =>
    _.chain(registry)
      # Create an array with each product's object value
      .map((project) ->
        project.versionsArray = _.map(project.versions, (v) -> v).sort((v1, v2) -> semver.rcompare(v1.version, v2.version))
        project
      )
      # Sort By most recent version in each project, and insert this information in the project object
      .sortBy((project) -> project.mostRecentVersionDate = (_.max(project.versions, (version) ->  new Date(version.created)).created))
      # Extract value from chain
      .value()
      # In descending order
      .reverse()

  ###
  Convert a tags map to an array of packages with tags info
  ###
  tagsMapToArray: (tags) =>
    _.chain(tags)
      # Create an array with each product's object value
      .map((projectObj, projectName) ->
        project = {}
        project.name = projectName

        # Map each tag on this project (stable, next, beta, alpha) to an object on this array
        project.tagsArray = _.map projectObj, (tags, tagName) ->
          tag: tagName,
          # Map each major on this tag (1, 2, latest) to an object on this array
          versionsArray: _.map tags, (version, majorName) -> major: majorName, version: version

        project.tagsArray = _.sortBy(project.tagsArray, (v) ->
          v.tag.replace('stable', 'a').replace('next', 'ab').replace('beta', 'b').replace('alpha', 'c'))

        return project
      )
      # Sort by name
      .sortBy((project) -> project.name)
      # Extract value from chain
      .value()

  ###
  Adds version to the registry
  ###
  addVersion: (pack) =>
    @downloadRegistry().then (registry) =>
      updatedRegistry = @updateRegistry(registry, pack)
      @uploadRegistry(updatedRegistry)
    .fail (err) ->
      console.log "Could not update registry", err
      err

  ###
  Updates tag in tags object
  ###
  updateTag: (name, version, tag) =>
    @downloadTags().then (tags) =>
      updatedTags = @updateTags(tags, name, version, tag)
      @uploadTags(updatedTags)
    .fail (err) ->
      console.log "Could not update tags", err
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