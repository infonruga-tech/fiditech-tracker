-- ============================================
-- FIDITECH SALES TRACKER — Supabase Setup SQL
-- Esegui questo nel SQL Editor di Supabase
-- ============================================

-- 1. TABELLA UTENTI/AGENTI
create table if not exists agenti_tracker (
  id uuid primary key default gen_random_uuid(),
  email text unique not null,
  nome text not null,
  ruolo text not null default 'agente', -- 'direttore' o 'agente'
  zona text,
  avatar text, -- iniziali es. "NR"
  attivo boolean default true,
  created_at timestamptz default now()
);

-- 2. TABELLA TRATTATIVE
create table if not exists trattative (
  id uuid primary key default gen_random_uuid(),
  agente_id uuid references agenti_tracker(id) on delete cascade not null,
  client_name text not null,
  prodotto text not null, -- 'fv','en','led','tlc','fid'
  valore_stimato integer default 0,
  stage integer default 0, -- 0=Contatto, 1=Sopralluogo, 2=Offerta, 3=Trattativa, 4=Vinta, -1=Persa
  probabilita text default 'med', -- 'low','med','high'
  zona_cliente text,
  note text,
  next_followup date,
  created_at timestamptz default now(),
  updated_at timestamptz default now()
);

-- 3. TABELLA LOG ATTIVITÀ
create table if not exists log_attivita (
  id uuid primary key default gen_random_uuid(),
  agente_id uuid references agenti_tracker(id) on delete cascade not null,
  trattativa_id uuid references trattative(id) on delete set null,
  tipo text not null,
  nota text,
  created_at timestamptz default now()
);

-- 4. TABELLA SESSIONI (login semplice senza Supabase Auth)
create table if not exists sessioni_tracker (
  id uuid primary key default gen_random_uuid(),
  agente_id uuid references agenti_tracker(id) on delete cascade not null,
  token text unique not null default gen_random_uuid()::text,
  created_at timestamptz default now(),
  expires_at timestamptz default (now() + interval '7 days')
);

-- ============================================
-- ROW LEVEL SECURITY
-- ============================================

alter table agenti_tracker enable row level security;
alter table trattative enable row level security;
alter table log_attivita enable row level security;
alter table sessioni_tracker enable row level security;

-- Per ora usiamo service_role key lato server (il JS fa le query come service)
-- Le policy permettono tutto dalla service key, niente dalla anon key
create policy "service only agenti" on agenti_tracker using (true) with check (true);
create policy "service only trattative" on trattative using (true) with check (true);
create policy "service only log" on log_attivita using (true) with check (true);
create policy "service only sessioni" on sessioni_tracker using (true) with check (true);

-- ============================================
-- DATI INIZIALI — Team Fiditech
-- ============================================

insert into agenti_tracker (email, nome, ruolo, zona, avatar) values
  ('nicola.ruga@fiditech.it',    'Nicola Ruga',       'direttore', 'Torino',      'NR'),
  ('roberto.etoli@fiditech.it',  'Roberto Etoli',     'agente',    'Piacenza',    'RE'),
  ('giovanni.grammaldo@fiditech.it', 'Giovanni Grammaldo', 'agente', 'Gaeta (LT)', 'GG'),
  ('roberto.denatale@fiditech.it', 'Roberto De Natale', 'agente',  'Da definire', 'RD')
on conflict (email) do nothing;

-- ============================================
-- FUNZIONE updated_at automatico
-- ============================================
create or replace function set_updated_at()
returns trigger as $$
begin new.updated_at = now(); return new; end;
$$ language plpgsql;

create trigger trattative_updated_at
  before update on trattative
  for each row execute function set_updated_at();
