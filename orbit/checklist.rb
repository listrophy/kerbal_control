require 'bijection'
require 'state_machines'

class Checklist
  attr_reader :krpc, :mc

  STAGES =
    begin
      stages = Bijection.new
      stages.add :launchpad, 6
      stages.add :boosted_first, 5
      stages.add :first, 4
      stages.add :intra_first_second, 3
      stages.add :second, 2
      stages.add :capsule, 1
      stages.add :parachuting, 0
      stages
    end

  state_machine :stage, initial: :launchpad do
    event :launch do
      transition launchpad: :boosted_first
    end
    after_transition on: :launch do |checklist, transition|
      checklist.liftoff
    end

    event :drop_boosters do
      transition boosted_first: :first
    end

    event :eject_first_stage do
      transition first: :intra_first_second
    end

    event :ignite_second do
      transition intra_first_second: :second
    end

    event :eject_second_stage do
      transition second: :capsule
    end

    event :deploy_parachute do
      transition capsule: :parachuting
    end

    after_transition any => any, do: :advance_stage
  end

  state_machine :control, initial: :gantried do
    event :liftoff do
      transition gantried: :clearing_tower
    end
    before_transition on: :liftoff do |checklist, transition|
    end

    event :start_pitchover do
      transition clearing_tower: :pitching_over
    end

    event :suborbital_seco do
      transition pitching_over: :suborbital_coast
    end
    before_transition on: :suborbital_seco, do: :finalize_pitchover

    event :circularize do
      transition suborbital_coast: :circularizing
    end
    after_transition on: :circularize, do: :initiate_circularize

    event :orbital_seco do
      transition circularizing: :orbit
    end
    before_transition on: :orbital_seco, do: :finalize_circularize

    event :deorbit do
      transition orbit: :deorbit_burn
    end
    after_transition on: :deorbit, do: :initiate_deorbit

    event :final_seco do
      transition deorbit_burn: :deorbiting
    end
    after_transition on: :final_seco, do: :jettison_second_stage

    after_transition on: [:suborbital_seco, :orbital_seco, :final_seco], do: :seco
  end

  def initialize(krpc_, mc_)
    @krpc = krpc_
    @mc = mc_
    @next_tick = []
    super()
  end

  def update(state)
    print "\r%20s\t%20s" % [stage, control] + (" " * 20)

    @next_tick.each do |f|
      f.call
    end
    @next_tick = []


    case stage_name
    when :launchpad
      if state.launch_button
        mc.remove_launch_panel
        launch
      end
    when :boosted_first
      boosters = vessel.parts.engines.reject(&:can_shutdown)
      if boosters.none?(&:has_fuel)
        drop_boosters
      end
    when :first
      main_engine = vessel.parts.engines.detect{|engine| engine.part.stage == STAGES.get_y(:first)}
      if !main_engine.has_fuel
        eject_first_stage
      end
    when :intra_first_second
      @next_tick << lambda do
        ignite_second
      end
    when :second
    when :capsule
    when :parachuting
    end

    case control_name
    when :gantried
      nil
    when :clearing_tower
      set_pitch_heading(89.999, 90.0)
      if state.altitude > 100
        vessel.auto_pilot.engage
        start_pitchover
      end
    when :pitching_over
      set_pitch_heading(mc.desired_pitch(state.altitude), 90)
      if state.apoapsis > 90_000
        suborbital_seco
      end
    when :suborbital_coast
      if state.time_to_apoapsis < 60
        circularize
      end
    when :circularizing
      if state.periapsis > 90_000
        orbital_seco
      end
    when :orbit
    when :deorbit_burn
    when :deorbiting
    end
  end

  def set_pitch_heading(new_pitch, new_heading)
    vessel.auto_pilot.target_pitch_and_heading(new_pitch, new_heading)
  end

  def finalize_pitchover
    vessel.auto_pilot.target_pitch_and_heading(0, 90)
    vessel.control.throttle = 0
  end

  def initiate_circularize
    vessel.control.throttle = 1
  end

  def finalize_circularize
    vessel.control.throttle = 0
  end

  def initiate_deorbit
  end

  def jettison_second_stage
  end

  def seco
  end


  def advance_stage
    vessel.control.activate_next_stage
  end

  private
  def vessel
    krpc.space_center.active_vessel
  end
end
