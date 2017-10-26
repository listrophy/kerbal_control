require 'krpc'
require 'pry'

require_relative '../lib/reporter'

client = KRPC.connect(name: "hoverer")

puts "Connected"
print "Launch in 3..."
sleep 1
print " 2..."
sleep 1
print " 1..."
sleep 1
puts " Liftoff!"

Reporter.run do |reporter|


  vessel = client.space_center.active_vessel
  ctrl = vessel.control
  ctrl.sas = true
  ctrl.sas_mode = :stability_assist
  ctrl.throttle = 0.3
  puts "Launching #{vessel.name}!"
  ctrl.activate_next_stage

  DESIRED_ALTITUDE = 250.0
  P = 0.1
  I = 0.008
  D = 0.17
  DT = 0.1

  flight = vessel.flight(vessel.orbital_reference_frame)

  prev_error =
    error =
    integral =
    derivative = 0

  prev_time = vessel.met

  def clamp min, max, x
    if x > max
      max
    elsif x < min
      min
    else
      x
    end
  end

  reporter.each_tick(DT) do
    curr_time = vessel.met
    dt = curr_time - prev_time # approximately DT

    current_altitude = flight.mean_altitude

    error = DESIRED_ALTITUDE - current_altitude
    derivative = (error - prev_error) / dt
    integral = integral + error * dt

    new_throttle = 0.1 * (P * error + D * derivative + I * integral)
    ctrl.throttle = clamp 0, 0.5, new_throttle

    reporter.report('hover', {
      altitude: current_altitude,
      error: error,
      derivative: derivative,
      integral: integral,
      throttle: clamp(0, 0.5, new_throttle),
      fuel: vessel.resources.amount('LiquidFuel')
    })

    prev_error, prev_time = error, curr_time

    if vessel.resources.amount('LiquidFuel') < 0.1
      client.close
      reporter.stop
    end
  end
end
