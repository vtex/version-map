(function() {
  var Q,
    _this = this;

  Q = require('q');

  /*
  Uploads a object to s3
  */


  exports.uploadObject = function(obj, path, client, timeoutMillis, dryRun) {
    var deferred, headers, json, req, timeoutCallback;
    if (timeoutMillis == null) {
      timeoutMillis = 1000 * 30;
    }
    if (dryRun == null) {
      dryRun = false;
    }
    json = JSON.stringify(obj);
    if (dryRun) {
      console.log('\nWARNING: Running in dry run mode. No upload was actually made.\n');
      return Q(obj);
    }
    deferred = Q.defer();
    headers = {
      "Content-Length": json.length,
      "Content-Type": "application/json"
    };
    req = client.put(path, headers);
    timeoutCallback = function() {
      req.abort();
      return deferred.reject(new Error("Timeout exceeded when uploading " + path));
    };
    req.setTimeout(timeoutMillis, timeoutCallback);
    req.on("error", function(err) {
      return deferred.reject(new Error(err));
    });
    req.on("response", function(res) {
      if (200 === res.statusCode) {
        console.log("Upload at " + req.url + " successful.");
        return deferred.resolve(obj);
      } else {
        return deferred.reject(new Error("Failed to upload " + path + ". Status: " + res.statusCode));
      }
    });
    req.end(json);
    return deferred.promise;
  };

  /*
  Returns a object from s3. If none is found at this path, an empty object is returned.
  */


  exports.downloadObject = function(path, client, timeoutMillis) {
    var deferred, req, timeoutCallback;
    if (timeoutMillis == null) {
      timeoutMillis = 1000 * 30;
    }
    deferred = Q.defer();
    req = client.get(path);
    timeoutCallback = function() {
      req.abort();
      return deferred.reject(new Error("Timeout exceeded when downloading " + path));
    };
    req.setTimeout(timeoutMillis, timeoutCallback);
    req.on("error", function(err) {
      return deferred.reject(err);
    });
    req.on("response", function(res) {
      if (res.statusCode === 404) {
        console.warn("No object found at " + path + ".");
        return deferred.resolve({});
      } else if (res.statusCode === 200) {
        return res.on('data', function(chunk) {
          var e, obj;
          try {
            obj = JSON.parse(chunk);
            return deferred.resolve(obj);
          } catch (_error) {
            e = _error;
            console.error(e);
            return deferred.reject(e);
          }
        });
      } else {
        return deferred.reject(new Error("Failed to download " + path + ". Status: " + res.statusCode));
      }
    });
    req.end();
    return deferred.promise;
  };

}).call(this);
