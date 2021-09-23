module MockUser
  belongs_to :belongs_to_assoc
  has_one :has_one_assoc
  has_many :has_many_assoc, :through => :has_and_belongs_to_many_assoc
  has_and_belongs_to_many :has_and_belongs_to_many_assoc, class_name: "Name",
                                                          foreign_key: "user_id"

  def a_method
    belongs_to_assoc
    has_one_assoc
    has_many_assoc
    has_and_belongs_to_many_assoc
  end
end
