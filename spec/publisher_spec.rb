require "spec_helper"

RSpec.describe Maitredee::Publisher do
  it "publisher will save a valid message", :test_client do
    recipe = Recipe.new(id: 1, name: "recipe name", servings: 2)
    message = RecipePublisher.call(recipe).first
    expect(message.primary_key).to eq recipe.id.to_s
    expect(Maitredee.client.messages.first.body["id"]).to eq recipe.id.to_s
  end

  it "raises errors if missing body" do
    recipe = Recipe.new(id: 1, name: "recipe name", servings: nil)
    expect {
      RecipePublisher.call(recipe)
    }.to raise_error(Maitredee::ValidationError)
  end
end
