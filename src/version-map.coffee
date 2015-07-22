AWS = require 'aws-sdk'
Q = require 'q'
_ = require 'underscore'
semver = require 'semver'
utils = require './s3-utils'

class VersionMap
  constructor: (options) ->
    @s3Client = new AWS.S3()
    @bucket = options.bucket or 'vtex-versioned'
    @dryRun = options.dryRun
    console.log '\nWARNING: VersionMap running in dry run mode. No changes will actually be made.\n' if @dryRun
    @registryPath = "registry/v2/registry.json"
    @tagsPath = "tags/v2/tags.json"

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
        stable: {}
        next: {}
        beta: {}
        alpha: {}

    major = semver(version).major
    tags[name][tag][major] = version

    return tags

  # Removes this major from the tags map
  removeMajorFromTags: (tags, name, major, tag) =>
    throw new Error("Required property name is null or undefined") unless name
    throw new Error("Required property major is null or undefined") unless major
    throw new Error("Required property tag is null or undefined") unless tag
    throw new Error("Tag must be one of: stable, next, beta, alpha") unless tag in ["stable", "next", "beta", "alpha"]

    delete tags[name][tag][major]

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
  uploadRegistry: (registry) => utils.putObject(registry, @s3Client, @bucket, @registryPath, @dryRun)

  ###
  Returns a registry object.
  ###
  downloadRegistry: => utils.getObject(@s3Client, @bucket, @registryPath)

  ###
  Uploads a tags object to s3
  ###
  uploadTags: (tags) =>
    utils.putObject(tags, @s3Client, @bucket, @tagsPath, @dryRun)

  ###
  Returns a tags object.
  ###
  downloadTags: => utils.getObject(@s3Client, @bucket, @tagsPath)

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
  Removes major from this tag in tags object
  ###
  removeMajor: (name, major, tag) =>
    @downloadTags().then (tags) =>
      updatedTags = @removeMajorFromTags(tags, name, major, tag)
      @uploadTags(updatedTags)
    .fail (err) ->
      console.log "Could not remove major from tags", err
      err

  ###
  Returns the version directory for the given package
  ###
  versionDirectory: (packageObj) =>
    packageObj.name + "/" +  packageObj.version

module.exports = VersionMap
