module Ruby
  attr_accessor :method1
  attr_reader :method2, :method3
  attr_writer :method4,
    :method5

  def a_method
    method1
    method2
    method3
    method4
    method5
  end
end
