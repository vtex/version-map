VersionMap = require '../libs/version-map'
options = 
  key: 'ASD'
  secret: 'FGH'
  bucket: 'test-bucket'

vmap = new VersionMap(options)

describe 'VersionMap', ->

  it 'should exist', ->
    expect(VersionMap).toBeDefined()
    expect(vmap.version).toBeTruthy()
    
  it 'should have defined properties', ->
    expect(vmap.key).toBe(options.key)
    expect(vmap.secret).toBe(options.secret)
    expect(vmap.bucket).toBe(options.bucket)
    expect(vmap.s3Client).toBeDefined()
    
  it 'should name path correctly', ->
    expect(vmap.versionMapFilePath('beta')).toBe('version/beta.json')
    
  it 'should update a versionMap JSON correctly', ->
    versionMapJSON = JSON.stringify({test: 'v00-01-00'})
    updatedVersionMapJSON = vmap.updateVersionMapJSON(versionMapJSON, 'test', 'v01-00-00')
    versionMap = JSON.parse updatedVersionMapJSON
    expect(versionMap.test).toBe('v01-00-00')
    
  it 'should call upload and download with appropriate values', ->
    versionMapJSON = JSON.stringify({test: 'v00-01-00'})
    
    vmap.downloadVersionMap = (environmentType, callback) ->
      callback null, versionMapJSON
      
    vmap.uploadVersionMap = (environmentType, versionMapJSON, callback) ->
      expect(vmap.downloadVersionMap).toHaveBeenCalledWith(['beta'])
      callback null, versionMapJSON
      
    spyOn(vmap, 'downloadVersionMap')
    spyOn(vmap, 'uploadVersionMap')

    vmap.updateVersion 'beta', 'test', 'v-01-00-00', (err, versionMap) ->
      expect(vmap.uploadVersionMap).toHaveBeenCalledWith(['beta', versionMapJSON])
      expect(versionMap).toBe(versionMapJSON)