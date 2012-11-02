async = require 'async'

RedisObject = require './redis_object'
Files = require './files'

###*
 * A helper for working with branches for an application/user combo.
###
class ApplicationBranch extends RedisObject
  constructor: (@user, @application, branch=null) ->
    super branch
    @basename = "node-ios-ota::applications"
    @object_name = 'branches'

  ###*
   * Returns the the prefix for the branchlist.
   * @return {String} The branchlist prefix for the current application
  ###
  branchlist_prefix: =>
    return [@basename, @user, @application, @object_name].join('::')

  ###*
   * Returns the list of branches for the given user/application.
   * @param {Function} (fn) The callback function
  ###
  list: (fn) =>
    return @redis.smembers(@branchlist_prefix(), fn)

  ###*
   * Inserts a new branch into the given application.
   * @param {String} (branch) The name of the branch to add
   * @param {Function} (fn) The callback function
  ###
  save: (fn) =>
    stat_add = @redis.sadd(@branchlist_prefix(), @current)
    status = if (stat_add) then null else
      message: "Error saving branch: `#{@user}/#{@application}/#{@current}`."
    fn(status, @current)

  ###*
   * Deletes a single branch for the given application.
   * @param {String} (branch) The name of the target branch
   * @param {Function} (fn) The callback function
  ###
  delete: (branch, fn) =>
    @current = branch
    @redis.srem(@branchlist_prefix(), branch)
    @files().delete_all (err, reply) =>
      fn(null)

  ###*
   * Deletes the branches for a given application.
   * @param {Function} (fn) The callback function
  ###
  delete_all: (fn) =>
    @list (err, branchlist) =>
      async.forEach(branchlist, @delete, fn)

  ###*
   * Returns the list of files for the current branch.
   * @return {Object} The Files object for the current branch
  ###
  files: =>
    return new Files(@user, @application, @object_name, @current)

module.exports = ApplicationBranch
