module Ey::Core::Subscribable
  def self.included(klass)
    klass.send(:attribute, :read_channel)
  end

  def read_channel_uri
    self.read_channel && Addressable::URI.parse(self.read_channel)
  end

  def subscribe(&block)
    puts "#{Time.now.strftime("%Y/%m/%d %H:%M:%S")} - DEBUG - subscribe - started"
    return false unless read_channel_uri

    gem 'faye', '~> 1.1'
    require 'faye' # soft dependency

    # Use the same env variable as faraday to activate debug output
    Faye.logger = Logger.new(STDOUT, level: "DEBUG") if ENV["DEBUG"]

    uri = read_channel_uri

    resource = self

    url          = uri.omit(:query).to_s
    token        = uri.query_values["token"]
    subscription = uri.query_values["subscription"]

    EM.run do
      puts "#{Time.now.strftime("%Y/%m/%d %H:%M:%S")} - DEBUG - subscribe - Inside EM.run block"
      puts "#{Time.now.strftime("%Y/%m/%d %H:%M:%S")} - DEBUG - subscribe - EM.run url #{url}"
      puts "#{Time.now.strftime("%Y/%m/%d %H:%M:%S")} - DEBUG - subscribe - EM.run token #{token}"
      puts "#{Time.now.strftime("%Y/%m/%d %H:%M:%S")} - DEBUG - subscribe - EM.run subscription #{subscription}"
      client = Faye::Client.new(url)
      puts "#{Time.now.strftime("%Y/%m/%d %H:%M:%S")} - DEBUG - subscribe - Faye client is nil? #{client.nil?}"
      puts "#{Time.now.strftime("%Y/%m/%d %H:%M:%S")} - DEBUG - subscribe - Faye client is #{client.to_json}"
      client.set_header("Authorization", "Token #{token}")
      next_ready_check = Time.now + 5
      handle_output = Proc.new do |m|
        puts "#{Time.now.strftime("%Y/%m/%d %H:%M:%S")} - DEBUG - subscribe - handle_output is called"
        next_ready_check = Time.now + 1
        block.call(m)
      end

      deferred = client.subscribe(subscription) do |message|
        puts "#{Time.now.strftime("%Y/%m/%d %H:%M:%S")} - DEBUG - subscribe - Faye - got message #{message}"
        handle_output.call(JSON.load(message))
      end
      puts "#{Time.now.strftime("%Y/%m/%d %H:%M:%S")} - DEBUG - subscribe - deferred after subscribe #{deferred.to_json}"

      deferred.callback do
        puts "#{Time.now.strftime("%Y/%m/%d %H:%M:%S")} - DEBUG - subscribe - Faye - executing the callback"
        handle_output.call({"meta" => true, "created_at" => Time.now,"message" => "log output stream connection established, waiting...\n"})
      end
      puts "#{Time.now.strftime("%Y/%m/%d %H:%M:%S")} - DEBUG - subscribe - deferred after callback #{deferred.to_json}"

      deferred.errback do |error|
        puts "#{Time.now.strftime("%Y/%m/%d %H:%M:%S")} - DEBUG - subscribe - Faye - executing the errback, error: #{error.inspect}"
        handle_output.call({"meta" => true, "created_at" => Time.now, "message" => "failed to stream output: #{error.inspect}\n"})
        EM.stop_event_loop
      end
      puts "#{Time.now.strftime("%Y/%m/%d %H:%M:%S")} - DEBUG - subscribe - deferred after errback #{deferred.to_json}"

      EventMachine::PeriodicTimer.new(1) do
        puts "#{Time.now.strftime("%Y/%m/%d %H:%M:%S")} - DEBUG - subscribe - PeriodicTimer is called"
        if Time.now > next_ready_check
          puts "#{Time.now.strftime("%Y/%m/%d %H:%M:%S")} - DEBUG - subscribe - PeriodicTimer 2"
          if resource.reload.ready?
            puts "#{Time.now.strftime("%Y/%m/%d %H:%M:%S")} - DEBUG - subscribe - Faye - resource.reload.ready? is true"
            handle_output.call({"meta" => true, "created_at" => Time.now, "message" => "#{resource} finished"})
            EM.stop_event_loop
          end
          next_ready_check = Time.now + 5
        end
      end
    end
  end
end
