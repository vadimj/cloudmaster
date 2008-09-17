require 'pp'

# Compute primes.
class Primes

  # Start with a couple primes.
  def initialize
    @shutdown = false
    @primes = []
    add(2)
    add(3)
  end

  # Test if a number is prime
  # by dividing by previous primes.
  def prime?(p)
    limit = Math::sqrt(p).ceil
    (1..@primes.size-1).each do |i|
      if @primes[i] > limit then return true end
      if p % @primes[i] == 0 then return false end
    end 
    true
  end

  # Add a new prime to the set.
  def add(p)
    @primes << p
    p
  end

  # Get the next prime by checking successive odd numbers.
  # This only works if there is already some entry in @primes.
  # This is why we pre-populate with 3.
  def next_prime
    candidate = @primes.last + 2
    while ! prime?(candidate) do candidate += 2 end
    add(candidate)
  end

  # eturn the first n primes.
  def primes(n)
    if n <= 0 then
      []
    elsif n == 1 then
      [2]
    else 
      (n-2).times do |i| 
        next_prime 
	return nil if @shutdown
      end
      @primes
    end
  end

  # shut down the prime generator before it finishes.
  def shutdown
    @shutdown = true
  end
end
