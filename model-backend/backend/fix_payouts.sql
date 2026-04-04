-- Add missing fraud_score column to payouts table
ALTER TABLE payouts ADD COLUMN IF NOT EXISTS fraud_score FLOAT;

-- Verify the column was added
SELECT column_name, data_type FROM information_schema.columns 
WHERE table_name = 'payouts' AND column_name = 'fraud_score';
