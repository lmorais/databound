_ = require 'lodash'
jQuery = require 'jquery'

# You can specify scope for the connection.
#
# ```coffeescript
#   User = new Databound '/users', city: 'New York'
#
#   User.where(name: 'John').then (users) ->
#     alert 'You are a New Yorker called John'
#
#   User.create(name: 'Peter').then (new_user) ->
#     # I am from New York
#     alert "I am from #{new_user.city}"
# ```
class Databound
  constructor: (@endpoint, @scope = {}, @options = {}) ->
    @extra_where_scopes = @options.extra_where_scopes or []
    @records = []
    @seeds = []
    @properties = []

  # ## Start of Configs
  # Functions ``request`` and ``promise`` are overritable
  Databound.API_URL = ""

  # Does a POST request and returns a ``promise``
  request: (action, params) ->
    jQuery.post @url(action), @data(params), 'json'

  # Returns a ``promise`` which resolves with ``result``
  promise: (result) ->
    deferred = jQuery.Deferred()
    deferred.resolve result
    deferred.promise()
  # ## End of Configs

  where: (params) ->
    _this = @

    @request('where', params).then (records) ->
      records = records.concat(_this.seeds)
      _this.records = _.sortBy(records, 'id')
      _this.promise _this.records

  # Return a single record by ``id``
  #
  # ```coffeescript
  # User.find(15).then (user) ->
  #   alert "Yo, #{user.name}"
  # ```
  find: (id) ->
    _this = @

    @where(id: id).then ->
      _this.promise _this.take(id)

  # Return a single record by ``params``
  #
  # ```coffeescript
  # User.findBy(name: 'John', city: 'New York').then (user) ->
  #   alert "I'm John from New York"
  # ```
  findBy: (params) ->
    _this = @

    @where(params).then (resp) ->
      _this.promise _.first(_.values(resp))

  create: (params) ->
    @requestAndRefresh 'create', params

  # Specify ``id`` when updating or destroying the record.
  #
  # ```coffeescript
  #   User = new Databound '/users'
  #
  #   User.update(id: 15, name: 'Saint John').then (updated_user) ->
  #     alert updated_user
  #
  #   User.destroy(15).then (resp) ->
  #     alert resp.success
  # ```
  update: (params) ->
    @requestAndRefresh 'update', params

  destroy: (id) ->
    @requestAndRefresh 'destroy', id: id

  # Just take already dowloaded records
  take: (id) ->
    _.detect @records, (record) ->
      id.toString() == record.id.toString()

  takeAll: ->
    @records

  # f.e. Have default records
  injectSeedRecords: (records) ->
    @seeds = records

  requestAndRefresh: (action, params) ->
    _this = @

    # backend responds with:
    #
    # ```javascript
    #   {
    #     success: true,
    #     id: record.id,
    #     scoped_records: []
    #   }
    # ```
    @request(action, params).then (resp) ->
      throw new Error 'Error in the backend' unless resp?.success

      records = JSON.parse(resp.scoped_records)
      records_with_seeds = records.concat(_this.seeds)
      _this.records = _.sortBy(records_with_seeds, 'id')

      if resp.id
        _this.promise _this.take(resp.id)
      else
        _this.promise resp.success

  url: (action) ->
    if _.isEmpty(Databound.API_URL)
      "#{@endpoint}/#{action}"
    else
      "#{Databound.API_URL}/#{@endpoint}/#{action}"

  data: (params) ->
    scope: JSON.stringify(@scope)
    extra_where_scopes: JSON.stringify(@extra_where_scopes)
    data: JSON.stringify(params)

module.exports = Databound
