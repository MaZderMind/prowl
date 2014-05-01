#!/usr/bin/env ruby
# vim:fileencoding=UTF-8:
# encoding: UTF-8

require 'yaml'
require 'httparty'
require 'net/irc'

class ProwlPushClient < Net::IRC::Client

  def initialize(server, opts)
    super(server['host'], server['port'], opts)
    @channels = server['channels']
  end

  def on_rpl_welcome(m)
    @log.debug "ON_RPL_WELCOME #{m.inspect}"
    post JOIN, @channels.join(',')
  end

  def on_privmsg(m)
    @log.debug "ON_PRIVMSG #{m.inspect}"

    # regular channel message
    #<Net::IRC::Message:0x4564064 prefix:jdrowell!~jdrowell@189-19-127-17.dsl.telesp.net.br command:PRIVMSG params:["#nosqlbr", "hi there"]>

    # private message /MSG
    #<Net::IRC::Message:0x4dd2fc0 prefix:jdrowell!~jdrowell@189-19-127-17.dsl.telesp.net.br command:PRIVMSG params:["prowlbot", "this is a secret"]>

    nick, user = m.prefix.split('!')
    is_public = m[0][0] == '#'
    channel = m[0] if is_public
    msg = m[1].force_encoding('UTF-8')

    interesting = false
    @opts.watchlist.each do |word|
      interesting |= msg.include? word
    end

    if is_public && interesting

      @log.info 'Msg from '+nick+' in channel '+channel+' forwarded: '+msg
      HTTParty.post('https://api.prowlapp.com/publicapi/add', :query => {
        :apikey => @opts.apikey,
        :application => channel,
        :event => 'Msg from '+nick,
        :description => msg
      })

    end
    if !is_public

      @log.info 'Query from '+nick+' forwarded: '+msg
      HTTParty.post('https://api.prowlapp.com/publicapi/add', :query => {
        :apikey => @opts.apikey,
        :application => 'IRC',
        :event => 'Query from '+nick,
        :description => m[1],
        :priority => 1
      })

    end

  end
end

opts = YAML.load_file('prowl.yaml')

opts['servers'].each do |server|
  cli = ProwlPushClient.new(server, opts)
  cli.start
end
