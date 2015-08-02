unless(Rails.application.config.respond_to?(:sparkle))
  Rails.application.config.sparkle = Smash.new(
    :orchestration => Smash.new
  )
end
