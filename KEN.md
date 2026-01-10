../scripts/reset-hybrid-db.sh
../scripts/init-clickhouse-hybrid.sh
yarn dotenvx run -f .env.hybrid -- yarn app:dev