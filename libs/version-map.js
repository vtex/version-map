(function() {
  var VersionMap, knox,
    __bind = function(fn, me){ return function(){ return fn.apply(me, arguments); }; };

  knox = require('knox');

  VersionMap = (function() {
    VersionMap.prototype.version = '0.1.0';

    function VersionMap(options) {
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
      var req, timeout;
      req = this.s3Client.put(this.versionMapFilePath(environmentType), {
        "Content-Length": versionMapJSON.length,
        "Content-Type": "application/json"
      });
      timeout = setTimeout((function() {
        return callback(new Error("Timeout exceeded when uploading version map at " + (this.versionMapFilePath(environmentType))));
      }), 1000 * 30);
      req.on("response", function(res) {
        if (200 === res.statusCode) {
          console.log("Version updated at " + req.url);
          clearTimeout(timeout);
          return callback(null, versionMapJSON);
        } else {
          clearTimeout(timeout);
          return callback(new Error("Failed to upload version map at " + (this.versionMapFilePath(environmentType))));
        }
      });
      return req.end(versionMapJSON);
    };

    VersionMap.prototype.downloadVersionMap = function(environmentType, callback) {
      return this.s3Client.getFile(this.versionMapFilePath(environmentType), function(err, res) {
        if (err) {
          console.error("Error reading version map: " + environmentType + ".json");
          callback(err);
        } else if (res.statusCode === 404) {
          console.warn("No such version map file available: " + environmentType + ".json. Creating one now.");
          callback(null, {});
        } else if (res.statusCode === 200) {
          res.on('data', function(chunk) {
            return callback(null, chunk);
          });
        }
        return res.resume();
      });
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

    return VersionMap;

  })();

  module.exports = VersionMap;

}).call(this);
