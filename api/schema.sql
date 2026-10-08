CREATE TABLE IF NOT EXISTS app_state (
  id integer PRIMARY KEY CHECK (id = 1),
  revision bigint NOT NULL DEFAULT 0,
  next_ids jsonb NOT NULL DEFAULT '{}',
  auth_settings jsonb
);
INSERT INTO app_state(id) VALUES (1) ON CONFLICT DO NOTHING;

CREATE TABLE IF NOT EXISTS clients (
  id bigint PRIMARY KEY,
  payload jsonb NOT NULL,
  email text GENERATED ALWAYS AS (lower(payload->>'email')) STORED UNIQUE NOT NULL
);
CREATE TABLE IF NOT EXISTS employees (
  id bigint PRIMARY KEY,
  payload jsonb NOT NULL,
  email text GENERATED ALWAYS AS (lower(payload->>'email')) STORED UNIQUE NOT NULL
);
CREATE TABLE IF NOT EXISTS services (
  id bigint PRIMARY KEY,
  payload jsonb NOT NULL,
  price integer GENERATED ALWAYS AS ((payload->>'price')::integer) STORED NOT NULL CHECK (price BETWEEN 1 AND 1000000)
);
CREATE TABLE IF NOT EXISTS scenarios (
  id bigint PRIMARY KEY,
  payload jsonb NOT NULL,
  service_id bigint GENERATED ALWAYS AS ((payload->>'serviceId')::bigint) STORED NOT NULL REFERENCES services(id) DEFERRABLE INITIALLY DEFERRED
);
CREATE TABLE IF NOT EXISTS requests (
  id bigint PRIMARY KEY,
  payload jsonb NOT NULL,
  code text GENERATED ALWAYS AS (payload->>'code') STORED UNIQUE NOT NULL,
  client_id bigint GENERATED ALWAYS AS ((payload->>'clientId')::bigint) STORED NOT NULL REFERENCES clients(id) DEFERRABLE INITIALLY DEFERRED,
  service_id bigint GENERATED ALWAYS AS ((payload->>'serviceId')::bigint) STORED NOT NULL REFERENCES services(id) DEFERRABLE INITIALLY DEFERRED
);
CREATE TABLE IF NOT EXISTS cards (
  id bigint PRIMARY KEY,
  payload jsonb NOT NULL,
  number text GENERATED ALWAYS AS (payload->>'number') STORED UNIQUE NOT NULL,
  client_id bigint GENERATED ALWAYS AS ((payload->>'clientId')::bigint) STORED UNIQUE NOT NULL REFERENCES clients(id) ON DELETE CASCADE DEFERRABLE INITIALLY DEFERRED,
  points integer GENERATED ALWAYS AS ((payload->>'points')::integer) STORED NOT NULL CHECK (points BETWEEN 0 AND 100000)
);
CREATE TABLE IF NOT EXISTS contracts (
  id bigint PRIMARY KEY,
  payload jsonb NOT NULL,
  code text GENERATED ALWAYS AS (payload->>'code') STORED UNIQUE NOT NULL,
  request_id bigint GENERATED ALWAYS AS ((payload->>'requestId')::bigint) STORED NOT NULL REFERENCES requests(id) DEFERRABLE INITIALLY DEFERRED,
  amount integer GENERATED ALWAYS AS ((payload->>'amount')::integer) STORED NOT NULL CHECK (amount > 0)
);
CREATE TABLE IF NOT EXISTS payments (
  id bigint PRIMARY KEY,
  payload jsonb NOT NULL,
  contract_id bigint GENERATED ALWAYS AS ((payload->>'contractId')::bigint) STORED NOT NULL REFERENCES contracts(id) DEFERRABLE INITIALLY DEFERRED,
  amount integer GENERATED ALWAYS AS ((payload->>'amount')::integer) STORED NOT NULL CHECK (amount BETWEEN 1 AND 10000000)
);
CREATE TABLE IF NOT EXISTS request_employees (
  request_id bigint REFERENCES requests(id) ON DELETE CASCADE DEFERRABLE INITIALLY DEFERRED,
  employee_id bigint REFERENCES employees(id) DEFERRABLE INITIALLY DEFERRED,
  PRIMARY KEY (request_id, employee_id)
);
CREATE TABLE IF NOT EXISTS request_scenarios (
  request_id bigint REFERENCES requests(id) ON DELETE CASCADE DEFERRABLE INITIALLY DEFERRED,
  scenario_id bigint REFERENCES scenarios(id) DEFERRABLE INITIALLY DEFERRED,
  PRIMARY KEY (request_id, scenario_id)
);
CREATE TABLE IF NOT EXISTS users (
  id bigint PRIMARY KEY,
  payload jsonb NOT NULL,
  username text GENERATED ALWAYS AS (lower(payload->>'username')) STORED UNIQUE NOT NULL,
  client_id bigint GENERATED ALWAYS AS ((payload->>'clientId')::bigint) STORED REFERENCES clients(id) DEFERRABLE INITIALLY DEFERRED,
  role text GENERATED ALWAYS AS (payload->>'role') STORED NOT NULL CHECK (role IN ('client', 'employee', 'admin'))
);
CREATE TABLE IF NOT EXISTS sessions (
  id uuid PRIMARY KEY,
  payload jsonb NOT NULL,
  user_id bigint GENERATED ALWAYS AS ((payload->>'userId')::bigint) STORED NOT NULL REFERENCES users(id) ON DELETE CASCADE DEFERRABLE INITIALLY DEFERRED
);
CREATE INDEX IF NOT EXISTS requests_client_idx ON requests(client_id);
CREATE INDEX IF NOT EXISTS contracts_request_idx ON contracts(request_id);
CREATE INDEX IF NOT EXISTS payments_contract_idx ON payments(contract_id);
