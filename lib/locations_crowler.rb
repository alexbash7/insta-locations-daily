require 'date'
module Spider
	class LocationsCrowler
		SECONDS_IN_MINUTE = 60
 		START_HOURS = 1 # 01:00 AM everyday

		def self.run log_level: 'ERROR', profile_dir: false
			logger = Spider::ProjectLogger.get_logger log_level
			Spider::InstagramBot.set_logger logger
			config = Spider::Config.get_config
			ENV['TZ'] = 'Europe/Moscow'
			while true
				current_hours = Time.now.strftime('%H').to_i

				if current_hours == START_HOURS
					run_crowler logger
				end

				tomorrow = Date.today + 1
				tomorrow_1_am = Time.new(tomorrow.year, tomorrow.month, tomorrow.day, 1)
				need_sleep_minutes = ((tomorrow_1_am - Time.now)/60).round

				logger.info "Time in Europe/Moscow = #{Time.now}"
				logger.info "#{need_sleep_minutes} minutes will sleep, until tomorrow 1AM"

				Spider::DB.disconnect
				logger.info "I'm sleep #{need_sleep_minutes} minutes"
				sleep (need_sleep_minutes + 1) * SECONDS_IN_MINUTE
			end
		end

		def self.run_crowler logger
			begin
				no_parse_locations = Spider::DB.get_db[:locations_daily].where(is_parse: 1).all
			rescue Sequel::DatabaseDisconnectError
				Spider::DB.disconnect
				no_parse_locations = Spider::DB.get_db[:locations_daily].where(is_parse: 1).all
			end
			no_parse_locations.each do |location_row|
				logger.info "Location - #{location_row}"
				posts_count = Spider::InstagramBot.crawl_location_posts location_row[:url], location_row
				logger.info "#{posts_count} posts found in location\n"
			end
			Spider::WebBrowser.quit_browser
		end
	end
end