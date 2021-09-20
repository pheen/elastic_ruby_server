module TypeMapping
  def unique_local_var
  end

  def a_method
    unique_local_var = :value
    unique_local_var
  end
end
