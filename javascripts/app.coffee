---
---

$ -> NPR.init()

# =================================================================
hideNav = ->
  setTimeout ->
    window.scrollTo(0, 1)
    # so nav bar doesn't show up when changing #stories html
    $(".wrapper").css minHeight: 920
  , 0

$(window).load -> hideNav()

# =================================================================
class window.Story
  volume: 1
  constructor: (@data, @showTitle, @showCode)->
    @id = @data.id
    @title = @data.title.$text
    seconds = @data.audio[0].duration.$text
    @duration = "#{padString Math.floor(seconds / 60)}:"+
      "#{padString(seconds % 60)}"
    @mp3 = @data.audio[0].format.mp3[0].$text
    date = new Date @data.storyDate.$text
    @date = "#{date.getMonth()+1}.#{date.getDate()}.#{date.getFullYear()}"

    @url = @data.link[2].$text
    @imgSrc = @data.image?[0].src

  hasPlayed: -> NPR.hasPlayed @

  play: -> Player.playStory @

  html: ->
    $(_.template NPR.storyTmpl, @).find(".playBtn").click(=> @play()).end()

  update: -> @container.html @html()

  render: ->
    @container = $("<div/>", class: "story")
    @el$ ?= @update()

  showImage: -> NPR.getSetting "ShowImage"

class window.HourlyStory extends Story
  volume: 0.5
  constructor: (@data)->
    @id = @data.guid
    @title = @data.title
    @duration = @data.enclosure.duration / 1000
    @mp3 = @data.enclosure.url
    @date = @data.pubDate
    @hourly = true

    @showTitle = @data.title
    @showCode = "hourly"

  update: -> # stub

# =================================================================
window.Player =
  playing: false
  audio: null

  setSrc: (src)-> @audio.src = src

  playStory: (story)->
    $(@audio).show()

    @story?.el$?.removeClass "playing"
    @story = story

    return @playToggle(false) unless @story

    @story.el$?.addClass "playing"

    @setSrc @story.mp3
    @playToggle()

    NPR.updateTitle story

  play: ->
    @playing = true
    @errorCount = 0
    @audio.volume = @story.volume
    @audio.play()

  pause: ->
    @playing = false
    @audio.pause()

  playToggle: (doPlay)->
    # log "playToggle: #{doPlay}, @playing: #{@playing}"
    if doPlay && @story
      @play()
    else
      if @story
        if @playing
          @pause()
        else
          @play() unless doPlay == false || NPR.checkDoNotPlay()
      else
        @playStory NPR.stories[0]


  next: (setPlayed=true)->
    @playing = false
    NPR.storePlayed @story if setPlayed
    @playStory NPR.getNextStory @story

  init: ->
    @audio = $("#player").get(0)

    $("#playBtn").click => @playToggle()

    @audio.volume = 1
    @audio.addEventListener "ended", => @next()

    _.each ["error", "stalled"], (e)=>
      @audio.addEventListener e, => @errorHandler(e)

    $('body').keypress (e)=>
      if e.keyCode == 32
        @playToggle()
        false

  errorCount: 0
  errorHandler: (e)->
    if e == "stalled" || e == "error"
      @errorCount++
      log "errors: #{@errorCount}"
      # @next false

# =================================================================
window.NPR =
  apiKey: "MDAzMzQ2MjAyMDEyMzk4MTU1MDg3ZmM3MQ010" # mp3
  # apiKey: "MDEwNzMzNTQ3MDEzNTgyMjE5MDhiNGU2Nw001" # only m3u

  stories: []

  showIds:
    atc: 2
    me: 3
    we_sat: 7
    we_sun: 10

  showCount: 4

  page: 0

  settings:
    AutoPlay:
      default: true
    ShowImage:
      default: true
      callback: -> @rerender()
    StartWithHourly:
      default: true
    Colorscheme:
      default: "dark"
      callback: -> @drawColors()

  localSettings: {}

  getSetting: (s)->
    @localSettings[s] ?= @settings[s].default

  checkDoNotPlay: ->
    doNotPlay = @doNotPlay
    @doNotPlay = false
    doNotPlay

  drawColors: ->
    $("body").attr("class", "").addClass @getSetting "Colorscheme"

  rerender: ->
    story.update() for story in @stories

  load: (@showCode, doPlay=true)->
    return @loadHourly() if showCode == 'hourly'
    return Player.next() if @showId == @showIds[@showCode]

    @showId = @showIds[@showCode]
    @stories = []
    $("#stories").html ''
    $("#title").html 'Loading...'
    $("#titleDate").html ''

    @loadPage 0, doPlay, -> hideNav()

    false

  backDates: 0
  loadPage: (@page, doPlay=false, callback=null)->
    d = @showDates[@showId]
    date = moment(d).subtract('days',@backDates).format "YYYY-MM-DD"

    $.getJSON "http://api.npr.org/query?id=#{@showId}&"+
      "fields=titles,audio,storyDate,image&date=#{date}&dateType=story"+
      "&sort=assigned&output=JSON&numResults=20&requiredAssets=audio"+
      "&startNum=#{@page * 20 + 1}&apiKey=#{@apiKey}&callback=?", (json)=>

        console.log json

        unless json.list.story?.length > 0
          @backDates++
          @page = 0
          return @loadPage @page, doPlay, callback

        else
          showTitle = json.list.title.$text
          _.each json.list.story, (data, i)=>

            story = new Story data, showTitle, @showCode

            $("#stories").append story.render()

            @stories.push story

            story.play() if i == 0 && doPlay

          @checkOrientation()
          callback?()

  loadMore: -> @loadPage @page+1

  getNextStory: (story)->
    i = 1
    loop
      nextStory = @stories[@stories.indexOf(story) + i++]
      return nextStory unless nextStory && nextStory.hasPlayed()

  storePlayed: (story)->
    if localStorage?
      ids = @playedStoryIds()
      ids.push story.id
      localStorage.playedStoryIds = JSON.stringify ids

    story.update()
    @checkOrientation()

  playedStoryIds: ->
    JSON.parse(localStorage.playedStoryIds || "[]")

  clearPlayedStoryIds: -> localStorage.playedStoryIds = "[]"

  hasPlayed: (story)->
    if localStorage? && localStorage.playedStoryIds?
      @playedStoryIds().indexOf(story.id) != -1

  updateTitle: (story)->
    $("#title").html story.showTitle
    unless story.hourly
      $("#titleDate").html story.date

    title = story.showTitle
    title += " | #{fullDate}" if fullDate?
    document.title = "#{title} | NPR.io"

    $("#showSelect").find("a").removeClass('current').end()
      .find("a[data-show=#{story.showCode}]").addClass 'current'


  init: ->
    @storyTmpl = $('#tmpl-story').html()

    @timeOffest = new Date().getTimezoneOffset() / 60

    Player.init()

    # determine closest show by date
    closestDate = null
    closestShow = null
    i = 0

    @showDates = {}
    _.each @showIds, (id,code)=>
      $.getJSON "http://api.npr.org/query?id=#{id}&fields=storyDate"+
        "&sort=dateDesc&output=JSON&numResults=1&requiredAssets=audio"+
        "&apiKey=#{@apiKey}&callback=?", (json)=>

          date = new Date json.list.story[0].storyDate.$text
          @showDates[id] = date

          if !closestDate || date > closestDate
            closestDate = date
            closestShow = code

          if i++ == @showCount - 1

            startWithHourly = @getSetting "StartWithHourly"
            @load closestShow, !startWithHourly
            @loadHourly() if startWithHourly

    # setup events

    $("#loadMore").click => @loadMore()

    $(".wrapper").css paddingTop: $("#player").height() + 50

    $("#showSelect").click (e)=>
      el = $ e.target
      @load el.attr('data-show')

    # setup settings
    $('#settingsBtn a, #settingsCloseBtn a').click =>
      $("#front, #back").toggleClass "flipped"
      $("#settings").css marginTop: $(window).scrollTop()

    # for setting in @settings
    @localSettings = JSON.parse(localStorage?.settings || "{}")

    _.each @settings, (setting, name)=>

      val = @localSettings[name] ?= @settings[name].default

      handler = (boolean)=>
        (e)=>
          el$ = $(e.target)

          @localSettings[name] = unless boolean then el$.val() else
            !!el$.attr("checked")

          localStorage?.settings = JSON.stringify @localSettings
          setting.callback?.call @

      el$ = $("#s#{name}")
      if typeof val == "boolean"
        el$.attr("checked", (if val then "checked" else false))
          .change handler(true)
      else
        el$.find("input").change(handler(false)).
          end().find("input[value=#{val}]").attr "checked", true

    # orientation changes
    $("body").on "orientationchange", @checkOrientation

    @doNotPlay = !@getSetting("AutoPlay")
    @drawColors()

    @iOS = window.navigator.userAgent.match(/iphone/i) ||
      window.navigator.userAgent.match(/ipad/i)

    # iOS won't let audio auto-play w/o a user event
    if @iOS
      $("#front, #back").css "-webkit-transform-style", "preserve-3d"
      if @getSetting("AutoPlay")
        $("#overlay").show().click =>
            $("#overlay").hide()
            Player.play()

  checkOrientation: ->
    $(".playBtn span").toggle window.orientation != 0

  loadHourly: ->
    url = "http://query.yahooapis.com/v1/public/yql?q="+
      "select%20*%20from%20rss%20where%20url%3D%22http%3A%2F%2Fwww.npr.org%2F"+
      "rss%2Fpodcast.php%3Fid%3D500005%22&format=json&diagnostics=true&"+
      "callback=?"

    $.getJSON url, (data)=>
      item = data.query.results.item

      hourlyStory = new HourlyStory item
      hourlyStory.play @getSetting("AutoPlay")

# ===============================================

window.log = (args...)->
  try
    console.log args...
  catch e

padString = (number, digits=2)->
  Array(Math.max(digits - String(number).length + 1, 0)).join(0) + number