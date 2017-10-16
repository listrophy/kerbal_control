class Pid
  attr_reader :name, :k_p, :k_i, :k_d
  attr_accessor :desired

  def initialize(name, k_p:, k_i:, k_d:, desired:, mult: 1.0, reporter: nil)
    @name = name
    @desired = desired
    @mult = mult
    @k_p, @k_i, @k_d = k_p, k_i, k_d
    @reporter = reporter

    @clamping = false

    @last_error = nil
    @accumulated_error = 0.0
  end

  def set_clamp(min:, max:)
    @clamping = true
    @min, @max = min, max
  end

  def tick(actual:, dt:)
    error = desired - actual
    @accumulated_error = @accumulated_error + error * dt
    derivative = @last_error ? (error - @last_error) / dt : 0

    report(error, @accumulated_error, derivative)

    @last_error = error

    clamp(@mult * (k_p * error + k_i * @accumulated_error + k_d * derivative))
  end

  def report(err, accum, deriv)
    if @reporter
      @reporter.report(:pid, name, "err: %2.2f, accum: %2.2f, deriv: %2.2f" % [err, accum, deriv])
    end
  end

  def clamp(output)
    if @clamping
      output.clamp(@min, @max)
    else
      output
    end
  end
end
