ALTER DATABASE lab_netmicro_payments OWNER TO lab_user;
ALTER DATABASE lab_netmicro_jobs OWNER TO lab_user;
ALTER DATABASE lab_netmicro_policy OWNER TO lab_user;
ALTER DATABASE lab_netmicro_pricing OWNER TO lab_user;
\connect lab_netmicro_payments
GRANT USAGE, CREATE ON SCHEMA public TO lab_user;
\connect lab_netmicro_jobs
GRANT USAGE, CREATE ON SCHEMA public TO lab_user;
\connect lab_netmicro_policy
GRANT USAGE, CREATE ON SCHEMA public TO lab_user;
\connect lab_netmicro_pricing
GRANT USAGE, CREATE ON SCHEMA public TO lab_user;
