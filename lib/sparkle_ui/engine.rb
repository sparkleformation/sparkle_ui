module SparkleUi
  class Engine < ::Rails::Engine

    config.to_prepare do
      SparkleUi::Setup.init!
    end

  end

end
