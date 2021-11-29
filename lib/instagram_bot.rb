require 'date'

module Spider
	module InstagramBot
		POSTS_PERIOD_MINUTES = 30
		def self.set_logger logger
			@@logger = logger
		end

		def self.click_not_now_notifications
			notif_not_now = Spider::WebBrowser.get_driver.find_element(:xpath, "//*[contains(text(), 'Not Now')]") rescue nil
			if notif_not_now
				notif_not_now.click
				sleep 1
			end
		end

		def self.login username, pass
			Spider::WebBrowser.get_driver.navigate.to "https://www.instagram.com/accounts/login/"
			sleep 3
			username_el = Spider::WebBrowser.get_driver.find_element(:css => "input[name='username']") rescue nil
			if username_el.nil?
				click_not_now_notifications
				return true
			end
			username_el.click
			username_el.send_keys username
			password_el = Spider::WebBrowser.get_driver.find_element(:css => "input[name='password']")
			password_el.click
			password_el.send_keys pass
			
			btn_submit =  Spider::WebBrowser.get_driver.find_element(:xpath, '//*[text()="Log In"]')
			btn_submit.click
			sleep 2
			click_not_now_notifications
		end

		def self.scrape_post_properties url, posts
			Spider::WebBrowser.get_driver.navigate.to url
			time_el = Spider::WebBrowser.get_driver.find_element(:css, 'a>time') rescue nil
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
				post_data = JSON.parse(matched[1])
				user_id = post_data['graphql']['shortcode_media']['owner']['id']
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
								Spider::WebBrowser.get_driver.save_screenshot 'src-error.png'
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
			Spider::WebBrowser.get_driver.navigate.to url
			rec_post_selector = "//h2[contains(text(), 'Most Recent')]/following-sibling::div/div/div/div"
			
			flag = true
			while flag
				recent_posts = Spider::WebBrowser.get_driver.find_elements(:xpath, rec_post_selector) rescue 0
				css_sel = "article>div>div>div>div.kIKUG"
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
						Spider::WebBrowser.get_driver.save_screenshot 'href_not_detected.png' rescue nil
						@@logger.warn "href not detected in the post list"
					end
					# close_el = Spider::WebBrowser.get_driver.find_element(:xpath, "//*[contains(@aria-label, 'Close')]")
					# close_el.click
				end
				if Spider::WebBrowser.get_driver.window_handles.count == 1
					Spider::WebBrowser.get_driver.execute_script( "window.open(); return true;" )
					Spider::WebBrowser.get_driver.switch_to.window( Spider::WebBrowser.get_driver.window_handles.last )
				else
					Spider::WebBrowser.get_driver.switch_to.window( Spider::WebBrowser.get_driver.window_handles.last )
				end
				urls.each do |url|
					if flag
						flag = scrape_post_properties url, posts
					end
				end
				Spider::WebBrowser.get_driver.switch_to.window( Spider::WebBrowser.get_driver.window_handles.first )
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
