/*******************************************************************************************
  🚀 TRAVEL PLANNER — COMPREHENSIVE SCHEMA & DATA MIGRATION
  - Fully idempotent, dependency-safe, Supabase-compatible
  - Normalized schema + integrity constraints + search optimization
  - Run this as OWNER in Supabase SQL Editor
*******************************************************************************************/


/* =========================================================================================
   SECTION 1: CORE ENTITIES
========================================================================================= */

-- USERS
CREATE TABLE IF NOT EXISTS public.users (
  id UUID PRIMARY KEY DEFAULT auth.uid(),
  email TEXT UNIQUE NOT NULL,
  name TEXT NOT NULL,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);


-- TRIPS
CREATE TABLE IF NOT EXISTS public.trips (
  id BIGSERIAL PRIMARY KEY,
  user_id UUID REFERENCES public.users(id) ON DELETE SET NULL,
  title TEXT NOT NULL DEFAULT 'Untitled Trip',
  -- description and state columns removed for normalized schema compatibility
  -- (use cities/trip_cities and search_vector instead)
  cities TEXT[], -- legacy array, retained for backward compatibility
  start_date DATE,
  end_date DATE,
  budget INTEGER CHECK (budget IS NULL OR budget >= 0),
  num_people INTEGER CHECK (num_people IS NULL OR num_people > 0),
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  last_modified TIMESTAMPTZ NOT NULL DEFAULT now(),
  search_vector TSVECTOR
);

CREATE INDEX IF NOT EXISTS idx_trips_search_vector ON public.trips USING gin (search_vector);



/* =========================================================================================
   SECTION 2: LOCATION & NORMALIZATION
========================================================================================= */

-- CITIES
CREATE TABLE IF NOT EXISTS public.cities (
  id BIGSERIAL PRIMARY KEY,
  name TEXT NOT NULL,
  state_name TEXT,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  UNIQUE (name, state_name)
);

-- TRIP-CITIES (Mapping)
CREATE TABLE IF NOT EXISTS public.trip_cities (
  trip_id BIGINT NOT NULL REFERENCES public.trips(id) ON DELETE CASCADE,
  city_id BIGINT NOT NULL REFERENCES public.cities(id) ON DELETE CASCADE,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  PRIMARY KEY (trip_id, city_id)
);



/* =========================================================================================
   SECTION 3: ITINERARY & SUPPORT TABLES
========================================================================================= */

CREATE TABLE IF NOT EXISTS public.itineraries (
  id BIGSERIAL PRIMARY KEY,
  trip_id BIGINT NOT NULL REFERENCES public.trips(id) ON DELETE CASCADE,
  day INT NOT NULL CHECK (day > 0),
  activities TEXT,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  UNIQUE (trip_id, day)
);



/* =========================================================================================
   SECTION 4: SERVICE PROVIDERS (Hotels, Transport, Guides)
========================================================================================= */

-- HOTELS
CREATE TABLE IF NOT EXISTS public.hotels (
  id BIGSERIAL PRIMARY KEY,
  name TEXT NOT NULL DEFAULT 'Unknown Hotel',
  city_id BIGINT REFERENCES public.cities(id) ON DELETE SET NULL,
  state TEXT,
  rating NUMERIC(2,1) NOT NULL DEFAULT 0 CHECK (rating >= 0 AND rating <= 5),
  price_per_night INTEGER NOT NULL DEFAULT 0 CHECK (price_per_night >= 0),
  image_url TEXT,
  description TEXT,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);
CREATE INDEX IF NOT EXISTS idx_hotels_city_id ON public.hotels (city_id);


-- TRANSPORT OPTIONS
CREATE TABLE IF NOT EXISTS public.transport_options (
  id BIGSERIAL PRIMARY KEY,
  type TEXT,
  name TEXT NOT NULL DEFAULT 'Unknown Transport',
  capacity INT CHECK (capacity IS NULL OR capacity >= 0),
  price_per_day INTEGER NOT NULL DEFAULT 0 CHECK (price_per_day >= 0),
  notes TEXT,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);


-- GUIDES
CREATE TABLE IF NOT EXISTS public.guides (
  id BIGSERIAL PRIMARY KEY,
  name TEXT NOT NULL DEFAULT 'Unknown Guide',
  languages TEXT[] NOT NULL DEFAULT '{}',
  rating NUMERIC(2,1) NOT NULL DEFAULT 0 CHECK (rating >= 0 AND rating <= 5),
  price_per_day INTEGER NOT NULL DEFAULT 0 CHECK (price_per_day >= 0),
  contact JSONB,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);
-- Create index on guides.languages only if the column exists (some schemas may not have it)
DO $$
BEGIN
  IF EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_schema = 'public' AND table_name = 'guides' AND column_name = 'languages'
  ) THEN
    EXECUTE 'CREATE INDEX IF NOT EXISTS idx_guides_languages ON public.guides USING gin (languages)';
  END IF;
END$$;



/* =========================================================================================
   SECTION 5: BOOKINGS + DETAIL TABLES
========================================================================================= */

-- BOOKINGS
CREATE TABLE IF NOT EXISTS public.bookings (
  id BIGSERIAL PRIMARY KEY,
  trip_id BIGINT NOT NULL REFERENCES public.trips(id) ON DELETE CASCADE,
  user_id UUID REFERENCES public.users(id) ON DELETE SET NULL,
  status TEXT NOT NULL DEFAULT 'draft' CHECK (status IN ('draft', 'confirmed', 'cancelled')),
  booked_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  selections JSONB,
  total_amount INTEGER NOT NULL DEFAULT 0 CHECK (total_amount >= 0),
  payment_id TEXT,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);
CREATE INDEX IF NOT EXISTS idx_bookings_user ON public.bookings (user_id);
CREATE INDEX IF NOT EXISTS idx_bookings_trip ON public.bookings (trip_id);


-- BOOKING TRAVELERS
CREATE TABLE IF NOT EXISTS public.booking_travelers (
  id BIGSERIAL PRIMARY KEY,
  booking_id BIGINT NOT NULL REFERENCES public.bookings(id) ON DELETE CASCADE,
  traveler_name TEXT NOT NULL,
  traveler_age INT CHECK (traveler_age >= 0),
  created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);


-- BOOKING HOTELS
CREATE TABLE IF NOT EXISTS public.booking_hotels (
  id BIGSERIAL PRIMARY KEY,
  booking_id BIGINT NOT NULL REFERENCES public.bookings(id) ON DELETE CASCADE,
  hotel_id BIGINT NOT NULL REFERENCES public.hotels(id) ON DELETE RESTRICT,
  nights INT NOT NULL CHECK (nights > 0),
  price_per_night INTEGER NOT NULL CHECK (price_per_night >= 0),
  total_price INTEGER NOT NULL CHECK (total_price >= 0),
  created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);
CREATE INDEX IF NOT EXISTS idx_booking_hotels_booking ON public.booking_hotels (booking_id);


-- BOOKING TRANSPORTS
CREATE TABLE IF NOT EXISTS public.booking_transports (
  id BIGSERIAL PRIMARY KEY,
  booking_id BIGINT NOT NULL REFERENCES public.bookings(id) ON DELETE CASCADE,
  transport_id BIGINT NOT NULL REFERENCES public.transport_options(id) ON DELETE RESTRICT,
  days INT NOT NULL CHECK (days > 0),
  price_per_day INTEGER NOT NULL CHECK (price_per_day >= 0),
  total_price INTEGER NOT NULL CHECK (total_price >= 0),
  created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);
CREATE INDEX IF NOT EXISTS idx_booking_transports_booking ON public.booking_transports (booking_id);


-- BOOKING GUIDES
CREATE TABLE IF NOT EXISTS public.booking_guides (
  id BIGSERIAL PRIMARY KEY,
  booking_id BIGINT NOT NULL REFERENCES public.bookings(id) ON DELETE CASCADE,
  guide_id BIGINT NOT NULL REFERENCES public.guides(id) ON DELETE RESTRICT,
  days INT NOT NULL CHECK (days > 0),
  price_per_day INTEGER NOT NULL CHECK (price_per_day >= 0),
  total_price INTEGER NOT NULL CHECK (total_price >= 0),
  created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);
CREATE INDEX IF NOT EXISTS idx_booking_guides_booking ON public.booking_guides (booking_id);



/* =========================================================================================
   SECTION 6: MIGRATIONS & FIXES
========================================================================================= */

-- Populate search_vector (safe backfill)
ALTER TABLE IF EXISTS public.trips DISABLE TRIGGER USER;
DO $$
BEGIN
  -- If the trips table has a description column, include it in the backfill;
  -- otherwise fall back to using title + cities (legacy array) so the script is safe
  IF EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_schema = 'public' AND table_name = 'trips' AND column_name = 'description'
  ) THEN
    UPDATE public.trips
    SET search_vector = to_tsvector('english', coalesce(title,'') || ' ' || coalesce(description,''))
    WHERE search_vector IS NULL;
  ELSE
    UPDATE public.trips
    SET search_vector = to_tsvector('english', coalesce(title,'') || ' ' || coalesce(array_to_string(cities, ' '), ''))
    WHERE search_vector IS NULL;
  END IF;
END$$;
ALTER TABLE IF EXISTS public.trips ENABLE TRIGGER USER;


-- Normalize legacy city data
DO $$
DECLARE
  has_cities boolean;
  has_state boolean;
  has_state_name boolean;
  state_col text;
BEGIN
  SELECT EXISTS(
    SELECT 1 FROM information_schema.columns
    WHERE table_schema = 'public' AND table_name = 'trips' AND column_name = 'cities'
  ) INTO has_cities;

  SELECT EXISTS(
    SELECT 1 FROM information_schema.columns
    WHERE table_schema = 'public' AND table_name = 'trips' AND column_name = 'state'
  ) INTO has_state;

  SELECT EXISTS(
    SELECT 1 FROM information_schema.columns
    WHERE table_schema = 'public' AND table_name = 'trips' AND column_name = 'state_name'
  ) INTO has_state_name;

  IF NOT has_cities THEN
    RETURN;
  END IF;

  -- Prefer 'state' column if present, else 'state_name', else NULL (use empty string)
  IF has_state THEN
    state_col := 'state';
  ELSIF has_state_name THEN
    state_col := 'state_name';
  ELSE
    state_col := NULL;
  END IF;

  IF state_col IS NOT NULL THEN
    -- Use compact single-line SQL for EXECUTE to avoid escaped backslashes
  EXECUTE format('INSERT INTO public.cities (name, state_name) SELECT DISTINCT unnest(cities) AS name, COALESCE(%I::text, '''') FROM public.trips WHERE cities IS NOT NULL ON CONFLICT (name, state_name) DO NOTHING', state_col);

  EXECUTE format('INSERT INTO public.trip_cities (trip_id, city_id) SELECT t.id, c.id FROM public.trips t CROSS JOIN LATERAL unnest(t.cities) AS cname(name) JOIN public.cities c ON c.name = cname.name AND c.state_name = COALESCE(t.%I::text, '''') ON CONFLICT DO NOTHING', state_col);
  ELSE
    -- No state column available; migrate cities with empty state (single-line exec)
  EXECUTE 'INSERT INTO public.cities (name, state_name) SELECT DISTINCT unnest(cities) AS name, '''' FROM public.trips WHERE cities IS NOT NULL ON CONFLICT (name, state_name) DO NOTHING';

  EXECUTE 'INSERT INTO public.trip_cities (trip_id, city_id) SELECT t.id, c.id FROM public.trips t CROSS JOIN LATERAL unnest(t.cities) AS cname(name) JOIN public.cities c ON c.name = cname.name AND c.state_name = '''' ON CONFLICT DO NOTHING';
  END IF;
END$$;



/* =========================================================================================
   SECTION 7: SANITY FIXES & DEFAULT ALIGNMENTS
========================================================================================= */

DO $$
BEGIN
  UPDATE public.trips SET title = 'Untitled Trip' WHERE title IS NULL;
  UPDATE public.bookings SET status = 'draft' WHERE status IS NULL;
  UPDATE public.bookings SET total_amount = 0 WHERE total_amount IS NULL;
  UPDATE public.hotels SET name = 'Unknown Hotel' WHERE name IS NULL;
  UPDATE public.guides SET name = 'Unknown Guide' WHERE name IS NULL;
  UPDATE public.transport_options SET name = 'Unknown Transport' WHERE name IS NULL;
END$$;

VACUUM ANALYZE public.trips;


/*******************************************************************************************
  ✅ SCHEMA MIGRATION COMPLETE
  Notes:
  - Fully idempotent (safe to rerun)
  - All foreign keys & constraints enforced
  - Ready for Supabase sync and API integration
*******************************************************************************************/
