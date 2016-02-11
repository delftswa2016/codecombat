ModalView = require 'views/core/ModalView'
template = require 'templates/core/create-account-modal'
{loginUser, createUser, me} = require 'core/auth'
forms = require 'core/forms'
User = require 'models/User'
application  = require 'core/application'

module.exports = class AuthModal extends ModalView
  id: 'create-account-modal'
  template: template

  events:
    # login buttons
    'click #switch-to-login-btn': 'onClickSwitchToLoginButton'
    'submit form': 'onSubmitForm'
    'keyup #name': 'onNameChange'
    'click #gplus-login-button': 'onClickGPlusLoginButton'
    'click #facebook-login-btn': 'onClickFacebookLoginButton'
    'click #close-modal': 'hide'

  subscriptions:
    'errors:server-error': 'onServerError'
    'auth:logging-in-with-facebook': 'onLoggingInWithFacebook'

  initialize: (options={}) ->
    @onNameChange = _.debounce @checkNameExists, 500
    @previousFormInputs = options.initialValues or {}
    @listenTo application.gplusHandler, 'logged-into-google', @onGPlusHandlerLoggedIntoGoogle
    @listenTo application.gplusHandler, 'person-loaded', @onGPlusPersonLoaded

  afterRender: ->
    super()
    @playSound 'game-menu-open'

  afterInsert: ->
    super()
    _.delay (=> application.router.renderLoginButtons()), 500
    _.delay (=> $('input:visible:first', @$el).focus()), 500

  onClickSwitchToLoginButton: (e) ->
    # open login modal instead

  onSubmitForm: (e) ->
    @playSound 'menu-button-click'
    e.preventDefault()
    forms.clearFormAlerts(@$el)
    console.log '1'
    return unless @gplusAttrs or @emailCheck()
    userObject = forms.formToObject @$el
    delete userObject.subscribe
    delete userObject.name if userObject.name is ''
    delete userObject.schoolName if userObject.schoolName is ''
    userObject.name = @suggestedName if @suggestedName
    for key, val of me.attributes when key in ['preferredLanguage', 'testGroupNumber', 'dateCreated', 'wizardColor1', 'name', 'music', 'volume', 'emails', 'schoolName']
      userObject[key] ?= val
    subscribe = @$el.find('#subscribe').prop('checked')
    userObject.emails ?= {}
    userObject.emails.generalNews ?= {}
    userObject.emails.generalNews.enabled = subscribe
    if @gplusAttrs
      _.assign userObject, @gplusAttrs
    res = tv4.validateMultiple userObject, User.schema
    console.log '2', res
    return forms.applyErrorsToForm(@$el, res.errors) unless res.valid
    Backbone.Mediator.publish "auth:signed-up", {}
    window.tracker?.trackEvent 'Finished Signup', label: 'CodeCombat'
    @enableModalInProgress(@$el)
    console.log 'create user?', userObject
    createUser userObject, null, window.nextURL
    false

  emailCheck: ->
    # TODO: Move to forms
    email = $('#email', @$el).val()
    filter = /^[A-Z0-9._%+-]+@[A-Z0-9.-]+\.[A-Z]{2,63}$/i  # https://news.ycombinator.com/item?id=5763990
    unless filter.test(email)
      forms.setErrorToProperty @$el, 'email', 'Please enter a valid email address', true
      return false
    return true

  onLoggingInWithFacebook: (e) ->
    modal = $('.modal:visible', @$el)
    @enableModalInProgress(modal) # TODO: part of forms

  onServerError: (e) -> # TODO: work error handling into a separate forms system
    @disableModalInProgress(@$el)

  checkNameExists: =>
    name = $('#name', @$el).val()
    return forms.clearFormAlerts(@$el) if name is ''
    User.getUnconflictedName name, (newName) =>
      forms.clearFormAlerts(@$el)
      if name is newName
        @suggestedName = undefined
      else
        @suggestedName = newName
        forms.setErrorToProperty @$el, 'name', "That name is taken! How about #{newName}?", true

  onClickGPlusLoginButton: ->
    @clickedGPlusLogin = true

  onGPlusHandlerLoggedIntoGoogle: ->
    return unless @clickedGPlusLogin
    application.gplusHandler.loginCodeCombat()
    @$('#gplus-login-btn .sign-in-blurb').text($.i18n.t('signup.creating')).attr('disabled', true)

  onGPlusPersonLoaded: (@gplusAttrs) ->
    @$('#email-password-row, #gplus-logged-in-row').toggleClass('hide')

  onClickFacebookLoginButton: ->
    application.facebookHandler.loginThroughFacebook()

  onHidden: ->
    super()
    @playSound 'game-menu-close'
