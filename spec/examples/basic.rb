class Basic
  def first_method(argument)
    argument

    local_var     = "value"
    @instance_var = "value"
    @@class_var   = "value"

    local_var
    @instance_var
    @@class_var
  end

  def second_method
    first_method
  end
end
