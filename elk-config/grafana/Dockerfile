FROM grafana/grafana:latest

COPY dashboards /etc/grafana/dashboards
COPY provisioning /etc/grafana/provisioning

EXPOSE 3000

CMD ["grafana-server"]
