CREATE TABLE `users` (
	`id` text PRIMARY KEY NOT NULL,
	`email` text,
	`email_verified` integer DEFAULT false,
	`is_private_email` integer DEFAULT false,
	`real_user_status` integer,
	`created_at` integer NOT NULL,
	`updated_at` integer NOT NULL
);
