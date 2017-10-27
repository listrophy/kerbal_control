require 'bijection'
require 'state_machines'

class Checklist
  attr_reader :krpc, :mc

  def state_id
    [ :determining_insertion_burn_delta_v,
      :determining_insertion_burn_location,
      :waiting_for_insertion_burn_far,
      :waiting_for_insertion_burn_mid,
      :waiting_for_insertion_burn_near,
      :insertion_burning,
      :finalizing_insertion_burn,
      :transmunar_orbit,
      :outer_munar_orbit,
      :mid_munar_orbit,
      :final_approach
    ].index(self.control_name)
  end

  state_machine :control, initial: :determining_insertion_burn_delta_v do
    {
      insertion_burn_delta_v_determined: :determining_insertion_burn_location,
      insertion_burn_location_determined: :waiting_for_insertion_burn_far,
      warp_mid: :waiting_for_insertion_burn_mid,
      warp_off: :waiting_for_insertion_burn_near,
      insertion_burn: :insertion_burning,
      almost_finalize_insertion_burn: :finalizing_insertion_burn,
      finalize_insertion_burn: :transmunar_orbit,
      enter_munar_soi: :outer_munar_orbit,
      approach_mun: :mid_munar_orbit,
      enter_final_approach: :final_approach
    }.each do |(event_name, state_name)|
      event(event_name) do
        transition to: state_name
      end
      after_transition to: state_name, do: "#{event_name}_hook".to_sym
    end
  end


  def initialize(krpc_, mc_)
    @krpc = krpc_
    @mc = mc_
    @next_tick = []
    super()
  end

  def update(state)
    to_call = []
    @next_tick.each do |f|
      to_call << f
    end
    @next_tick = []

    to_call.each(&:call)

    case control_name
    when :determining_insertion_burn_delta_v
      node = get_node
      if node
        if node.orbit.apoapsis < state.munar_semimajor_axis
          node.prograde = node.prograde + 6
        else
          insertion_burn_delta_v_determined
        end
      else
        make_node
      end
    when :determining_insertion_burn_location
      node = get_node
      if insertion_burn_good_enough?(state)
        insertion_burn_location_determined
      else
        node.ut += 3
      end
    when :waiting_for_insertion_burn_far
      node = get_node
      if node.time_to < 2 * approximate_insertion_burn_duration(node)
        warp_mid
      end
    when :waiting_for_insertion_burn_mid
      node = get_node
      if node.time_to < 0.75 * approximate_insertion_burn_duration(node)
        warp_off
      end
    when :waiting_for_insertion_burn_near
      if close_enough_to_start_insertion_burn(get_node)
        insertion_burn
      end
    when :insertion_burning
      dv = get_node.remaining_delta_v
      if dv < 15
        almost_finalize_insertion_burn
      end
    when :finalizing_insertion_burn
      dv = get_node.remaining_delta_v
      if dv < 1
        finalize_insertion_burn
      end
    when :transmunar_orbit
      if vessel.orbit.body.name == 'Mun'
        enter_munar_soi
      end
    when :outer_munar_orbit
      if state.radius / state.munar_radius < 5
        approach_mun
      end
    when :mid_munar_orbit
      if state.radius / state.munar_radius < 1.15
        enter_final_approach
      end
    when :final_approach
      nil
    end
  end

  def insertion_burn_delta_v_determined_hook
  end

  def insertion_burn_location_determined_hook
    set_warp(4)
  end

  def warp_mid_hook
    set_warp(2)
  end

  def warp_off_hook
    set_warp(0)
    vessel.auto_pilot.sas = true
    vessel.auto_pilot.sas_mode = :maneuver
  end

  def insertion_burn_hook
    vessel.control.throttle = 1
  end

  def almost_finalize_insertion_burn_hook
    vessel.control.throttle = 0.3
  end

  def finalize_insertion_burn_hook
    vessel.control.throttle = 0
    @next_tick << lambda do
      @next_tick << lambda do
        @next_tick << lambda do
          @next_tick << lambda do
            @next_tick << lambda do
              @next_tick << lambda do
                remove_node
                set_warp 5
              end
            end
          end
        end
      end
    end
  end

  def enter_munar_soi_hook
    @next_tick << lambda do
      @next_tick << lambda do
        set_warp 5
      end
    end
  end

  def approach_mun_hook
    set_warp 3
  end

  def enter_final_approach_hook
    set_warp 0
    vessel.control.lights = true
  end

  def close_enough_to_start_insertion_burn(node)
    node.time_to < 0.45 * approximate_insertion_burn_duration(node)
  end

  def approximate_insertion_burn_duration(node)
    engine = vessel.parts.engines.first
    vessel.mass * node.delta_v / engine.available_thrust
  end

  def insertion_burn_good_enough?(state)
    state.munar_periapsis < 0.75 * state.munar_radius
  end

  #

  def remove_node
    get_node.remove
  end

  def get_node
    vessel.control.nodes.first
  end

  def make_node
    vessel.control.add_node(ut: krpc.space_center.ut + 25 * 60)
  end

  def vessel
    krpc.space_center.active_vessel
  end

  def set_warp(x)
    krpc.space_center.rails_warp_factor = x
  end

end
