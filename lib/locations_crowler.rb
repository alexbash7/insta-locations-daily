module Spider
	class LocationsCrowler
		SLEEP_MINUTES = 60*60*24

		def self.run log_level: "ERROR", profile_dir: false
			logger = Spider::ProjectLogger.get_logger log_level
			Spider::InstagramBot.set_logger logger
			config = Spider::Config.get_config
			while true
				run_crowler logger
				Spider::DB.disconnect
				logger.info "I'm sleep #{SLEEP_MINUTES} minutes"
				sleep SLEEP_MINUTES
			end
		end

		def self.run_crowler logger
			begin
				no_parse_locations = Spider::DB.get_db[:locations_daily].where(:is_parse => 0).all
			rescue Sequel::DatabaseDisconnectError
				Spider::DB.disconnect
				no_parse_locations = Spider::DB.get_db[:locations_daily].where(:is_parse => 0).all
			end
			no_parse_locations.each do |location_row|
				logger.debug location_row
				Spider::InstagramBot.get_location_posts location_row[:url], location_row
				Spider::DB.get_db[:locations_daily].where(:id => location_row[:id]).update(:is_parse => 1)
			end
			Spider::DB.get_db[:locations_daily].update(:is_parse => 0)
			Spider::WebBrowser.quit_browser
		end
	end
end