CREATE TABLE IF NOT EXISTS `account_bot_tokens` (
    `account_id` INT(10) UNSIGNED NOT NULL,
    `autogear_tokens` INT(11) NOT NULL DEFAULT 0,
    `maintenance_tokens` INT(11) NOT NULL DEFAULT 0,
    PRIMARY KEY (`account_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;