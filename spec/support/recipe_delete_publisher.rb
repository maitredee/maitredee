class RecipeDeletePublisher < Maitredee::Publisher

  publish_defaults(
    topic: :recipes,
    event_name: :delete,
    schema_name: :recipe_v1
  )

  attr_reader :recipe, :recipe_json

  def initialize(recipe)
    @recipe = recipe
  end

  def process
    publish(
      primary_key: recipe.id,
      body: {
        name: recipe.name,
        id: recipe.id.to_s,
        servings: recipe.servings
      }
    )
  end
end
