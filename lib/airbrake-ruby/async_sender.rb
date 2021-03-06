module Airbrake
  # Responsible for sending notices to Airbrake asynchronously.
  #
  # @see SyncSender
  # @api private
  # @since v1.0.0
  class AsyncSender
    include Loggable

    # @return [String]
    WILL_NOT_DELIVER_MSG =
      "%<log_label>s AsyncSender has reached its capacity of %<capacity>s " \
      "and the following notice will not be delivered " \
      "Error: %<type>s - %<message>s\nBacktrace: %<backtrace>s\n".freeze

    def initialize(method = :post)
      @config = Airbrake::Config.instance
      @method = method
    end

    # Asynchronously sends a notice to Airbrake.
    #
    # @param [Airbrake::Notice] notice A notice that was generated by the
    #   library
    # @return [Airbrake::Promise]
    def send(notice, promise, endpoint = @config.endpoint)
      unless thread_pool << [notice, promise, endpoint]
        return will_not_deliver(notice, promise)
      end

      promise
    end

    # @return [void]
    def close
      thread_pool.close
    end

    # @return [Boolean]
    def closed?
      thread_pool.closed?
    end

    # @return [Boolean]
    def has_workers?
      thread_pool.has_workers?
    end

    private

    def thread_pool
      @thread_pool ||= begin
        sender = SyncSender.new(@method)
        ThreadPool.new(
          worker_size: @config.workers,
          queue_size: @config.queue_size,
          block: proc { |args| sender.send(*args) },
        )
      end
    end

    def will_not_deliver(notice, promise)
      error = notice[:errors].first

      logger.error(
        format(
          WILL_NOT_DELIVER_MSG,
          log_label: LOG_LABEL,
          capacity: @config.queue_size,
          type: error[:type],
          message: error[:message],
          backtrace: error[:backtrace].map do |line|
            "#{line[:file]}:#{line[:line]} in `#{line[:function]}'"
          end.join("\n"),
        ),
      )
      promise.reject("AsyncSender has reached its capacity of #{@config.queue_size}")
    end
  end
end
