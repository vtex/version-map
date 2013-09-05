knox = require 'knox'

class VersionMap
  version: 'VERSION_NUMBER'
  constructor: (options) ->
    @key = options.key
    @secret = options.secret
    @bucket = options.bucket
    @s3Client = knox.createClient
      key: @key
      secret: @secret
      bucket: @bucket

  # Return a versionMap file path given the current environmentType. e.g. version/beta.json
  versionMapFilePath: (environmentType) ->
    "version/#{environmentType}.json"

  # Uploads this versionMap object on the appropriate path, updating this project's key to the current version
  updateVersionMapJSON: (versionMapJSON, productName, version) =>
    # e.g. { vtex_deploy: "v00-02-00-beta-3" }
    versionMapObj = JSON.parse(versionMapJSON)
    versionMapObj[productName] = version
    JSON.stringify(versionMapObj)

  uploadVersionMap: (environmentType, versionMapJSON, callback) =>
    req = @s3Client.put(@versionMapFilePath(environmentType),
      "Content-Length": versionMapJSON.length
      "Content-Type": "application/json"
    )

    # Let's not wait for more than 30 seconds to fail the build if there is no response to the upload request
    timeout = setTimeout (->
      callback new Error("Timeout exceeded when uploading version map at #{@versionMapFilePath(environmentType)}")
    ), 1000 * 30
    
    req.on "response", (res) ->
      if 200 is res.statusCode
        console.log "Version updated at #{req.url}"
        console.log versionMapJSON
        clearTimeout timeout
        callback null, versionMapJSON
      else
        clearTimeout timeout
        callback new Error("Failed to upload version map at #{@versionMapFilePath(environmentType)}")

    req.end versionMapJSON
    
  downloadVersionMap: (environmentType, callback) =>
    @s3Client.getFile @versionMapFilePath(environmentType), (err, res) ->
      if err
        console.error "Error reading version map: #{environmentType}.json"
        callback err
      else if res.statusCode is 404
        console.log "No such version map file available: #{environmentType}.json. Creating one now."
        callback null, {}
      else if res.statusCode is 200
        res.on 'data', (chunk) ->
          callback null, chunk
      res.resume()
  
  updateVersion: (environmentType, productName, version, callback) =>
    @downloadVersionMap environmentType, (err, versionMapJSON) =>
      if err
        callback err
      else
        updatedVersionMapJSON = @updateVersionMapJSON(versionMapJSON, productName, version)
        @uploadVersionMap environmentType, updatedVersionMapJSON, (err, versionMap) ->
          if err
            callback err
          else 
            callback null, versionMap
    
module.exports = VersionMap 