require 'websocket-eventmachine-client'
require 'eventmachine'
require 'json'

class Reporter
  URI = "ws://localhost:3000/cable/"
  AUTH = 'foo'

  def self.run(&blk)
    EventMachine.run do
      reporter = new(URI, AUTH)
      reporter.on_subscribe do
        EventMachine.next_tick do
          blk.call(reporter)
        end
      end
    end
  end

  def each_tick(dt, &blk)
    EM.add_periodic_timer(dt, &blk)
  end

  def stop
    EM.stop
  end

  def initialize(uri, auth)
    @connected = false
    @last_report_time = Time.now.to_f - 10000000

    headers = {
      'Authorization' => 'Bearer foo'
    }
    @client = WebSocket::EventMachine::Client.connect(uri: uri, headers: headers) #, "KspChannel", true, headers)
    @client.onopen { puts "CONNECTED TO WS"; @connected = true }
    @client.onerror {|e| puts "Error: #{e}"}
    @client.onmessage do |msg, type|
      handle_message(msg)
    end
    @_welcome_callbacks = [-> {subscribe_to_ksp}]
  end

  def handle_message(msg)
    json = JSON.parse(msg)
    cbs =
      case json['type']
      when 'welcome'
        @_welcome_callbacks
      when 'ping'
        @_ping_callbacks
      when 'confirm_subscription'
        @_subscribe_callbacks
      end

    (cbs || []).each(&:call)
  end

  def subscribe_to_ksp
    puts "subscribing..."
    @client.send({command: 'subscribe', identifier: identifier}.to_json)
  end

  def on_subscribe(&blk)
    @_subscribe_callbacks ||= []
    @_subscribe_callbacks << blk
  end

  def report(activity, data)
    current_time = Time.now.to_f

    if @last_report_time < current_time - 0.5
      @last_report_time = current_time

      @client.send({
        command: 'message',
        identifier: identifier,
        data: data.merge({action: activity}).to_json
      }.to_json)
    end
  end

  def identifier
    {channel: 'KspChannel'}.to_json
  end

  # def connected(&blk)
  #   @client.connected(&blk)
  # end

  # def subscribed(&blk)
  #   @client.subscribed(&blk)
  # end

  # def pinged(&blk)
  #   @client.pinged do |msg|
  #     puts "pinged: #{msg}"
  #   end
  # end

end
