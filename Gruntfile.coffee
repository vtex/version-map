module.exports = (grunt) ->
  pkg = grunt.file.readJSON('package.json')
  spawn = require("child_process").spawn

  replacements =
    dev:
      'VERSION_NUMBER': pkg.version

  # Project configuration.
  grunt.initConfig

    # Tasks
    clean: 
      main: ['libs']

    coffee:
      main:
        files: [
          expand: true
          cwd: 'src/'
          src: ['**/*.coffee']
          dest: 'libs/'
          ext: '.js'
        ]

    'string-replace':
      dev:
        files:
          'libs/version-map.js': ['libs/version-map.js']
        options:
          replacements: ({'pattern': new RegExp(key, "g"), 'replacement': value} for key, value of replacements.dev)

    watch:
      dev:
        files: ['src/**/*.coffee', 'spec/**/*.coffee']
        tasks: ['clean', 'coffee', 'string-replace', 'test']

  grunt.loadNpmTasks name for name of pkg.devDependencies when name[0..5] is 'grunt-'

  grunt.registerTask 'test', ->
    done = @async()
    cmd = spawn('./node_modules/jasmine-node/bin/jasmine-node', ['--coffee', 'spec/'])
    write = (data) ->
      process.stdout.write data.toString()
    cmd.stdout.on "data", write
    cmd.stderr.on "data", write
    cmd.on "exit", (code) ->
      done code is 0

  grunt.registerTask 'default', ['clean', 'coffee', 'string-replace', 'test', 'watch']