VersionMap = require '../libs/version-map'
Q = require 'q'
options =
  key: 'ASD'
  secret: 'FGH'
  bucket: 'test-bucket'

vmap = undefined
packageJSON = undefined
registryIndexJSON = undefined

describe 'VersionMap', ->

  beforeEach ->
    vmap = new VersionMap(options)

    packageJSON = JSON.stringify({
      name: "test"
      version: "1.0.2"
      main: "index.html"
      backend: "https://io.vtex.com.br/"
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
          beta: "1.0.1-beta"
          stable: "1.0.0"
          next: "1.0.1"
          alpha: "1.0.1-alpha"
        }
        main: "index.html"
        paths: ["/admin/test",
                "/admin/new"]
        hosts: ["vtexcommerce.com.br",
                "vtexcommercebeta.com.br",
                "vtexlocal.com.br"],
        backend: "https://io.vtex.com.br/"
        versions: {
          "1.0.0": {
            version: "1.0.0"
            rootRewrite: "test/1.0.0"
            created: "2013-11-21T17:28:23.577Z"
          }
          "1.0.1": {
            version: "1.0.1"
            rootRewrite: "test/1.0.1"
            created: "2013-11-26T17:42:23.577Z"
          }
          "1.0.1-beta": {
            version: "1.0.1-beta"
            rootRewrite: "test/1.0.1-beta"
            created: "2013-11-24T17:42:23.577Z"
          }
          "1.0.1-alpha": {
            version: "1.0.1-alpha"
            rootRewrite: "test/1.0.1-alpha"
            created: "2013-11-23T17:42:23.577Z"
          }
        }
      }
    })

  it 'should exist', ->
    expect(VersionMap).toBeDefined()
    expect(vmap.version).toBeTruthy()

  it 'should have defined properties', ->
    expect(vmap.key).toBe(options.key)
    expect(vmap.secret).toBe(options.secret)
    expect(vmap.bucket).toBe(options.bucket)
    expect(vmap.s3Client).toBeDefined()
    expect(vmap.registryIndexPath).toBeDefined()

  it 'should create a registryIndex JSON correctly with tag', ->
    updatedVersionMapJSON = vmap.updateRegistryIndexJSON("{}", packageJSON, 'beta')
    registryIndex = JSON.parse updatedVersionMapJSON
    expect(registryIndex.test.paths).toEqual(JSON.parse(packageJSON).paths)
    expect(registryIndex.test.hosts).toEqual(JSON.parse(packageJSON).hosts)
    expect(registryIndex.test.versions["1.0.2"]).toBeDefined()
    expect(registryIndex.test.versions["1.0.2"].version).toBe("1.0.2")
    expect(registryIndex.test.versions["1.0.2"].created).toBeDefined()
    expect(registryIndex.test.versions["1.0.2"].rootRewrite).toBe("test/1.0.2")
    expect(registryIndex.test.tags.beta).toBe("1.0.2")

  it 'should create a registryIndex JSON correctly without tag', ->
    updatedVersionMapJSON = vmap.updateRegistryIndexJSON("{}", packageJSON)
    registryIndex = JSON.parse updatedVersionMapJSON
    expect(registryIndex.test.paths).toEqual(JSON.parse(packageJSON).paths)
    expect(registryIndex.test.hosts).toEqual(JSON.parse(packageJSON).hosts)
    expect(registryIndex.test.versions["1.0.2"]).toBeDefined()
    expect(registryIndex.test.versions["1.0.2"].version).toBe("1.0.2")
    expect(registryIndex.test.versions["1.0.2"].created).toBeDefined()
    expect(registryIndex.test.versions["1.0.2"].rootRewrite).toBe("test/1.0.2")
    expect(registryIndex.test.tags.beta).toBeUndefined()

  it 'should update a registryIndex JSON correctly with tag', ->
    updatedVersionMapJSON = vmap.updateRegistryIndexJSON(registryIndexJSON, packageJSON, 'beta')
    registryIndex = JSON.parse updatedVersionMapJSON
    expect(registryIndex.test.paths).toEqual(JSON.parse(packageJSON).paths)
    expect(registryIndex.test.hosts).toEqual(JSON.parse(packageJSON).hosts)
    expect(registryIndex.test.versions["1.0.2"]).toBeDefined()
    expect(registryIndex.test.versions["1.0.2"].version).toBe("1.0.2")
    expect(registryIndex.test.versions["1.0.2"].created).toBeDefined()
    expect(registryIndex.test.versions["1.0.2"].rootRewrite).toBe("test/1.0.2")
    expect(registryIndex.test.tags.beta).toBe("1.0.2")

  it 'should update a registryIndex JSON correctly without tag', ->
    updatedVersionMapJSON = vmap.updateRegistryIndexJSON(registryIndexJSON, packageJSON)
    registryIndex = JSON.parse updatedVersionMapJSON
    expect(registryIndex.test.paths).toEqual(JSON.parse(packageJSON).paths)
    expect(registryIndex.test.hosts).toEqual(JSON.parse(packageJSON).hosts)
    expect(registryIndex.test.versions["1.0.2"]).toBeDefined()
    expect(registryIndex.test.versions["1.0.2"].version).toBe("1.0.2")
    expect(registryIndex.test.versions["1.0.2"].created).toBeDefined()
    expect(registryIndex.test.versions["1.0.2"].rootRewrite).toBe("test/1.0.2")
    expect(registryIndex.test.tags.beta).toBe("1.0.1-beta")

  it 'should update a registryIndex JSON tag correctly without a complete packageJSON', ->
    virtualPackageJSON = JSON.stringify({name: "test", version: "2.0.0"})
    updatedVersionMapJSON = vmap.updateRegistryIndexJSON(registryIndexJSON, virtualPackageJSON, 'stable')
    registryIndex = JSON.parse updatedVersionMapJSON
    expect(registryIndex.test.paths).toEqual(JSON.parse(registryIndexJSON).test.paths)
    expect(registryIndex.test.hosts).toEqual(JSON.parse(registryIndexJSON).test.hosts)
    expect(registryIndex.test.rootRewrite).toEqual(JSON.parse(registryIndexJSON).test.rootRewrite)
    expect(registryIndex.test.backend).toEqual(JSON.parse(registryIndexJSON).test.backend)
    expect(registryIndex.test.main).toEqual(JSON.parse(registryIndexJSON).test.main)
    expect(registryIndex.test.versions["1.0.1"]).toBeDefined()
    expect(registryIndex.test.versions["1.0.1"].version).toBe("1.0.1")
    expect(registryIndex.test.versions["1.0.1"].created).toBeDefined()
    expect(registryIndex.test.versions["1.0.1"].rootRewrite).toBe("test/1.0.1")
    expect(registryIndex.test.tags.beta).toBe("1.0.1-beta")
    expect(registryIndex.test.tags.stable).toBe("2.0.0")

  it 'should throw an error when updating a registryIndex without name', ->
    virtualPackageJSON = JSON.stringify({version: "2.0.0"})
    expect( -> vmap.updateRegistryIndexJSON(registryIndexJSON, virtualPackageJSON, 'stable')).toThrow(new Error("Required property name not found"))

  it 'should throw an error when updating a registryIndex without version', ->
    virtualPackageJSON = JSON.stringify({name: "test"})
    expect( -> vmap.updateRegistryIndexJSON(registryIndexJSON, virtualPackageJSON, 'stable')).toThrow(new Error("Required property version not found"))

  it 'should throw an error when creating a package with paths, hosts and without backend', ->
    virtualPackageJSON = JSON.stringify({name: "newtest", version: "1.0.0", paths: ["/admin/checkout"], hosts: ["vtexcommerce.com.br"]})
    expect( -> vmap.updateRegistryIndexJSON(registryIndexJSON, virtualPackageJSON, 'stable')).toThrow(new Error("Required property for creation backend not found"))

  it 'should call upload and download with appropriate values', ->
    vmap.downloadRegistryIndex = createSpy('downloadRegistryIndex').andCallFake -> Q(registryIndexJSON)
    vmap.uploadRegistryIndex = createSpy('uploadRegistryIndex').andCallFake -> Q(registryIndexJSON)

    promise = vmap.updateVersion(packageJSON, 'beta')

    expect(promise).toBeDefined()

    promise.then (response) ->
      expect(vmap.downloadRegistryIndex).toHaveBeenCalled()
      expect(vmap.uploadRegistryIndex).toHaveBeenCalledWith([registryIndexJSON])
      expect(response).toBe(registryIndexJSON)

  it 'should call upload and download with appropriate values in dry run mode', ->
    vmap = new VersionMap(
      key: 'ASD'
      secret: 'FGH'
      bucket: 'test-bucket'
      dryRun: true
    )
    vmap.downloadRegistryIndex = createSpy('downloadRegistryIndex').andCallFake -> Q(registryIndexJSON)

    promise = vmap.updateVersion(packageJSON, 'beta')

    expect(promise).toBeDefined()

    promise.then (response) ->
      expect(vmap.downloadRegistryIndex).toHaveBeenCalled()
      expect(vmap.uploadRegistryIndex).toHaveBeenCalledWith([registryIndexJSON])
      expect(response).toBe(registryIndexJSON)

  it 'should transform a registry map to array', ->
    registryArray = vmap.registryMapToArray(JSON.parse(registryIndexJSON))
    expect(registryArray.length).toBe(1)
    expect(registryArray[0].name).toBe("test")
    expect(registryArray[0].tagsArray.length).toBe(4)
    expect(registryArray[0].tagsArray[0].tag).toBe("stable")
    expect(registryArray[0].tagsArray[1].tag).toBe("next")
    expect(registryArray[0].tagsArray[2].tag).toBe("beta")
    expect(registryArray[0].tagsArray[3].tag).toBe("alpha")
    expect(registryArray[0].versionsArray.length).toBe(4)
    expect(registryArray[0].versionsArray[0].version).toBe("1.0.1")
    expect(registryArray[0].mostRecentVersionDate).toBe("2013-11-26T17:42:23.577Z")

  it 'should correctly get versionName and versionDirectory from package', ->
    virtualPackageJSON = {name: "test", version: "2.0.0"}
    expect(vmap.versionName(virtualPackageJSON)).toBe("2.0.0")
    expect(vmap.versionDirectory(virtualPackageJSON)).toBe("test/2.0.0")