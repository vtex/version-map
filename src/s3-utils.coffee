Q = require('q')

# Parses s3 object's content
parseData = (data) -> JSON.parse data.Body

###
Uploads a object to s3
###
exports.putObject = (obj, client, bucket, path, dryRun = false) =>
  json = JSON.stringify(obj)
  if dryRun
    console.log '\nWARNING: Running in dry run mode. No upload was actually made.\n'
    return Q(obj)

  params =
    ContentType: 'application/json'
    Bucket: bucket
    Key: path
    Body: json

  Q.ninvoke(client, "putObject", params)

###
Returns a object from s3. If none is found at this path, an empty object is returned.
###
exports.getObject = (client, bucket, path) =>
  Q.ninvoke(client, "getObject", { Bucket: bucket, Key: path }).then parseData
