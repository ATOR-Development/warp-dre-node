CREATE ROLE warp WITH LOGIN password 'warp_password';
GRANT warp TO postgres;
CREATE SCHEMA IF NOT EXISTS AUTHORIZATION warp;
ALTER ROLE warp SET search_path TO warp;

CREATE ROLE dre WITH LOGIN password 'dre_password';
GRANT dre TO postgres;
CREATE SCHEMA IF NOT EXISTS AUTHORIZATION dre;
ALTER ROLE dre SET search_path TO dre;

GRANT CONNECT ON DATABASE "postgres" TO dre;
GRANT CONNECT ON DATABASE "postgres" TO warp;
GRANT CREATE ON DATABASE "postgres" TO warp;
GRANT CREATE ON DATABASE "postgres" TO dre;

GRANT ALL PRIVILEGES ON ALL TABLES IN SCHEMA dre TO dre;
GRANT ALL PRIVILEGES ON ALL SEQUENCES IN SCHEMA dre TO dre;
GRANT ALL PRIVILEGES ON ALL TABLES IN SCHEMA warp TO warp;
GRANT ALL PRIVILEGES ON ALL SEQUENCES IN SCHEMA warp TO warp;

GRANT USAGE ON SCHEMA warp to dre;
GRANT USAGE ON SCHEMA warp to postgres;
GRANT USAGE ON SCHEMA dre to postgres;
ALTER DEFAULT PRIVILEGES FOR USER warp IN SCHEMA warp GRANT SELECT ON TABLES TO dre;
ALTER DEFAULT PRIVILEGES FOR USER warp IN SCHEMA warp GRANT SELECT ON TABLES TO postgres;
ALTER DEFAULT PRIVILEGES FOR USER dre IN SCHEMA dre GRANT SELECT ON TABLES TO postgres;
