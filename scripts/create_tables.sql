CREATE TABLE `blacklist_users` (
  `id` bigint(20) unsigned NOT NULL AUTO_INCREMENT,
  `user_id` bigint(20) DEFAULT NULL,
  PRIMARY KEY (`id`),
  KEY `user_id` (`user_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8;

CREATE TABLE `locations_daily` (
  `id` bigint(20) unsigned NOT NULL AUTO_INCREMENT,
  `url` varchar(255) DEFAULT NULL,
  `city` varchar(255) DEFAULT NULL,
  `is_parse` int(11) DEFAULT 0,
  `locid` bigint(20) DEFAULT NULL,
  PRIMARY KEY (`id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8;

CREATE TABLE `posts` (
  `id` bigint(20) unsigned NOT NULL AUTO_INCREMENT,
  `img_url` text DEFAULT NULL,
  `user_id` varchar(255) DEFAULT NULL,
  `post_url` varchar(255) DEFAULT NULL,
  `location_id` bigint(20) DEFAULT NULL,
  `post_date` datetime DEFAULT NULL,
  `created` datetime NOT NULL DEFAULT current_timestamp(),
  PRIMARY KEY (`id`),
  UNIQUE KEY `post_url` (`post_url`,`location_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8;