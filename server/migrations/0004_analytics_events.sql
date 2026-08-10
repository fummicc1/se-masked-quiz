-- Anonymous usage events for product discovery experiments (Issue #6, Experiment 1).
CREATE TABLE `analytics_events` (
  `id` integer PRIMARY KEY NOT NULL,
  `name` text NOT NULL,
  `anon_id` text NOT NULL,
  `params` text,
  `app_version` text,
  `updated_at` text DEFAULT (strftime('%Y-%m-%dT%H:%M:%fZ', 'now')) NOT NULL,
  `created_at` text DEFAULT (strftime('%Y-%m-%dT%H:%M:%fZ', 'now')) NOT NULL
);
CREATE INDEX `analytics_events_name_idx` ON `analytics_events` (`name`);
CREATE INDEX `analytics_events_anon_id_idx` ON `analytics_events` (`anon_id`);
CREATE INDEX `analytics_events_updated_at_idx` ON `analytics_events` (`updated_at`);
CREATE INDEX `analytics_events_created_at_idx` ON `analytics_events` (`created_at`);
-- Covers WAU-style aggregations filtered by name over a time window.
CREATE INDEX `analytics_events_name_created_at_idx` ON `analytics_events` (`name`, `created_at`);

-- Payload's locked-documents join table needs a column per collection.
ALTER TABLE `payload_locked_documents_rels` ADD COLUMN `analytics_events_id` integer REFERENCES `analytics_events`(`id`);
CREATE INDEX `payload_locked_documents_rels_analytics_events_id_idx` ON `payload_locked_documents_rels` (`analytics_events_id`);
