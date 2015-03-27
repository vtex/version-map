(function() {
  var Q, parseData,
    _this = this;

  Q = require('q');

  parseData = function(data) {
    return JSON.parse(data.Body);
  };

  /*
  Uploads a object to s3
  */


  exports.putObject = function(obj, client, bucket, path, dryRun) {
    var json, params;
    if (dryRun == null) {
      dryRun = false;
    }
    json = JSON.stringify(obj);
    if (dryRun) {
      console.log('\nWARNING: Running in dry run mode. No upload was actually made.\n');
      return Q(obj);
    }
    params = {
      ContentType: 'application/json',
      Bucket: bucket,
      Key: path,
      Body: json
    };
    return Q.ninvoke(client, "putObject", params);
  };

  /*
  Returns a object from s3. If none is found at this path, an empty object is returned.
  */


  exports.getObject = function(client, bucket, path) {
    return Q.ninvoke(client, "getObject", {
      Bucket: bucket,
      Key: path
    }).then(parseData);
  };

}).call(this);
