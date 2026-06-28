CREATE TABLE `testing_proposals` (
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
CREATE UNIQUE INDEX `testing_proposals_proposal_id_idx` ON `testing_proposals` (`proposal_id`);
CREATE INDEX `testing_proposals_updated_at_idx` ON `testing_proposals` (`updated_at`);
CREATE INDEX `testing_proposals_created_at_idx` ON `testing_proposals` (`created_at`);

CREATE TABLE `testing_quiz_answers` (
  `id` integer PRIMARY KEY NOT NULL,
  `proposal_id` text NOT NULL,
  `answers` text NOT NULL,
  `updated_at` text DEFAULT (strftime('%Y-%m-%dT%H:%M:%fZ', 'now')) NOT NULL,
  `created_at` text DEFAULT (strftime('%Y-%m-%dT%H:%M:%fZ', 'now')) NOT NULL
);
CREATE UNIQUE INDEX `testing_quiz_answers_proposal_id_idx` ON `testing_quiz_answers` (`proposal_id`);
CREATE INDEX `testing_quiz_answers_updated_at_idx` ON `testing_quiz_answers` (`updated_at`);
CREATE INDEX `testing_quiz_answers_created_at_idx` ON `testing_quiz_answers` (`created_at`);

-- Payload's locked-documents join table needs a column per collection.
ALTER TABLE `payload_locked_documents_rels` ADD COLUMN `testing_proposals_id` integer REFERENCES `testing_proposals`(`id`);
ALTER TABLE `payload_locked_documents_rels` ADD COLUMN `testing_quiz_answers_id` integer REFERENCES `testing_quiz_answers`(`id`);
CREATE INDEX `payload_locked_documents_rels_testing_proposals_id_idx` ON `payload_locked_documents_rels` (`testing_proposals_id`);
CREATE INDEX `payload_locked_documents_rels_testing_quiz_answers_id_idx` ON `payload_locked_documents_rels` (`testing_quiz_answers_id`);
