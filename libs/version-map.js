(function() {
  var Q, VersionMap, knox, _,
    __bind = function(fn, me){ return function(){ return fn.apply(me, arguments); }; };

  knox = require('knox');

  Q = require('q');

  _ = require('underscore');

  VersionMap = (function() {
    VersionMap.prototype.version = '0.4.0';

    function VersionMap(options) {
      this.updateVersion = __bind(this.updateVersion, this);
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
      registryIndexObj[_name = packageObj.name] || (registryIndexObj[_name] = {});
      (_base = registryIndexObj[packageObj.name]).tags || (_base.tags = {});
      (_base1 = registryIndexObj[packageObj.name]).versions || (_base1.versions = {});
      packageAtIndex = registryIndexObj[packageObj.name];
      packageAtIndex.name = packageObj.name;
      packageAtIndex.paths = packageObj.paths;
      packageAtIndex.hosts = packageObj.hosts;
      packageAtIndex.main = packageObj.main;
      packageAtIndex.tags[tag] = packageObj.version;
      packageAtIndex.versions[packageObj.version] = {};
      packageAtIndex.versions[packageObj.version].created = new Date();
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

    VersionMap.prototype.updateVersion = function(environmentType, packageJSON) {
      var _this = this;
      return this.downloadRegistryIndex().then(function(registryIndexJSON) {
        var updatedRegistryIndexJSON;
        updatedRegistryIndexJSON = _this.updateRegistryIndexJSON(registryIndexJSON, packageJSON, environmentType);
        return _this.uploadRegistryIndex(updatedRegistryIndexJSON);
      }).fail(function(err) {
        return console.err("Could not update registry index!", err);
      });
    };

    return VersionMap;

  })();

  module.exports = VersionMap;

}).call(this);
