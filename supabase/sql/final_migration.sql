-- FINAL MIGRATION (idempotent)
-- Combines compatibility fixes, column ensures, rich backfill, safe defaults, grants, and seeds.
-- Safe to run multiple times; non-destructive where possible.

BEGIN;

-- ====================================================================
-- 1) COMPATIBILITY: ensure both `name` and `city_name` exist and are populated
-- ====================================================================
DO $$
BEGIN
  -- add missing columns if needed
  IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_schema='public' AND table_name='cities' AND column_name='name') THEN
    ALTER TABLE public.cities ADD COLUMN IF NOT EXISTS name TEXT;
  END IF;
  IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_schema='public' AND table_name='cities' AND column_name='city_name') THEN
    ALTER TABLE public.cities ADD COLUMN IF NOT EXISTS city_name TEXT;
  END IF;

  -- copy values between the two variants when present
  IF EXISTS (SELECT 1 FROM information_schema.columns WHERE table_schema='public' AND table_name='cities' AND column_name='city_name') THEN
    UPDATE public.cities SET city_name = COALESCE(city_name, name) WHERE name IS NOT NULL OR city_name IS NULL;
  END IF;
  IF EXISTS (SELECT 1 FROM information_schema.columns WHERE table_schema='public' AND table_name='cities' AND column_name='name') THEN
    UPDATE public.cities SET name = COALESCE(name, city_name) WHERE city_name IS NOT NULL OR name IS NULL;
  END IF;

  -- ensure no NULLs remain (use empty string for safety)
  UPDATE public.cities SET name = '' WHERE name IS NULL;
  UPDATE public.cities SET city_name = '' WHERE city_name IS NULL;

  -- set harmless default on city_name
  BEGIN
    IF EXISTS (SELECT 1 FROM information_schema.columns WHERE table_schema='public' AND table_name='cities' AND column_name='city_name') THEN
      ALTER TABLE public.cities ALTER COLUMN city_name SET DEFAULT '';
    END IF;
  EXCEPTION WHEN OTHERS THEN
    RAISE NOTICE 'Could not set default on public.cities.city_name: %', SQLERRM;
  END;
END$$;

-- ====================================================================
-- 2) ENSURE bookings.selections exists and backfill with structured data
-- ====================================================================
ALTER TABLE IF EXISTS public.bookings
  ADD COLUMN IF NOT EXISTS selections JSONB DEFAULT '{}'::jsonb;

-- Rich backfill: aggregate booking_* relations into selections JSONB (idempotent)
UPDATE public.bookings b
SET selections = COALESCE(b.selections, jsonb_build_object(
  'hotels', COALESCE((
    SELECT jsonb_agg(jsonb_build_object(
      'booking_hotel_id', bh.id,
      'hotel_id', bh.hotel_id,
      'hotel_name', h.name,
      'nights', bh.nights,
      'price_per_night', bh.price_per_night,
      'total_price', bh.total_price
    )) FROM public.booking_hotels bh LEFT JOIN public.hotels h ON bh.hotel_id = h.id WHERE bh.booking_id = b.id
  ), '[]'::jsonb),
  'transport', COALESCE((
    SELECT jsonb_agg(jsonb_build_object(
      'booking_transport_id', bt.id,
      'transport_id', bt.transport_id,
      'transport_name', t.name,
      'days', bt.days,
      'price_per_day', bt.price_per_day,
      'total_price', bt.total_price
    )) FROM public.booking_transport bt LEFT JOIN public.transport_options t ON bt.transport_id = t.id WHERE bt.booking_id = b.id
  ), '[]'::jsonb),
  'guides', COALESCE((
    SELECT jsonb_agg(jsonb_build_object(
      'booking_guide_id', bg.id,
      'guide_id', bg.guide_id,
      'guide_name', g.name,
      'days', bg.days,
      'price_per_day', bg.price_per_day,
      'total_price', bg.total_price
    )) FROM public.booking_guides bg LEFT JOIN public.guides g ON bg.guide_id = g.id WHERE bg.booking_id = b.id
  ), '[]'::jsonb),
  'travelers', COALESCE((
    SELECT jsonb_agg(jsonb_build_object(
      'traveler_id', bt.id,
      'traveler_name', bt.traveler_name,
      'traveler_age', bt.traveler_age
    )) FROM public.booking_travelers bt WHERE bt.booking_id = b.id
  ), '[]'::jsonb)
))
WHERE b.selections IS NULL OR b.selections = 'null'::jsonb;

-- Ensure default for selections
ALTER TABLE public.bookings ALTER COLUMN selections SET DEFAULT '{}'::jsonb;

-- ====================================================================
-- 3) SAFE DEFAULTS: populate common nullable columns with sensible defaults
--    (updates existing NULLs and sets column DEFAULTs; not forcing NOT NULL)
-- ====================================================================

-- Cities: ensure state_name not null
ALTER TABLE IF EXISTS public.cities ALTER COLUMN state_name SET DEFAULT '';
UPDATE public.cities SET state_name = '' WHERE state_name IS NULL;

-- Trips: cities array default, numeric defaults
ALTER TABLE IF EXISTS public.trips ALTER COLUMN cities SET DEFAULT ARRAY[]::text[];
UPDATE public.trips SET cities = ARRAY[]::text[] WHERE cities IS NULL;

ALTER TABLE IF EXISTS public.trips ALTER COLUMN budget_per_person SET DEFAULT 0;
UPDATE public.trips SET budget_per_person = 0 WHERE budget_per_person IS NULL;

ALTER TABLE IF EXISTS public.trips ALTER COLUMN total_days SET DEFAULT 0;
UPDATE public.trips SET total_days = 0 WHERE total_days IS NULL;

-- Hotels: rating/price defaults, description default
ALTER TABLE IF EXISTS public.hotels ALTER COLUMN rating SET DEFAULT 0;
UPDATE public.hotels SET rating = 0 WHERE rating IS NULL;

ALTER TABLE IF EXISTS public.hotels ALTER COLUMN price_per_night SET DEFAULT 0;
UPDATE public.hotels SET price_per_night = 0 WHERE price_per_night IS NULL;

ALTER TABLE IF EXISTS public.hotels ALTER COLUMN state SET DEFAULT '';
UPDATE public.hotels SET state = '' WHERE state IS NULL;

ALTER TABLE IF EXISTS public.hotels ALTER COLUMN description SET DEFAULT '';
UPDATE public.hotels SET description = '' WHERE description IS NULL;

-- Transport: price default
ALTER TABLE IF EXISTS public.transport_options ALTER COLUMN price_per_day SET DEFAULT 0;
UPDATE public.transport_options SET price_per_day = 0 WHERE price_per_day IS NULL;

-- Guides: rating/price defaults, phone default
ALTER TABLE IF EXISTS public.guides ALTER COLUMN rating SET DEFAULT 0;
UPDATE public.guides SET rating = 0 WHERE rating IS NULL;

ALTER TABLE IF EXISTS public.guides ALTER COLUMN price_per_day SET DEFAULT 0;
UPDATE public.guides SET price_per_day = 0 WHERE price_per_day IS NULL;

ALTER TABLE IF EXISTS public.guides ALTER COLUMN phone_number SET DEFAULT '';
UPDATE public.guides SET phone_number = '' WHERE phone_number IS NULL;

-- Bookings: total_amount default and status default
ALTER TABLE IF EXISTS public.bookings ALTER COLUMN total_amount SET DEFAULT 0;
UPDATE public.bookings SET total_amount = 0 WHERE total_amount IS NULL;

ALTER TABLE IF EXISTS public.bookings ALTER COLUMN status SET DEFAULT 'pending';
UPDATE public.bookings SET status = 'pending' WHERE status IS NULL;

-- Booking relations: traveler defaults
ALTER TABLE IF EXISTS public.booking_travelers ALTER COLUMN traveler_name SET DEFAULT '';
UPDATE public.booking_travelers SET traveler_name = '' WHERE traveler_name IS NULL;

ALTER TABLE IF EXISTS public.booking_travelers ALTER COLUMN traveler_age SET DEFAULT 0;
UPDATE public.booking_travelers SET traveler_age = 0 WHERE traveler_age IS NULL;

-- ====================================================================
-- 4) SEEDS (idempotent)
-- ====================================================================

-- Cities seeds
DO $$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM public.cities WHERE name='Calangute' AND state_name='Goa') THEN
    INSERT INTO public.cities (name, state_name) VALUES ('Calangute','Goa');
  END IF;
  IF NOT EXISTS (SELECT 1 FROM public.cities WHERE name='Panaji' AND state_name='Goa') THEN
    INSERT INTO public.cities (name, state_name) VALUES ('Panaji','Goa');
  END IF;
END$$;

-- Hotels seeds
DO $$
DECLARE
  cid_cal BIGINT;
  cid_pan BIGINT;
BEGIN
  SELECT id INTO cid_cal FROM public.cities WHERE name='Calangute' LIMIT 1;
  SELECT id INTO cid_pan FROM public.cities WHERE name='Panaji' LIMIT 1;

  IF NOT EXISTS (SELECT 1 FROM public.hotels WHERE name='Luxury Beach Resort') THEN
    INSERT INTO public.hotels (name, city_id, state, rating, price_per_night, description)
    VALUES ('Luxury Beach Resort', cid_cal, 'Goa', 4.8, 5000, 'Beachfront resort with pool');
  END IF;

  IF NOT EXISTS (SELECT 1 FROM public.hotels WHERE name='City Center Hotel') THEN
    INSERT INTO public.hotels (name, city_id, state, rating, price_per_night, description)
    VALUES ('City Center Hotel', cid_pan, 'Goa', 4.5, 3500, 'Comfortable hotel near attractions');
  END IF;

  IF NOT EXISTS (SELECT 1 FROM public.hotels WHERE name='Budget Inn') THEN
    INSERT INTO public.hotels (name, city_id, state, rating, price_per_night, description)
    VALUES ('Budget Inn', cid_pan, 'Goa', 4.0, 2000, 'Affordable stay with basic amenities');
  END IF;
END$$;

-- Transport seeds
DO $$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM public.transport_options WHERE name='AC Sedan' AND type='Private Car') THEN
    INSERT INTO public.transport_options (type, name, price_per_day, features) VALUES ('Private Car','AC Sedan',2500,'{"comfort":"AC","capacity":4}');
  END IF;
  IF NOT EXISTS (SELECT 1 FROM public.transport_options WHERE name='Tourist Cab' AND type='Shared Taxi') THEN
    INSERT INTO public.transport_options (type, name, price_per_day, features) VALUES ('Shared Taxi','Tourist Cab',1200,'{"shared":true,"capacity":6}');
  END IF;
  IF NOT EXISTS (SELECT 1 FROM public.transport_options WHERE name='AC Bus' AND type='Public Bus') THEN
    INSERT INTO public.transport_options (type, name, price_per_day, features) VALUES ('Public Bus','AC Bus',500,'{"shared":true,"capacity":40}');
  END IF;
END$$;

-- Guides + languages seeds
DO $$
DECLARE raj_id BIGINT;
DECLARE priya_id BIGINT;
BEGIN
  IF NOT EXISTS (SELECT 1 FROM public.guides WHERE name='Rajesh Kumar') THEN
    INSERT INTO public.guides (name, rating, price_per_day, phone_number) VALUES ('Rajesh Kumar',4.9,2000,'+91-9876543210') RETURNING id INTO raj_id;
  ELSE
    SELECT id INTO raj_id FROM public.guides WHERE name='Rajesh Kumar' LIMIT 1;
  END IF;

  IF NOT EXISTS (SELECT 1 FROM public.guides WHERE name='Priya Sharma') THEN
    INSERT INTO public.guides (name, rating, price_per_day, phone_number) VALUES ('Priya Sharma',4.7,1800,'+91-9123456780') RETURNING id INTO priya_id;
  ELSE
    SELECT id INTO priya_id FROM public.guides WHERE name='Priya Sharma' LIMIT 1;
  END IF;

  IF raj_id IS NOT NULL THEN
    IF NOT EXISTS (SELECT 1 FROM public.guide_languages WHERE guide_id = raj_id AND language = 'English') THEN
      INSERT INTO public.guide_languages (guide_id, language) VALUES (raj_id, 'English');
    END IF;
    IF NOT EXISTS (SELECT 1 FROM public.guide_languages WHERE guide_id = raj_id AND language = 'Hindi') THEN
      INSERT INTO public.guide_languages (guide_id, language) VALUES (raj_id, 'Hindi');
    END IF;
  END IF;

  IF priya_id IS NOT NULL THEN
    IF NOT EXISTS (SELECT 1 FROM public.guide_languages WHERE guide_id = priya_id AND language = 'English') THEN
      INSERT INTO public.guide_languages (guide_id, language) VALUES (priya_id, 'English');
    END IF;
    IF NOT EXISTS (SELECT 1 FROM public.guide_languages WHERE guide_id = priya_id AND language = 'Hindi') THEN
      INSERT INTO public.guide_languages (guide_id, language) VALUES (priya_id, 'Hindi');
    END IF;
    IF NOT EXISTS (SELECT 1 FROM public.guide_languages WHERE guide_id = priya_id AND language = 'Tamil') THEN
      INSERT INTO public.guide_languages (guide_id, language) VALUES (priya_id, 'Tamil');
    END IF;
  END IF;
END$$;

-- Trips seeds
DO $$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM public.trips WHERE title = 'Seed: Weekend in Lisbon') THEN
    INSERT INTO public.trips (user_id, title, total_days, budget_per_person) VALUES (NULL, 'Seed: Weekend in Lisbon', 2, 10000);
  END IF;
  IF NOT EXISTS (SELECT 1 FROM public.trips WHERE title = 'Seed: Mountain Hike') THEN
    INSERT INTO public.trips (user_id, title, total_days, budget_per_person) VALUES (NULL, 'Seed: Mountain Hike', 2, 8000);
  END IF;
END$$;

-- Bookings + relations seed (safe)
DO $$
DECLARE trip1 BIGINT;
DECLARE booking1 BIGINT;
DECLARE hid BIGINT;
DECLARE tid BIGINT;
DECLARE gid BIGINT;
BEGIN
  SELECT id INTO trip1 FROM public.trips WHERE title = 'Seed: Weekend in Lisbon' LIMIT 1;
  IF trip1 IS NULL THEN
    RAISE NOTICE 'No seed trip found; skipping booking seed';
    RETURN;
  END IF;

  IF NOT EXISTS (SELECT 1 FROM public.bookings WHERE trip_id = trip1 AND total_amount = 15000) THEN
    INSERT INTO public.bookings (trip_id, user_id, status, booked_at, total_amount) VALUES (trip1, NULL, 'pending', now(), 15000) RETURNING id INTO booking1;
  ELSE
    SELECT id INTO booking1 FROM public.bookings WHERE trip_id = trip1 AND total_amount = 15000 LIMIT 1;
  END IF;

  SELECT id INTO hid FROM public.hotels WHERE name = 'Luxury Beach Resort' LIMIT 1;
  IF hid IS NOT NULL AND NOT EXISTS (SELECT 1 FROM public.booking_hotels WHERE booking_id = booking1 AND hotel_id = hid) THEN
    INSERT INTO public.booking_hotels (booking_id, hotel_id, nights, price_per_night, total_price) VALUES (booking1, hid, 2, 5000, 10000);
  END IF;

  SELECT id INTO tid FROM public.transport_options WHERE name = 'AC Sedan' LIMIT 1;
  IF tid IS NOT NULL AND NOT EXISTS (SELECT 1 FROM public.booking_transport WHERE booking_id = booking1 AND transport_id = tid) THEN
    INSERT INTO public.booking_transport (booking_id, transport_id, days, price_per_day, total_price) VALUES (booking1, tid, 2, 2500, 5000);
  END IF;

  SELECT id INTO gid FROM public.guides WHERE name = 'Rajesh Kumar' LIMIT 1;
  IF gid IS NOT NULL AND NOT EXISTS (SELECT 1 FROM public.booking_guides WHERE booking_id = booking1 AND guide_id = gid) THEN
    INSERT INTO public.booking_guides (booking_id, guide_id, days, price_per_day, total_price) VALUES (booking1, gid, 2, 2000, 4000);
  END IF;
END$$;

-- ====================================================================
-- 5) INDEXES, TRIGGERS and GRANTS (non-destructive)
-- ====================================================================

CREATE INDEX IF NOT EXISTS idx_trip_cities_trip ON public.trip_cities (trip_id);
CREATE INDEX IF NOT EXISTS idx_itineraries_trip ON public.itineraries (trip_id);
CREATE INDEX IF NOT EXISTS idx_guides_language ON public.guide_languages (language);

GRANT SELECT ON TABLE
  public.hotels,
  public.transport_options,
  public.guides,
  public.cities,
  public.hotel_images,
  public.trips,
  public.trip_cities,
  public.itineraries,
  public.bookings,
  public.booking_hotels,
  public.booking_transport,
  public.booking_guides,
  public.booking_travelers
TO public;

COMMIT;

-- ====================================================================
-- END OF FINAL MIGRATION
-- ====================================================================
