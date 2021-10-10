module Usage
  module NamespacedConstants
    module Module1
      module Module2
        module Module3
        end
      end
    end

    Module1::Module2::Module3
  end
end
