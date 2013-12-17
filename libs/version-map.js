(function() {
  var Q, VersionMap, knox, semver, utils, _,
    __bind = function(fn, me){ return function(){ return fn.apply(me, arguments); }; };

  knox = require('knox');

  Q = require('q');

  _ = require('underscore');

  semver = require('semver');

  utils = require('./s3-utils');

  VersionMap = (function() {
    function VersionMap(options) {
      this.versionDirectory = __bind(this.versionDirectory, this);
      this.updateTag = __bind(this.updateTag, this);
      this.addVersion = __bind(this.addVersion, this);
      this.tagsMapToArray = __bind(this.tagsMapToArray, this);
      this.registryMapToArray = __bind(this.registryMapToArray, this);
      this.downloadTags = __bind(this.downloadTags, this);
      this.uploadTags = __bind(this.uploadTags, this);
      this.downloadRegistry = __bind(this.downloadRegistry, this);
      this.uploadRegistry = __bind(this.uploadRegistry, this);
      this.updateTagsFromRegistry = __bind(this.updateTagsFromRegistry, this);
      this.updateTags = __bind(this.updateTags, this);
      this.updateRegistry = __bind(this.updateRegistry, this);
      this.key = options.key;
      this.secret = options.secret;
      this.bucket = options.bucket || 'vtex-versioned';
      this.dryRun = options.dryRun;
      if (this.dryRun) {
        console.log('\nWARNING: VersionMap running in dry run mode. No changes will actually be made.\n');
      }
      this.s3Client = knox.createClient({
        key: this.key,
        secret: this.secret,
        bucket: this.bucket
      });
      this.registryPath = "registry/1/registry.json";
      this.tagsPath = "registry/1/tags.json";
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
          name: name,
          stable: {},
          next: {},
          beta: {},
          alpha: {}
        };
      }
      major = semver(version).major;
      tags[name][tag][major] = version;
      tags[name][tag].latest = version;
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
      return utils.uploadObject(registry, this.registryPath, this.s3Client, 1000 * 30, this.dryRun);
    };

    /*
    Returns a registry object.
    */


    VersionMap.prototype.downloadRegistry = function() {
      return utils.downloadObject(this.registryPath, this.s3Client);
    };

    /*
    Uploads a tags object to s3
    */


    VersionMap.prototype.uploadTags = function(tags) {
      return utils.uploadObject(tags, this.tagsPath, this.s3Client, 1000 * 30, this.dryRun);
    };

    /*
    Returns a tags object.
    */


    VersionMap.prototype.downloadTags = function() {
      return utils.downloadObject(this.tagsPath, this.s3Client);
    };

    /*
    Convert a registry map to an array of packages with registry info
    */


    VersionMap.prototype.registryMapToArray = function(registry) {
      return _.chain(registry).map(function(project) {
        project.versionsArray = _.map(project.versions, function(v) {
          return v;
        }).sort(function(v1, v2) {
          return semver.rcompare(v1.version, v2.version);
        });
        return project;
      }).sortBy(function(project) {
        return project.mostRecentVersionDate = (_.max(project.versions, function(version) {
          return new Date(version.created);
        }).created);
      }).value().reverse();
    };

    /*
    Convert a tags map to an array of packages with tags info
    */


    VersionMap.prototype.tagsMapToArray = function(tags) {
      return _.chain(tags).map(function(projectObj, projectName) {
        var project;
        project = {};
        project.name = projectName;
        project.tagsArray = _.map(projectObj, function(tags, tagName) {
          return {
            tag: tagName,
            versionsArray: _.map(tags, function(version, majorName) {
              return {
                major: majorName,
                version: version
              };
            })
          };
        });
        project.tagsArray = _.sortBy(project.tagsArray, function(v) {
          return v.tag.replace('stable', 'a').replace('next', 'ab').replace('beta', 'b').replace('alpha', 'c');
        });
        return project;
      }).sortBy(function(project) {
        return project.name;
      }).value();
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
    Returns the version name for the given package
    */


    VersionMap.prototype.versionName = function(packageObj) {
      return packageObj.version;
    };

    /*
    Returns the version directory for the given package
    */


    VersionMap.prototype.versionDirectory = function(packageObj) {
      return packageObj.name + "/" + this.versionName(packageObj);
    };

    return VersionMap;

  })();

  module.exports = VersionMap;

}).call(this);
