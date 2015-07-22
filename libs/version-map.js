(function() {
  var AWS, Q, VersionMap, semver, utils, _,
    __bind = function(fn, me){ return function(){ return fn.apply(me, arguments); }; };

  AWS = require('aws-sdk');

  Q = require('q');

  _ = require('underscore');

  semver = require('semver');

  utils = require('./s3-utils');

  VersionMap = (function() {
    function VersionMap(options) {
      this.versionDirectory = __bind(this.versionDirectory, this);
      this.removeMajor = __bind(this.removeMajor, this);
      this.updateTag = __bind(this.updateTag, this);
      this.addVersion = __bind(this.addVersion, this);
      this.downloadTags = __bind(this.downloadTags, this);
      this.uploadTags = __bind(this.uploadTags, this);
      this.downloadRegistry = __bind(this.downloadRegistry, this);
      this.uploadRegistry = __bind(this.uploadRegistry, this);
      this.updateTagsFromRegistry = __bind(this.updateTagsFromRegistry, this);
      this.removeMajorFromTags = __bind(this.removeMajorFromTags, this);
      this.updateTags = __bind(this.updateTags, this);
      this.updateRegistry = __bind(this.updateRegistry, this);
      this.s3Client = new AWS.S3();
      this.bucket = options.bucket || 'vtex-versioned';
      this.dryRun = options.dryRun;
      if (this.dryRun) {
        console.log('\nWARNING: VersionMap running in dry run mode. No changes will actually be made.\n');
      }
      this.registryPath = "registry/v2/registry.json";
      this.tagsPath = "tags/v2/tags.json";
    }

    VersionMap.prototype.updateRegistry = function(registry, pkg) {
      if (!pkg.name) {
        throw new Error("Required property name not found");
      }
      if (!pkg.version) {
        throw new Error("Required property version not found");
      }
      if (!pkg.backend && pkg.hosts && pkg.paths) {
        throw new Error("Required property for creation backend not found");
      }
      if (!registry[pkg.name]) {
        registry[pkg.name] = {
          name: pkg.name,
          versions: {}
        };
      }
      if (pkg.backend) {
        registry[pkg.name].backend = pkg.backend;
      }
      if (pkg.paths) {
        registry[pkg.name].paths = pkg.paths;
      }
      if (pkg.hosts) {
        registry[pkg.name].hosts = pkg.hosts;
      }
      if (pkg.main) {
        registry[pkg.name].main = pkg.main;
      }
      registry[pkg.name].versions[pkg.version] = {};
      registry[pkg.name].versions[pkg.version].version = pkg.version;
      registry[pkg.name].versions[pkg.version].created = new Date();
      registry[pkg.name].versions[pkg.version].rootRewrite = this.versionDirectory(pkg);
      return registry;
    };

    VersionMap.prototype.updateTags = function(tags, name, version, tag) {
      var major;
      if (!name) {
        throw new Error("Required property name is null or undefined");
      }
      if (!version) {
        throw new Error("Required property version is null or undefined");
      }
      if (!tag) {
        throw new Error("Required property tag is null or undefined");
      }
      if (tag !== "stable" && tag !== "next" && tag !== "beta" && tag !== "alpha") {
        throw new Error("Tag must be one of: stable, next, beta, alpha");
      }
      if (!tags[name]) {
        tags[name] = {
          stable: {},
          next: {},
          beta: {},
          alpha: {}
        };
      }
      major = semver(version).major;
      tags[name][tag][major] = version;
      return tags;
    };

    VersionMap.prototype.removeMajorFromTags = function(tags, name, major, tag) {
      if (!name) {
        throw new Error("Required property name is null or undefined");
      }
      if (!major) {
        throw new Error("Required property major is null or undefined");
      }
      if (!tag) {
        throw new Error("Required property tag is null or undefined");
      }
      if (tag !== "stable" && tag !== "next" && tag !== "beta" && tag !== "alpha") {
        throw new Error("Tag must be one of: stable, next, beta, alpha");
      }
      delete tags[name][tag][major];
      return tags;
    };

    VersionMap.prototype.updateTagsFromRegistry = function(tags, registry) {
      var biggest, majorName, majors, project, projectName, tagName, tagNames;
      for (projectName in registry) {
        project = registry[projectName];
        tagNames = _.groupBy(project.versions, function(v) {
          return semver(v.version).prerelease[0] || 'stable';
        });
        for (tagName in tagNames) {
          majors = _.groupBy(tagNames[tagName], function(v) {
            return semver(v.version).major;
          });
          for (majorName in majors) {
            biggest = majors[majorName].sort(function(a, b) {
              return semver.rcompare(a.version, b.version);
            })[0];
            tags = this.updateTags(tags, projectName, biggest.version, tagName);
          }
        }
      }
      return tags;
    };

    /*
    Uploads a registry object to s3
    */


    VersionMap.prototype.uploadRegistry = function(registry) {
      return utils.putObject(registry, this.s3Client, this.bucket, this.registryPath, this.dryRun);
    };

    /*
    Returns a registry object.
    */


    VersionMap.prototype.downloadRegistry = function() {
      return utils.getObject(this.s3Client, this.bucket, this.registryPath);
    };

    /*
    Uploads a tags object to s3
    */


    VersionMap.prototype.uploadTags = function(tags) {
      return utils.putObject(tags, this.s3Client, this.bucket, this.tagsPath, this.dryRun);
    };

    /*
    Returns a tags object.
    */


    VersionMap.prototype.downloadTags = function() {
      return utils.getObject(this.s3Client, this.bucket, this.tagsPath);
    };

    /*
    Adds version to the registry
    */


    VersionMap.prototype.addVersion = function(pack) {
      var _this = this;
      return this.downloadRegistry().then(function(registry) {
        var updatedRegistry;
        updatedRegistry = _this.updateRegistry(registry, pack);
        return _this.uploadRegistry(updatedRegistry);
      }).fail(function(err) {
        console.log("Could not update registry", err);
        return err;
      });
    };

    /*
    Updates tag in tags object
    */


    VersionMap.prototype.updateTag = function(name, version, tag) {
      var _this = this;
      return this.downloadTags().then(function(tags) {
        var updatedTags;
        updatedTags = _this.updateTags(tags, name, version, tag);
        return _this.uploadTags(updatedTags);
      }).fail(function(err) {
        console.log("Could not update tags", err);
        return err;
      });
    };

    /*
    Removes major from this tag in tags object
    */


    VersionMap.prototype.removeMajor = function(name, major, tag) {
      var _this = this;
      return this.downloadTags().then(function(tags) {
        var updatedTags;
        updatedTags = _this.removeMajorFromTags(tags, name, major, tag);
        return _this.uploadTags(updatedTags);
      }).fail(function(err) {
        console.log("Could not remove major from tags", err);
        return err;
      });
    };

    /*
    Returns the version directory for the given package
    */


    VersionMap.prototype.versionDirectory = function(packageObj) {
      return packageObj.name + "/" + packageObj.version;
    };

    return VersionMap;

  })();

  module.exports = VersionMap;

}).call(this);
