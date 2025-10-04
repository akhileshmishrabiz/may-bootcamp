# Production Deployment Recommendations for Craftista Microservices

## Domain and Ingress Strategy

### Single Domain with Subdomains Approach
Using subdomain-based routing for better service isolation and cleaner URLs.

**Main Domain:** `ms.akhileshmishra.tech`
**Subdomains:**
- `ms.akhileshmishra.tech` → Frontend service (main website)
- `catalogue.ms.akhileshmishra.tech` → Catalogue service API
- `voting.ms.akhileshmishra.tech` → Voting service API
- `recommendations.ms.akhileshmishra.tech` → Recommendation service API

### Why Subdomains are Better

1. **Clean URLs**: Each service gets its own clean namespace
   - Instead of: `ms.akhileshmishra.tech/api/products/123`
   - You get: `catalogue.ms.akhileshmishra.tech/products/123`

2. **Independent Scaling**: Each subdomain can have its own rate limits and scaling rules

3. **Service Isolation**: Problems with one service don't affect others

4. **Security**: Easier to apply different security policies per service

## TLS/SSL Configuration

### AWS Certificate Manager (ACM)
1. Create a wildcard certificate for `*.ms.akhileshmishra.tech` and `ms.akhileshmishra.tech`
2. This single certificate covers all subdomains
3. ACM handles automatic renewal - no manual work needed

### How TLS Works with ALB
```
User → HTTPS → ALB (with ACM cert) → HTTP → Pods
```
- Users connect securely to ALB using HTTPS
- ALB handles SSL termination (decrypts traffic)
- ALB forwards plain HTTP to your pods (inside secure VPC)
- This is standard practice and secure within AWS VPC

## Production Setup Components

### 1. Single ALB for All Services
- One Application Load Balancer handles all subdomains
- Cost-effective: ~$20/month instead of $100+ for multiple ALBs
- ALB routes based on Host header (which subdomain was requested)

### 2. Ingress Configuration
- One Ingress resource with multiple hosts
- Each host section defines routing for one subdomain
- AWS Load Balancer Controller creates and configures the ALB

### 3. Resource Limits
Each pod should have:
- **Requests**: Minimum resources guaranteed (e.g., 100m CPU, 128Mi memory)
- **Limits**: Maximum resources allowed (e.g., 500m CPU, 512Mi memory)
- Prevents one service from consuming all cluster resources

### 4. Health Checks
- **Liveness Probe**: Restarts pod if it's broken
- **Readiness Probe**: Only sends traffic when pod is ready
- Each service needs proper health endpoints

### 5. Horizontal Pod Autoscaler (HPA)
- Automatically scales pods based on CPU/memory usage
- Example: Scale from 2 to 10 pods when CPU > 70%
- Ensures availability during traffic spikes

## DNS Setup

### Route 53 Configuration
1. You already have hosted zone for `akhileshmishra.tech`
2. Add CNAME records:
   ```
   ms.akhileshmishra.tech → ALB DNS
   catalogue.ms.akhileshmishra.tech → ALB DNS
   voting.ms.akhileshmishra.tech → ALB DNS
   recommendations.ms.akhileshmishra.tech → ALB DNS
   ```
3. All subdomains point to the same ALB

### Alternative: Route 53 Alias Records
- Use Alias records instead of CNAME for better performance
- No additional charges for DNS queries
- Faster DNS resolution

## Step-by-Step Implementation

### 1. Create ACM Certificate
```bash
# In AWS Console → Certificate Manager
# Request certificate for:
# - ms.akhileshmishra.tech
# - *.ms.akhileshmishra.tech
# Choose DNS validation
# Add CNAME records to Route 53 for validation
```

### 2. Deploy Manifests
```bash
# Apply all production manifests
kubectl apply -f k8s-menifest-adv/
```

### 3. Get ALB DNS
```bash
# Get the ALB DNS name
kubectl get ingress -n craftista craftista-ingress

# Output will show:
# ADDRESS: k8s-craftista-xxx.elb.ap-south-1.amazonaws.com
```

### 4. Setup DNS Records
Go to Route 53 → Hosted Zone for `akhileshmishra.tech`:

```
Type: A (Alias)
Name: ms.akhileshmishra.tech
Alias Target: [Your ALB DNS]

Type: A (Alias)  
Name: catalogue.ms.akhileshmishra.tech
Alias Target: [Your ALB DNS]

Type: A (Alias)
Name: voting.ms.akhileshmishra.tech
Alias Target: [Your ALB DNS]

Type: A (Alias)
Name: recommendations.ms.akhileshmishra.tech
Alias Target: [Your ALB DNS]
```

### 5. Test Each Service
```bash
# Test frontend
curl https://ms.akhileshmishra.tech

# Test catalogue API
curl https://catalogue.ms.akhileshmishra.tech/products

# Test voting API
curl https://voting.ms.akhileshmishra.tech/api/origamis

# Test recommendations API
curl https://recommendations.ms.akhileshmishra.tech/api/origami-of-the-day
```

## Ingress Annotations Explained

```yaml
# Force HTTPS redirect
alb.ingress.kubernetes.io/ssl-redirect: "443"

# Use ACM certificate
alb.ingress.kubernetes.io/certificate-arn: arn:aws:acm:ap-south-1:xxx:certificate/xxx

# Internet-facing ALB
alb.ingress.kubernetes.io/scheme: internet-facing

# Target type for pods
alb.ingress.kubernetes.io/target-type: ip

# Listen on both HTTP and HTTPS
alb.ingress.kubernetes.io/listen-ports: '[{"HTTP": 80}, {"HTTPS": 443}]'
```

## Cost Breakdown

### What You're Paying For
- **ALB**: ~$20/month + data transfer ($0.008/GB)
- **ACM Certificate**: Free
- **Route 53 DNS queries**: ~$0.40 per million queries
- **Total**: ~$25/month for production-grade setup

### What You Save
- No multiple load balancers ($20/month each)
- No manual SSL certificate management
- No downtime for certificate renewal
- No additional ingress controllers

## Security Best Practices

1. **Force HTTPS**: All HTTP traffic redirects to HTTPS
2. **Security Groups**: ALB only allows ports 80/443 from internet
3. **Pod Security**: Use SecurityContext to run as non-root
4. **Secrets Management**: Store sensitive data in Kubernetes secrets

## Quick Commands Reference

```bash
# Check ingress status
kubectl get ingress -n craftista

# View ALB details
kubectl describe ingress craftista-ingress -n craftista

# Check pod health
kubectl get pods -n craftista

# View HPA status
kubectl get hpa -n craftista

# Check service endpoints
kubectl get endpoints -n craftista
```

## Troubleshooting

### If ALB is not created:
1. Check AWS Load Balancer Controller logs:
   ```bash
   kubectl logs -n kube-system deployment/aws-load-balancer-controller
   ```

2. Verify IAM permissions are correct

3. Check ingress class is set to "alb"

### If subdomains don't work:
1. Verify DNS propagation (can take 5-10 minutes)
2. Check ACM certificate is validated and issued
3. Ensure certificate ARN is correct in ingress

## Why This Approach Works

- **Simple**: One ingress, one ALB, multiple subdomains
- **Secure**: TLS everywhere with ACM managed certificates
- **Scalable**: Each service scales independently with HPA
- **Cost-effective**: Single ALB for all services
- **Production-ready**: Health checks, autoscaling, resource limits
- **Easy DNS**: All subdomains under ms.akhileshmishra.tech

This setup gives you enterprise-grade deployment without complexity!