# Weather App Monitoring Configuration

This directory contains monitoring configurations for the Weather App project.

## Structure

- `grafana-dashboards/` - Pre-built Grafana dashboards
- `alert-rules.yaml` - Prometheus alert rules
- `README.md` - Monitoring setup guide

## Components

### Prometheus
- Metrics collection from EKS, RDS, ALB, and Application
- 7-day retention (configured for project scope)
- Custom application metrics

### Grafana
- Pre-built dashboards for Weather App monitoring
- Admin access: admin/598684
- Email alerts: pankajshakya12345@gmail.com

### AlertManager
- Email notifications for critical issues
- Custom alert rules for application health

## Access URLs

After deployment:
- Grafana: http://<grafana-alb-dns>.elb.amazonaws.com
- Prometheus: http://<prometheus-service>.monitoring.svc.cluster.local:9090

## Metrics Collected

### Application Metrics
- Request count and rate
- Response time percentiles
- Error rates by type
- Database connection count
- Weather API response time

### Infrastructure Metrics
- EKS cluster metrics
- RDS performance metrics
- ALB request/response metrics
- Node resource utilization

## Alert Rules

- High CPU/Memory usage
- Database connection issues
- Application error spikes
- API response time degradation
- Storage space warnings

## Dashboards

1. **Weather App Overview** - Main application metrics
2. **Infrastructure Health** - EKS, RDS, ALB status
3. **Performance Analysis** - Response times and throughput
4. **Error Analysis** - Error rates and patterns

## Configuration

All monitoring components are configured via Terraform:
- `terraform/prometheus.tf` - Prometheus infrastructure
- `terraform/grafana.tf` - Grafana infrastructure
- `terraform/variables.tf` - Monitoring variables

## Security

- Prometheus runs with least privilege
- Grafana admin password configured
- Network access restricted to internal services
- No public exposure of metrics endpoints