#!/bin/bash

# Aether-X Ultimate Development Environment Setup

echo "🔧 Setting up Aether-X Ultimate Development Environment..."

# Create necessary directories
mkdir -p logs
mkdir -p temp
mkdir -p docs

# Create .gitignore
cat << 'EOF' > .gitignore
# Python
__pycache__/
*.py[cod]
*$py.class
*.so

# Dependencies
pip-log.txt
pip-delete-this-directory.txt
.venv/
env/
venv/

# Environment variables
.env
.env.local
.env.*.local

# IDE
.vscode/
.idea/
*.swp
*.swo

# OS
.DS_Store
Thumbs.db

# Logs
logs/
*.log

# Temporary files
temp/
tmp/
*.tmp

# Docker
.dockerignore

# Kubernetes
*.kubeconfig

# SSL certificates
*.crt
*.key
*.pem

# Database files
*.db
*.sqlite
*.sqlite3

# Node modules (if any)
node_modules/

# Build artifacts
dist/
build/
EOF

# Create Docker .dockerignore
cat << 'EOF' > .dockerignore
.git
.gitignore
README.md
.dockerignore
*.log
temp/
tmp/
.env
node_modules/
__pycache__/
*.pyc
EOF

# Create development environment configuration
mkdir -p config
cat << 'EOF' > config/development.yaml
# Development configuration
services:
  text-generation:
    port: 8000
    debug: true
    model: gpt2
  image-generation:
    port: 8001
    debug: true
    model: stable-diffusion
  video-generation:
    port: 8002
    debug: true
  ai-models:
    port: 8003
    debug: true
  no-code-development:
    port: 8004
    debug: true
  security:
    port: 8005
    debug: true
    jwt_secret: dev_secret_key
  data-processing:
    port: 8006
    debug: true

databases:
  mysql:
    host: localhost
    port: 3306
    name: aether_x_dev
  postgres:
    host: localhost
    port: 5432
    name: aether_x_dev
  mongodb:
    host: localhost
    port: 27017
    name: aether_x_dev
  redis:
    host: localhost
    port: 6379

kafka:
  bootstrap_servers: localhost:9092
  zookeeper: localhost:2181

monitoring:
  prometheus:
    port: 9090
  grafana:
    port: 3001

api_gateway:
  port: 80
  rate_limit: 1000
EOF

# Create development README
cat << 'EOF' > docs/DEVELOPMENT_ENVIRONMENT.md
# Development Environment Setup

## Prerequisites

- Docker and Docker Compose
- Python 3.9+
- Node.js 16+ (for dashboard development)

## Quick Start

1. Clone the repository
2. Run `./setup-dev.sh`
3. Start services: `docker-compose up -d`
4. Access services:
   - API Gateway: http://localhost
   - Dashboard: http://localhost:3000
   - Development logs: Check `logs/` directory

## Service Development

Each service can be developed independently:

```bash
cd services/<service-name>
python app.py  # Run locally
pytest         # Run tests
```

## Database Development

Initialize databases for development:

```bash
cd infrastructure/databases
./init-databases.sh
docker-compose up -d
```

## Testing

Run tests for all services:

```bash
./test-all.sh
```

Or test individual services:

```bash
cd services/<service-name>
pytest tests/
```

## Monitoring Development

Access monitoring tools:
- Grafana: http://localhost:3001 (admin/admin)
- Prometheus: http://localhost:9090
- Kibana: http://localhost:5601

## Debugging

Enable debug mode for services by setting environment variables:

```bash
export FLASK_DEBUG=1
export DEBUG=True
```

## Hot Reloading

For development, use the `--build` flag with Docker Compose to rebuild on changes:

```bash
docker-compose up --build -d
```
EOF

echo "✅ Development environment setup complete!"
echo ""
echo "📋 Next Steps:"
echo "   1. Review the configuration in config/development.yaml"
echo "   2. Start services: docker-compose up -d"
echo "   3. Check docs/DEVELOPMENT_ENVIRONMENT.md for development guidelines"
echo ""
echo "🔧 Development Commands:"
echo "   Start all services: docker-compose up -d"
echo "   View logs: docker-compose logs -f"
echo "   Stop services: docker-compose down"
echo "   Rebuild services: docker-compose up --build -d"