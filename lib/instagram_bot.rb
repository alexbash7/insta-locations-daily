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
		SCREENSHOTS_DIR = File.join(__dir__, '..', 'tmp')
		BUN_SLEEP = 60 * 10

		def self.set_logger logger
			@@logger = logger
		end

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

		def self.get_location_http_response page_number, max_id, location_id, attempt = 1
			begin
				sessions = [
					# '45294772993%3ANqC3ffVkaXCKLN%3A26',
					'45450101247%3AOAKXuwD1f1t6OS%3A2',
					'45661832288%3AvKqSVrxBt1Blfd%3A16',
					'45602006188%3A2coTcxoaHneL31%3A22',
					'45648432877%3ANdhjMOY3p3BoU0%3A10',
					'45076749441%3Av8dB19JnzrPY8L%3A5',
					# '44775405086%3AmynsjPqCXCTBUJ%3A6',
					'45290532920%3AS6O1UUgIuIeEbP%3A20',
				]
				@@sess_index ||= -1
				@@sess_index += 1
				if sessions.count == @@sess_index
					@@sess_index = 0
				end
				session_id = sessions[@@sess_index]
				proxy = Net::HTTP::Proxy('connect4.mproxy.top', '10813', 'alexwhte', 'alexwhte')
				http = proxy.start('i.instagram.com', :use_ssl => true, :verify_mode => OpenSSL::SSL::VERIFY_NONE)
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
					return get_location_http_response(page_number, max_id, location_id, attempt + 1)
				end
				return [resp, post_data]
			rescue Net::ReadTimeout
				if attempt < 3
					@@logger.debug "#get_location_http_response - attempt #{attempt + 1}"
					return get_location_http_response(page_number, max_id, location_id, attempt + 1)
				end
				[nil,nil]
			end
		end

		def self.get_location_page_json page_number, max_id, location_id			
			resp, data = get_location_http_response page_number, max_id, location_id
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

		def self.get_location_posts url, location_row
			posts = []
			@@logger.debug "try to load location #{url}"
			location_id = url.scan(/[0-9]+/).first
			current_time = Time.now
			page = 0
			flag = true
			# posts_hash = {}
			max_id = ''
			while flag
				posts = []
				page_response = get_location_page_json page, max_id, location_id
				if page_response.empty?
					@@logger.debug "#get_location_posts - empty http response"
					begin
						insert_in_db posts, location_row[:id]
					rescue Sequel::DatabaseDisconnectError
						Spider::DB.disconnect
						insert_in_db posts, location_row[:id]
					end
					return true
				end
				prev_posts_count = posts.count
				sections = page_response['sections']
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
						# @@logger.debug "Post time = #{post_time}"
						if current_time - post_time > POSTS_PERIOD_MINUTES * 60
							@@logger.debug "Post time is old"
							flag = false
							break
						else
							# posts_hash[post_url] = true
							posts.push({
								'img_url' => img_src,
								'user_id' => user_id,
								'post_url' => post_url,
								'date' => post_time,
							})
						end
					end
				end
				@@logger.debug "posts.last['date'] = #{posts.last['date']}"
				@@logger.debug "#{posts.count} posts scrapped"
				# @@logger.debug "#{posts_hash.keys.count} uniqu posts scrapped"
				if prev_posts_count == posts.count
					@@logger.debug "Posts not increase, stop location load"
					flag = false
				end
				begin
					insert_in_db posts, location_row[:id]
				rescue Sequel::DatabaseDisconnectError
					Spider::DB.disconnect
					insert_in_db posts, location_row[:id]
				end
				
				max_id = page_response['next_max_id']
				page += 1
			end
		end
	end
end
