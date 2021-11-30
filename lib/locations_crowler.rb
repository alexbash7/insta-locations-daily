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
			logger = Spider::ProjectLogger.get_logger log_level
			Spider::InstagramBot.set_logger logger
			Spider::WebBrowser.set_profile_dir_name profile_dir
			config = Spider::Config.get_config
			Spider::InstagramBot.login config.insta_account['login'], config.insta_account['password']
			while true
				no_parse_locations = Spider::DB.get_db[:locations_daily].where(:is_parse => 0).all
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
				logger.info "I'm sleep #{SLEEP_MINUTES} minutes"
				sleep SLEEP_MINUTES
			end
		end
	end
end