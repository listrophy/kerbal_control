require_relative './pid'

class Ship
  G = 9.81
  attr_reader :height

  def initialize
    @height = 0.0
    @speed = 0.0
    @thrust = 0.0
    @dry_mass = 100.0
    @fuel_mass = 200.0
  end

  def tick(thrust:, dt:)
    #         kg m s-2
    if @fuel_mass > 0
      @thrust = thrust
    else
      @thrust = 0
    end
    @speed += (6_000 * @thrust / mass - G) * dt
    @height += @speed * dt
    @fuel_mass -= @thrust * 0.01
  end

  def mass
    @dry_mass + @fuel_mass
  end

end

class Reporter
  def report(typ, id, val)
    print typ, id, val
  end
end

def state(actual, desired)
  range = (desired / 3).to_i
  str = " " * (range * 2)
  str[desired / 3] = '|'
  str[actual / 3] = '*'
  "\r#{str}"
end

ship = Ship.new
pid = Pid.new("ship engine", k_p: 0.9, k_i: 0.05, k_d: 0.9, desired: 150, reporter: Reporter.new)
pid.set_clamp(min: 0, max: 1.0)

t = 0
dt = 0.01

loop do
  new_thrust = pid.tick(actual: ship.height, dt: dt)
  ship.tick(thrust: new_thrust, dt: dt)

  print state(ship.height, 150), " #{"%3.1f" % ship.height}"

  t += dt
  sleep 0.01
end while t < 100
puts
