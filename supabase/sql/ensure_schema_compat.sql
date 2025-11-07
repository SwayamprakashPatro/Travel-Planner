-- Ensure compatibility: add expected columns if missing (safe / idempotent)
-- Run this first in Supabase SQL editor if you see 'column ... does not exist' errors

DO $$
BEGIN
  -- cities.name (some older schemas used city_name)
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_schema='public' AND table_name='cities' AND column_name='name'
  ) THEN
    IF EXISTS (
      SELECT 1 FROM information_schema.columns
      WHERE table_schema='public' AND table_name='cities' AND column_name='city_name'
    ) THEN
      -- Create 'name' and copy from 'city_name'
      ALTER TABLE public.cities ADD COLUMN IF NOT EXISTS name TEXT;
      UPDATE public.cities SET name = city_name WHERE name IS NULL;
    ELSE
      ALTER TABLE public.cities ADD COLUMN IF NOT EXISTS name TEXT;
    END IF;
  END IF;

  -- cities.state_name (older might have 'state')
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_schema='public' AND table_name='cities' AND column_name='state_name'
  ) THEN
    IF EXISTS (
      SELECT 1 FROM information_schema.columns
      WHERE table_schema='public' AND table_name='cities' AND column_name='state'
    ) THEN
      ALTER TABLE public.cities ADD COLUMN IF NOT EXISTS state_name TEXT;
      UPDATE public.cities SET state_name = state WHERE state_name IS NULL;
    ELSE
      ALTER TABLE public.cities ADD COLUMN IF NOT EXISTS state_name TEXT;
    END IF;
  END IF;

  -- trips.cities array (if missing, add as nullable text[] for migration compatibility)
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_schema='public' AND table_name='trips' AND column_name='cities'
  ) THEN
    ALTER TABLE public.trips ADD COLUMN IF NOT EXISTS cities TEXT[];
  END IF;

  -- hotels.description (optional) — add if missing
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_schema='public' AND table_name='hotels' AND column_name='description'
  ) THEN
    ALTER TABLE public.hotels ADD COLUMN IF NOT EXISTS description TEXT;
  END IF;

  -- trips.state (legacy) — don't add unless necessary; keep safe
  -- If other scripts expect trips.state, we can add it as nullable text
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_schema='public' AND table_name='trips' AND column_name='state'
  ) THEN
    ALTER TABLE public.trips ADD COLUMN IF NOT EXISTS state TEXT;
  END IF;

  -- Ensure trip_cities has id primary key (our master expects id bigint primary)
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_schema='public' AND table_name='trip_cities' AND column_name='id'
  ) THEN
    -- add id column if missing (note: should be safe when primary key absent)
    ALTER TABLE public.trip_cities ADD COLUMN IF NOT EXISTS id BIGSERIAL PRIMARY KEY;
  END IF;

  RAISE NOTICE 'Compatibility fixes applied (no-op if already present).';
END$$;

-- After running this file, run the merged migration (schema/fix_schema) and restart Supabase if PostgREST schema cache errors persist.
