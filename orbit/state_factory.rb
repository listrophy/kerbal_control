class StateFactory
  attr_reader :streams, :ksp

  def initialize(_ksp)
    @streams = {}
    @ksp = _ksp

    @streams[:launch_button] = make_launch_button

    vessel = @ksp.space_center.active_vessel
    flight = vessel.flight
    orbit = vessel.orbit
    control = vessel.control

    @streams[:altitude] = flight.mean_altitude_stream
    @streams[:apoapsis] = orbit.apoapsis_altitude_stream
    @streams[:time_to_apoapsis] = orbit.time_to_apoapsis_stream
    @streams[:periapsis] = orbit.periapsis_altitude_stream
    @streams[:pitch] = flight.pitch_stream
    @streams[:heading] = flight.heading_stream
    @streams[:direction] = flight.direction_stream
    @streams[:rotation] = flight.rotation_stream
    @streams[:stage] = control.current_stage_stream

    @state_class = make_state_class

    @current_state = nil
  end

  def make_state_class
    _streams = streams
    Class.new(Object) do
      attr_accessor(*(_streams.keys))
      attr_reader(*(_streams.keys.map{|attr| "#{attr}_changed"}))
      attr_reader :dt, :prev_state

      define_method :initialize do |params, prev_state, dt|
        (_streams.keys).each do |attr|
          send "#{attr}=", params[attr]

          instance_variable_set("@#{attr}_changed", (send(attr) == prev_state.send(attr) rescue true))
          instance_variable_set("@dt", dt)

          if prev_state
            prev_state_ = prev_state.dup
            prev_state_.instance_variable_set("@prev_state", nil) # avoid retaining all of history
            instance_variable_set("@prev_state", prev_state_)
          end
        end
      end

      def to_s
        "%3d  %3d" % [heading, pitch]
      end
    end
  end

  def make_launch_button
    canvas = ksp.ui.stock_canvas
    screen_size = canvas.rect_transform.size

    @launch_panel = canvas.add_panel
    launch_panel_rect = @launch_panel.rect_transform
    launch_panel_rect.size = [200, 70]
    launch_panel_rect.position = [110 - (screen_size[0] / 2), (screen_size[1] / 2) - 110]

    launch_button = @launch_panel.add_button("Launch")
    launch_button.rect_transform.position = [0, 0]

    return launch_button.clicked_stream
  end

  def remove_launch_panel
    @launch_panel.remove
  end

  def tick(dt)
    hash = streams.reduce({}) do |memo, (name, stream)|
      memo.merge({name => stream.get})
    end

    @current_state = @state_class.new(hash, @current_state, dt)
  end

end
