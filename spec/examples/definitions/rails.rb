module MockUser
  belongs_to :association1
  has_one :association2
  has_many :association3
  has_and_belongs_to_many :association4

  def a_method
    association1
    association2
    association3
    association4
  end
end