VersionMap = require '../libs/version-map'
Q = require 'q'
_ = require 'underscore'
options =
  key: 'ASD'
  secret: 'FGH'
  bucket: 'test-bucket'

vmap = undefined
pack = undefined
registry = undefined
tags = undefined

describe 'VersionMap', ->

  beforeEach ->
    vmap = new VersionMap(options)

    pack = {
      name: "test"
      version: "1.0.2"
      updated: "2013-11-27T17:00:00.000Z"
      main: "index.html"
      backend: "https://io.vtex.com.br/"
      paths: ["/admin/test",
              "/admin/new",
              "/admin/newest"]
      hosts: ["vtexcommerce.com.br",
              "vtexcommercebeta.com.br",
              "vtexlocal.com.br"]
      description: "a test package that works"
    }

    registry = {
      test: {
        name: "test"
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
          "0.9.8": {
            version: "0.9.8"
            rootRewrite: "test/0.9.8"
            created: "2013-10-21T17:28:23.577Z"
          }
          "1.0.1": {
            version: "1.0.1"
            rootRewrite: "test/1.0.1"
            created: "2013-11-26T12:00:00.000Z"
          }
          "1.0.1-beta": {
            version: "1.0.1-beta"
            rootRewrite: "test/1.0.1-beta"
            created: "2013-11-24T12:00:00.000Z"
          }
          "0.9.9-beta": {
            version: "0.9.9"
            rootRewrite: "test/0.9.9"
            created: "2013-10-21T17:28:23.577Z"
          }
          "1.0.1-alpha": {
            version: "1.0.1-alpha"
            rootRewrite: "test/1.0.1-alpha"
            created: "2013-11-23T12:00:00.000Z"
          }
          "2.0.0-alpha": {
            version: "2.0.0-alpha"
            rootRewrite: "test/2.0.0-alpha"
            created: "2013-12-23T12:00:00.000Z"
          }
        }
      }
    }

    tags = {
      test: {
        stable: {
          "1": "1.0.1"
        }
        beta: {
          "1": "1.0.1-beta"
        }
        alpha: {
          "1": "1.0.1-alpha"
        }
        next: {
          "1": "1.0.1-beta"
        }
      }
    }

  it 'should exist', ->
    expect(VersionMap).toBeDefined()

  it 'should have defined properties', ->
    expect(vmap.key).toBe(options.key)
    expect(vmap.secret).toBe(options.secret)
    expect(vmap.bucket).toBe(options.bucket)
    expect(vmap.s3Client).toBeDefined()
    expect(vmap.registryPath).toBeDefined()

  it 'should create a registry JSON correctly', ->
    registry = vmap.updateRegistry({}, pack)
    expect(registry.test.paths).toEqual(pack.paths)
    expect(registry.test.hosts).toEqual(pack.hosts)
    expect(registry.test.versions["1.0.2"]).toBeDefined()
    expect(registry.test.versions["1.0.2"].version).toBe("1.0.2")
    expect(registry.test.versions["1.0.2"].created).toBeDefined()
    expect(registry.test.versions["1.0.2"].rootRewrite).toBe("test/1.0.2")

  it 'should update a registry JSON correctly', ->
    registry = vmap.updateRegistry(registry, pack)
    expect(registry.test.paths).toEqual(pack.paths)
    expect(registry.test.hosts).toEqual(pack.hosts)
    expect(registry.test.versions["1.0.2"]).toBeDefined()
    expect(registry.test.versions["1.0.2"].version).toBe("1.0.2")
    expect(registry.test.versions["1.0.2"].created).toBeDefined()
    expect(registry.test.versions["1.0.2"].rootRewrite).toBe("test/1.0.2")

  it 'should create a tags JSON correctly', ->
    tags = vmap.updateTags({}, pack.name, pack.version, 'stable')
    expect(_.keys(tags.test).length).toBe(4)
    expect(tags.test.beta).toEqual({})
    expect(tags.test.stable["1"]).toEqual("1.0.2")

  it 'should update a tags JSON correctly', ->
    tags = vmap.updateTags(tags, pack.name, pack.version, 'beta')
    expect(_.keys(tags.test).length).toBe(4)
    expect(tags.test.stable["1"]).toEqual("1.0.1")
    expect(tags.test.beta["1"]).toEqual("1.0.2")

  it 'should update a registry JSON tag correctly without a complete packageJSON', ->
    virtualPackage = {name: "test", version: "2.0.0"}
    registry = vmap.updateRegistry(registry, virtualPackage)
    expect(registry.test.paths).toEqual(registry.test.paths)
    expect(registry.test.hosts).toEqual(registry.test.hosts)
    expect(registry.test.rootRewrite).toEqual(registry.test.rootRewrite)
    expect(registry.test.backend).toEqual(registry.test.backend)
    expect(registry.test.main).toEqual(registry.test.main)
    expect(registry.test.versions["1.0.1"]).toBeDefined()
    expect(registry.test.versions["1.0.1"].version).toBe("1.0.1")
    expect(registry.test.versions["1.0.1"].created).toBeDefined()
    expect(registry.test.versions["1.0.1"].rootRewrite).toBe("test/1.0.1")

  it 'should create a tags JSON from a registry correctly', ->
    tags = vmap.updateTagsFromRegistry({}, registry)
    expect(_.keys(tags.test).length).toBe(4)
    expect(tags.test.stable["1"]).toEqual("1.0.1")
    expect(tags.test.beta["1"]).toEqual("1.0.1-beta")
    expect(tags.test.alpha["1"]).toEqual("1.0.1-alpha")
    expect(tags.test.alpha["2"]).toEqual("2.0.0-alpha")

  it 'should update a tags JSON from a registry correctly', ->
    tags.test2 = _.extend {}, tags.test
    tags.test = undefined
    tags = vmap.updateTagsFromRegistry(tags, registry)
    expect(_.keys(tags.test).length).toBe(4)
    expect(tags.test.stable["1"]).toEqual("1.0.1")
    expect(tags.test.beta["1"]).toEqual("1.0.1-beta")
    expect(tags.test2.stable["1"]).toEqual("1.0.1")
    expect(tags.test2.beta["1"]).toEqual("1.0.1-beta")

  it 'should throw an error when updating a registry without name', ->
    virtualPackage = {version: "2.0.0"}
    expect( -> vmap.updateRegistry(registry, virtualPackage)).toThrow(new Error("Required property name not found"))

  it 'should throw an error when updating a registryIndex without version', ->
    virtualPackage = {name: "test"}
    expect( -> vmap.updateRegistry(registry, virtualPackage)).toThrow(new Error("Required property version not found"))

  it 'should throw an error when creating a package with paths, hosts and without backend', ->
    virtualPackage = {name: "newtest", version: "1.0.0", paths: ["/admin/checkout"], hosts: ["vtexcommerce.com.br"]}
    expect( -> vmap.updateRegistry(registry, virtualPackage)).toThrow(new Error("Required property for creation backend not found"))

  it 'should throw an error when updating a tags object without name', ->
    expect( -> vmap.updateTags(registry, null, "2.0.0", "stable")).toThrow(new Error("Required property name is null or undefined"))

  it 'should throw an error when updating a tags object without version', ->
    expect( -> vmap.updateTags(registry, "test", null, "stable")).toThrow(new Error("Required property version is null or undefined"))

  it 'should throw an error when updating a tags object without tag', ->
    expect( -> vmap.updateTags(registry, "test", "2.0.0", null)).toThrow(new Error("Required property tag is null or undefined"))

  it 'should throw an error when updating a tags object with invalid tag', ->
    expect( -> vmap.updateTags(registry, "test", "2.0.0", "banana")).toThrow(new Error("Tag must be one of: stable, next, beta, alpha"))

  it 'should call upload and download with appropriate values in dry run mode', ->
    vmap = new VersionMap(
      key: 'ASD'
      secret: 'FGH'
      bucket: 'test-bucket'
      dryRun: true
    )
    vmap.downloadRegistry = createSpy('downloadRegistry').andCallFake -> Q(registry)
    promise = vmap.addVersion(pack)
    expect(promise).toBeDefined()
    promise.then (response) ->
      expect(vmap.downloadRegistry).toHaveBeenCalled()
      expect(vmap.uploadRegistry).toHaveBeenCalledWith([registry])
      expect(response).toBe(registry)

  it 'should call upload and download when updating tags in dry run mode', ->
    vmap = new VersionMap
      key: 'ASD'
      secret: 'FGH'
      bucket: 'test-bucket'
      dryRun: true
    vmap.downloadTags = createSpy('downloadTags').andCallFake -> Q(tags)
    promise = vmap.updateTag(pack.name, pack.version, 'stable')
    expect(promise).toBeDefined()
    promise.then (response) ->
      expect(vmap.downloadTags).toHaveBeenCalled()
      expect(vmap.uploadTags).toHaveBeenCalledWith([tags])
      expect(response).toBe(tags)

  it 'should transform a registry map to array', ->
    registryArray = vmap.registryMapToArray(registry)
    expect(registryArray.length).toBe(1)
    expect(registryArray[0].name).toBe("test")
    expect(registryArray[0].versionsArray.length).toBe(7)
    expect(registryArray[0].versionsArray[0].version).toBe("2.0.0-alpha")
    expect(registryArray[0].mostRecentVersionDate).toBe("2013-12-23T12:00:00.000Z")

  it 'should transform a tags map to array', ->
    tags = vmap.tagsMapToArray(tags)
    expect(tags.length).toBe(1)
    expect(tags[0].name).toBe("test")
    expect(tags[0].tagsArray.length).toBe(4)
    expect(tags[0].tagsArray[0].tag).toBe("stable")
    expect(tags[0].tagsArray[0].majorsArray.length).toBe(1)
    expect(tags[0].tagsArray[0].majorsArray[0].version).toBe("1.0.1")
    expect(tags[0].tagsArray[0].majorsArray[0].major).toBe("1")

  it 'should correctly get versionName and versionDirectory from package', ->
    virtualPackage = {name: "test", version: "2.0.0"}
    expect(vmap.versionName(virtualPackage)).toBe("2.0.0")
    expect(vmap.versionDirectory(virtualPackage)).toBe("test/2.0.0")