fs = require 'fs'
async = require 'async'

RedisObject = require './redis_object'
Files = require './files'
logger = require '../logger'

###
A helper for working with tags for an application/user combo.
###
class ApplicationTag extends RedisObject
  constructor: (@user, @application, tag=null) ->
    super tag
    @basename = "node-ios-ota::applications"
    @object_name = 'tags'

  ###
  Returns the the prefix for the taglist.
  @return {String} The taglist prefix for the current application
  ###
  taglist_prefix: =>
    return [@basename, @user, @application, @object_name].join('::')

  ###
  Returns the list of tags for the given user/application.
  @param {Function} (fn) The callback function
  ###
  list: (fn) =>
    return @redis.smembers(@taglist_prefix(), fn)

  ###
  Returns the information for the current application tag.
  @param {String} (name) The name of the tag to retrieve
  @param {Function} (fn) The callback function
  ###
  find: (name, fn) =>
    original = @current
    @current = name
    @files().all (err, reply) =>
      @current = original
      fn(err, {name: name, files: reply})

  ###
  Returns the information for all the current application tags.
  @param {Function} (fn) The callback function
  ###
  all: (fn) =>
    @list (err, tags) =>
      async.map tags, @find, (err, results) =>
        fn(err, {tags: results})

  ###
  Inserts a new tag into the given application.
  @param {String} (branch) The name of the branch to add
  @param {Function} (fn) The callback function
  ###
  save: (fn) =>
    stat_add = @redis.sadd(@taglist_prefix(), @current)
    status = if (stat_add) then null else
      message: "Error saving tag: `#{@user}/#{@application}/tags/#{@current}`."
    @setup_directories @current, (err, reply) =>
      fn(status, @current)

  ###
  Deletes a single tag for the given application.
  @param {String} (tag) The name of the target tag
  @param {Function} The callback function
  ###
  delete: (tag, fn) =>
    @current = tag
    @redis.srem(@taglist_prefix(), tag)
    @files().delete_all (err, reply) =>
      @delete_directories tag, (err, reply) =>
        fn(null, true)

  ###
  Deletes all of the tags for the current application.
  @param {Function} The callback function
  ###
  delete_all: (fn) =>
    @list (err, taglist) =>
      async.each(taglist, @delete, fn)

  ###
  Returns the list of files for the current tag.
  @return {Object} The Files object for the current application
  ###
  files: =>
    return new Files(@user, @application, @object_name, @current)

  ###
  Creates the directories for the tag.
  @param {Object} (tag) The tag to create directories for
  @param {Function} (fn) The callback function
  ###
  setup_directories: (tag, fn) =>
    dirloc = [@user, @application, @object_name, tag].join('/')
    target = [config.get('repository'), dirloc].join('/')
    fs.exists target, (exists) =>
      unless exists
        fs.mkdir target, (err, made) =>
          if err
            logger.error "Error setting up directories for `#{dirloc}`."
          fn(err, made)
      else
        fn(null, false)

  ###
  Deletes the directories for the application.
  @param {Object} (tag) The tag to create directories for
  @param {Function} (fn) The callback function
  ###
  delete_directories: (tag, fn) =>
    dirloc = [@user, @application, @object_name, tag].join('/')
    fs.rmdir [config.get('repository'), dirloc].join('/'), (err) =>
      if err
        logger.error "Error removing directories for `#{dirloc}`."
      fn(null, true)

module.exports = ApplicationTag
