RSpec.describe MockClass do
  let!(:let_bang) { :let_bang }
  let(:lazy_let)  { :lazy_let }

  context "first" do
    it "destroys only records which match the scope" do
      let_bang
      lazy_let
    end
  end

  context "immediately expiring current change requests" do
    let!(:let_bang)  { :let_bang }
    let(:lazy_let)   { :lazy_let }
    let(:nested_let) { :nested_let }

    it "finds the right definition" do
      let_bang
      lazy_let
      nested_let
    end
  end

  it { let_bang; lazy_let }

  describe "second" do
    it "destroys only records which match the scope" do
      let_bang
      lazy_let
    end
  end
end
