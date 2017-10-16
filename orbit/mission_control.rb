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
    vessel = @krpc.space_center.active_vessel
    state = State.new(vessel)

    pid_heading = Pid.new("heading", k_p: 0.06, k_i: 0, k_d: 0.008, mult: 0.001, desired: 90)
    pid_heading.clamp(min: -1, max: 1)

    pid_pitch = Pid.new("pitch", k_p: 0.006, k_i: 0.0001, k_d: 0.003, mult: 0.001, desired: 90)
    pid_pitch.clamp(min: -1, max: 1)

    dt = 0.2
    puts "   alt      apo      peri ptch  st"

    loop do
      state.update

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

class State
  attr_reader :altitude, :apoapsis, :periapsis, :pitch, :heading, :stage

  def initialize(vessel)
    #refframe = vessel.orbit.body.reference_frame

    @altitude_stream = vessel.flight.mean_altitude_stream
    @apoapsis_stream = vessel.orbit.apoapsis_altitude_stream
    @periapsis_stream = vessel.orbit.periapsis_altitude_stream
    @pitch_stream = vessel.flight.pitch_stream
    @heading_stream = vessel.flight.heading_stream
    @stage_stream = vessel.control.current_stage_stream
  end

  def update
    @altitude = @altitude_stream.get
    @apoapsis = @apoapsis_stream.get
    @periapsis = @periapsis_stream.get
    @pitch = @pitch_stream.get
    @heading = @heading_stream.get
    @stage = @stage_stream.get
  end

  def to_s
    "%3d  %3d" % [heading, pitch]
  end
end
