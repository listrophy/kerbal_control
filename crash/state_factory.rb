class StateFactory
  attr_reader :streams, :ksp

  def initialize(_ksp)
    @streams = {}
    @ksp = _ksp

    vessel = @ksp.space_center.active_vessel
    #flight = vessel.flight
    orbit = vessel.orbit
    control = vessel.control

    @streams[:apoapsis] = orbit.apoapsis_altitude_stream
    @streams[:periapsis] = orbit.periapsis_altitude_stream
    @streams[:radius] = orbit.radius_stream
    @streams[:throttle] = control.throttle_stream
    @streams[:stage] = control.current_stage_stream
    @streams[:body] = orbit.body_stream
    @streams[:warp] = @ksp.space_center.rails_warp_factor_stream
    @munar_radius = @ksp.space_center.bodies['Mun'].equatorial_radius
    @munar_semimajor_axis = @ksp.space_center.bodies['Mun'].orbit.semi_major_axis

    @state_class = make_state_class

    @current_state = nil
  end

  def make_state_class
    _streams = streams
    Class.new(Object) do
      attr_accessor(*(_streams.keys))
      attr_accessor :munar_radius, :munar_periapsis, :munar_semimajor_axis
      attr_reader(*(_streams.keys.map{|attr| "#{attr}_changed"}))
      attr_reader :dt, :prev_state

      define_method :initialize do |params, prev_state, dt|
        (_streams.keys).each do |attr|
          send "#{attr}=", params[attr]

          instance_variable_set("@#{attr}_changed", (send(attr) == prev_state.send(attr) rescue true))

          if prev_state
            prev_state_ = prev_state.dup
            prev_state_.instance_variable_set("@prev_state", nil) # avoid retaining all of history
            instance_variable_set("@prev_state", prev_state_)
          end
        end
        instance_variable_set("@dt", dt)

        %i(munar_radius munar_periapsis munar_semimajor_axis).each do |k|
          instance_variable_set("@#{k}", params[k])
        end
      end

      def to_s
        "%3d  %3d" % [heading, pitch]
      end
    end
  end

  def tick(dt, reporter)
    hash = streams.reduce({}) do |memo, (name, stream)|
      memo.merge({name => stream.get})
    end.merge({
      munar_radius: @munar_radius,
      munar_periapsis: get_munar_periapsis,
      munar_semimajor_axis: @munar_semimajor_axis
    })

    @current_state = @state_class.new(hash, @current_state, dt)

    reporter.report('crash', {
      throttle: hash[:throttle],
      periapsis: hash[:periapsis],
      apoapsis: hash[:apoapsis],
      stage: hash[:stage],
      orbitingBody: hash[:body].name,
      warpFactor: hash[:warp]
    })

    @current_state
  end

  def get_munar_periapsis
    vessel = ksp.space_center.active_vessel
    node = vessel.control.nodes.first
    orbit = node.orbit.next_orbit

    if orbit.body.name == 'Mun'
      orbit.periapsis
    else
      1e12
    end
  rescue
    1e12
  end

end
