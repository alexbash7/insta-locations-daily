require 'logger'

module Spider
	module ProjectLogger
		def self.get_logger log_level = "ERROR"
			@@logger ||= Logger.new(STDOUT).tap do |l|
				case log_level
				when "INFO"
					l.level = Logger::INFO
				when "WARN"
					l.level = Logger::WARN
				when "DEBUG"
					l.level = Logger::DEBUG
				else
					l.level = Logger::ERROR
				end
			end
		end
	end
end
