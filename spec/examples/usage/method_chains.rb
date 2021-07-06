module Usage
  def multiple_usages_per_line(args)
    method1(args).method2
  end

  def multiline_usages
    method1
      .method2
      .method3
  end
end
