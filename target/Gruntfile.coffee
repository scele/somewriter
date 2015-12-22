module.exports = (grunt) ->
  all = [
    'coffee',
    'mochaTest',
  ]
  grunt.initConfig
    pkg: grunt.file.readJSON('package.json')
    clean: ['out', 'dist']
    mochaTest:
      test:
        options:
          reporter: 'spec'
          require: [
            'coffee-script/register',
            'should',
          ]
        src: ['src/test.coffee']
      cov:
        options:
          reporter: 'mocha-lcov-reporter'
          require: [
            'coffee-coverage/register',
            'should',
          ]
        src: ['src/test.coffee']
    coffee:
      files:
        expand: true,
        flatten: true,
        src: ['src/*.coffee'],
        dest: 'out/'
        ext: '.js'

  grunt.loadNpmTasks('grunt-contrib-coffee')
  grunt.loadNpmTasks('grunt-mocha-test')

  grunt.registerTask('default', all)
  grunt.registerTask('test', ['mochaTest:test'])
  grunt.registerTask('coverage', ['mochaTest:cov'])
