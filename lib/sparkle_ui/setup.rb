module SparkleUi
  # Configuration setup helpers
  class Setup

    class << self

      # Initialize configuration for sparkles
      #
      # @return [TrueClass, FalseClass]
      def init!
        require 'base64'
        require 'sfn'
        require 'content_for_in_controllers'
        unless(Rails.application.config.respond_to?(:sparkle))
          if(Rails.application.config.respond_to?(:settings))
            Rails.application.config.sparkle = Rails.application.config.settings.fetch(:sparkle, Smash.new)
          else
            Rails.application.config.sparkle = Smash.new
          end
        else
          Rails.application.config.sparkle = Rails.application.config.sparkle.to_smash
        end
        if(Rails.application.config.sparkle[:orchestration])
          orchestration_provider = Rails.application.config.sparkle.fetch(:orchestration, :provider, :aws)
          orchestration_credentials = Rails.application.config.sparkle.get(:orchestration, :credentials)
          if(orchestration_credentials)
            api = Sfn::Provider.new(
              :provider => orchestration_provider,
              :miasma => orchestration_credentials,
              :logger => Rails.logger,
              :async => false,
              :fetch => true
            )
            Rails.application.config.sparkle[:provider_api] = api
            Rails.application.config.sparkle[:orchestration_connection] = api.connection
            true
          else
            Rails.logger.warn 'Unable to connect to orchestration provider. No credentials found!'
            false
          end
        end
        unless(Rails.application.config.sparkle[:stack_modify_checker])
          Rails.application.config.sparkle[:stack_modify_checker] = lambda{|*_| true}
        end
        unless(Rails.application.config.sparkle[:stack_creation_defaults])
          Rails.application.config.sparkle[:stack_creation_defaults] = {
            :disable_rollback => true,
            :timeout_in_minutes => 30
          }
        end
      end

    end

  end

  # Verify user is allowed to modify stack
  #
  # @param user [Object]
  # @param stack [Fog::Model::Stack]
  # @return [TrueClass, FalseClass]
  def self.stack_modification_allowed?(user, stack)
    !!Rails.application.config.sparkle[:stack_modify_checker].call(user, stack)
  end
end
