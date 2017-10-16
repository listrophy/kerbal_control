require 'krpc'
require 'pry'

client = KRPC.connect(name: "hoverer")

puts "Connected"
print "Launch in 3..."
sleep 1
print " 2..."
sleep 1
print " 1..."
sleep 1
puts " Liftoff!"

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
DT = 0.2

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

while vessel.resources.amount('LiquidFuel') > 0.1
  sleep DT
  curr_time = vessel.met
  dt = curr_time - prev_time # approximately DT

  current_altitude = flight.mean_altitude

  error = DESIRED_ALTITUDE - current_altitude
  derivative = (error - prev_error) / dt
  integral = integral + error * dt

  new_throttle = 0.1 * (P * error + D * derivative + I * integral)
  puts "NEW THROTTLE: #{"%0.4f" % new_throttle}. error = #{"%0.2f" % error}. deriv: #{"%0.4f" % derivative}. accum: #{"%0.3f" % integral}"
  ctrl.throttle = clamp 0, 0.5, new_throttle

  prev_error, prev_time = error, curr_time
end


client.close
