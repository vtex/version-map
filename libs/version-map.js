(function() {
  var Q, VersionMap, knox, semver, _,
    __bind = function(fn, me){ return function(){ return fn.apply(me, arguments); }; };

  knox = require('knox');

  Q = require('q');

  _ = require('underscore');

  semver = require('semver');

  VersionMap = (function() {
    VersionMap.prototype.version = '0.7.2';

    function VersionMap(options) {
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
      this.s3Client = knox.createClient({
        key: this.key,
        secret: this.secret,
        bucket: this.bucket
      });
      this.registryIndexPath = "index.json";
    }

    VersionMap.prototype.updateRegistryIndexJSON = function(registryIndexJSON, packageJSON, tag) {
      var packageAtIndex, packageObj, registryIndexObj, _base, _base1, _name;
      registryIndexObj = JSON.parse(registryIndexJSON);
      packageObj = JSON.parse(packageJSON);
      if (!packageObj.name) {
        throw new Error("Required property name not found");
      }
      if (!packageObj.version) {
        throw new Error("Required property version not found");
      }
      registryIndexObj[_name = packageObj.name] || (registryIndexObj[_name] = {});
      (_base = registryIndexObj[packageObj.name]).tags || (_base.tags = {});
      (_base1 = registryIndexObj[packageObj.name]).versions || (_base1.versions = {});
      packageAtIndex = registryIndexObj[packageObj.name];
      packageAtIndex.name = packageObj.name;
      if (packageObj.paths) {
        packageAtIndex.paths = packageObj.paths;
      }
      if (packageObj.hosts) {
        packageAtIndex.hosts = packageObj.hosts;
      }
      if (packageObj.main) {
        packageAtIndex.main = packageObj.main;
      }
      packageAtIndex.versions[packageObj.version] = {};
      packageAtIndex.versions[packageObj.version].created = new Date();
      if (tag) {
        packageAtIndex.tags[tag] = packageObj.version;
      }
      return JSON.stringify(registryIndexObj);
    };

    VersionMap.prototype.uploadRegistryIndex = function(registryIndexJSON) {
      var deferred, req, timeoutCallback, timeoutMillis;
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
        project.versionsArray = _.map(project.versions, function(v, k) {
          return {
            version: k,
            created: v.created
          };
        }).sort(function(v1, v2) {
          return semver.rcompare(v1.version, v2.version);
        });
        project.tagsArray = _.chain(project.tags).map(function(v, k) {
          return {
            tag: k,
            version: v
          };
        }).sortBy(function(v) {
          return v.tag.replace('stable', 'a').replace('beta', 'b').replace('alpha', 'c');
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

    return VersionMap;

  })();

  module.exports = VersionMap;

}).call(this);
