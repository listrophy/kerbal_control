require 'krpc'
require_relative './state_factory'
require_relative './checklist'

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
    krpc.space_center.active_vessel.control.sas = true
    krpc.space_center.active_vessel.control.throttle = 1.0

    @states = StateFactory.new(krpc)
    @checklist = Checklist.new(krpc, self)

    desired_dt = 0.1

    prev_time = krpc.space_center.active_vessel.met
    sleep desired_dt

    loop do
      curr_time = krpc.space_center.active_vessel.met
      new_state = @states.tick(curr_time - prev_time)

      @checklist.update(new_state)

      prev_time = curr_time
      sleep desired_dt
    end
  end

  def desired_pitch(alt)
    if alt > 70_000
      0
    elsif alt < 400
      90.0
    else
      90.0 * (1 - (alt / 70_000) ** 1.5)
    end
  end

  def remove_launch_panel
    @states.remove_launch_panel
  end

  def close
    krpc.close
  end

end

