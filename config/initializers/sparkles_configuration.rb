require 'will_paginate/array'

unless(Rails.application.config.respond_to?(:sparkle))
  Rails.application.config.sparkle = {
    :orchestration => {}.with_indifferent_access
  }.with_indifferent_access
end
