(function() {
  var Q, VersionMap, knox, semver, _,
    __bind = function(fn, me){ return function(){ return fn.apply(me, arguments); }; };

  knox = require('knox');

  Q = require('q');

  _ = require('underscore');

  semver = require('semver');

  VersionMap = (function() {
    VersionMap.prototype.version = '0.8.0';

    function VersionMap(options) {
      this.versionDirectory = __bind(this.versionDirectory, this);
      this.updateVersion = __bind(this.updateVersion, this);
      this.registryMapToArray = __bind(this.registryMapToArray, this);
      this.getRegistryAsArray = __bind(this.getRegistryAsArray, this);
      this.getRegistryJSON = __bind(this.getRegistryJSON, this);
      this.downloadRegistryIndex = __bind(this.downloadRegistryIndex, this);
      this.uploadRegistryIndex = __bind(this.uploadRegistryIndex, this);
      this.updateRegistryIndexJSON = __bind(this.updateRegistryIndexJSON, this);
      this.key = options.key;
      this.secret = options.secret;
      this.bucket = options.bucket;
      this.dryRun = options.dryRun;
      if (this.dryRun) {
        console.log('\nWARNING: VersionMap running in dry run mode. No changes will actually be made.\n');
      }
      this.s3Client = knox.createClient({
        key: this.key,
        secret: this.secret,
        bucket: this.bucket
      });
      this.registryIndexPath = "index.json";
    }

    VersionMap.prototype.updateRegistryIndexJSON = function(registryIndexJSON, packageJSON, tag) {
      var pkg, registry;
      registry = JSON.parse(registryIndexJSON);
      pkg = JSON.parse(packageJSON);
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
          tags: {},
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
      if (tag) {
        registry[pkg.name].tags[tag] = pkg.version;
      }
      return JSON.stringify(registry);
    };

    VersionMap.prototype.uploadRegistryIndex = function(registryIndexJSON) {
      var deferred, req, timeoutCallback, timeoutMillis;
      if (this.dryRun) {
        console.log('\nWARNING: VersionMap running in dry run mode. No changes were actually made.\n');
        return Q(registryIndexJSON);
      }
      deferred = Q.defer();
      req = this.s3Client.put(this.registryIndexPath, {
        "Content-Length": registryIndexJSON.length,
        "Content-Type": "application/json"
      });
      timeoutMillis = 1000 * 30;
      timeoutCallback = function() {
        req.abort();
        return deferred.reject(new Error("Timeout exceeded when uploading registry index at " + this.registryIndexPath));
      };
      req.setTimeout(timeoutMillis, timeoutCallback);
      req.on("error", function(err) {
        return deferred.reject(new Error(err));
      });
      req.on("response", function(res) {
        if (200 === res.statusCode) {
          console.log("Version updated at " + req.url);
          return deferred.resolve(registryIndexJSON);
        } else {
          return deferred.reject(new Error("Failed to upload registry index at " + this.registryIndexPath));
        }
      });
      req.end(registryIndexJSON);
      return deferred.promise;
    };

    /*
    Returns a buffer with the index contents. You should JSON.parse() it.
    */


    VersionMap.prototype.downloadRegistryIndex = function() {
      var deferred, req, timeoutCallback, timeoutMillis;
      deferred = Q.defer();
      req = this.s3Client.get(this.registryIndexPath);
      timeoutMillis = 1000 * 30;
      timeoutCallback = function() {
        req.abort();
        return deferred.reject(new Error("Timeout exceeded when downloading registry index at " + this.registryIndexPath));
      };
      req.setTimeout(timeoutMillis, timeoutCallback);
      req.on("error", function(err) {
        return deferred.reject(err);
      });
      req.on("response", function(res) {
        if (res.statusCode === 404) {
          console.warn("No such registry index file available: " + this.registryIndexPath + ". Creating one now.");
          return deferred.resolve("{}");
        } else if (res.statusCode === 200) {
          return res.on('data', function(chunk) {
            return deferred.resolve(chunk);
          });
        }
      });
      req.end();
      return deferred.promise;
    };

    VersionMap.prototype.getRegistryJSON = function() {
      return this.downloadRegistryIndex().then(function(registryIndexBuffer) {
        return JSON.parse(registryIndexBuffer);
      });
    };

    VersionMap.prototype.getRegistryAsArray = function() {
      var _this = this;
      return this.getRegistryJSON().then(function(registryMap) {
        return _this.registryMapToArray(registryMap);
      });
    };

    /*
    Convert a registryMap to an array of products
    */


    VersionMap.prototype.registryMapToArray = function(registry) {
      return _.chain(registry).map(function(project) {
        project.versionsArray = _.map(project.versions, function(v) {
          return v;
        }).sort(function(v1, v2) {
          return semver.rcompare(v1.version, v2.version);
        });
        project.tagsArray = _.chain(project.tags).map(function(v, k) {
          return {
            tag: k,
            version: v
          };
        }).sortBy(function(v) {
          return v.tag.replace('stable', 'a').replace('next', 'ab').replace('beta', 'b').replace('alpha', 'c');
        }).value();
        return project;
      }).sortBy(function(project) {
        return project.mostRecentVersionDate = (_.max(project.versions, function(version) {
          return new Date(version.created);
        }).created);
      }).value().reverse();
    };

    /*
    Updates version at the index, changing the provided tag, if any.
    */


    VersionMap.prototype.updateVersion = function(packageJSON, tag) {
      var _this = this;
      return this.downloadRegistryIndex().then(function(registryIndexBuffer) {
        var updatedRegistryIndexJSON;
        updatedRegistryIndexJSON = _this.updateRegistryIndexJSON(registryIndexBuffer, packageJSON, tag);
        return _this.uploadRegistryIndex(updatedRegistryIndexJSON);
      }).fail(function(err) {
        console.log("Could not update registry index!", err);
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
