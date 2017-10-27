require 'krpc'
require_relative './state_factory'
require_relative './checklist'
require_relative '../lib/reporter'

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
    Reporter.run do |reporter|
      krpc.space_center.active_vessel.control.sas = true

      @states = StateFactory.new(krpc)
      @checklist = Checklist.new(krpc, self)

      prev_time = krpc.space_center.active_vessel.met

      reporter.each_tick(0.1) do
        curr_time = krpc.space_center.active_vessel.met
        new_state = @states.tick(curr_time - prev_time, reporter)

        @checklist.update(new_state)

        prev_time = curr_time
      end
    end
  end

  def close
    krpc.close
  end

end

