require 'date'
require 'unicode'
require 'unicode/emoji'

module Spider
	module InstagramBot
		POSTS_PERIOD_MINUTES = 60
		SCREENSHOTS_DIR = File.join(__dir__, '..', 'tmp')

		def self.set_logger logger
			@@logger = logger
		end

		def self.is_page_bunned
			html_text = Spider::WebBrowser.get_driver.find_element(:css => "html").text
			matched = html_text.match /Please wait a few minutes before you try again/
			if html_text.empty? || matched
				return true
			end

			false
		end

		def self.click_save_info
			notif_not_now = Spider::WebBrowser.get_driver.find_element(:xpath, "//*[contains(text(), 'Save Info')]") rescue nil
			if notif_not_now
				@@logger.debug "I'm click save info"
				notif_not_now.click
				sleep 2
			end
		end

		def self.click_not_now_notifications
			notif_not_now = Spider::WebBrowser.get_driver.find_element(:xpath, "//*[contains(text(), 'Not Now')]") rescue nil
			if notif_not_now
				notif_not_now.click
				sleep 1
			end
		end

		def self.save_screenshot alias_name
			file_path = File.join(SCREENSHOTS_DIR, "#{alias_name}.png")
			Spider::WebBrowser.get_driver.save_screenshot file_path
			file = File.open(file_path)
			content = file.read
			file.close
			Spider::DB.get_db[:screenshots].insert(alias: alias_name, image: content, html: get_driver_page_source)
		end

		def self.get_driver_page_source
			Spider::WebBrowser.get_driver.page_source.gsub(/[\u{10000}-\u{10FFFF}]/, "?").gsub(Unicode::Emoji::REGEX, "[smile]")
		end

		def self.check_login
			html_el = Spider::WebBrowser.get_driver.find_element(:css => "html") rescue nil
			if html_el.nil?
				return 'not detected'
			end
			matched = html_el.attribute('class').match /not-logged-in/
			if matched
				return 'no login'
			end
			matched = html_el.attribute('class').match /logged-in/
			if matched
				return 'login'
			end
			'not detected'
		end

		def self.login username, pass
			Spider::WebBrowser.get_driver.navigate.to "https://www.instagram.com/accounts/login/"
			sleep 3
			if is_page_bunned
				Spider::WebBrowser.quit_browser
				@@logger.debug "Page banned. I'm sleep 60 min and exit"
				sleep 60 * 60
				exit
			else
				@@logger.debug "#login - No bun"
			end
			save_screenshot 'check_login'
			is_login = check_login
			@@logger.debug "is_login = #{is_login}"
			if is_login == 'login'
				@@logger.debug "allready logged in"
				click_not_now_notifications
				return true
			end
			

			username_el = Spider::WebBrowser.get_driver.find_element(:css => "input[name='username']") rescue nil
			if username_el.nil?
				@@logger.debug "#login - no username_el"
				click_not_now_notifications
				return true
			end
			@@logger.debug "try to login"
			username_el.click
			username_el.send_keys username
			password_el = Spider::WebBrowser.get_driver.find_element(:css => "input[name='password']")
			password_el.click
			password_el.send_keys pass
			
			btn_submit =  Spider::WebBrowser.get_driver.find_element(:css => "button[type='submit']")
			btn_submit.click
			sleep 8
			@@logger.debug 'save page_source AFTER LOGIN1'
			save_screenshot 'after_login1'
			click_not_now_notifications
			click_save_info
			sleep 2
			@@logger.debug 'save page_source AFTER LOGIN2'
			save_screenshot 'after_login2'
		end

		def self.scrape_post_properties url, posts
			@@logger.debug "try to load #{url}"
			Spider::WebBrowser.get_driver.navigate.to url
			sleep 1
			if is_page_bunned
				Spider::WebBrowser.quit_browser
				@@logger.debug "Page banned. I'm sleep 60 min and exit"
				sleep 60 * 60
				exit
			else
				@@logger.debug "#scrape_post_properties - No bun"
			end
			time_el = Spider::WebBrowser.get_driver.find_element(:css, 'a>time') rescue nil
			@@logger.debug "save page source in location parse post"
			save_screenshot 'parse_post'
			if time_el.nil?
				sleep 2
				time_el = Spider::WebBrowser.get_driver.find_element(:css, 'a>time') rescue nil
				if time_el.nil?
					sleep 4
					time_el = Spider::WebBrowser.get_driver.find_element(:css, 'a>time') rescue nil
					if time_el.nil?
						# close_el = Spider::WebBrowser.get_driver.find_element(:xpath, "//*[contains(@aria-label, 'Close')]")
						# close_el.click
						return true
					end
				end
			end
			post_time_str = time_el.attribute("datetime")
			post_time = DateTime.parse(post_time_str)
			seconds_diff = ((DateTime.now - post_time) * 24 * 60 * 60).to_i
			@@logger.debug "minutes diff = #{seconds_diff / 60 }"
			if seconds_diff < 60 * POSTS_PERIOD_MINUTES
				page_html = Spider::WebBrowser.get_driver.page_source
				matched = page_html.match(/window\.__additionalDataLoaded\('.+?\',(.+?)\);<\/script>/)
				if matched
					post_data = JSON.parse(matched[1])
					user_id = post_data['graphql']['shortcode_media']['owner']['id']
				else
					begin
						matched = page_html.match(/window\._sharedData = (.+?)\);<\/script>/)
						post_data = JSON.parse(matched[1])
						user_id = post_data['graphql']['shortcode_media']['owner']['id']
					rescue
						@@logger.error "user_id not detected"
						return true
					end
				end
				@@logger.debug "user_id = #{user_id}"
				img_src = nil
				video = Spider::WebBrowser.get_driver.find_element(:xpath, "//article//video") rescue nil
				if video
					img_src = video.attribute("poster")
				end
				if img_src.nil?
					img_el = Spider::WebBrowser.get_driver.find_element(:xpath, "//article//ul//img") rescue nil
					if img_el
						begin
							img_src = img_el.attribute("src")
						rescue
							sleep 1
							begin
								img_el = Spider::WebBrowser.get_driver.find_element(:xpath, "//article//ul//img") rescue nil
								img_src = img_el.attribute("src")
							rescue
								print 'Error on img_src. Press button'
							end
						end
					end
				end
				if img_src.nil?
					img_el = Spider::WebBrowser.get_driver.find_element(:xpath, "//article//img") rescue nil
					if img_el
						img_src = img_el.attribute("src")
					end
				end
				@@logger.debug  "img_src = #{img_src}"
				posts.push({
					'img_url' => img_src,
					'user_id' => user_id,
					'post_url' => url,
					'date' => post_time,
				})
			else
				return false
			end
			true
		end

		def self.get_location_posts url
			posts = []
			@@logger.debug "try to load location #{url}"
			Spider::WebBrowser.get_driver.navigate.to url
			sleep 3
			if is_page_bunned
				Spider::WebBrowser.quit_browser
				@@logger.debug "Page banned. I'm sleep 60 min and exit"
				sleep 60 * 60
				exit
			else
				@@logger.debug "#get_location_posts - No bun"
			end
			save_screenshot 'parse_location_url'
			rec_post_selector = "//h2[contains(@class, 'yQ0j1')]/following-sibling::div/div/div/div"
			flag = true
			while flag
				recent_posts = Spider::WebBrowser.get_driver.find_elements(:xpath, rec_post_selector) rescue 0
				if recent_posts.count == 0
					flag = false
					next
				end
				urls = []
				recent_posts.each do |_post_el|
					begin
						a_el = _post_el.find_element(:xpath, './/a')
						url = a_el.attribute('href')
						urls.push url
					rescue
						@@logger.warn "href not detected in the post list"
					end
					# close_el = Spider::WebBrowser.get_driver.find_element(:xpath, "//*[contains(@aria-label, 'Close')]")
					# close_el.click
				end
				if Spider::WebBrowser.get_driver.window_handles.count == 1
					Spider::WebBrowser.get_driver.execute_script( "window.open(); return true;" )
					Spider::WebBrowser.get_driver.switch_to.window( Spider::WebBrowser.get_driver.window_handles.last )
					sleep 2
				else
					Spider::WebBrowser.get_driver.switch_to.window( Spider::WebBrowser.get_driver.window_handles.last )
					sleep 2
				end
				@@logger.debug  "#{urls.count} detected on page location"
				urls.each do |url|
					if flag
						flag = scrape_post_properties url, posts
					end
				end
				Spider::WebBrowser.get_driver.switch_to.window( Spider::WebBrowser.get_driver.window_handles.first )
				sleep 2
				if flag
					sleep 1
					Spider::WebBrowser.get_driver.find_elements(:xpath, rec_post_selector).each do |css_sel_el|
						Spider::WebBrowser.get_driver.execute_script("var element = arguments[0]; element.remove(); return true;", css_sel_el) rescue nil
					end
					sleep 1
					Spider::WebBrowser.get_driver.execute_script("window.scrollTo(0, document.documentElement.scrollHeight);")
					sleep 4
				end
			end
			posts
		end

	end
end
