./scripts/deploy-clickhouse.sh
./scripts/deploy-mongodb.sh

kubectl port-forward -n clickhouse svc/clickhouse-clickhouse-staging 8123:8123
kubectl port-forward -n clickhouse svc/clickhouse-clickhouse-staging 9000:9000
kubectl port-forward -n mongodb svc/mongodb-staging-svc 27017:27017

./scripts/init-clickhouse-hybrid.sh


connect using mongo atlas: mongodb://my-user:staging-password-change-me@localhost:27017/?authMechanism=SCRAM-SHA-256&authSource=admin&directConnection=true

./scripts/deploy-otel-collector.sh
./scripts/setup-opamp-service.sh


<!-- kubectl port-forward -n default svc/otel-collector-staging-otel-collector 4317:4317 -->
kubectl port-forward -n default svc/otel-collector-staging-otel-collector 4318:4318


yarn install
yarn build:common-utils
yarn dotenvx run -f .env.tracefox -- yarn app:dev



helm uninstall mongodb-staging -n mongodb






redeploy collector
kubectl rollout restart deployment -n default -l app.kubernetes.io/name=otel-collector


kubectl logs -n default -l app.kubernetes.io/name=otel-collector -f

uninstall collector


kubectl port-forward -n clickhouse svc/clickhouse-clickhouse-staging 9000:9000





export CLICKSTACK_API_KEY=5741d4c9-ec60-4c63-adcd-6595bacbe27b

for filename in $(tar -tf sample.tar.gz); do
  endpoint="http://localhost:4318/v1/${filename%.json}"
  echo "loading ${filename%.json}"
  tar -xOf sample.tar.gz "$filename" | while read -r line; do
    printf '%s\n' "$line" | curl -s -o /dev/null -X POST "$endpoint" \
    -H "Content-Type: application/json" \
    -H "authorization: ${CLICKSTACK_API_KEY}" \
    --data-binary @-
  done
done









COLLECTOR_POD=$(kubectl get pods -n default -l app=otel-collector -o jsonpath='{.items[0].metadata.name}') && kubectl exec -n default $COLLECTOR_POD -- tail -50 /etc/otel/supervisor-data/agent.log 2>/dev/null | grep -E "error|fail|clickhouse|export" | tail -10


kubectl logs -n default -l app=otel-collector -f | grep -E "error|fail|Exporting"