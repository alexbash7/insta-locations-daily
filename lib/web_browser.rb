require "selenium-webdriver"

module Spider
	module WebBrowser
		def self.get_driver
			@@driver ||= begin
				@@proxy ||= nil
				@@profile_dir ||= nil
				config = Spider::Config.get_config
				case config.web_browser['type']
				when 'firefox'
					Spider::ProjectLogger.get_logger.info "profile_dir = #{@@profile_dir}"
					if @@profile_dir
						profile = Selenium::WebDriver::Firefox::Profile.new(get_profile_dir_path)
					else
						profile = Selenium::WebDriver::Firefox::Profile.new
					end
					profile['geo.enabled'] = true # appCodeName
					profile['geo.prompt.testing'] = true
					profile['geo.prompt.testing.allow'] = true
					profile['general.description.override'] = "Mozilla" # appCodeName
					profile['general.appname.override'] = "Netscape"
					profile['general.appversion.override'] = "5.0 (Macintosh)"
					profile['general.platform.override'] = "MacIntel"
					profile['general.oscpu.override'] = "Intel Mac OS X 10.15"
					profile['general.useragent.override'] = 'Mozilla/5.0 (Macintosh; Intel Mac OS X 10.15; rv:87.0) Gecko/20100101 Firefox/87.0'
					if @@proxy
						profile['network.proxy.http'] = @@proxy[:host]
						profile['network.proxy.http_port'] = @@proxy[:port]
					end
					if config.web_browser['disable_images']
						profile['permissions.default.image'] = 2
					end
					args = []
					args.push '-headless' if config.web_browser['headless']
					options = Selenium::WebDriver::Firefox::Options.new(args: args, profile: profile)
					driver = Selenium::WebDriver.for :firefox, options: options
					target_size = Selenium::WebDriver::Dimension.new(config.web_browser['window_width'], config.web_browser['window_height'])
					driver.manage.window.size = target_size
				when 'chrome'
					options = Selenium::WebDriver::Chrome::Options.new
					options.add_argument("--user-agent=Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_3) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/79.0.3945.130 Safari/537.36")
					if @@profile_dir
						options.add_argument("--user-data-dir=#{get_profile_dir_path}")
					end
					options.add_argument("--proxy-server=#{@@proxy[:host]}:#{@@proxy[:port]}") if @@proxy
					options.add_argument('--headless') if config.web_browser['headless']
					options.add_argument("--window-size=#{config.web_browser['window_width']},#{config.web_browser['window_height']}")
					options.add_argument('--disable-dev-shm-usage') if config.web_browser['disable-dev-shm-usage']
					if config.web_browser['disable_images']
						options.add_argument('--blink-settings=imagesEnabled=false')
					end
					options.add_argument('--no-sandbox') if config.web_browser['no-sandbox']
					driver = Selenium::WebDriver.for :chrome, options: options
				else
				  Spider::ProjectLogger.get_logger.error "Error: browser not detected in config"
				  exit
				end
				at_exit { quit_browser }
				driver
			end
		end

		def self.set_profile_dir_name profile_dir
			@@profile_dir = profile_dir
		end

		def self.get_profile_dir_path
			File.expand_path(File.join(__dir__, '..', 'browser_profiles', @@profile_dir), __FILE__)
		end

		def self.get_current_proxy
			@@proxy ||= nil
		end

		def self.set_proxy proxy
			@@proxy = proxy
		end

		def self.restart_browser
			quit_browser
			Spider::ProjectLogger.get_logger.info "Restart browser"
			get_driver
		end

		def self.quit_browser
			@@driver.quit rescue nil
			@@driver = nil
		end
	end
end
