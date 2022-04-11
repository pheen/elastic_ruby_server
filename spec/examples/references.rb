class UsageReferences
  def initialize
    @var = :var
  end

  def method1(var)
    @var
    var
  end

  def method2(var)
    @var
    var
  end
end
