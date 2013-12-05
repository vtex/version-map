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
      beta: "1.0.1"
      stable: "1.0.0"
      alpha: "1.0.1"
    }
    main: "index.html"
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

  it 'should update a registryIndex JSON correctly with tag', ->
    updatedVersionMapJSON = vmap.updateRegistryIndexJSON(registryIndexJSON, packageJSON, 'beta')
    registryIndex = JSON.parse updatedVersionMapJSON
    expect(registryIndex.test.paths).toEqual(JSON.parse(packageJSON).paths)
    expect(registryIndex.test.hosts).toEqual(JSON.parse(packageJSON).hosts)
    expect(registryIndex.test.versions["1.0.2"]).toBeDefined()
    expect(registryIndex.test.versions["1.0.2"].created).toBeDefined()
    expect(registryIndex.test.tags.beta).toBe("1.0.2")

  it 'should update a registryIndex JSON correctly without tag', ->
    updatedVersionMapJSON = vmap.updateRegistryIndexJSON(registryIndexJSON, packageJSON)
    registryIndex = JSON.parse updatedVersionMapJSON
    expect(registryIndex.test.paths).toEqual(JSON.parse(packageJSON).paths)
    expect(registryIndex.test.hosts).toEqual(JSON.parse(packageJSON).hosts)
    expect(registryIndex.test.versions["1.0.2"]).toBeDefined()
    expect(registryIndex.test.versions["1.0.2"].created).toBeDefined()
    expect(registryIndex.test.tags.beta).toBe("1.0.1")

  it 'should update a registryIndex JSON tag correctly without a complete packageJSON', ->
    virtualPackageJSON = JSON.stringify({name: "test", version: "2.0.0"})
    updatedVersionMapJSON = vmap.updateRegistryIndexJSON(registryIndexJSON, virtualPackageJSON, 'stable')
    registryIndex = JSON.parse updatedVersionMapJSON
    expect(registryIndex.test.paths).toEqual(JSON.parse(registryIndexJSON).test.paths)
    expect(registryIndex.test.hosts).toEqual(JSON.parse(registryIndexJSON).test.hosts)
    expect(registryIndex.test.main).toEqual(JSON.parse(registryIndexJSON).test.main)
    expect(registryIndex.test.versions["1.0.1"]).toBeDefined()
    expect(registryIndex.test.versions["1.0.1"].created).toBeDefined()
    expect(registryIndex.test.tags.beta).toBe("1.0.1")
    expect(registryIndex.test.tags.stable).toBe("2.0.0")

  it 'should throw an error when updating a registryIndex without name', ->
    virtualPackageJSON = JSON.stringify({version: "2.0.0"})
    expect( -> vmap.updateRegistryIndexJSON(registryIndexJSON, virtualPackageJSON, 'stable')).toThrow(new Error("Required property name not found"))

  it 'should throw an error when updating a registryIndex without version', ->
    virtualPackageJSON = JSON.stringify({name: "test"})
    expect( -> vmap.updateRegistryIndexJSON(registryIndexJSON, virtualPackageJSON, 'stable')).toThrow(new Error("Required property version not found"))

  it 'should call upload and download with appropriate values', ->
    spyOn(vmap, 'downloadRegistryIndex').andReturn Q(registryIndexJSON)
    spyOn(vmap, 'uploadRegistryIndex').andReturn Q(registryIndexJSON)

    promise = vmap.updateVersion('beta', packageJSON)

    expect(promise).toBeDefined()

    promise.then (response) ->
      expect(vmap.downloadRegistryIndex).toHaveBeenCalled()
      expect(vmap.uploadRegistryIndex).toHaveBeenCalledWith([registryIndexJSON])
      expect(response).toBe(registryIndexJSON)

  it 'should transform a registry map to array', ->
    registryArray = vmap.registryMapToArray(JSON.parse(registryIndexJSON))
    expect(registryArray.length).toBe(1)
    expect(registryArray[0].name).toBe("test")
    expect(registryArray[0].tagsArray.length).toBe(3)
    expect(registryArray[0].tagsArray[0].tag).toBe("stable")
    expect(registryArray[0].tagsArray[1].tag).toBe("beta")
    expect(registryArray[0].tagsArray[2].tag).toBe("alpha")
    expect(registryArray[0].versionsArray.length).toBe(2)
    expect(registryArray[0].versionsArray[0].version).toBe("1.0.1")
    expect(registryArray[0].mostRecentVersionDate).toBe("2013-11-21T17:42:23.577Z")