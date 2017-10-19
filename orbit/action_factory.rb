class ActionFactory
  attr_reader :mission_control

  def initialize(mc)
    @mission_control = mc
    @autopilot_engaged = false
  end

  def activate_next_stage
    Action.new(:activate_next_stage) do
      vessel.control.activate_next_stage
    end
  end

  def remove_launch_panel
    Action.new(:remove_launch_panel) do
      mission_control.remove_launch_panel
    end
  end

  def add_yaw(value)
    Action.new(:add_yaw) do
      vessel.control.input_mode = :override
      vessel.control.yaw = value
    end
  end

  def engage_autopilot
    if !@autopilot_engaged
      Action.new(:engage_autopilot) do
        vessel.auto_pilot.engage
      end
    else
      Action.new(:autopilot_already_engaged) do
        nil
      end
    end
  end

  def set_target_pitch_heading(desired_pitch, desired_heading)
    Action.new(:set_target_pitch_heading) do
      vessel.auto_pilot.target_pitch_and_heading(desired_pitch, desired_heading)
    end
  end

  def vessel
    mission_control.krpc.space_center.active_vessel
  end
end

class Action
  attr_reader :name, :block

  def initialize(name_, &block_)
    @name = name_
    @block = block_
  end
end
