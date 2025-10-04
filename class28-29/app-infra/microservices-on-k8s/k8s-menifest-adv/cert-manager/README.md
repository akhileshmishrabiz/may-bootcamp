# cert-manager Configuration

This directory contains configurations for using cert-manager with Let's Encrypt certificates as an alternative to AWS ACM.

## Files

- `01-cert-manager-install.yaml` - Instructions for installing cert-manager
- `02-cluster-issuer.yaml` - Let's Encrypt issuer configuration
- `03-certificate.yaml` - Certificate request for craftista domains
- `04-ingress-with-tls.yaml` - Ingress configured for cert-manager TLS

## Installation Steps

### 1. Install cert-manager

```bash
# Install cert-manager CRDs and components
kubectl apply -f https://github.com/cert-manager/cert-manager/releases/download/v1.14.4/cert-manager.yaml

# Wait for cert-manager to be ready
kubectl wait --for=condition=ready pod -l app.kubernetes.io/instance=cert-manager -n cert-manager --timeout=300s

# Verify installation
kubectl get pods -n cert-manager
```

### 2. Create ClusterIssuer

```bash
# Create Let's Encrypt issuers (staging and production)
kubectl apply -f 02-cluster-issuer.yaml

# Verify issuers
kubectl get clusterissuer
```

### 3. Create Certificate

```bash
# Request certificate for your domains
kubectl apply -f 03-certificate.yaml

# Check certificate status
kubectl get certificate -n craftista
kubectl describe certificate craftista-tls -n craftista
```

### 4. Deploy Ingress with TLS

```bash
# Deploy ingress configured for cert-manager
kubectl apply -f 04-ingress-with-tls.yaml

# Check ingress status
kubectl get ingress -n craftista
```

## How It Works

1. **cert-manager** watches for Certificate resources
2. **ClusterIssuer** defines how to obtain certificates (Let's Encrypt)
3. **Certificate** resource requests a certificate for specific domains
4. **HTTP-01 Challenge** validates domain ownership
5. **TLS Secret** is created with the certificate
6. **Ingress** uses the TLS secret for HTTPS

## Verification

```bash
# Check certificate is issued
kubectl get certificate -n craftista craftista-tls

# Check secret is created
kubectl get secret -n craftista craftista-tls-secret

# View certificate details
kubectl describe certificate -n craftista craftista-tls

# Check challenge progress (if pending)
kubectl get challenges -n craftista
```

## Troubleshooting

### Certificate Stuck in Pending

```bash
# Check cert-manager logs
kubectl logs -n cert-manager deployment/cert-manager

# Check challenges
kubectl describe challenges -n craftista

# Common issues:
# - DNS not pointing to ALB yet
# - Firewall blocking port 80
# - Wrong email in ClusterIssuer
```

### HTTP-01 Challenge Failing

```bash
# Ensure ALB allows port 80
# Check ingress has correct annotations
kubectl describe ingress -n craftista

# Test challenge endpoint
curl http://ms.akhileshmishra.tech/.well-known/acme-challenge/test
```

## Using Staging vs Production

Start with staging issuer for testing:
```yaml
cert-manager.io/cluster-issuer: "letsencrypt-staging"
```

Switch to production when ready:
```yaml
cert-manager.io/cluster-issuer: "letsencrypt-prod"
```

## Important Notes

- **Rate Limits**: Let's Encrypt has rate limits (50 certs/week per domain)
- **Use Staging First**: Test with staging to avoid hitting rate limits
- **Email Required**: Valid email needed for Let's Encrypt account
- **Auto-Renewal**: Certificates auto-renew 30 days before expiry
- **DNS Required**: Domains must resolve to ALB for HTTP-01 validation

## Advantages of cert-manager

✅ Free SSL certificates
✅ Automatic renewal
✅ Works with any Kubernetes cluster
✅ Cloud-agnostic solution
✅ Supports multiple issuers

## Disadvantages vs ACM

❌ Additional pods and resources
❌ More complex troubleshooting
❌ Rate limits from Let's Encrypt
❌ Requires HTTP-01 or DNS-01 validation
❌ Not integrated with AWS services