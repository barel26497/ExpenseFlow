-- ExpenseFlow DB bootstrap (idempotent)
-- Safe for repeated runs.
-- NOTE: We DO NOT auto-fix type mismatches here. If you need strict type verification, we can add it.

BEGIN;

-- 1) Extensions
CREATE EXTENSION IF NOT EXISTS pgcrypto WITH SCHEMA public;

-- 2) Tables (create if missing)

CREATE TABLE IF NOT EXISTS public.users (
  id uuid DEFAULT gen_random_uuid() NOT NULL,
  email text NOT NULL,
  name text NOT NULL,
  role text NOT NULL,
  token text NOT NULL,
  active boolean DEFAULT true NOT NULL,
  created_at timestamp with time zone DEFAULT now() NOT NULL,
  supervisor_email text,
  password_hash text,
  token_expires_at timestamp with time zone
);

CREATE TABLE IF NOT EXISTS public.employees (
  employee_email text NOT NULL,
  supervisor_email text,
  created_at timestamp with time zone DEFAULT now() NOT NULL
);

CREATE TABLE IF NOT EXISTS public.claims (
  claim_id uuid DEFAULT gen_random_uuid() NOT NULL,
  submitted_at timestamp with time zone DEFAULT now() NOT NULL,
  employee_email text NOT NULL,
  employee_name text NOT NULL,
  category text NOT NULL,
  amount numeric(12,2) NOT NULL,
  currency text DEFAULT 'ILS'::text NOT NULL,
  merchant text,
  description text,
  receipt_url text,
  status text DEFAULT 'PENDING'::text NOT NULL,
  route text DEFAULT 'EMPLOYEE'::text NOT NULL,
  approver_email text,
  approved_at timestamp with time zone,
  decision_notes text
);

-- 3) Columns (add if missing) - future proofing

ALTER TABLE public.users
  ADD COLUMN IF NOT EXISTS supervisor_email text,
  ADD COLUMN IF NOT EXISTS password_hash text,
  ADD COLUMN IF NOT EXISTS token_expires_at timestamp with time zone;

ALTER TABLE public.employees
  ADD COLUMN IF NOT EXISTS supervisor_email text,
  ADD COLUMN IF NOT EXISTS created_at timestamp with time zone;

ALTER TABLE public.claims
  ADD COLUMN IF NOT EXISTS approved_at timestamp with time zone,
  ADD COLUMN IF NOT EXISTS decision_notes text;

-- 4) Constraints

DO $$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'users_pkey') THEN
    ALTER TABLE ONLY public.users ADD CONSTRAINT users_pkey PRIMARY KEY (id);
  END IF;

  IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'users_email_key') THEN
    ALTER TABLE ONLY public.users ADD CONSTRAINT users_email_key UNIQUE (email);
  END IF;

  IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'users_token_key') THEN
    ALTER TABLE ONLY public.users ADD CONSTRAINT users_token_key UNIQUE (token);
  END IF;

  IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'users_role_check') THEN
    ALTER TABLE ONLY public.users
      ADD CONSTRAINT users_role_check
      CHECK (role = ANY (ARRAY['ADMIN'::text,'SUPERVISOR'::text,'EMPLOYEE'::text]));
  END IF;
END $$;

DO $$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'employees_pkey') THEN
    ALTER TABLE ONLY public.employees ADD CONSTRAINT employees_pkey PRIMARY KEY (employee_email);
  END IF;
END $$;

DO $$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'claims_pkey') THEN
    ALTER TABLE ONLY public.claims ADD CONSTRAINT claims_pkey PRIMARY KEY (claim_id);
  END IF;

  IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'claims_amount_check') THEN
    ALTER TABLE ONLY public.claims
      ADD CONSTRAINT claims_amount_check CHECK (amount >= (0)::numeric);
  END IF;

  IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'claims_status_check') THEN
    ALTER TABLE ONLY public.claims
      ADD CONSTRAINT claims_status_check
      CHECK (status = ANY (ARRAY['PENDING'::text,'APPROVED'::text,'REJECTED'::text]));
  END IF;
END $$;

-- Foreign keys
DO $$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'fk_users_supervisor') THEN
    ALTER TABLE ONLY public.users
      ADD CONSTRAINT fk_users_supervisor
      FOREIGN KEY (supervisor_email) REFERENCES public.users(email) ON DELETE SET NULL;
  END IF;

  IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'fk_employees_employee') THEN
    ALTER TABLE ONLY public.employees
      ADD CONSTRAINT fk_employees_employee
      FOREIGN KEY (employee_email) REFERENCES public.users(email) ON DELETE CASCADE;
  END IF;

  IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'fk_employees_supervisor') THEN
    ALTER TABLE ONLY public.employees
      ADD CONSTRAINT fk_employees_supervisor
      FOREIGN KEY (supervisor_email) REFERENCES public.users(email) ON DELETE SET NULL;
  END IF;

  IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'fk_claims_employee') THEN
    ALTER TABLE ONLY public.claims
      ADD CONSTRAINT fk_claims_employee
      FOREIGN KEY (employee_email) REFERENCES public.users(email) ON DELETE RESTRICT;
  END IF;

  IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'fk_claims_approver') THEN
    ALTER TABLE ONLY public.claims
      ADD CONSTRAINT fk_claims_approver
      FOREIGN KEY (approver_email) REFERENCES public.users(email) ON DELETE SET NULL;
  END IF;
END $$;

-- 5) Indexes

CREATE INDEX IF NOT EXISTS idx_users_role ON public.users USING btree (role);
CREATE INDEX IF NOT EXISTS idx_users_token_active ON public.users USING btree (token, active);

CREATE INDEX IF NOT EXISTS idx_employees_supervisor_email ON public.employees USING btree (supervisor_email);

CREATE INDEX IF NOT EXISTS idx_claims_approver ON public.claims USING btree (approver_email);
CREATE INDEX IF NOT EXISTS idx_claims_employee_submitted ON public.claims USING btree (employee_email, submitted_at DESC);
CREATE INDEX IF NOT EXISTS idx_claims_status_submitted ON public.claims USING btree (status, submitted_at DESC);

-- 6) Default admin user (idempotent)
-- email: admin@local
-- password: Admin123!
-- role: ADMIN

DO $$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM public.users WHERE email = 'admin@local') THEN
    INSERT INTO public.users (
      id,
      email,
      name,
      role,
      token,
      active,
      created_at,
      password_hash
    )
    VALUES (
      gen_random_uuid(),
      'admin@local',
      'Administrator',
      'ADMIN',
      encode(gen_random_bytes(32), 'hex'),
      true,
      now(),
      crypt('Admin123!', gen_salt('bf'))
    );

    RAISE NOTICE 'Default admin user created: admin@local';
  ELSE
    RAISE NOTICE 'Default admin already exists: admin@local';
  END IF;
END $$;

COMMIT;
