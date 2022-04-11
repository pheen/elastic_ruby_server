module NestedConstants
  module Layer1
  end

  class Layer1::Layer2
    def a_method
      Layer2
      Layer1::Layer2
    end
  end

  Layer1::Layer2::Layer3 = :sym
  Layer1::Layer2::Layer3
end

module Methods
  def self.method1
  end

  def method2
    self.class.method1
  end

  def method3
    method2
  end
end

class Accessors
  attr_accessor :method1
  attr_reader :method2, :method3
  attr_writer :method4,
    :method5,

  def call
    method1
    method2
    method3
    method4
    method5
  end
end
