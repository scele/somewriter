module.exports = (grunt) ->
  all = [
    'coffee',
    'copy',
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
            'coffee-script/register'
            'should'
          ]
        src: ['test/**/*.coffee']
    coffee:
      files:
        expand: true,
        src: ['*.coffee'],
        dest: 'out/'
        ext: '.js'
    copy:
      files:
        expand: true,
        src: ['mouse.js']
        dest: 'out/',

  grunt.loadNpmTasks('grunt-contrib-coffee')
  grunt.loadNpmTasks('grunt-mocha-test')
  grunt.loadNpmTasks('grunt-contrib-copy');

  grunt.registerTask('default', all)
  grunt.registerTask('test', ['mochaTest'])
