CREATE TABLE `proposal_references` (
  `id` integer PRIMARY KEY NOT NULL,
  `from_proposal_id` text NOT NULL,
  `to_proposal_id` text NOT NULL,
  `updated_at` text DEFAULT (strftime('%Y-%m-%dT%H:%M:%fZ', 'now')) NOT NULL,
  `created_at` text DEFAULT (strftime('%Y-%m-%dT%H:%M:%fZ', 'now')) NOT NULL
);
CREATE UNIQUE INDEX `proposal_references_from_to_idx` ON `proposal_references` (`from_proposal_id`, `to_proposal_id`);
CREATE INDEX `proposal_references_from_idx` ON `proposal_references` (`from_proposal_id`);
CREATE INDEX `proposal_references_to_idx` ON `proposal_references` (`to_proposal_id`);
CREATE INDEX `proposal_references_updated_at_idx` ON `proposal_references` (`updated_at`);
CREATE INDEX `proposal_references_created_at_idx` ON `proposal_references` (`created_at`);

-- Payload's locked-documents join table needs a column per collection.
ALTER TABLE `payload_locked_documents_rels` ADD COLUMN `proposal_references_id` integer REFERENCES `proposal_references`(`id`);
CREATE INDEX `payload_locked_documents_rels_proposal_references_id_idx` ON `payload_locked_documents_rels` (`proposal_references_id`);
