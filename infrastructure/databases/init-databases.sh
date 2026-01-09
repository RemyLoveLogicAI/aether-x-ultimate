#!/bin/bash

# Aether-X Ultimate Database Initialization Script

echo "Initializing Aether-X Ultimate Databases..."

# Create MySQL initialization script
mkdir -p mysql-init
cat << 'EOF' > mysql-init/01-create-tables.sql
CREATE DATABASE IF NOT EXISTS aether_x_db;
USE aether_x_db;

CREATE TABLE IF NOT EXISTS users (
    id INT AUTO_INCREMENT PRIMARY KEY,
    username VARCHAR(255) UNIQUE NOT NULL,
    email VARCHAR(255) UNIQUE NOT NULL,
    password_hash VARCHAR(255) NOT NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP
);

CREATE TABLE IF NOT EXISTS apps (
    id INT AUTO_INCREMENT PRIMARY KEY,
    name VARCHAR(255) NOT NULL,
    description TEXT,
    user_id INT,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (user_id) REFERENCES users(id)
);

CREATE TABLE IF NOT EXISTS workflows (
    id INT AUTO_INCREMENT PRIMARY KEY,
    name VARCHAR(255) NOT NULL,
    app_id INT,
    description TEXT,
    structure JSON,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (app_id) REFERENCES apps(id)
);

CREATE TABLE IF NOT EXISTS content_generated (
    id INT AUTO_INCREMENT PRIMARY KEY,
    user_id INT,
    content_type VARCHAR(50),
    content_data TEXT,
    metadata JSON,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (user_id) REFERENCES users(id)
);

CREATE INDEX idx_users_username ON users(username);
CREATE INDEX idx_apps_user_id ON apps(user_id);
CREATE INDEX idx_workflows_app_id ON workflows(app_id);
CREATE INDEX idx_content_user_id ON content_generated(user_id);
EOF

# Create PostgreSQL initialization script
mkdir -p postgres-init
cat << 'EOF' > postgres-init/01-create-tables.sql
CREATE DATABASE aether_x_db;

\c aether_x_db;

CREATE TABLE IF NOT EXISTS users (
    id SERIAL PRIMARY KEY,
    username VARCHAR(255) UNIQUE NOT NULL,
    email VARCHAR(255) UNIQUE NOT NULL,
    password_hash VARCHAR(255) NOT NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE IF NOT EXISTS apps (
    id SERIAL PRIMARY KEY,
    name VARCHAR(255) NOT NULL,
    description TEXT,
    user_id INTEGER REFERENCES users(id),
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE IF NOT EXISTS workflows (
    id SERIAL PRIMARY KEY,
    name VARCHAR(255) NOT NULL,
    app_id INTEGER REFERENCES apps(id),
    description TEXT,
    structure JSONB,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE IF NOT EXISTS content_generated (
    id SERIAL PRIMARY KEY,
    user_id INTEGER REFERENCES users(id),
    content_type VARCHAR(50),
    content_data TEXT,
    metadata JSONB,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX IF NOT EXISTS idx_users_username ON users(username);
CREATE INDEX IF NOT EXISTS idx_apps_user_id ON apps(user_id);
CREATE INDEX IF NOT EXISTS idx_workflows_app_id ON workflows(app_id);
CREATE INDEX IF NOT EXISTS idx_content_user_id ON content_generated(user_id);
EOF

# Create MongoDB initialization script
mkdir -p mongodb-init
cat << 'EOF' > mongodb-init/01-create-collections.js
db = db.getSiblingDB('aether_x_db');

// Create collections with validation
db.createCollection("users", {
  validator: {
    $jsonSchema: {
      bsonType: "object",
      required: ["username", "email", "password_hash", "created_at"],
      properties: {
        username: { bsonType: "string" },
        email: { bsonType: "string" },
        password_hash: { bsonType: "string" },
        created_at: { bsonType: "date" },
        updated_at: { bsonType: "date" }
      }
    }
  }
});

db.createCollection("apps", {
  validator: {
    $jsonSchema: {
      bsonType: "object",
      required: ["name", "user_id", "created_at"],
      properties: {
        name: { bsonType: "string" },
        description: { bsonType: "string" },
        user_id: { bsonType: "objectId" },
        created_at: { bsonType: "date" }
      }
    }
  }
});

db.createCollection("workflows", {
  validator: {
    $jsonSchema: {
      bsonType: "object",
      required: ["name", "app_id", "created_at"],
      properties: {
        name: { bsonType: "string" },
        app_id: { bsonType: "objectId" },
        description: { bsonType: "string" },
        structure: { bsonType: "object" },
        created_at: { bsonType: "date" }
      }
    }
  }
});

db.createCollection("content_generated", {
  validator: {
    $jsonSchema: {
      bsonType: "object",
      required: ["user_id", "content_type", "created_at"],
      properties: {
        user_id: { bsonType: "objectId" },
        content_type: { bsonType: "string" },
        content_data: { bsonType: "string" },
        metadata: { bsonType: "object" },
        created_at: { bsonType: "date" }
      }
    }
  }
});

// Create indexes
db.users.createIndex({ "username": 1 }, { unique: true });
db.users.createIndex({ "email": 1 }, { unique: true });
db.apps.createIndex({ "user_id": 1 });
db.workflows.createIndex({ "app_id": 1 });
db.content_generated.createIndex({ "user_id": 1 });
EOF

# Create Cassandra initialization script
mkdir -p cassandra-init
cat << 'EOF' > cassandra-init/01-create-keyspace.cql
CREATE KEYSPACE IF NOT EXISTS aether_x_keyspace 
WITH REPLICATION = { 
  'class' : 'SimpleStrategy', 
  'replication_factor' : 1 
};

USE aether_x_keyspace;

CREATE TABLE IF NOT EXISTS users (
    id UUID PRIMARY KEY,
    username text,
    email text,
    password_hash text,
    created_at timestamp,
    updated_at timestamp
);

CREATE TABLE IF NOT EXISTS apps (
    id UUID PRIMARY KEY,
    name text,
    description text,
    user_id UUID,
    created_at timestamp
);

CREATE TABLE IF NOT EXISTS workflows (
    id UUID PRIMARY KEY,
    name text,
    app_id UUID,
    description text,
    structure text,
    created_at timestamp
);

CREATE TABLE IF NOT EXISTS content_generated (
    id UUID PRIMARY KEY,
    user_id UUID,
    content_type text,
    content_data text,
    metadata text,
    created_at timestamp
);

CREATE INDEX IF NOT EXISTS idx_users_username ON users (username);
CREATE INDEX IF NOT EXISTS idx_apps_user_id ON apps (user_id);
CREATE INDEX IF NOT EXISTS idx_workflows_app_id ON workflows (app_id);
CREATE INDEX IF NOT EXISTS idx_content_user_id ON content_generated (user_id);
EOF

echo "Database initialization scripts created successfully!"
echo ""
echo "To start the databases, run:"
echo "  cd infrastructure/databases && docker-compose up -d"
echo ""
echo "To stop the databases, run:"
echo "  cd infrastructure/databases && docker-compose down"