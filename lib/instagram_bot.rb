require 'date'
require 'unicode'
require 'unicode/emoji'
require 'net/http'
require 'zlib'
require 'stringio'
require 'json'

module Spider
	module InstagramBot
		POSTS_PERIOD_MINUTES = 24*60

		def self.set_logger logger
			@@logger = logger
		end

		def self.insert_in_db posts, location_id
			Spider::DB.get_db.transaction do
				posts.each do |post|
					blacklist_user = Spider::DB.get_db[:accounts_all].where(user_id: post['user_id']).first
					if blacklist_user
						next
					end
					begin
						Spider::DB.get_db[:posts].insert(img_url: post['img_url'], user_id: post['user_id'], post_url: post['post_url'], location_id: location_id, post_date: post['date'])
					rescue Sequel::UniqueConstraintViolation
					end
				end
			end
		end

		def self.get_location_http_response cookie_list, page_number, max_id, location_id, attempt = 1
			begin
				cookie_list
				@@sess_index ||= -1
				@@sess_index += 1
				if cookie_list.count == @@sess_index
					@@sess_index = 0
				end
				session_id = cookie_list[@@sess_index]
				begin
					proxy = Net::HTTP::Proxy('connect4.mproxy.top', '10813', 'alexwhte', 'alexwhte')
					http = proxy.start('i.instagram.com', use_ssl: true, verify_mode: OpenSSL::SSL::VERIFY_NONE)
				rescue OpenSSL::SSL::SSLError, Net::HTTPFatalError
					sleep 2
					proxy = Net::HTTP::Proxy('connect4.mproxy.top', '10813', 'alexwhte', 'alexwhte')
					http = proxy.start('i.instagram.com', use_ssl: true, verify_mode: OpenSSL::SSL::VERIFY_NONE)
				end
				# http = Net::HTTP.new('i.instagram.com', 443)
				http.use_ssl = true
				path = "/api/v1/locations/#{location_id}/sections/"
				max_id_par = ''
				if page_number > 0
					max_id_par = '&max_id=' + max_id.gsub('=', '%3D')
				end
				data = 'surface=grid&tab=recent'+max_id_par+'&page='+page_number.to_s+'&next_media_ids=%5B%5D'
				# @@logger.debug "@@sess_index = #{@@sess_index}"
				@@logger.debug "req data = #{data}"
				# @@logger.debug "req location_id = #{location_id}"
				headers = {
					'accept' => '*/*',
					'accept-encoding' => 'gzip, deflate, br',
					'accept-language' => 'en-GB,en;q=0.9,en-US;q=0.8,ru;q=0.7',
					'content-length' => '209',
					'content-type' => 'application/x-www-form-urlencoded',
					'cookie' => 'sessionid='+session_id,
					'origin' => 'https://www.instagram.com',
					'referer' => 'https://www.instagram.com/',
					'sec-ch-ua' => '" Not A;Brand";v="99", "Chromium";v="96", "Google Chrome";v="96"',
					'sec-ch-ua-mobile' => '?0',
					'sec-ch-ua-platform' => '"macOS"',
					'sec-fetch-dest' => 'empty',
					'sec-fetch-mode' => 'cors',
					'sec-fetch-site' => 'same-site',
					'user-agent' => 'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/96.0.4664.55 Safari/537.36',
					'x-asbd-id' => '198387',
					'x-csrftoken' => '2px9HDxLBbPqyE57NxR52k5asBS8EqAN',
					'x-ig-app-id' => '936619743392459',
					'x-ig-www-claim' => 'hmac.AR1Ny7RnGLJpi3yApnV1C2flBb6obPQ24lSkSneN6k6xA1IS',
					'x-instagram-ajax' => '5cf8305bdd2d'
				}

				resp, post_data = http.post(path, data, headers)
				if attempt < 3 && (resp.body.nil? || resp.body.empty?)
					@@logger.debug "#get_location_http_response - data is nil. Attempt #{attempt + 1}"
					return get_location_http_response(cookie_list, page_number, max_id, location_id, attempt + 1)
				end
				return [resp, post_data]
			rescue Net::ReadTimeout, EOFError
				if attempt < 3
					@@logger.debug "#get_location_http_response - attempt #{attempt + 1}"
					return get_location_http_response(cookie_list, page_number, max_id, location_id, attempt + 1)
				end
				[nil,nil]
			end
		end

		def self.get_location_page_json cookie_list, page_number, max_id, location_id			
			resp, data = get_location_http_response cookie_list, page_number, max_id, location_id
			begin
				gz = Zlib::GzipReader.new(StringIO.new(resp.body.to_s))
				uncompressed_string = gz.read
				JSON.parse(uncompressed_string)
			rescue
				p resp
				p resp.body
				{}
			end
		end

		def self.crawl_location_posts url, location_row
			cookie_list_text = Spider::DB.get_db[:settings].where(app_name: 'insta-locations-daily').where(key: 'cookie_list').first[:value] rescue ''
			cookie_list = cookie_list_text.split("\n")
			if cookie_list.empty?
				@@logger.error 'cookie_list not found in settings table. Exit'
				sleep 5
				exit
			end
			@@logger.debug "try to load location #{url}"
			location_id = url.scan(/[0-9]+/).first
			yesterday_day_number = Date.today.prev_day.strftime('%d').to_i
			page = 0
			no_posts_count = 0
			all_posts_count = 0
			flag = true
			max_id = ''
			while flag
				posts = []
				page_response = get_location_page_json cookie_list, page, max_id, location_id
				if page_response.empty?
					@@logger.debug '#get_location_posts - empty http response'
				else
					prev_posts_count = posts.count
					sections = page_response['sections']
					max_id = page_response['next_max_id']
					sections.each do |section|
						medias = section['layout_content']['medias']
						medias.each do |media|
							media_info = media['media']
							carousel_media = media_info['carousel_media'] rescue nil
							if carousel_media.nil?
								img_src_text = media_info['image_versions2']['candidates'].first['url']
							else
								img_src_text = carousel_media.first['image_versions2']['candidates'].first['url']
							end
							img_src = img_src_text.gsub('\\\\u0026','&')
							user_id = media_info['user']['pk']
							code = media_info['code']
							post_url = "https://www.instagram.com/p/#{code}/"
							taken_at = media_info['taken_at']
							post_time = Time.at(taken_at.to_i)
							if post_time.strftime("%d").to_i < yesterday_day_number
								flag = false
								break
							end
							posts.push({
								'img_url' => img_src,
								'user_id' => user_id,
								'post_url' => post_url,
								'date' => post_time,
							})
						end
					end
					@@logger.debug "posts.last['date'] = #{posts.last['date']}" if posts.last
					@@logger.debug "#{posts.count} posts scrapped on page #{page}"
				end
				if posts.count == 0
					no_posts_count += 1
					if no_posts_count == 5
						@@logger.info 'Posts not found 5 times in sequence. Completing the crowl of location'
						flag = false
					end
				end
				posts = posts.select { |post| post['date'].strftime('%d').to_i == yesterday_day_number }
				all_posts_count += posts.count
				begin
					insert_in_db posts, location_row[:locid]
				rescue Sequel::DatabaseDisconnectError
					Spider::DB.disconnect
					insert_in_db posts, location_row[:locid]
				end
				page += 1
			end
			all_posts_count
		end
	end
end
