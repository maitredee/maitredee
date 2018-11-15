require "spec_helper"

RSpec.describe Maitredee::Publisher do
  Recipe = Struct.new(:id, :name, :servings, keyword_init: true)

  class RecipePublisher
    include Maitredee::Publisher

    publish_defaults(
      topic: :recipes,
      validation_schema: :recipe_v1
    )

    attr_reader :recipe, :recipe_json

    def initialize(recipe)
      @recipe = recipe
    end

    def compose
      publish(
        primary_key: recipe.id,
        data: {
          name: recipe.name,
          id: recipe.id.to_s,
          servings: recipe.servings
        }
      )
    end
  end

  it "publisher will save a valid message" do
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
