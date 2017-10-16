require 'krpc'
require_relative './pid'

class MissionControl
  attr_reader :krpc

  def self.begin_countdown
    mc = new
    mc.looper
  ensure
    mc.close if mc
  end

  def initialize
    @krpc = KRPC.connect(name: 'KRW Presenter')
  end

  def looper
    vessel = krpc.space_center.active_vessel
    states = StateFactory.new(krpc)

    pid_heading = Pid.new("heading", k_p: 0.06, k_i: 0, k_d: 0.008, mult: 0.001, desired: 90)
    pid_heading.clamp(min: -1, max: 1)

    pid_pitch = Pid.new("pitch", k_p: 0.006, k_i: 0.0001, k_d: 0.003, mult: 0.001, desired: 90)
    pid_pitch.clamp(min: -1, max: 1)

    dt = 0.2
    puts "   alt      apo      peri ptch  st"

    canvas = krpc.ui.stock_canvas
    screen_size = canvas.rect_transform.size

    launch_panel = canvas.add_panel
    launch_panel_rect = launch_panel.rect_transform
    launch_panel_rect.size = [200, 100]
    launch_panel_rect.position = [110 - (screen_size[0] / 2), 0]

    launch_button = launch_panel.add_button("Launch")
    launch_button.rect_transform.position = [0, 20]

    go_for_launch = launch_button.clicked_stream

    loop do

      state = states.tick
      if state.stage < 6 || (go_for_launch.get rescue false)
        if state.stage == 6
          vessel.control.activate_next_stage
          launch_panel.remove
        end

        foo = desired_pitch(state.altitude)
        print "  #{foo}"
        pid_pitch.desired = foo

        new_pitch = pid_pitch.tick(actual: state.pitch, dt: dt)
        new_yaw = pid_heading.tick(actual: state.heading, dt: dt)


        if state.altitude > 100
          vessel.control.yaw = new_yaw
          vessel.control.pitch = new_pitch
        end

        replace = false
        print (replace ? "\r" : "\n") + state.to_s + " " * 20

        print " %01.4f  %03.1f %01.4f" % [new_pitch, state.pitch, new_yaw]
      end

      sleep dt
    end
  end

  def desired_pitch(alt)
    if alt > 100_000
      0
    elsif alt < 1_000
      90.0
    else
      90 * Math.sqrt(1 - (alt / 100_000) ** 2)
    end
  end

  def close
    krpc.close
  end

end

class StateFactory
  attr_reader :streams

  def initialize(ksp)
    @streams = {}
    vessel = ksp.space_center.active_vessel
    flight = vessel.flight
    orbit = vessel.orbit
    control = vessel.control

    @streams[:altitude] = flight.mean_altitude_stream
    @streams[:apoapsis] = orbit.apoapsis_altitude_stream
    @streams[:periapsis] = orbit.periapsis_altitude_stream
    @streams[:pitch] = flight.pitch_stream
    @streams[:heading] = flight.heading_stream
    @streams[:stage] = control.current_stage_stream

    @state_class = make_state_class

    @current_state = nil
  end

  def make_state_class
    _streams = streams
    Class.new(Object) do
      attr_accessor(*(_streams.keys))
      attr_reader(*(_streams.keys.map{|attr| "#{attr}_changed"}))

      define_method :initialize do |params, prev_state|
        (_streams.keys).each do |attr|
          send "#{attr}=", params[attr]

          instance_variable_set("@#{attr}_changed", (send(attr) == prev_state.send(attr) rescue true))
        end
      end

      def to_s
        "%3d  %3d" % [heading, pitch]
      end
    end
  end

  def tick
    hash = streams.reduce({}) do |memo, (name, stream)|
      memo.merge({name => stream.get})
    end

    @current_state = @state_class.new(hash, @current_state)
  end

end
