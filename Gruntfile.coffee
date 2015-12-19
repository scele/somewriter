module.exports = (grunt) ->
  all = [
    'coffee',
    'mochaTest',
    'symlink',
    'browserify:dev'
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
        src: ['test/**/*.coffee']
      cov:
        options:
          reporter: 'mocha-lcov-reporter'
          require: [
            'coffee-coverage/register',
            'should',
          ]
        src: ['test/**/*.coffee']
    symlink:
      explicit:
        src: 'server/public'
        dest: 'out/server/public'
    coffee:
      files:
        expand: true,
        src: ['**/*.coffee'],
        dest: 'out/'
        ext: '.js'
    browserify:
      dev: {
        options: {
          debug: true,
          transform: ['reactify']
        },
        files: {
          'out/app.js': 'server/public/*.jsx'
        }
      },

  grunt.loadNpmTasks('grunt-contrib-coffee')
  grunt.loadNpmTasks('grunt-contrib-symlink')
  grunt.loadNpmTasks('grunt-browserify')
  grunt.loadNpmTasks('grunt-mocha-test')

  grunt.registerTask('default', all)
  grunt.registerTask('test', ['mochaTest:test'])
  grunt.registerTask('coverage', ['mochaTest:cov'])
