module.exports = (grunt) ->
  all = [
    'coffee',
    'symlink',
    'browserify:dev'
  ]
  grunt.initConfig
    pkg: grunt.file.readJSON('package.json')
    clean: ['out', 'dist']
    symlink:
      expanded:
        files: [
          {
            expand: true
            cwd: 'client'
            src: ['*.css', '*.html']
            dest: 'out/client'
          }
        ]
    coffee:
      files:
        expand: true,
        cwd: 'server'
        src: ['**/*.coffee'],
        dest: 'out/server'
        ext: '.js'
    browserify:
      dev: {
        options: {
          debug: true,
          transform: ['reactify']
        },
        files: {
          'out/client/app.js': 'client/*.jsx'
        }
      },

  grunt.loadNpmTasks('grunt-contrib-coffee')
  grunt.loadNpmTasks('grunt-contrib-symlink')
  grunt.loadNpmTasks('grunt-browserify')

  grunt.registerTask('default', all)
