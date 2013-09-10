(function() {
  var VersionMap, knox,
    __bind = function(fn, me){ return function(){ return fn.apply(me, arguments); }; };

  knox = require('knox');

  VersionMap = (function() {
    VersionMap.prototype.version = '0.2.0';

    function VersionMap(options) {
      this.listVersions = __bind(this.listVersions, this);
      this.updateVersion = __bind(this.updateVersion, this);
      this.downloadVersionMap = __bind(this.downloadVersionMap, this);
      this.uploadVersionMap = __bind(this.uploadVersionMap, this);
      this.updateVersionMapJSON = __bind(this.updateVersionMapJSON, this);
      this.key = options.key;
      this.secret = options.secret;
      this.bucket = options.bucket;
      this.s3Client = knox.createClient({
        key: this.key,
        secret: this.secret,
        bucket: this.bucket
      });
    }

    VersionMap.prototype.versionMapFilePath = function(environmentType) {
      return "version/" + environmentType + ".json";
    };

    VersionMap.prototype.updateVersionMapJSON = function(versionMapJSON, productName, version) {
      var versionMapObj;
      versionMapObj = JSON.parse(versionMapJSON);
      versionMapObj[productName] = version;
      return JSON.stringify(versionMapObj);
    };

    VersionMap.prototype.uploadVersionMap = function(environmentType, versionMapJSON, callback) {
      var req, timeoutCallback, timeoutMillis;
      req = this.s3Client.put(this.versionMapFilePath(environmentType), {
        "Content-Length": versionMapJSON.length,
        "Content-Type": "application/json"
      });
      timeoutMillis = 1000 * 30;
      timeoutCallback = function() {
        req.abort();
        return callback(new Error("Timeout exceeded when uploading version map at " + (this.versionMapFilePath(environmentType))));
      };
      req.setTimeout(timeoutMillis, timeoutCallback);
      req.on("error", function(err) {
        return callback(err);
      });
      req.on("response", function(res) {
        if (200 === res.statusCode) {
          console.log("Version updated at " + req.url);
          return callback(null, versionMapJSON);
        } else {
          return callback(new Error("Failed to upload version map at " + (this.versionMapFilePath(environmentType))));
        }
      });
      return req.end(versionMapJSON);
    };

    VersionMap.prototype.downloadVersionMap = function(environmentType, callback) {
      var req, timeoutCallback, timeoutMillis;
      req = this.s3Client.get(this.versionMapFilePath(environmentType));
      timeoutMillis = 1000 * 30;
      timeoutCallback = function() {
        req.abort();
        return callback(new Error("Timeout exceeded when downloading version map at " + (this.versionMapFilePath(environmentType))));
      };
      req.setTimeout(timeoutMillis, timeoutCallback);
      req.on("error", function(err) {
        return callback(err);
      });
      req.on("response", function(res) {
        if (res.statusCode === 404) {
          console.warn("No such version map file available: " + environmentType + ".json. Creating one now.");
          return callback(null, {});
        } else if (res.statusCode === 200) {
          return res.on('data', function(chunk) {
            return callback(null, chunk);
          });
        }
      });
      return req.end();
    };

    VersionMap.prototype.updateVersion = function(environmentType, productName, version, callback) {
      var _this = this;
      return this.downloadVersionMap(environmentType, function(err, versionMapJSON) {
        var updatedVersionMapJSON;
        if (err) {
          return callback(err);
        } else {
          updatedVersionMapJSON = _this.updateVersionMapJSON(versionMapJSON, productName, version);
          return _this.uploadVersionMap(environmentType, updatedVersionMapJSON, function(err, versionMap) {
            if (err) {
              return callback(err);
            } else {
              return callback(null, versionMap);
            }
          });
        }
      });
    };

    VersionMap.prototype.listVersions = function(productName, callback) {
      return this.s3Client.list({
        prefix: productName
      }, callback);
    };

    return VersionMap;

  })();

  module.exports = VersionMap;

}).call(this);
