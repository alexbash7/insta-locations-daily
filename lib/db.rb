require 'sequel'

module Spider
	class DB
		def self.get_db
			@@db ||= begin
				config = Spider::Config.get_config

				db = Sequel.connect(
					adapter: :mysql2,
					host: config.db['host'],
					port: config.db['port'],
			  		database: config.db['name'],
					username: config.db['user'],
					password: config.db['passwd'],
			  		max_connections: 10,
			  		encoding: 'utf8',
			  		# loggers: [Logger.new($stdout)],
			  	)

			  	db.extension(:connection_validator)

			  	at_exit { disconnect }

			  	db
			end
		end

		def self.disconnect
			@@db.disconnect rescue nil
		end
	end
end