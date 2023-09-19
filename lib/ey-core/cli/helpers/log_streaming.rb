module Ey
  module Core
    module Cli
      module Helpers
        module LogStreaming

          def stream_deploy_log(request)
            puts "#{Time.now.strftime("%Y/%m/%d %H:%M:%S")} - DEBUG - stream_deploy_log - started. request: #{request.to_json}"
            if request.finished_at
              return finished_request(request)
            end
            puts "#{Time.now.strftime("%Y/%m/%d %H:%M:%S")} - DEBUG - stream_deploy_log - 2"
            unless request.read_channel
              puts "Unable to stream log (streaming not enabled for this deploy)".yellow
              return
            end
            puts "#{Time.now.strftime("%Y/%m/%d %H:%M:%S")} - DEBUG - stream_deploy_log - 3"
            request.subscribe { |m| print m["message"] if m.is_a?(Hash) }
            puts "" # fix console output from stream
            puts "#{Time.now.strftime("%Y/%m/%d %H:%M:%S")} - DEBUG - stream_deploy_log - 4"
            finished_request(request)
          end

          def finished_request(request)
            if request.successful
              if request.resource.successful
                puts "Deploy successful!".green
              else
                puts "Deploy failed!".red
              end
            else
              abort <<-EOF
        Deploy failed!
        Request output:
        #{request.message}
              EOF
              .red
            end
          end

        end
      end
    end
  end
end
