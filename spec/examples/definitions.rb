module Definitions
  module Layer1
  end

  class Layer1::Layer2
    def self.method1
      Layer2
      Layer1::Layer2
    end

    def method2
      self.class.method1
    end
  end
end
