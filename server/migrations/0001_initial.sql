CREATE TABLE `users` (
  `id` integer PRIMARY KEY NOT NULL,
  `updated_at` text DEFAULT (strftime('%Y-%m-%dT%H:%M:%fZ', 'now')) NOT NULL,
  `created_at` text DEFAULT (strftime('%Y-%m-%dT%H:%M:%fZ', 'now')) NOT NULL,
  `enable_a_p_i_key` integer,
  `api_key` text,
  `api_key_index` text,
  `email` text NOT NULL,
  `reset_password_token` text,
  `reset_password_expiration` text,
  `salt` text,
  `hash` text,
  `login_attempts` numeric DEFAULT 0,
  `lock_until` text
);
CREATE INDEX `users_updated_at_idx` ON `users` (`updated_at`);
CREATE INDEX `users_created_at_idx` ON `users` (`created_at`);
CREATE UNIQUE INDEX `users_email_idx` ON `users` (`email`);

CREATE TABLE `users_sessions` (
  `_order` integer NOT NULL,
  `_parent_id` integer NOT NULL,
  `id` text PRIMARY KEY NOT NULL,
  `created_at` text,
  `expires_at` text NOT NULL,
  FOREIGN KEY (`_parent_id`) REFERENCES `users`(`id`) ON UPDATE no action ON DELETE cascade
);
CREATE INDEX `users_sessions_order_idx` ON `users_sessions` (`_order`);
CREATE INDEX `users_sessions_parent_id_idx` ON `users_sessions` (`_parent_id`);

CREATE TABLE `proposals` (
  `id` integer PRIMARY KEY NOT NULL,
  `proposal_id` text NOT NULL,
  `title` text NOT NULL,
  `authors` text NOT NULL,
  `content` text NOT NULL,
  `review_manager` text,
  `status` text,
  `updated_at` text DEFAULT (strftime('%Y-%m-%dT%H:%M:%fZ', 'now')) NOT NULL,
  `created_at` text DEFAULT (strftime('%Y-%m-%dT%H:%M:%fZ', 'now')) NOT NULL
);
CREATE UNIQUE INDEX `proposals_proposal_id_idx` ON `proposals` (`proposal_id`);
CREATE INDEX `proposals_updated_at_idx` ON `proposals` (`updated_at`);
CREATE INDEX `proposals_created_at_idx` ON `proposals` (`created_at`);

CREATE TABLE `quiz_answers` (
  `id` integer PRIMARY KEY NOT NULL,
  `proposal_id` text NOT NULL,
  `answers` text NOT NULL,
  `updated_at` text DEFAULT (strftime('%Y-%m-%dT%H:%M:%fZ', 'now')) NOT NULL,
  `created_at` text DEFAULT (strftime('%Y-%m-%dT%H:%M:%fZ', 'now')) NOT NULL
);
CREATE UNIQUE INDEX `quiz_answers_proposal_id_idx` ON `quiz_answers` (`proposal_id`);
CREATE INDEX `quiz_answers_updated_at_idx` ON `quiz_answers` (`updated_at`);
CREATE INDEX `quiz_answers_created_at_idx` ON `quiz_answers` (`created_at`);

CREATE TABLE `payload_kv` (
  `id` integer PRIMARY KEY NOT NULL,
  `key` text NOT NULL,
  `data` text NOT NULL
);
CREATE UNIQUE INDEX `payload_kv_key_idx` ON `payload_kv` (`key`);

CREATE TABLE `payload_locked_documents` (
  `id` integer PRIMARY KEY NOT NULL,
  `global_slug` text,
  `updated_at` text DEFAULT (strftime('%Y-%m-%dT%H:%M:%fZ', 'now')) NOT NULL,
  `created_at` text DEFAULT (strftime('%Y-%m-%dT%H:%M:%fZ', 'now')) NOT NULL
);
CREATE INDEX `payload_locked_documents_global_slug_idx` ON `payload_locked_documents` (`global_slug`);
CREATE INDEX `payload_locked_documents_updated_at_idx` ON `payload_locked_documents` (`updated_at`);
CREATE INDEX `payload_locked_documents_created_at_idx` ON `payload_locked_documents` (`created_at`);

CREATE TABLE `payload_locked_documents_rels` (
  `id` integer PRIMARY KEY NOT NULL,
  `order` integer,
  `parent_id` integer NOT NULL,
  `path` text NOT NULL,
  `users_id` integer,
  `proposals_id` integer,
  `quiz_answers_id` integer,
  FOREIGN KEY (`parent_id`) REFERENCES `payload_locked_documents`(`id`) ON UPDATE no action ON DELETE cascade,
  FOREIGN KEY (`users_id`) REFERENCES `users`(`id`) ON UPDATE no action ON DELETE cascade,
  FOREIGN KEY (`proposals_id`) REFERENCES `proposals`(`id`) ON UPDATE no action ON DELETE cascade,
  FOREIGN KEY (`quiz_answers_id`) REFERENCES `quiz_answers`(`id`) ON UPDATE no action ON DELETE cascade
);
CREATE INDEX `payload_locked_documents_rels_order_idx` ON `payload_locked_documents_rels` (`order`);
CREATE INDEX `payload_locked_documents_rels_parent_idx` ON `payload_locked_documents_rels` (`parent_id`);
CREATE INDEX `payload_locked_documents_rels_path_idx` ON `payload_locked_documents_rels` (`path`);
CREATE INDEX `payload_locked_documents_rels_users_id_idx` ON `payload_locked_documents_rels` (`users_id`);
CREATE INDEX `payload_locked_documents_rels_proposals_id_idx` ON `payload_locked_documents_rels` (`proposals_id`);
CREATE INDEX `payload_locked_documents_rels_quiz_answers_id_idx` ON `payload_locked_documents_rels` (`quiz_answers_id`);

CREATE TABLE `payload_preferences` (
  `id` integer PRIMARY KEY NOT NULL,
  `key` text,
  `value` text,
  `updated_at` text DEFAULT (strftime('%Y-%m-%dT%H:%M:%fZ', 'now')) NOT NULL,
  `created_at` text DEFAULT (strftime('%Y-%m-%dT%H:%M:%fZ', 'now')) NOT NULL
);
CREATE INDEX `payload_preferences_key_idx` ON `payload_preferences` (`key`);
CREATE INDEX `payload_preferences_updated_at_idx` ON `payload_preferences` (`updated_at`);
CREATE INDEX `payload_preferences_created_at_idx` ON `payload_preferences` (`created_at`);

CREATE TABLE `payload_preferences_rels` (
  `id` integer PRIMARY KEY NOT NULL,
  `order` integer,
  `parent_id` integer NOT NULL,
  `path` text NOT NULL,
  `users_id` integer,
  FOREIGN KEY (`parent_id`) REFERENCES `payload_preferences`(`id`) ON UPDATE no action ON DELETE cascade,
  FOREIGN KEY (`users_id`) REFERENCES `users`(`id`) ON UPDATE no action ON DELETE cascade
);
CREATE INDEX `payload_preferences_rels_order_idx` ON `payload_preferences_rels` (`order`);
CREATE INDEX `payload_preferences_rels_parent_idx` ON `payload_preferences_rels` (`parent_id`);
CREATE INDEX `payload_preferences_rels_path_idx` ON `payload_preferences_rels` (`path`);
CREATE INDEX `payload_preferences_rels_users_id_idx` ON `payload_preferences_rels` (`users_id`);

CREATE TABLE `payload_migrations` (
  `id` integer PRIMARY KEY NOT NULL,
  `name` text,
  `batch` numeric,
  `updated_at` text DEFAULT (strftime('%Y-%m-%dT%H:%M:%fZ', 'now')) NOT NULL,
  `created_at` text DEFAULT (strftime('%Y-%m-%dT%H:%M:%fZ', 'now')) NOT NULL
);
CREATE INDEX `payload_migrations_updated_at_idx` ON `payload_migrations` (`updated_at`);
CREATE INDEX `payload_migrations_created_at_idx` ON `payload_migrations` (`created_at`);

INSERT INTO `payload_migrations` (`name`, `batch`) VALUES ('20260505_065448', 1);
