VersionMap = require '../libs/version-map'
Q = require 'q'
options =
  key: 'ASD'
  secret: 'FGH'
  bucket: 'test-bucket'

vmap = new VersionMap(options)

packageJSON = JSON.stringify({
  name: "test"
  version: "1.0.2"
  paths: ["/admin/test",
          "/admin/new",
          "/admin/newest"]
  hosts: ["vtexcommerce.com.br",
          "vtexcommercebeta.com.br",
          "vtexlocal.com.br"]
  description: "a test package that works"
})

registryIndexJSON = JSON.stringify({
  test: {
    name: "test"
    tags: {
      stable: "1.0.0"
      beta: "1.0.1"
    }
    paths: ["/admin/test",
            "/admin/new"]
    hosts: ["vtexcommerce.com.br",
            "vtexcommercebeta.com.br",
            "vtexlocal.com.br"]
    versions: {
      "1.0.0": {
        created: "2013-11-21T17:28:23.577Z"
      }
      "1.0.1": {
        created: "2013-11-21T17:42:23.577Z"
      }
    }
  }
})

describe 'VersionMap', ->

  it 'should exist', ->
    expect(VersionMap).toBeDefined()
    expect(vmap.version).toBeTruthy()

  it 'should have defined properties', ->
    expect(vmap.key).toBe(options.key)
    expect(vmap.secret).toBe(options.secret)
    expect(vmap.bucket).toBe(options.bucket)
    expect(vmap.s3Client).toBeDefined()
    expect(vmap.registryIndexPath).toBeDefined()

  it 'should update a registryIndex JSON correctly', ->
    updatedVersionMapJSON = vmap.updateRegistryIndexJSON(registryIndexJSON, packageJSON, 'beta')
    registryIndex = JSON.parse updatedVersionMapJSON
    expect(registryIndex.test.paths).toEqual(JSON.parse(packageJSON).paths)
    expect(registryIndex.test.hosts).toEqual(JSON.parse(packageJSON).hosts)
    expect(registryIndex.test.versions["1.0.2"]).toBeDefined()
    expect(registryIndex.test.versions["1.0.2"].created).toBeDefined()
    expect(registryIndex.test.tags.beta).toBe("1.0.2")

  it 'should call upload and download with appropriate values', ->
    spyOn(vmap, 'downloadRegistryIndex').andReturn Q(registryIndexJSON)
    spyOn(vmap, 'uploadRegistryIndex').andReturn Q(registryIndexJSON)

    promise = vmap.updateVersion('beta', packageJSON)

    expect(promise).toBeDefined()

    promise.then (response) ->
      expect(vmap.downloadRegistryIndex).toHaveBeenCalled()
      expect(vmap.uploadRegistryIndex).toHaveBeenCalledWith([registryIndexJSON])
      expect(response).toBe(registryIndexJSON)