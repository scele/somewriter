module.exports = (grunt) ->
  grunt.initConfig
    pkg: grunt.file.readJSON('package.json')
    clean: ['out', 'dist']
    mochaTest:
      test:
        options:
          reporter: 'spec'
          require: [
            'coffee-script/register'
            'should'
          ]
        src: ['test/**/*.coffee']

  grunt.loadNpmTasks('grunt-mocha-test')

  all = [
    'mochaTest',
  ]
  grunt.registerTask('default', all)
  grunt.registerTask('test', ['mochaTest'])
