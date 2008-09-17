
# Used to wrap Time so it can be mocked

class Clock < Time

  def Clock.sleep(numeric = 0)
    Kernel.sleep numeric
  end
  
end
