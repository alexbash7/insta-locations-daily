require 'net/http'
require 'zlib'
require 'stringio'


session_id = ''
location_id = ''
page = ''

http = Net::HTTP.new('i.instagram.com', 443)
http.use_ssl = true
path = "/api/v1/locations/#{location_id}/sections/"


# POST request -> logging in
data = 'surface=grid&tab=recent&max_id=QVFBWVczcFdzSEtCNXkzWmhIQmJUREpWNzZyRkNuTktHS3pzMnVVZTdSVWRtVW1EdUtEMnlQSlFPdkduMEluT1BRb0g3NDk5TEJ3OUNVTHZUSlRDaW5KVA%3D%3D&page='+page+'&next_media_ids=%5B%222720030957321528368%22%5D'
headers = {
	# ':authority' => 'i.instagram.com',
	# ':method' => 'POST',
	# ':path' => '/api/v1/locations/359545221/sections/',
	# ':scheme' => 'https',
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

resp, data = http.post(path, data, headers)


# Output on the screen -> we should get either a 302 redirect (after a successful login) or an error page
# p resp.body.force_encoding(Encoding::UTF_8)

gz = Zlib::GzipReader.new(StringIO.new(resp.body.to_s))    
uncompressed_string = gz.read
p uncompressed_string