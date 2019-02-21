module Airbrake
  # DeployNotifier sends deploy information to Airbrake. The information
  # consists of:
  # - environment
  # - username
  # - repository
  # - revision
  # - version
  #
  # @api public
  # @since v3.2.0
  class DeployNotifier
    include Inspectable

    # @param [Airbrake::Config] config
    def initialize(config)
      @config = config
      @sender = SyncSender.new(config)
    end

    # @see Airbrake.create_deploy
    def notify(deploy_info, promise = Airbrake::Promise.new)
      if @config.ignored_environment?
        return promise.reject("The '#{@config.environment}' environment is ignored")
      end

      deploy_info[:environment] ||= @config.environment
      @sender.send(
        deploy_info,
        promise,
        URI.join(@config.host, "api/v4/projects/#{@config.project_id}/deploys")
      )

      promise
    end
  end
end
