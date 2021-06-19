class Basic
  def first_method
    local_var     = "value"
    @instance_var = "value"
    @@class_var   = "value"

    local_var
    @instance_var
    @@class_var
  end
end
