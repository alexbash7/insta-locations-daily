module Spider
	class LocationsCrowler
		SLEEP_MINUTES = 60*24

		def self.insert_in_db posts, location_id
			Spider::DB.get_db.transaction do
				posts.each do |post|
					blacklist_user = Spider::DB.get_db[:blacklist_users].where(:user_id => post['user_id']).first
					if blacklist_user
						next
					end
					begin
						Spider::DB.get_db[:posts].insert(:img_url => post['img_url'], :user_id => post['user_id'], :post_url => post['post_url'], :location_id => location_id, :post_date => post['date'])
					rescue Sequel::UniqueConstraintViolation
					end
				end
			end
		end

		def self.run log_level: "ERROR", profile_dir: false
			infinite_run(log_level: log_level, profile_dir: profile_dir)
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
				posts = Spider::InstagramBot.get_location_posts location_row[:url]
				logger.debug "posts.count = #{posts.count}"
				begin
					insert_in_db posts, location_row[:id]
				rescue Sequel::DatabaseDisconnectError
					Spider::DB.disconnect
					insert_in_db posts, location_row[:id]
				end
				Spider::DB.get_db[:locations_daily].where(:id => location_row[:id]).update(:is_parse => 1)
			end
			Spider::DB.get_db[:locations_daily].update(:is_parse => 0)
			Spider::WebBrowser.quit_browser
		end

		def self.infinite_run log_level: "ERROR", profile_dir: false
			logger = Spider::ProjectLogger.get_logger log_level
			logger.debug "infinite crowler is runing"
			Spider::InstagramBot.set_logger logger
			Spider::WebBrowser.set_profile_dir_name profile_dir
			config = Spider::Config.get_config
			proxy = {:host => '137.184.109.153', :port => '8091'}
			Spider::WebBrowser.set_proxy proxy
			Spider::InstagramBot.login config.insta_account['login'], config.insta_account['password']
			while true
				run_crowler logger
				logger.info "I'm sleep #{SLEEP_MINUTES} minutes"
				sleep SLEEP_MINUTES
			end
		end

		def self.once_run log_level: "ERROR", profile_dir: false
			logger = Spider::ProjectLogger.get_logger log_level
			logger.debug "once crowler is runing"
			Spider::InstagramBot.set_logger logger
			Spider::WebBrowser.set_profile_dir_name profile_dir
			config = Spider::Config.get_config
			proxy = {:host => '137.184.109.153', :port => '8091'}
			Spider::WebBrowser.set_proxy proxy
			Spider::InstagramBot.login config.insta_account['login'], config.insta_account['password']
			run_crowler logger
			logger.info "I'm finished"
		end
	end
end