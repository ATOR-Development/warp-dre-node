job "dre-node-stage" {
  datacenters = ["ator-fin"]
  type = "service"

  group "dre-stage-group" {
    
    count = 1

    volume "psql-dre-stage" {
      type = "host"
      read_only = false
      source = "psql-dre-stage"
    }

    volume "redis-dre-stage" {
      type = "host"
      read_only = false
      source = "redis-dre-stage"
    }

    network {
      mode = "bridge"
      port "psql-dre" {
        host_network = "wireguard"
      }
      port "redisdre" {
        host_network = "wireguard"
      }
      port "dre-node" {
        to = 8080
        host_network = "wireguard"
      }
    }

    task "psql-dre-stage-task" {
        driver = "docker"
        config {
            image = "postgres:16-alpine"
            network_mode = "host"
            volumes = [
              "secrets/pgRolesAndSchemasSetup.sql:/docker-entrypoint-initdb.d/pgRolesAndSchemasSetup.sql",
            ]
        }

        lifecycle {
          sidecar = true
          hook = "prestart"
        }

        vault {
            policies = ["dre-node-stage"]
        }

        template {
            data = <<EOH
            {{with secret "kv/dre-node/stage"}}
                POSTGRES_USER="{{.Data.data.POSTGRES_USER}}"
                POSTGRES_PASSWORD="{{.Data.data.POSTGRES_PASSWORD}}"
            {{end}}
            EOH
            destination = "secrets/file.env"
            env         = true
        }

        template {
            data = <<EOH
            {{with secret "kv/dre-node/stage"}}
                CREATE ROLE warp WITH LOGIN password '{{.Data.data.PSQL_WARP_PASSWORD}}';
                GRANT warp TO {{.Data.data.POSTGRES_USER}};
                CREATE SCHEMA IF NOT EXISTS AUTHORIZATION warp;
                ALTER ROLE warp SET search_path TO warp;

                CREATE ROLE dre WITH LOGIN password '{{.Data.data.PSQL_DRE_PASSWORD}}';
                GRANT dre TO {{.Data.data.POSTGRES_USER}};
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
                GRANT USAGE ON SCHEMA warp to {{.Data.data.POSTGRES_USER}};
                GRANT USAGE ON SCHEMA dre to {{.Data.data.POSTGRES_USER}};
                ALTER DEFAULT PRIVILEGES FOR USER warp IN SCHEMA warp GRANT SELECT ON TABLES TO dre;
                ALTER DEFAULT PRIVILEGES FOR USER warp IN SCHEMA warp GRANT SELECT ON TABLES TO {{.Data.data.POSTGRES_USER}};
                ALTER DEFAULT PRIVILEGES FOR USER dre IN SCHEMA dre GRANT SELECT ON TABLES TO {{.Data.data.POSTGRES_USER}};
            {{end}}
            EOH
            destination = "secrets/pgRolesAndSchemasSetup.sql"
        }

        env {
            POSTGRES_DB="postgres"
            PGDATA="/pgdata"
            PGPORT="${NOMAD_PORT_psql-dre}"
        }
        logs {
            max_files     = 5
            max_file_size = 15
        }
        volume_mount {
            volume = "psql-dre-stage"
            destination = "/pgdata"
            read_only = false
        }
        resources {
            cpu = 2048
            memory = 4096
        }
        service {
            name = "psql-dre-stage"
            port = "psql-dre"
            check {
                name     = "Postgres alive"
                type     = "tcp"
                interval = "10s"
                timeout  = "2s"
                check_restart {
                    limit = 10
                    grace = "15s"
                }
            }
        }
    }

    task "redis-dre-stage-task" {
      driver = "docker"
      config {
        image = "redis:7.2"
        args = ["/usr/local/etc/redis/redis.conf"]
        volumes = [
          "local/redis.conf:/usr/local/etc/redis/redis.conf"
        ]
      }

      lifecycle {
        sidecar = true
        hook = "prestart"
      }

      template {
        data = <<EOH
# Based on https://raw.githubusercontent.com/redis/redis/7.2/redis.conf
bind 0.0.0.0
port {{ env "NOMAD_PORT_redisdre" }}
protected-mode yes
tcp-backlog 511
timeout 0
tcp-keepalive 300
daemonize no
pidfile /tmp/redis_6379.pid
loglevel notice
logfile ""
databases 16
always-show-logo no
set-proc-title yes
proc-title-template "{title} {listen-addr} {server-mode}"
locale-collate ""
stop-writes-on-bgsave-error yes
rdbcompression yes
rdbchecksum yes
dbfilename dump.rdb
rdb-del-sync-files no
dir ./
replica-serve-stale-data yes
replica-read-only yes
repl-diskless-sync yes
repl-diskless-sync-delay 5
repl-diskless-sync-max-replicas 0
repl-diskless-load disabled
repl-disable-tcp-nodelay no
replica-priority 100
acllog-max-len 128
lazyfree-lazy-eviction no
lazyfree-lazy-expire no
lazyfree-lazy-server-del no
replica-lazy-flush no
lazyfree-lazy-user-del no
lazyfree-lazy-user-flush no
oom-score-adj no
oom-score-adj-values 0 200 800
disable-thp yes
appendonly yes
appendfilename "appendonly.aof"
appenddirname "appendonlydir"
appendfsync everysec
no-appendfsync-on-rewrite no
auto-aof-rewrite-percentage 100
auto-aof-rewrite-min-size 64mb
aof-load-truncated yes
aof-use-rdb-preamble yes
aof-timestamp-enabled no
slowlog-log-slower-than 10000
slowlog-max-len 128
latency-monitor-threshold 0
notify-keyspace-events ""
hash-max-listpack-entries 512
hash-max-listpack-value 64
list-max-listpack-size -2
list-compress-depth 0
set-max-intset-entries 512
set-max-listpack-entries 128
set-max-listpack-value 64
zset-max-listpack-entries 128
zset-max-listpack-value 64
hll-sparse-max-bytes 3000
stream-node-max-bytes 4096
stream-node-max-entries 100
activerehashing yes
client-output-buffer-limit normal 0 0 0
client-output-buffer-limit replica 256mb 64mb 60
client-output-buffer-limit pubsub 32mb 8mb 60
hz 10
dynamic-hz yes
aof-rewrite-incremental-fsync yes
rdb-save-incremental-fsync yes
jemalloc-bg-thread yes
        EOH
        destination = "local/redis.conf"
        env         = false
      }

      volume_mount {
        volume = "redis-dre-stage"
        destination = "/data"
        read_only = false
      }

      resources {
        cpu    = 4096
        memory = 4096
      }

      service {
        name = "redis-dre-stage"
        port = "redisdre"
        
        check {
          name     = "Redis health check"
          type     = "tcp"
          interval = "5s"
          timeout  = "10s"
        }
      }
    }

    task "dre-node-stage-task" {
      driver = "docker"
      config {
        image = "ghcr.io/ator-development/warp-dre-node:[[.deploy]]"
        force_pull = true
      }

      vault {
        policies = ["dre-node-stage"]
      }

      template {
        data = <<EOH
        {{with secret "kv/dre-node/stage"}}
            NODE_JWK_KEY_BASE64="{{.Data.data.NODE_JWK_KEY_BASE64}}"
            PG_USER_WARP_PASSWORD="{{.Data.data.PSQL_WARP_PASSWORD}}"
            PG_USER_DRE_PASSWORD="{{.Data.data.PSQL_DRE_PASSWORD}}"
        {{end}}
        EVALUATION_WHITELIST_SOURCES="['[[ consulKey "smart-contracts/stage/relay-registry-address" ]]','[[ consulKey "smart-contracts/stage/distribution-address" ]]']"
        EOH
        destination = "secrets/file.env"
        env         = true
      }

      env {
        ENV=prod
        WARP_GW_URL="https://gw.warp.cc"

        PG_HOST="localhost"
        PG_DATABASE="postgres"
        PG_USER_WARP="warp"
        PG_USER_DRE="dre"

        PG_PORT="${NOMAD_PORT_psql-dre}"
        PG_SSL="false"

        FIRST_INTERACTION_TIMESTAMP=1685570400000
        REDIS_PUBLISH_STATE=false
        APPSYNC_PUBLISH_STATE=false
        APPSYNC_KEY=""

        UPDATE_MODE="subscription"

        GW_PORT=6379
        GW_HOST="dre-redis-read.warp.cc"
        GW_USERNAME="contracts"
        GW_PASSWORD=""
        GW_TLS=true
        GW_ENABLE_OFFLINE_QUEUE=true
        GW_LAZY_CONNECT=true
        GW_TLS_CA_CERT="-----BEGIN CERTIFICATE-----MIIDETCCAfmgAwIBAgIQHXVHBz5eF6OFL5LG9vGB1zANBgkqhkiG9w0BAQsFADATMREwDwYDVQQDEwhyZWRpcy1jYTAeFw0yMzAyMjMxNDU1MTNaFw0yNDAyMjMxNDU1MTNaMBMxETAPBgNVBAMTCHJlZGlzLWNhMIIBIjANBgkqhkiG9w0BAQEFAAOCAQ8AMIIBCgKCAQEAqqOn6V/e69b+A5mp+u1b79duxX59UoKk21cjywol2tg5GfTxq16xhYne+g1jy91wRz36K1El9Qa8OPyJCGbe+Ab2iMQ4361X4CTMSMd18dLjjy+urm2xoyCM82MZO14oLr2J2yJk1DFERwW5GFVFluJto/LmwY5eA/7GK3nm5bqZQaYgqgpHGuypcjM1AMubw7m9n55Nol93jytr3eFUQcZKKFqJlP6xJJgFltsGwDwSu3sjolwuy7JHvNTgyC/nkKwQ899nF4UN3QaYtH9WMShTHzIrIFQLjxk/qq3UKgIqah/Wv/nVG9JWRGaodu/suSVM7w4RrR1KTTmWzdkpiQIDAQABo2EwXzAOBgNVHQ8BAf8EBAMCAqQwHQYDVR0lBBYwFAYIKwYBBQUHAwEGCCsGAQUFBwMCMA8GA1UdEwEB/wQFMAMBAf8wHQYDVR0OBBYEFPFhc8RVSce6AH5fG2Wq++gw/EbuMA0GCSqGSIb3DQEBCwUAA4IBAQCcAIJiEP3SITKiMVPPvbHTSfkwSIi33LC5JwozXqDH8I9J2PCgbTGrnvlfau3VzhRuve7kobWsWtZoiLuo08P1dvEfV2mCgyknIvP0vrY6qqO9YnOObEGQASIkTb5RoAjK/ccNXUP7n6Ck21xAbOXd2JITADZtLlsDPYvmR7IWdVgDFUAlhUf8IrHMtz/XOyBHYX38rEvY7+5UMNUvRwqZ4xrDE/bwIfmBjLMZCuNkQhCrd0SseHECjWuHNIcUeuv6s0p1SpLBlbDtBVoaOQUqKURS2ynqYnLvqNwQuoNG69n4U2IbLNkoV7SzrirJbWgiegob4xr6fkr+n7z41EwO-----END CERTIFICATE-----"

        EVALUATION_USEVM2=true
        EVALUATION_MAXCALLDEPTH=5
        EVALUATION_MAXINTERACTIONEVALUATIONTIMESECONDS=10
        EVALUATION_ALLOWBIGINT=true
        EVALUATION_UNSAFECLIENT=skip
        EVALUATION_INTERNALWRITES=true
        EVALUATION_BLACKLISTED_CONTRACTS="[]"

        BULLMQ_PORT="${NOMAD_PORT_redisdre}"
        BULLMQ_HOST="localhost"
      }

      resources {
        cpu    = 8192
        memory = 8192
      }

      service {
        name = "dre-node-live"
        port = "dre-node"
        
        check {
          name     = "dre-node health check"
          type     = "http"
          path     = "/health"
          interval = "5s"
          timeout  = "10s"
          check_restart {
            limit = 180
            grace = "15s"
          }
        }
      }
    }
  }
}