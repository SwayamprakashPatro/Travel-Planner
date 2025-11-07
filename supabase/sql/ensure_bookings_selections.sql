-- Ensure bookings.selections exists (idempotent). Run this in Supabase SQL editor if the frontend errors with "bookings.selections does not exist".
BEGIN;

-- Add column if missing
ALTER TABLE IF EXISTS public.bookings
  ADD COLUMN IF NOT EXISTS selections JSONB;

-- Backfill existing rows with empty JSON object where NULL
UPDATE public.bookings
SET selections = '{}'::jsonb
WHERE selections IS NULL;

COMMIT;

-- Done. The frontend expects this JSONB column to store chosen hotels/transport/guides per booking.
