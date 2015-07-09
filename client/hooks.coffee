hooks = Iron.Router.hooks

sessionKey = 'iron-router-auth'

hooks.authenticate = ->
  if @route.getName() is '__notfound__' or Meteor.userId()
    @next()
    return

  if Meteor.loggingIn()
    # Remove warning about this.next(), we know what we're doing
    @_rendered = true
    return

  ns = 'authenticate'

  options = @lookupOption ns

  if options is false
    @next()
    return

  {
    allowExternalRoute
    home
    layout
    logout
    replaceState
    route
    template
  } = options ? {}

  logout ?= 'logout'

  route = options if _.isString options

  check allowExternalRoute, Match.Optional Match.OneOf Boolean, Function
  check home, Match.Optional Match.OneOf Function, String
  check layout, Match.Optional Match.OneOf Function, String
  check logout, Match.Optional Match.OneOf Function, String
  check replaceState, Match.Optional Match.OneOf Boolean, Function
  check route, Match.Optional Match.OneOf Function, String
  check template, Match.Optional Match.OneOf Function, String

  replaceState ?= true

  replaceState = replaceState.apply @ if _.isFunction replaceState

  logout = logout.apply @ if _.isFunction logout

  if @route.getName() is logout and not Meteor.userId()
    home = home.apply @ if _.isFunction home
    home = '/' unless @router.routes[home] and home
    @redirect home, {}, replaceState: replaceState
    return

  route = route.apply @ if _.isFunction route

  if @router.routes[route]
    params = {}
    params[key] = value for own key, value of @params

    sessionValue =
      params: params
      route: @route.getName()

    Session.set sessionKey, sessionValue
    @redirect route, {}, replaceState: replaceState
    return

  if _.isFunction allowExternalRoute
    allowExternalRoute = allowExternalRoute.apply @

  if allowExternalRoute and route
    @redirect route
    return

  template = template.apply @ if _.isFunction template

  template = false if _.isString template and not Template[template]

  layout = layout.apply @ if _.isFunction layout

  @layout = layout if layout
  @render template or new Template -> 'Not authenticated...'
  @renderRegions()

  if route
    console.warn "Route \"#{route}\" for authenticate hook not found."

  else if not template
    if template is false
      console.warn "Template \"#{template}\" for authenticate hook not found."

    else if not route
      console.warn 'No route or template set for authenticate hook.'

    else
      console.warn 'No template set for authenticate hook.'

hooks.authorize = ->
  if @route.getName() is '__notfound__'
    @next()
    return

  authenticate = @lookupOption 'authenticate'

  if authenticate is false
    @next()
    return

  if Meteor.loggingIn() or not Meteor.userId()
    # Remove warning about this.next(), we know what we're doing
    @_rendered = true
    return

  ns = 'authorize'

  options = @lookupOption ns

  if options is false
    @next()
    return

  {
    allow
    allowExternalRoute
    deny
    layout
    replaceState
    route
    template
  } = options ? {}

  check allow, Match.Optional Function
  check allowExternalRoute, Match.Optional Match.OneOf Boolean, Function
  check deny, Match.Optional Function
  check layout, Match.Optional Match.OneOf Function, String
  check replaceState, Match.Optional Match.OneOf Boolean, Function
  check route, Match.Optional Match.OneOf Function, String
  check template, Match.Optional Match.OneOf Function, String

  if not allow? and deny?
    authorized = not deny()

  else if allow? and not deny?
    authorized = allow()

  else if allow? and deny?
    authorized = not deny() and allow()

  if authorized
    @next()
    return

  if Package.insecure
    console.warn 'Remove "insecure" package to respect allow and deny rules.'
    @next()
    return

  replaceState ?= true

  replaceState = replaceState.apply @ if _.isFunction replaceState

  route = route.apply @ if _.isFunction route

  if @router.routes[route]
    params = {}
    params[key] = value for own key, value of @params

    sessionValue =
      notAuthorized: true
      params: params
      route: @route.getName()

    Session.set sessionKey, sessionValue
    @redirect route, {}, replaceState: replaceState
    return

  if _.isFunction allowExternalRoute
    allowExternalRoute = allowExternalRoute.apply @

  if allowExternalRoute and route
    @redirect route
    return

  @state.set sessionKey,
    notAuthorized: true

  template = template.apply @ if _.isFunction template

  template = false if _.isString template and not Template[template]

  layout = layout.apply @ if _.isFunction layout

  @layout layout if layout
  @render template or new Template -> 'Access denied...'
  @renderRegions()

  if route
    console.warn "Route \"#{route}\" for authorize hook not found."

  else if not template
    if template is false
      console.warn "Template \"#{template}\" for authorize hook not found."

    else if not route
      console.warn 'No route or template set for authorize hook.'

    else
      console.warn 'No template set for authorize hook.'

hooks.noAuth = ->
  if @route.getName() is '__notfound__'
    @next()
    return

  if Meteor.loggingIn()
    # Remove warning about this.next(), we know what we're doing
    @_rendered = true
    return

  unless Meteor.userId()
    @next()
    return

  sessionValue = Session.get sessionKey

  if Meteor.userId() and sessionValue?.notAuthorized
    @next()
    return

  ns = 'noAuth'

  options = @lookupOption ns

  {
    allowExternalRoute
    dashboard
    home
    replaceState
  } = options ? {}

  route = options if _.isString options

  check allowExternalRoute, Match.Optional Match.OneOf Boolean, Function
  check dashboard, Match.Optional Match.OneOf Function, String
  check home, Match.Optional Match.OneOf Function, String
  check replaceState, Match.Optional Match.OneOf Function, Boolean

  if _.isFunction allowExternalRoute
    allowExternalRoute = allowExternalRoute.apply @

  dashboard = dashboard.apply @ if _.isFunction dashboard
  home = home.apply @ if _.isFunction home

  if dashboard
    route = dashboard if @router.routes[dashboard]

  else if home
    route = home if @router.routes[home]

  else if allowExternalRoute and dashboard
    route = dashboard

  else if allowExternalRoute and home
    route = home

  replaceState ?= true

  replaceState = replaceState.apply @ if _.isFunction replaceState

  route = sessionValue?.route ? route

  route = route.apply @ if _.isFunction route

  route = '/' unless route and @router.routes[route]

  params = sessionValue?.params ? {}

  delete Session.keys[sessionKey]

  @redirect route, params, replaceState: replaceState

  if route is '/'
    if dashboard
      console.warn "Route \"#{dashboard}\" for noAuth hook not found, using" +
        "\"/\""

    else if home
      console.warn "Route \"#{home}\" for noAuth hook not found, using \"/\""

    else
      console.warn "No route or template set for noAuth hook, using \"/\""
