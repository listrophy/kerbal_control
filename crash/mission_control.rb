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

  def close
    krpc.close
  end

end

